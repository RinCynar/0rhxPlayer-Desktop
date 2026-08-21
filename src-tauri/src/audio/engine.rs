use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use cpal::{SampleRate, StreamConfig};
use serde::{Deserialize, Serialize};
use std::collections::VecDeque;
use std::path::Path;
use std::sync::atomic::{AtomicBool, AtomicU32, AtomicU64, AtomicU8, Ordering};
use std::sync::mpsc::{channel, Receiver, Sender};
use std::sync::{Arc, Mutex};
use std::thread::{self, JoinHandle};
use std::time::Duration;
use tauri::{AppHandle, Emitter};

use super::decoder::{convert_and_resample, AudioDecoder};
use super::eq::Equalizer;
use crate::metadata::{fast_metadata, parse_metadata, TrackMetadata};

const STATUS_STOPPED: u8 = 0;
const STATUS_PLAYING: u8 = 1;
const STATUS_PAUSED: u8 = 2;
const STATUS_BUFFERING: u8 = 3;

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
pub enum PlaybackStatus {
    #[serde(rename = "stopped")]
    Stopped,
    #[serde(rename = "playing")]
    Playing,
    #[serde(rename = "paused")]
    Paused,
    #[serde(rename = "buffering")]
    Buffering,
}

impl From<u8> for PlaybackStatus {
    fn from(val: u8) -> Self {
        match val {
            STATUS_PLAYING => PlaybackStatus::Playing,
            STATUS_PAUSED => PlaybackStatus::Paused,
            STATUS_BUFFERING => PlaybackStatus::Buffering,
            _ => PlaybackStatus::Stopped,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PlaybackState {
    pub status: PlaybackStatus,
    pub current_track: Option<TrackMetadata>,
    pub position_ms: u64,
    pub duration_ms: u64,
    pub volume: f32,
    pub is_muted: bool,
    pub shuffle: bool,
    pub repeat_mode: String,
}

#[allow(dead_code)]
enum EngineCmd {
  Load(String, u64),
  Play,
  Pause,
  Stop,
  Seek(u64),
  SetVolume(f32),
}


pub struct AudioEngine {
    cmd_tx: Sender<EngineCmd>,
    status: Arc<AtomicU8>,
    position_ms: Arc<AtomicU64>,
    duration_ms: Arc<AtomicU64>,
    volume_bits: Arc<AtomicU32>,
    is_muted: Arc<AtomicBool>,
    current_generation: Arc<AtomicU64>,
    current_track: Arc<Mutex<Option<TrackMetadata>>>,
    eq: Arc<Mutex<Equalizer>>,
    _app_handle: AppHandle,
    _worker_handle: JoinHandle<()>,
}

unsafe impl Send for AudioEngine {}
unsafe impl Sync for AudioEngine {}

impl AudioEngine {
    pub fn new(app_handle: AppHandle) -> Result<Self, String> {
        let sample_queue = Arc::new(Mutex::new(VecDeque::<f32>::with_capacity(48000 * 2 * 2)));
        let status = Arc::new(AtomicU8::new(STATUS_STOPPED));
        let position_ms = Arc::new(AtomicU64::new(0));
        let duration_ms = Arc::new(AtomicU64::new(0));
        let volume_bits = Arc::new(AtomicU32::new(1.0f32.to_bits()));
        let is_muted = Arc::new(AtomicBool::new(false));
        let current_generation = Arc::new(AtomicU64::new(0));
        let current_track = Arc::new(Mutex::new(None));
        let eq = Arc::new(Mutex::new(Equalizer::new(48000.0)));

        let (cmd_tx, cmd_rx) = channel::<EngineCmd>();

        let queue_clone = sample_queue.clone();
        let status_clone = status.clone();
        let position_clone = position_ms.clone();
        let duration_clone = duration_ms.clone();
        let generation_clone = current_generation.clone();
        let track_clone = current_track.clone();
        let volume_bits_clone = volume_bits.clone();
        let is_muted_clone = is_muted.clone();
        let eq_clone = eq.clone();
        let app_handle_clone = app_handle.clone();

        let (init_tx, init_rx) = channel::<Result<(), String>>();

        let worker_handle = thread::spawn(move || {
            let host = cpal::default_host();
            let device = match host.default_output_device() {
                Some(d) => d,
                None => {
                    let _ = init_tx.send(Err("No default audio output device available".to_string()));
                    return;
                }
            };

            let supported_config = match device.default_output_config() {
                Ok(c) => c,
                Err(e) => {
                    let _ = init_tx.send(Err(format!("Failed to get default output config: {}", e)));
                    return;
                }
            };

            let sample_rate = supported_config.sample_rate().0;
            let channels = supported_config.channels() as usize;

            if let Ok(mut eq_guard) = eq_clone.lock() {
                eq_guard.set_sample_rate(sample_rate as f32);
            }

            let config = StreamConfig {
                channels: channels as u16,
                sample_rate: SampleRate(sample_rate),
                buffer_size: cpal::BufferSize::Default,
            };

            let cb_queue = queue_clone.clone();
            let cb_status = status_clone.clone();
            let cb_position = position_clone.clone();
            let cb_vol_bits = volume_bits_clone.clone();
            let cb_muted = is_muted_clone.clone();
            let cb_eq = eq_clone.clone();

            let stream_res = device.build_output_stream(
                &config,
                move |data: &mut [f32], _: &cpal::OutputCallbackInfo| {
                    let st = cb_status.load(Ordering::Relaxed);
                    let vol = if cb_muted.load(Ordering::Relaxed) {
                        0.0f32
                    } else {
                        f32::from_bits(cb_vol_bits.load(Ordering::Relaxed))
                    };

                    if st == STATUS_PLAYING {
                        if let Ok(mut queue) = cb_queue.lock() {
                            let mut read_samples = 0;

                            for sample in data.iter_mut() {
                                if let Some(s) = queue.pop_front() {
                                    *sample = s * vol;
                                    read_samples += 1;
                                } else {
                                    *sample = 0.0;
                                }
                            }

                            if read_samples > 0 && channels > 0 && sample_rate > 0 {
                                let frames = (read_samples / channels) as u64;
                                let ms_advanced = (frames * 1000) / (sample_rate as u64);
                                cb_position.fetch_add(ms_advanced, Ordering::Relaxed);
                            }
                        } else {
                            data.fill(0.0);
                        }

                        // Apply DSP 10-band Equalizer
                        if let Ok(mut eq_guard) = cb_eq.lock() {
                            eq_guard.process_interleaved(data, channels);
                        }
                    } else {
                        data.fill(0.0);
                    }
                },
                |err| {
                    eprintln!("CPAL Audio stream error: {}", err);
                },
                None,
            );

            let stream = match stream_res {
                Ok(s) => s,
                Err(e) => {
                    let _ = init_tx.send(Err(format!("Failed to build CPAL audio stream: {}", e)));
                    return;
                }
            };

            if let Err(e) = stream.play() {
                let _ = init_tx.send(Err(format!("Failed to start CPAL stream: {}", e)));
                return;
            }

            let _ = init_tx.send(Ok(()));

            Self::worker_loop(
                cmd_rx,
                queue_clone,
                status_clone,
                position_clone,
                duration_clone,
                generation_clone,
                track_clone,
                app_handle_clone,
                sample_rate,
                channels,
            );

            drop(stream);
        });

        match init_rx.recv() {
            Ok(Ok(())) => Ok(Self {
                cmd_tx,
                status,
                position_ms,
                duration_ms,
                volume_bits,
                is_muted,
                current_generation,
                current_track,
                eq,
                _app_handle: app_handle,
                _worker_handle: worker_handle,
            }),
            Ok(Err(e)) => Err(e),
            Err(e) => Err(format!("Worker initialization failed: {}", e)),
        }
    }

    #[allow(clippy::too_many_arguments)]
    fn worker_loop(
        cmd_rx: Receiver<EngineCmd>,
        sample_queue: Arc<Mutex<VecDeque<f32>>>,
        status: Arc<AtomicU8>,
        position_ms: Arc<AtomicU64>,
        duration_ms: Arc<AtomicU64>,
        current_generation: Arc<AtomicU64>,
        current_track: Arc<Mutex<Option<TrackMetadata>>>,
        app_handle: AppHandle,
        device_sample_rate: u32,
        device_channels: usize,
    ) {
        let mut decoder: Option<AudioDecoder> = None;
        let mut active_gen: u64 = 0;
        let mut is_eof = false;
        let max_buffer_samples = (device_sample_rate as usize * device_channels) * 2; // 2 seconds buffer

        loop {
            // Process commands, skipping superseded Load operations
            while let Ok(cmd) = cmd_rx.try_recv() {
                match cmd {
                    EngineCmd::Load(path, gen) => {
                        // If this generation is superseded by a newer load, skip it immediately
                        if gen < current_generation.load(Ordering::Relaxed) {
                            continue;
                        }

                        // Immediate pre-emption: stop old decoder and clear queue instantly
                        decoder = None;
                        if let Ok(mut queue) = sample_queue.lock() {
                            queue.clear();
                        }
                        position_ms.store(0, Ordering::SeqCst);

                        match AudioDecoder::open(&path) {
                            Ok(dec) => {
                                // Check cancellation again right after opening
                                if gen < current_generation.load(Ordering::Relaxed) {
                                    continue;
                                }

                                active_gen = gen;
                                let mut meta = fast_metadata(Path::new(&path));
                                meta.duration_ms = dec.duration_ms();
                                meta.sample_rate = Some(dec.sample_rate());
                                meta.channels = Some(dec.channels() as u16);

                                duration_ms.store(dec.duration_ms(), Ordering::SeqCst);
                                position_ms.store(0, Ordering::SeqCst);

                                if let Ok(mut t) = current_track.lock() {
                                    *t = Some(meta);
                                }

                                decoder = Some(dec);
                                is_eof = false;
                                status.store(STATUS_PLAYING, Ordering::SeqCst);

                                // Instant pre-decode for zero-latency audio output
                                if let Some(ref mut d) = decoder {
                                    for _ in 0..2 {
                                        if let Ok(Some(raw)) = d.next_samples() {
                                            let resampled = convert_and_resample(
                                                &raw,
                                                d.channels(),
                                                d.sample_rate(),
                                                device_channels,
                                                device_sample_rate,
                                            );
                                            if let Ok(mut queue) = sample_queue.lock() {
                                                queue.extend(resampled);
                                            }
                                        }
                                    }
                                }

                                // Asynchronously extract full metadata and cover artwork in background
                                let path_for_meta = path.clone();
                                let app_handle_for_meta = app_handle.clone();
                                let track_holder = current_track.clone();
                                let gen_holder = current_generation.clone();

                                std::thread::spawn(move || {
                                    if gen_holder.load(Ordering::Relaxed) != gen {
                                        return;
                                    }
                                    if let Ok(full_meta) = parse_metadata(&path_for_meta) {
                                        if gen_holder.load(Ordering::Relaxed) == gen {
                                            if let Ok(mut t) = track_holder.lock() {
                                                *t = Some(full_meta.clone());
                                            }
                                            let _ = app_handle_for_meta.emit("track-metadata-updated", full_meta);
                                        }
                                    }
                                });
                            }
                            Err(e) => {
                                eprintln!("Failed to load audio track: {}", e);
                            }
                        }
                    }
                    EngineCmd::Play => {
                        if decoder.is_some() {
                            status.store(STATUS_PLAYING, Ordering::SeqCst);
                        }
                    }
                    EngineCmd::Pause => {
                        status.store(STATUS_PAUSED, Ordering::SeqCst);
                    }
                    EngineCmd::Stop => {
                        status.store(STATUS_STOPPED, Ordering::SeqCst);
                        position_ms.store(0, Ordering::SeqCst);
                        decoder = None;
                        if let Ok(mut queue) = sample_queue.lock() {
                            queue.clear();
                        }
                    }
                    EngineCmd::Seek(target_ms) => {
                        if let Some(ref mut dec) = decoder {
                            match dec.seek(target_ms) {
                                Ok(actual_ms) => {
                                    if let Ok(mut queue) = sample_queue.lock() {
                                        queue.clear();
                                    }
                                    position_ms.store(actual_ms, Ordering::SeqCst);
                                    is_eof = false;
                                }
                                Err(e) => {
                                    eprintln!("Seek failed in worker: {}", e);
                                }
                            }
                        }
                    }
                    EngineCmd::SetVolume(_) => {}
                }
            }

            let cur_status = status.load(Ordering::Relaxed);
            let latest_gen = current_generation.load(Ordering::Relaxed);

            // If a newer generation has started, stop decoding the old one
            if active_gen < latest_gen {
                decoder = None;
                is_eof = true;
            }

            if cur_status == STATUS_PLAYING && !is_eof {
                if let Some(ref mut dec) = decoder {
                    let cur_len = sample_queue.lock().map(|q| q.len()).unwrap_or(0);
                    if cur_len < max_buffer_samples {
                        match dec.next_samples() {
                            Ok(Some(raw_samples)) => {
                                let resampled = convert_and_resample(
                                    &raw_samples,
                                    dec.channels(),
                                    dec.sample_rate(),
                                    device_channels,
                                    device_sample_rate,
                                );
                                if let Ok(mut queue) = sample_queue.lock() {
                                    queue.extend(resampled);
                                }
                            }
                            Ok(None) => {
                                is_eof = true;
                            }
                            Err(e) => {
                                eprintln!("Error decoding samples: {}", e);
                                is_eof = true;
                            }
                        }
                    } else {
                        thread::sleep(Duration::from_millis(8));
                    }
                } else {
                    thread::sleep(Duration::from_millis(15));
                }
            } else {
                if is_eof && cur_status == STATUS_PLAYING {
                    let queue_len = sample_queue.lock().map(|q| q.len()).unwrap_or(0);
                    if queue_len == 0 {
                        status.store(STATUS_STOPPED, Ordering::SeqCst);
                        let _ = app_handle.emit("track-ended", ());
                    }
                }
                thread::sleep(Duration::from_millis(15));
            }
        }
    }

    pub fn load_track(&self, path: String) -> Result<TrackMetadata, String> {
        let meta = fast_metadata(Path::new(&path));
        let gen = self.current_generation.fetch_add(1, Ordering::SeqCst) + 1;
        self.cmd_tx
            .send(EngineCmd::Load(path, gen))
            .map_err(|e| format!("Failed to send Load command: {}", e))?;
        Ok(meta)
    }

    pub fn play(&self) -> Result<(), String> {
        self.cmd_tx
            .send(EngineCmd::Play)
            .map_err(|e| format!("Failed to send Play command: {}", e))
    }

    pub fn pause(&self) -> Result<(), String> {
        self.cmd_tx
            .send(EngineCmd::Pause)
            .map_err(|e| format!("Failed to send Pause command: {}", e))
    }

    pub fn stop(&self) -> Result<(), String> {
        self.cmd_tx
            .send(EngineCmd::Stop)
            .map_err(|e| format!("Failed to send Stop command: {}", e))
    }

    pub fn seek(&self, position_ms: u64) -> Result<(), String> {
        self.cmd_tx
            .send(EngineCmd::Seek(position_ms))
            .map_err(|e| format!("Failed to send Seek command: {}", e))
    }

    pub fn set_volume(&self, volume: f32) -> Result<(), String> {
        let clamped = volume.clamp(0.0, 1.0);
        self.volume_bits.store(clamped.to_bits(), Ordering::Relaxed);
        self.cmd_tx
            .send(EngineCmd::SetVolume(clamped))
            .map_err(|e| format!("Failed to send SetVolume command: {}", e))
    }

    pub fn get_playback_state(&self) -> PlaybackState {
        let status = self.status.load(Ordering::Relaxed).into();
        let current_track = self.current_track.lock().ok().and_then(|g| g.clone());
        let position_ms = self.position_ms.load(Ordering::Relaxed);
        let duration_ms = self.duration_ms.load(Ordering::Relaxed);
        let volume = f32::from_bits(self.volume_bits.load(Ordering::Relaxed));
        let is_muted = self.is_muted.load(Ordering::Relaxed);

        PlaybackState {
            status,
            current_track,
            position_ms,
            duration_ms,
            volume,
            is_muted,
            shuffle: false,
            repeat_mode: "off".to_string(),
        }
    }

    pub fn set_eq_enabled(&self, enabled: bool) -> Result<(), String> {
        if let Ok(mut eq_guard) = self.eq.lock() {
            eq_guard.set_enabled(enabled);
            Ok(())
        } else {
            Err("Failed to acquire EQ lock".to_string())
        }
    }

    pub fn set_eq_bands(&self, bands: Vec<f32>) -> Result<(), String> {
        if let Ok(mut eq_guard) = self.eq.lock() {
            eq_guard.set_bands(&bands);
            Ok(())
        } else {
            Err("Failed to acquire EQ lock".to_string())
        }
    }

    pub fn set_eq_preamp(&self, preamp_db: f32) -> Result<(), String> {
        if let Ok(mut eq_guard) = self.eq.lock() {
            eq_guard.set_preamp(preamp_db);
            Ok(())
        } else {
            Err("Failed to acquire EQ lock".to_string())
        }
    }
}
