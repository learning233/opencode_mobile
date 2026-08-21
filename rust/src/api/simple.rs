pub use super::common::{
    greet, init_app, AsrSettings, AudioDevice, TranscribeResult, VadSegment, VadSettings,
};
pub use super::online::stop_online_transcription;
use crate::frb_generated::StreamSink;

pub async fn run_online_transcription(
    model_path: String,
    vocab_path: String,
    vad_model_path: String,
    asr_settings: AsrSettings,
    vad_settings: VadSettings,
    sink: StreamSink<String>,
) -> anyhow::Result<()> {
    super::online::run_online_transcription(
        model_path,
        vocab_path,
        vad_model_path,
        String::new(),
        asr_settings,
        vad_settings,
        sink,
    )
    .await
}
