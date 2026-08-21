use crate::api::common::debug_marker;
use anyhow::{anyhow, Result};
use ort::execution_providers::CPUExecutionProvider;
use ort::session::builder::GraphOptimizationLevel;
use ort::session::Session;

pub mod sense_voice;
pub mod vad;

#[derive(Debug, Clone)]
pub struct SessionConfig {
    pub intra_threads: Option<usize>,
    pub inter_threads: Option<usize>,
}

impl Default for SessionConfig {
    fn default() -> Self {
        Self {
            intra_threads: Some(4),
            inter_threads: Some(1),
        }
    }
}

pub fn build_session_builder(config: &SessionConfig, model_path: &str) -> Result<Session> {
    build_session_builder_with_level(config, model_path, GraphOptimizationLevel::Level3, None)
}

pub fn build_session_builder_with_level(
    config: &SessionConfig,
    model_path: &str,
    optimization_level: GraphOptimizationLevel,
    memory_pattern: Option<bool>,
) -> Result<Session> {
    debug_marker("R300.0.01 Session::builder() starting...");
    let mut builder = Session::builder().map_err(|e| anyhow!("{e}"))?;
    debug_marker("R300.0.02 Session::builder() created ok");

    builder = builder
        .with_optimization_level(optimization_level)
        .map_err(|e| anyhow!("{e}"))?;

    if let Some(intra) = config.intra_threads {
        builder = builder
            .with_intra_threads(intra)
            .map_err(|e| anyhow!("{e}"))?;
    }

    if let Some(inter) = config.inter_threads {
        builder = builder
            .with_inter_threads(inter)
            .map_err(|e| anyhow!("{e}"))?;
    }

    if let Some(mem) = memory_pattern {
        builder = builder
            .with_memory_pattern(mem)
            .map_err(|e| anyhow!("{e}"))?;
    }

    debug_marker(&format!("R300.0.1 committing session from: {}", model_path));
    let session = builder
        .with_execution_providers([CPUExecutionProvider::default().build()])
        .map_err(|e| anyhow!("{e}"))?
        .commit_from_file(model_path)
        .map_err(|e| anyhow!("{e}"))?;
    debug_marker("R300.0.2 session committed ok");
    Ok(session)
}
