use super::SenseVoiceModel;
use anyhow::{anyhow, Result};
use kaldi_fbank_rust_kautism::{
    FbankOptions, FrameExtractionOptions, MelBanksOptions, OnlineFbank,
};
use ndarray::{s, Array, Array2, Array3};
use rayon::prelude::*;
use std::borrow::Cow;
use std::ffi::CStr;

impl SenseVoiceModel {
    pub fn extract_fbank(&self, audio_samples: &[f32]) -> Result<Array2<f32>> {
        if audio_samples.is_empty() {
            return Err(anyhow!("音频数据为空"));
        }

        self.compute_fbank_features(&audio_samples)
    }

    pub fn preprocess_audio(&self, audio_samples: &[f32]) -> Result<Array3<f32>> {
        if audio_samples.is_empty() {
            return Err(anyhow!("音频数据为空"));
        }

        let t0 = std::time::Instant::now();
        let t1 = std::time::Instant::now();

        let fbank_features = self.compute_fbank_features(audio_samples)?;
        let t2 = std::time::Instant::now();

        let lfr_features = self.apply_lfr(&fbank_features)?;
        let (n_frames_560d, n_mels_560d) = lfr_features.dim();
        let t3 = std::time::Instant::now();

        let cmvn_features = self.apply_cmvn(&lfr_features)?;
        let t4 = std::time::Instant::now();

        let array = Array::from_shape_vec(
            (1, n_frames_560d, n_mels_560d),
            cmvn_features.into_raw_vec_and_offset().0,
        )?;

        let bytes_fbank =
            (fbank_features.dim().0 * fbank_features.dim().1 * std::mem::size_of::<f32>()) as u64;
        let bytes_lfr =
            (lfr_features.dim().0 * lfr_features.dim().1 * std::mem::size_of::<f32>()) as u64;
        let bytes_cmvn = (n_frames_560d * n_mels_560d * std::mem::size_of::<f32>()) as u64;
        tracing::debug!(
            dur_pre_emph = (t1 - t0).as_secs_f64(),
            dur_fbank = (t2 - t1).as_secs_f64(),
            dur_lfr = (t3 - t2).as_secs_f64(),
            dur_cmvn = (t4 - t3).as_secs_f64(),
            bytes_fbank,
            bytes_lfr,
            bytes_cmvn,
            n_frames = n_frames_560d,
            feat_dim = n_mels_560d,
            "SenseVoice preprocess"
        );

        Ok(array)
    }

    fn compute_fbank_features(&self, waveform: &[f32]) -> Result<Array2<f32>> {
        let opt = FbankOptions {
            frame_opts: FrameExtractionOptions {
                samp_freq: 16000.0,
                window_type: CStr::from_bytes_with_nul(b"hamming\0").unwrap().as_ptr(),
                dither: 0.0,
                frame_shift_ms: 10.0,
                frame_length_ms: 25.0,
                snip_edges: true,
                remove_dc_offset: true,
                preemph_coeff: 0.97,
                round_to_power_of_two: true,
                ..Default::default()
            },
            mel_opts: MelBanksOptions {
                num_bins: 80,
                low_freq: 20.0,
                high_freq: 0.0,
                is_librosa: false,
                ..Default::default()
            },
            energy_floor: 0.0,
            use_log_fbank: true,
            use_power: true,
            htk_compat: false,
            raw_energy: false,
            ..Default::default()
        };

        let mut fbank = OnlineFbank::new(opt);

        let scaled_waveform = if self.meta.normalize_samples == 0 {
            let scale = (1 << 15) as f32;
            let mut v = waveform.to_vec();
            v.iter_mut().for_each(|x| *x *= scale);
            Cow::Owned(v)
        } else {
            Cow::Borrowed(waveform)
        };
        fbank.accept_waveform(16000.0, &scaled_waveform);

        let frames = fbank.num_ready_frames();

        let mut fbank_feats_flat = Vec::with_capacity(frames as usize * 80);
        for i in 0..frames {
            let frame = fbank
                .get_frame(i)
                .ok_or_else(|| anyhow!("Failed to get frame {} from fbank", i))?;
            fbank_feats_flat.extend_from_slice(frame);
        }

        let fbank_array =
            Array2::from_shape_vec((frames as usize, 80), fbank_feats_flat).map_err(|e| {
                anyhow!(
                    "Failed to create fbank array with shape ({}, {}): {}",
                    frames,
                    80,
                    e
                )
            })?;

        Ok(fbank_array)
    }

    pub fn apply_lfr(&self, features: &Array2<f32>) -> Result<Array2<f32>> {
        let lfr_m = self.meta.window_size as usize;
        let lfr_n = self.meta.window_shift as usize;

        let (num_frames, feat_dim) = features.dim();

        if num_frames == 0 {
            return Ok(Array2::zeros((0, feat_dim * lfr_m)));
        }
        if num_frames < lfr_m {
            return Ok(Array2::zeros((0, feat_dim * lfr_m)));
        }

        let out_num_frames = (num_frames - lfr_m) / lfr_n + 1;
        let mut lfr_features = Array2::zeros((out_num_frames, feat_dim * lfr_m));

        for i in 0..out_num_frames {
            let start_frame = i * lfr_n;
            for j in 0..lfr_m {
                let src_idx = start_frame + j;
                let mut dst = lfr_features.slice_mut(s![i, j * feat_dim..(j + 1) * feat_dim]);
                let src = features.slice(s![src_idx, ..]);
                dst.assign(&src);
            }
        }

        if lfr_features.dim().1 != feat_dim * lfr_m {
            return Err(anyhow!(
                "LFR 输出维度不一致: {} != {}",
                lfr_features.dim().1,
                feat_dim * lfr_m
            ));
        }

        Ok(lfr_features)
    }

    pub fn apply_cmvn(&self, features: &Array2<f32>) -> Result<Array2<f32>> {
        let (n_frames, n_features) = features.dim();

        if n_frames == 0 {
            return Ok(Array2::zeros((0, n_features)));
        }

        let neg_mean = &self.meta.neg_mean;
        let inv_stddev = &self.meta.inv_stddev;

        if neg_mean.is_empty() || inv_stddev.is_empty() {
            return Ok(features.to_owned());
        }

        if neg_mean.len() != n_features || inv_stddev.len() != n_features {
            return Err(anyhow!(
                "CMVN参数维度与特征维度不匹配: 期望{}维，实际{}维",
                neg_mean.len(),
                n_features
            ));
        }

        let mut normalized = Array2::zeros((n_frames, n_features));

        for (i, row_in) in features.rows().into_iter().enumerate() {
            let mut row_out = normalized.row_mut(i);
            for (j, &val) in row_in.iter().enumerate() {
                row_out[j] = (val + neg_mean[j]) * inv_stddev[j];
            }
        }

        Ok(normalized)
    }

    pub fn preprocess_audio_batch(
        &self,
        audio_samples_list: &[&[f32]],
    ) -> Result<Vec<Array3<f32>>> {
        audio_samples_list
            .par_iter()
            .map(|audio_samples| self.preprocess_audio(audio_samples))
            .collect()
    }
}
