use anyhow::{anyhow, Result};
use audioadapter_buffers::direct::SequentialSlice;
use rubato::{
    Async, FixedAsync, Resampler, SincInterpolationParameters, SincInterpolationType,
    WindowFunction,
};
use std::borrow::Cow;

pub struct AudioProcessor {
    target_sample_rate: u32,
}

impl AudioProcessor {
    pub fn new(target_sample_rate: u32) -> Self {
        Self { target_sample_rate }
    }

    pub fn resample_if_needed<'a>(
        &self,
        samples: &'a [f32],
        current_rate: u32,
    ) -> Result<Cow<'a, [f32]>> {
        if samples.is_empty() {
            return Ok(Cow::Borrowed(samples));
        }
        if current_rate == 0 {
            return Err(anyhow!("Input sample rate cannot be 0"));
        }
        if self.target_sample_rate == 0 {
            return Err(anyhow!("Target sample rate cannot be 0"));
        }
        if current_rate == self.target_sample_rate {
            return Ok(Cow::Borrowed(samples));
        }

        let ratio = self.target_sample_rate as f64 / current_rate as f64;
        let params = SincInterpolationParameters {
            sinc_len: 64,
            f_cutoff: Some(0.99),
            interpolation: SincInterpolationType::Linear,
            oversampling_factor: 256,
            window: WindowFunction::Hann,
        };

        let chunk_size = samples.len().clamp(256, 4096);
        let mut resampler =
            Async::<f32>::new_sinc(ratio, 1.0, &params, chunk_size, 1, FixedAsync::Input)
                .map_err(|e| anyhow!("Resampler init failed: {e}"))?;

        let input_adapter = SequentialSlice::new(samples, 1, samples.len())
            .map_err(|e| anyhow!("Input adapter init failed: {e}"))?;

        let output_len = resampler.process_all_needed_output_len(samples.len());
        let mut output = vec![0.0_f32; output_len.max(1)];
        let output_capacity = output.len();
        let mut output_adapter = SequentialSlice::new_mut(&mut output, 1, output_capacity)
            .map_err(|e| anyhow!("Output adapter init failed: {e}"))?;

        let (_, frames_out) = resampler
            .process_all_into_buffer(&input_adapter, &mut output_adapter, samples.len(), None)
            .map_err(|e| anyhow!("Resampling failed: {e}"))?;

        output.truncate(frames_out);
        Ok(Cow::Owned(output))
    }
}

pub fn float_to_i16_pcm(sample: f32) -> i16 {
    let clamped = sample.clamp(-1.0, 1.0);
    let scaled = clamped * 32768.0;
    scaled.clamp(i16::MIN as f32, i16::MAX as f32) as i16
}
