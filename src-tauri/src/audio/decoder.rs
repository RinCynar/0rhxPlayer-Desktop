use std::fs::File;
use std::path::Path;
use symphonia::core::audio::{AudioBufferRef, SampleBuffer};
use symphonia::core::codecs::{Decoder, DecoderOptions};
use symphonia::core::errors::Error as SymphoniaError;
use symphonia::core::formats::{FormatOptions, FormatReader, SeekMode, SeekTo};
use symphonia::core::io::MediaSourceStream;
use symphonia::core::meta::MetadataOptions;
use symphonia::core::probe::Hint;
use symphonia::core::units::{Time, TimeBase};

pub struct AudioDecoder {
    reader: Box<dyn FormatReader>,
    decoder: Box<dyn Decoder>,
    track_id: u32,
    time_base: Option<TimeBase>,
    sample_rate: u32,
    bits_per_sample: Option<u32>,
    channels: usize,
    duration_ms: u64,
}

impl AudioDecoder {
    pub fn open<P: AsRef<Path>>(path: P) -> Result<Self, String> {
        let file = File::open(path.as_ref())
            .map_err(|e| format!("Failed to open audio file: {}", e))?;
        let mss = MediaSourceStream::new(Box::new(file), Default::default());

        let mut hint = Hint::new();
        if let Some(ext) = path.as_ref().extension().and_then(|s| s.to_str()) {
            hint.with_extension(ext);
        }

        let fmt_opts = FormatOptions {
            enable_gapless: true,
            ..Default::default()
        };
        let meta_opts: MetadataOptions = Default::default();

        let probed = symphonia::default::get_probe()
            .format(&hint, mss, &fmt_opts, &meta_opts)
            .map_err(|e| format!("Failed to probe audio format: {}", e))?;

        let reader = probed.format;

        // Select the first valid audio track
        let track = reader
            .tracks()
            .iter()
            .find(|t| t.codec_params.codec != symphonia::core::codecs::CODEC_TYPE_NULL)
            .ok_or_else(|| "No supported audio track found in file".to_string())?;

        let track_id = track.id;
        let time_base = track.codec_params.time_base;
        let sample_rate = track.codec_params.sample_rate.unwrap_or(44100);
        let bits_per_sample = track.codec_params.bits_per_sample;
        let channels = track
            .codec_params
            .channels
            .map(|c| c.count())
            .unwrap_or(2);

        // Calculate duration
        let duration_ms = if let (Some(n_frames), Some(tb)) =
            (track.codec_params.n_frames, track.codec_params.time_base)
        {
            let time = tb.calc_time(n_frames);
            (time.seconds as u64 * 1000) + (time.frac * 1000.0) as u64
        } else if let Some(n_frames) = track.codec_params.n_frames {
            (n_frames * 1000) / (sample_rate as u64)
        } else {
            0
        };

        let dec_opts: DecoderOptions = Default::default();
        let decoder = symphonia::default::get_codecs()
            .make(&track.codec_params, &dec_opts)
            .map_err(|e| format!("Failed to initialize audio decoder: {}", e))?;

        Ok(Self {
            reader,
            decoder,
            track_id,
            time_base,
            sample_rate,
            bits_per_sample,
            channels,
            duration_ms,
        })
    }

    pub fn sample_rate(&self) -> u32 {
        self.sample_rate
    }

    pub fn bits_per_sample(&self) -> Option<u32> {
        self.bits_per_sample
    }

    pub fn channels(&self) -> usize {
        self.channels
    }

    pub fn duration_ms(&self) -> u64 {
        self.duration_ms
    }

    /// Read and decode the next audio packet into interleaved f32 samples.
    /// Returns Ok(Some(samples)) or Ok(None) at EOF.
    pub fn next_samples(&mut self) -> Result<Option<Vec<f32>>, String> {
        loop {
            let packet = match self.reader.next_packet() {
                Ok(packet) => packet,
                Err(SymphoniaError::IoError(ref err))
                    if err.kind() == std::io::ErrorKind::UnexpectedEof =>
                {
                    return Ok(None);
                }
                Err(SymphoniaError::IoError(_)) => return Ok(None),
                Err(SymphoniaError::ResetRequired) => {
                    self.decoder.reset();
                    continue;
                }
                Err(e) => return Err(format!("Error reading next packet: {}", e)),
            };

            if packet.track_id() != self.track_id {
                continue;
            }

            match self.decoder.decode(&packet) {
                Ok(decoded) => {
                    let samples = Self::convert_buffer_to_f32(&decoded);
                    return Ok(Some(samples));
                }
                Err(SymphoniaError::DecodeError(e)) => {
                    eprintln!("Warning: decode error, skipping packet: {}", e);
                    continue;
                }
                Err(SymphoniaError::ResetRequired) => {
                    self.decoder.reset();
                    continue;
                }
                Err(e) => return Err(format!("Critical decode error: {}", e)),
            }
        }
    }

