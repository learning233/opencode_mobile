use crate::models::sense_voice::SenseVoiceConfig;
use crate::models::vad::SileroVadModelConfig;
use std::path::Path;

pub fn greet(name: String) -> String {
    format!("Hello, {name}!")
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    debug_marker("R100 init_app enter");
    configure_onnxruntime_dylib();
    flutter_rust_bridge::setup_default_user_utils();

    #[cfg(target_os = "android")]
    {
        android_logger::init_once(
            android_logger::Config::default().with_max_level(log::LevelFilter::Debug),
        );
        log::info!(
            "init_app done, ORT_DYLIB_PATH={:?}",
            std::env::var("ORT_DYLIB_PATH").ok()
        );
    }
    debug_marker("R101 init_app done");
}

pub struct TranscribeResult {
    pub text: String,
    pub confidence: f32,
    pub language: String,
    pub start_ms: i64,
    pub end_ms: i64,
}

pub struct VadSettings {
    pub threshold: f32,
    pub min_silence_duration: f32,
    pub min_speech_duration: f32,
    pub max_speech_duration: f32,
    pub speech_pad_ms: i32,
}

impl Default for VadSettings {
    fn default() -> Self {
        let def = SileroVadModelConfig::default();
        Self {
            threshold: def.threshold,
            min_silence_duration: def.min_silence_duration,
            min_speech_duration: def.min_speech_duration,
            max_speech_duration: def.max_speech_duration,
            speech_pad_ms: def.speech_pad_ms,
        }
    }
}

pub struct AsrSettings {
    pub language: String,
    pub use_itn: bool,
}

impl Default for AsrSettings {
    fn default() -> Self {
        let def = SenseVoiceConfig::default();
        Self {
            language: def.language,
            use_itn: def.use_itn,
        }
    }
}

pub struct AudioDevice {
    pub name: String,
    pub is_input: bool,
}

pub struct VadSegment {
    pub start_sample: usize,
    pub end_sample: usize,
}


pub fn build_asr_config(
    model_path: String,
    vocab_path: String,
    settings: &AsrSettings,
) -> SenseVoiceConfig {
    SenseVoiceConfig {
        model_path,
        vocab_path,
        language: settings.language.clone(),
        use_itn: settings.use_itn,
    }
}

pub fn build_vad_config(model_path: String, settings: &VadSettings) -> SileroVadModelConfig {
    SileroVadModelConfig {
        model: model_path,
        threshold: settings.threshold,
        min_silence_duration: settings.min_silence_duration,
        min_speech_duration: settings.min_speech_duration,
        max_speech_duration: settings.max_speech_duration,
        speech_pad_ms: settings.speech_pad_ms,
        ..Default::default()
    }
}

pub fn normalize_confidence(confidence: f32) -> f32 {
    if confidence.is_finite() {
        confidence
    } else {
        0.0
    }
}

pub fn escape_json_string(input: &str) -> String {
    let mut escaped = String::with_capacity(input.len());
    for ch in input.chars() {
        match ch {
            '"' => escaped.push_str("\\\""),
            '\\' => escaped.push_str("\\\\"),
            '\n' => escaped.push_str("\\n"),
            '\r' => escaped.push_str("\\r"),
            '\t' => escaped.push_str("\\t"),
            '\u{08}' => escaped.push_str("\\b"),
            '\u{0C}' => escaped.push_str("\\f"),
            c if c <= '\u{1F}' => {
                let code = c as u32;
                escaped.push_str(&format!("\\u{code:04X}"));
            }
            c => escaped.push(c),
        }
    }
    escaped
}

pub fn configure_onnxruntime_dylib() {
    if std::env::var_os("ORT_DYLIB_PATH").is_some() {
        return;
    }

    #[cfg(target_os = "windows")]
    {
        let candidates = [
            "onnx/onnxruntime.dll",
            "onnxruntime.dll",
            "./onnxruntime.dll",
            "rust/onnx/onnxruntime.dll",
        ];
        for p in candidates {
            if Path::new(p).exists() {
                std::env::set_var("ORT_DYLIB_PATH", p);
                log::info!("Configured ORT_DYLIB_PATH={}", p);
                return;
            }
        }
        log::warn!("ORT_DYLIB_PATH not configured on Windows; no candidate dll found");
    }

    #[cfg(target_os = "android")]
    {
        std::env::set_var("ORT_DYLIB_PATH", "libonnxruntime.so");
        log::info!("Configured ORT_DYLIB_PATH=libonnxruntime.so");
    }

    #[cfg(all(not(target_os = "windows"), not(target_os = "android")))]
    {
        log::info!("ORT_DYLIB_PATH is not preset; relying on platform default loader");
    }
}

pub(crate) fn debug_marker(msg: &str) {
    eprintln!("{msg}");
    #[cfg(target_os = "android")]
    {
        android_debug_log(msg);
    }
}

#[cfg(target_os = "android")]
fn android_debug_log(msg: &str) {
    use std::ffi::CString;
    use std::os::raw::{c_char, c_int};

    unsafe extern "C" {
        fn __android_log_write(prio: c_int, tag: *const c_char, text: *const c_char) -> c_int;
    }

    const ANDROID_LOG_INFO: c_int = 4;
    let Ok(tag) = CString::new("owl-rust") else {
        return;
    };
    let Ok(text) = CString::new(msg) else {
        return;
    };

    unsafe {
        let _ = __android_log_write(ANDROID_LOG_INFO, tag.as_ptr(), text.as_ptr());
    }
}
