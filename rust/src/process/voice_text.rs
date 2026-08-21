#[derive(Debug, Clone, Default)]
pub struct VoiceText {
    pub content: String,
    pub language: Option<String>,
    pub emotion: Option<String>,
    pub event: Option<String>,
    pub confidence: f32,
    pub timestamp: Option<VoiceTimestamp>,
    pub segments: Vec<VoiceSegment>,
    pub segments_info: Option<String>,
}

#[derive(Debug, Clone)]
pub struct VoiceTimestamp {
    pub start_ms: u64,
    pub end_ms: u64,
}

#[derive(Debug, Clone)]
pub struct VoiceSegment {
    pub text: String,
    pub start_ms: u64,
    pub end_ms: u64,
    pub confidence: f32,
}
