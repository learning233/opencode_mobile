use crate::frb_generated::StreamSink;
use crate::models::SessionConfig;

use super::common::{AsrSettings, VadSettings};

pub async fn run_online_transcription(
    model_path: String,
    vocab_path: String,
    vad_model_path: String,
    onnxruntime_path: String,
    asr_settings: AsrSettings,
    vad_settings: VadSettings,
    sink: StreamSink<String>,
) -> anyhow::Result<()> {
    #[allow(unused_mut)]
    let mut resolved_ort_path = onnxruntime_path;
    #[cfg(target_os = "android")]
    {
        if resolved_ort_path.is_empty() {
            if let Some(parent) = std::path::Path::new(&model_path).parent() {
                let candidate = parent.join("libonnxruntime.so");
                if candidate.exists() {
                    resolved_ort_path = candidate.to_string_lossy().into_owned();
                    crate::api::common::debug_marker(&format!(
                        "R299 Resolved local libonnxruntime.so path: {}",
                        resolved_ort_path
                    ));
                }
            }
        }
    }

    if !resolved_ort_path.is_empty() {
        std::env::set_var("ORT_DYLIB_PATH", &resolved_ort_path);
        crate::api::common::debug_marker(&format!(
            "R299 Set ORT_DYLIB_PATH to resolved path: {}",
            resolved_ort_path
        ));
    } else {
        super::common::configure_onnxruntime_dylib();
    }

    let asr_config = super::common::build_asr_config(model_path, vocab_path, &asr_settings);
    let vad_config = super::common::build_vad_config(vad_model_path, &vad_settings);
    let session_config = SessionConfig::default();
    let (mut event_rx, epoch) =
        crate::online::run_online_session(asr_config, vad_config, session_config).await?;

    while let Some(payload) = event_rx.recv().await {
        if sink.add(payload).is_err() {
            crate::online::stop_online_session(Some(epoch));
            break;
        }
    }

    crate::online::stop_online_session(Some(epoch));
    Ok(())
}

pub fn push_online_audio(
    source: String,
    pcm_s16le: Vec<u8>,
    sample_rate: u32,
) -> anyhow::Result<()> {
    let source = crate::online::AudioSource::from_str(&source)?;
    crate::online::push_audio_to_online_session(source, pcm_s16le, sample_rate)
}

pub fn finish_online_audio_source(source: String) -> anyhow::Result<()> {
    let source = crate::online::AudioSource::from_str(&source)?;
    crate::online::finish_online_source(source)
}

pub fn stop_online_transcription() {
    crate::online::stop_online_session(None);
}
