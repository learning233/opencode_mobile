pub mod vad_stream_onnx;
pub use vad_stream_onnx::VadStreamOnnx;

#[derive(Debug, Clone, Copy, PartialEq)]
pub(crate) enum VadState {
    Silence,
    PossibleSpeech,
    Speech,
    PossibleSilence,
}

#[derive(Debug, Clone)]
pub struct SileroVadModelConfig {
    pub model: String,
    pub threshold: f32,
    pub sample_rate: i32,
    pub min_silence_duration: f32,
    pub min_speech_duration: f32,
    pub max_speech_duration: f32,
    pub speech_pad_ms: i32,
}

impl Default for SileroVadModelConfig {
    fn default() -> Self {
        Self {
            model: "models/vad/vad.onnx".to_string(),
            threshold: 0.5,
            sample_rate: 16000,
            min_silence_duration: 0.2,
            min_speech_duration: 0.4,
            max_speech_duration: 20.0,
            speech_pad_ms: 50,
        }
    }
}

#[derive(Clone, Copy, Debug)]
pub struct SileroVadSegment {
    pub start_sample: usize,
    pub end_sample: usize,
}