    /// Seek to a specific timestamp in milliseconds
    pub fn seek(&mut self, pos_ms: u64) -> Result<u64, String> {
        let seconds = pos_ms / 1000;
        let frac = (pos_ms % 1000) as f64 / 1000.0;
        let time = Time::from(seconds as f64 + frac);

        let make_seek = |tb_opt: Option<TimeBase>, trk_id: u32| {
            if let Some(tb) = tb_opt {
                let ts = tb.calc_timestamp(time);
                SeekTo::TimeStamp { ts, track_id: trk_id }
            } else {
                SeekTo::Time {
                    time,
                    track_id: Some(trk_id),
                }
            }
        };

        let seek_to_accurate = make_seek(self.time_base, self.track_id);
        match self.reader.seek(SeekMode::Accurate, seek_to_accurate) {
            Ok(seeked_to) => {
                self.decoder.reset();
                let actual_ms = if let Some(tb) = self.time_base {
                    let t = tb.calc_time(seeked_to.actual_ts);
                    (t.seconds * 1000) + (t.frac * 1000.0) as u64
                } else {
                    pos_ms
                };
                Ok(actual_ms)
            }
            Err(e) => {
                let seek_to_coarse = make_seek(self.time_base, self.track_id);
                match self.reader.seek(SeekMode::Coarse, seek_to_coarse) {
                    Ok(seeked_to) => {
                        self.decoder.reset();
                        let actual_ms = if let Some(tb) = self.time_base {
                            let t = tb.calc_time(seeked_to.actual_ts);
                            (t.seconds * 1000) + (t.frac * 1000.0) as u64
                        } else {
                            pos_ms
                        };
                        Ok(actual_ms)
                    }
                    Err(e2) => Err(format!("Seek failed: {} / {}", e, e2)),
                }
            }
        }
    }

    fn convert_buffer_to_f32(buffer: &AudioBufferRef) -> Vec<f32> {
        let spec = *buffer.spec();
        let mut sample_buf = SampleBuffer::<f32>::new(buffer.capacity() as u64, spec);
        sample_buf.copy_interleaved_ref(buffer.clone());
        sample_buf.samples().to_vec()
    }
}

/// Helper function to resample and channel-convert samples into standard Stereo (2-channel) target_sample_rate
pub fn convert_and_resample(
    input: &[f32],
    src_channels: usize,
    src_rate: u32,
    dst_channels: usize,
    dst_rate: u32,
) -> Vec<f32> {
    if input.is_empty() {
        return Vec::new();
    }

    let stereo_samples: Vec<f32> = match (src_channels, dst_channels) {
        (1, 2) => {
            let mut out = Vec::with_capacity(input.len() * 2);
            for &sample in input {
                out.push(sample);
                out.push(sample);
            }
            out
        }
        (2, 2) => input.to_vec(),
        (n, 2) if n > 2 => {
            let frames = input.len() / n;
            let mut out = Vec::with_capacity(frames * 2);
            for i in 0..frames {
                let left = input[i * n];
                let right = input[i * n + 1];
                out.push(left);
                out.push(right);
            }
            out
        }
        _ => input.to_vec(),
    };

    if src_rate == dst_rate {
        return stereo_samples;
    }

    let ratio = dst_rate as f64 / src_rate as f64;
    let in_frames = stereo_samples.len() / dst_channels;
    let out_frames = (in_frames as f64 * ratio).round() as usize;
    let mut resampled = Vec::with_capacity(out_frames * dst_channels);

    for i in 0..out_frames {
        let src_index_exact = i as f64 / ratio;
        let index_floor = src_index_exact.floor() as usize;
        let frac = (src_index_exact - index_floor as f64) as f32;

        let idx0 = index_floor.min(in_frames.saturating_sub(1));
        let idx1 = (index_floor + 1).min(in_frames.saturating_sub(1));

        for ch in 0..dst_channels {
            let s0 = stereo_samples[idx0 * dst_channels + ch];
            let s1 = stereo_samples[idx1 * dst_channels + ch];
            let interpolated = s0 + (s1 - s0) * frac;
            resampled.push(interpolated);
        }
    }

    resampled
}
