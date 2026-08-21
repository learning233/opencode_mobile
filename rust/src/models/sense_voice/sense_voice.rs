use anyhow::{anyhow, Result};
use ort::session::Session;
use std::collections::HashMap;
use std::fs;
use std::path::Path;

use crate::models::{build_session_builder_with_level, SessionConfig};
use ort::session::builder::GraphOptimizationLevel;

#[path = "decoder.rs"]
mod decoder;
#[path = "inference.rs"]
mod inference;
#[path = "preprocessing.rs"]
mod preprocessing;

#[allow(dead_code)]
#[derive(Debug, Clone)]
pub(crate) struct SenseVoiceMetaData {
    with_itn_id: i32,
    without_itn_id: i32,
    window_size: i32,
    window_shift: i32,
    vocab_size: i32,
    subsampling_factor: i32,
    normalize_samples: i32,
    blank_id: i32,
    lang2id: HashMap<String, i32>,
    neg_mean: Vec<f32>,
    inv_stddev: Vec<f32>,
}

#[derive(Debug, Clone)]
pub struct SenseVoiceConfig {
    pub model_path: String,
    pub vocab_path: String,
    pub language: String,
    pub use_itn: bool,
}

impl Default for SenseVoiceConfig {
    fn default() -> Self {
        Self {
            model_path: "models/asr/model1/model1_small.onnx".to_string(),
            vocab_path: "models/asr/model1/tokens.txt".to_string(),
            language: "auto".to_string(),
            use_itn: true,
        }
    }
}

pub struct SenseVoiceModel {
    pub(crate) session: Session,
    pub(crate) vocab: HashMap<i32, String>,
    pub(crate) config: SenseVoiceConfig,
    pub(crate) meta: SenseVoiceMetaData,
}

impl SenseVoiceModel {
    pub async fn new_with_session(
        config: &SenseVoiceConfig,
        session_config: &SessionConfig,
    ) -> Result<Self> {
        if !Path::new(&config.model_path).exists() {
            return Err(anyhow!("模型文件不存在: {}", config.model_path));
        }
        if !Path::new(&config.vocab_path).exists() {
            return Err(anyhow!("词汇表文件不存在: {}", config.vocab_path));
        }
        let session = build_session_builder_with_level(
            session_config,
            &config.model_path,
            GraphOptimizationLevel::Level3,
            Some(false),
        )?;

        let meta = Self::read_model_meta_data(&session)?;

        Ok(Self {
            session,
            vocab: Self::load_vocab(&config.vocab_path)?,
            config: config.clone(),
            meta,
        })
    }

    fn load_vocab<P: AsRef<Path>>(token_path: P) -> Result<HashMap<i32, String>> {
        let content = fs::read_to_string(token_path)?;
        let mut vocab = HashMap::new();

        for line in content.lines() {
            if line.trim().is_empty() {
                continue;
            }

            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() >= 2 {
                if let Ok(id) = parts[parts.len() - 1].parse::<i32>() {
                    let token = parts[..parts.len() - 1].join(" ");
                    vocab.insert(id, token);
                }
            }
        }

        Ok(vocab)
    }

    fn read_model_meta_data(session: &Session) -> Result<SenseVoiceMetaData> {
        let md = session.metadata()?;

        let vocab_size: i32 = md
            .custom("vocab_size")
            .ok_or_else(|| anyhow!("模型缺少 vocab_size 元数据"))?
            .parse()?;

        let window_size: i32 = md
            .custom("lfr_window_size")
            .ok_or_else(|| anyhow!("模型缺少 lfr_window_size 元数据"))?
            .parse()?;

        let window_shift: i32 = md
            .custom("lfr_window_shift")
            .ok_or_else(|| anyhow!("模型缺少 lfr_window_shift 元数据"))?
            .parse()?;

        let normalize_samples: i32 = md
            .custom("normalize_samples")
            .filter(|s| !s.is_empty())
            .unwrap_or_else(|| "0".to_string())
            .parse()
            .unwrap_or(0);

        let with_itn_id: i32 = md
            .custom("with_itn")
            .ok_or_else(|| anyhow!("模型缺少 with_itn 元数据"))?
            .parse()?;

        let without_itn_id: i32 = md
            .custom("without_itn")
            .ok_or_else(|| anyhow!("模型缺少 without_itn 元数据"))?
            .parse()?;

        let mut lang2id = HashMap::new();
        let lang_keys = [
            ("lang_auto", "auto"),
            ("lang_zh", "zh"),
            ("lang_en", "en"),
            ("lang_ja", "ja"),
            ("lang_ko", "ko"),
            ("lang_yue", "yue"),
        ];

        for (k, alias) in lang_keys {
            if let Some(val) = md.custom(k).filter(|s| !s.is_empty()) {
                if let Ok(id) = val.parse::<i32>() {
                    lang2id.insert(alias.to_string(), id);
                }
            }
        }
        lang2id.entry("auto".to_string()).or_insert(0);

        let neg_mean = Self::read_float_vector(&md, "neg_mean")?;
        let inv_stddev = Self::read_float_vector(&md, "inv_stddev")?;

        let blank_id: i32 = md
            .custom("blank_id")
            .filter(|s| !s.is_empty())
            .unwrap_or_else(|| "0".to_string())
            .parse()
            .unwrap_or(0);

        Ok(SenseVoiceMetaData {
            with_itn_id,
            without_itn_id,
            window_size,
            window_shift,
            vocab_size,
            subsampling_factor: 1,
            normalize_samples,
            blank_id,
            lang2id,
            neg_mean,
            inv_stddev,
        })
    }

    fn read_float_vector(md: &ort::session::ModelMetadata, key: &str) -> Result<Vec<f32>> {
        if let Some(value_str) = md.custom(key) {
            let values: Result<Vec<f32>, _> = value_str
                .split(',')
                .map(|s| s.trim().parse::<f32>())
                .collect();
            values.map_err(|e| anyhow!("解析 {} 失败: {}", key, e))
        } else {
            Ok(Vec::new())
        }
    }

    pub async fn recognize_audio(
        &mut self,
        samples: &[f32],
    ) -> Result<crate::process::voice_text::VoiceText> {
        let features = self.preprocess_audio(samples)?;
        self.recognize(features, None, None).await
    }
}
