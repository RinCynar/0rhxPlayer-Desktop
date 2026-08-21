pub const EQ_FREQUENCIES: [f32; 10] = [
    31.25, 62.5, 125.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0, 16000.0,
];

#[derive(Clone, Debug)]
pub struct BiquadFilter {
    b0: f32,
    b1: f32,
    b2: f32,
    a1: f32,
    a2: f32,
    x1: [f32; 2],
    x2: [f32; 2],
    y1: [f32; 2],
    y2: [f32; 2],
}

impl BiquadFilter {
    pub fn new_peaking(sample_rate: f32, freq: f32, gain_db: f32, q: f32) -> Self {
        if gain_db.abs() < 0.05 {
            return Self {
                b0: 1.0,
                b1: 0.0,
                b2: 0.0,
                a1: 0.0,
                a2: 0.0,
                x1: [0.0; 2],
                x2: [0.0; 2],
                y1: [0.0; 2],
                y2: [0.0; 2],
            };
        }

        let clamped_gain = gain_db.clamp(-12.0, 12.0);
        let a = 10.0f32.powf(clamped_gain / 40.0);
        let w0 = 2.0 * std::f32::consts::PI * freq / sample_rate;
        let alpha = (w0.sin()) / (2.0 * q);
        let cos_w0 = w0.cos();

        let b0 = 1.0 + alpha * a;
        let b1 = -2.0 * cos_w0;
        let b2 = 1.0 - alpha * a;
        let a0 = 1.0 + alpha / a;
        let a1 = -2.0 * cos_w0;
        let a2 = 1.0 - alpha / a;

        Self {
            b0: b0 / a0,
            b1: b1 / a0,
            b2: b2 / a0,
            a1: a1 / a0,
            a2: a2 / a0,
            x1: [0.0; 2],
            x2: [0.0; 2],
            y1: [0.0; 2],
            y2: [0.0; 2],
        }
    }

    #[inline(always)]
    pub fn process_sample(&mut self, sample: f32, ch: usize) -> f32 {
        let ch_idx = if ch < 2 { ch } else { 0 };
        let out = self.b0 * sample + self.b1 * self.x1[ch_idx] + self.b2 * self.x2[ch_idx]
            - self.a1 * self.y1[ch_idx]
            - self.a2 * self.y2[ch_idx];

        self.x2[ch_idx] = self.x1[ch_idx];
        self.x1[ch_idx] = sample;
        self.y2[ch_idx] = self.y1[ch_idx];
        self.y1[ch_idx] = out;

        out
    }
}

pub struct Equalizer {
    enabled: bool,
    preamp_linear: f32,
    sample_rate: f32,
    gains: [f32; 10],
    filters: Vec<BiquadFilter>,
}

impl Equalizer {
    pub fn new(sample_rate: f32) -> Self {
        let gains = [0.0f32; 10];
        let mut eq = Self {
            enabled: false,
            preamp_linear: 1.0,
            sample_rate: if sample_rate > 0.0 { sample_rate } else { 48000.0 },
            gains,
            filters: Vec::with_capacity(10),
        };
        eq.recalculate_filters();
        eq
    }

    pub fn set_enabled(&mut self, enabled: bool) {
        self.enabled = enabled;
    }

    pub fn set_preamp(&mut self, preamp_db: f32) {
        let clamped = preamp_db.clamp(-12.0, 12.0);
        self.preamp_linear = 10.0f32.powf(clamped / 20.0);
    }

    pub fn set_bands(&mut self, bands: &[f32]) {
        for (i, &gain) in bands.iter().take(10).enumerate() {
            self.gains[i] = gain.clamp(-12.0, 12.0);
        }
        self.recalculate_filters();
    }

    pub fn set_sample_rate(&mut self, sample_rate: f32) {
        if (self.sample_rate - sample_rate).abs() > 1.0 && sample_rate > 0.0 {
            self.sample_rate = sample_rate;
            self.recalculate_filters();
        }
    }

    fn recalculate_filters(&mut self) {
        self.filters.clear();
        for i in 0..10 {
            let freq = EQ_FREQUENCIES[i];
            let gain = self.gains[i];
            // Q = 1.414 for 1-octave band spacing
            let filter = BiquadFilter::new_peaking(self.sample_rate, freq, gain, 1.414);
            self.filters.push(filter);
        }
    }

    pub fn process_interleaved(&mut self, data: &mut [f32], channels: usize) {
        if !self.enabled {
            return;
        }

        let preamp = self.preamp_linear;
        for (i, sample) in data.iter_mut().enumerate() {
            let ch = if channels > 0 { i % channels } else { 0 };
            let mut s = *sample * preamp;
            for filter in self.filters.iter_mut() {
                s = filter.process_sample(s, ch);
            }
            // Soft clipping prevention
            *sample = s.clamp(-1.0, 1.0);
        }
    }
}