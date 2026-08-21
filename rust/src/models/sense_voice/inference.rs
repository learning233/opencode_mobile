use super::SenseVoiceModel;
use crate::process::voice_text::VoiceText;
use anyhow::{anyhow, Result};
use futures::executor::block_on;
use ndarray::Array3;
use ort::session::SessionInputValue;
use ort::value::Value;

impl SenseVoiceModel {
    pub async fn recognize(
        &mut self,
        features: Array3<f32>,
        language: Option<&str>,
        use_itn: Option<bool>,
    ) -> Result<VoiceText> {
        let n_frames = features.shape()[1];

        if n_frames == 0 {
            return Ok(VoiceText {
                content: String::new(),
                language: None,
                emotion: Some("neutral".to_string()),
                event: Some("nospeech".to_string()),
                confidence: 0.0,
                timestamp: None,
                segments: Vec::new(),
                segments_info: None,
            });
        }

        let features_tensor = Value::from_array((
            features.shape(),
            features.to_owned().into_raw_vec_and_offset().0,
        ))?;

        let features_length_array = ndarray::Array1::from(vec![n_frames as i32]);
        let features_length_tensor = Value::from_array((
            features_length_array.shape(),
            features_length_array.to_owned().into_raw_vec_and_offset().0,
        ))?;

        let lang_str = language.unwrap_or(&self.config.language);
        let lang_id = *self.meta.lang2id.get(lang_str).unwrap_or(&0);
        let language_array = ndarray::Array1::from(vec![lang_id]);
        let language_tensor = Value::from_array((
            language_array.shape(),
            language_array.to_owned().into_raw_vec_and_offset().0,
        ))?;

        let use_itn_final = use_itn.unwrap_or(self.config.use_itn);
        let text_norm_id = if use_itn_final {
            self.meta.with_itn_id
        } else {
            self.meta.without_itn_id
        };
        let text_norm_array = ndarray::Array1::from(vec![text_norm_id]);
        let text_norm_tensor = Value::from_array((
            text_norm_array.shape(),
            text_norm_array.to_owned().into_raw_vec_and_offset().0,
        ))?;

        let mut inputs = std::collections::HashMap::new();
        inputs.insert("x", SessionInputValue::from(features_tensor));
        inputs.insert("x_length", SessionInputValue::from(features_length_tensor));
        inputs.insert("language", SessionInputValue::from(language_tensor));
        inputs.insert("text_norm", SessionInputValue::from(text_norm_tensor));

        let outputs = self.session.run(inputs)?;

        let output = outputs
            .get("logits")
            .ok_or_else(|| anyhow!("模型没有输出"))?;

        let (shape, data) = output.try_extract_tensor::<f32>()?;

        if shape.len() != 3 {
            return Err(anyhow!(
                "输出张量维度不正确，期望3维，实际{}维",
                shape.len()
            ));
        }

        let vocab_size = shape[2] as usize;

        let mut decoded_ids: Vec<u32> = Vec::new();
        let mut decoded_probs: Vec<f32> = Vec::new();
        let mut previous_token_id = 0u32;

        for row in data.chunks_exact(vocab_size) {
            let mut best_idx = 0usize;
            let mut max_logit = f32::NEG_INFINITY;
            for (i, &x) in row.iter().enumerate() {
                if x > max_logit {
                    max_logit = x;
                    best_idx = i;
                }
            }
            let best_token_id = best_idx as u32;
            if best_token_id == self.meta.blank_id as u32 || best_token_id == previous_token_id {
                previous_token_id = best_token_id;
                continue;
            }
            previous_token_id = best_token_id;
            let probability = 1.0 / (1.0 + (-(max_logit / 10.0)).exp());
            decoded_ids.push(best_token_id);
            decoded_probs.push(probability);
        }

        drop(outputs);

        self.decode_tokens(decoded_ids, decoded_probs)
    }

    pub fn recognize_blocking(
        &mut self,
        features: Array3<f32>,
        language: Option<&str>,
        use_itn: Option<bool>,
    ) -> Result<VoiceText> {
        block_on(self.recognize(features, language, use_itn))
    }

    pub fn lfr_params(&self) -> (usize, usize) {
        (
            self.meta.window_size as usize,
            self.meta.window_shift as usize,
        )
    }

    pub fn cmvn_params(&self) -> Option<(Vec<f32>, Vec<f32>)> {
        if self.meta.neg_mean.is_empty() || self.meta.inv_stddev.is_empty() {
            None
        } else {
            Some((self.meta.neg_mean.clone(), self.meta.inv_stddev.clone()))
        }
    }

    pub fn sample_scale(&self) -> f32 {
        if self.meta.normalize_samples == 0 {
            (1 << 15) as f32
        } else {
            1.0
        }
    }

    pub fn get_normalize_samples(&self) -> i32 {
        self.meta.normalize_samples
    }

    pub fn base_feature_dim(&self) -> usize {
        80
    }
}
