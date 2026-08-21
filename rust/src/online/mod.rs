use std::sync::{
    atomic::{AtomicU64, Ordering},
    mpsc::{self, Receiver, Sender},
    Mutex, OnceLock,
};
use std::thread;
use std::time::Instant;

use anyhow::{anyhow, Result};
use tokio::runtime::{Builder as RuntimeBuilder, Runtime};
use tokio::sync::mpsc::{UnboundedReceiver, UnboundedSender};

use crate::models::sense_voice::{SenseVoiceConfig, SenseVoiceModel};
use crate::models::vad::{SileroVadModelConfig, VadStreamOnnx};
use crate::models::SessionConfig;
use crate::process::audio_processor::AudioProcessor;

const TARGET_SAMPLE_RATE: u32 = 16_000;
const HARD_LIMIT_SAMPLES: usize = TARGET_SAMPLE_RATE as usize * 60;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum AudioSource {
    Mic,
    Playback,
}

impl AudioSource {
    pub fn as_str(self) -> &'static str {
        match self {
            AudioSource::Mic => "mic",
            AudioSource::Playback => "playback",
        }
    }

    pub fn from_str(value: &str) -> Result<Self> {
        match value {
            "mic" => Ok(Self::Mic),
            "playback" => Ok(Self::Playback),
            other => Err(anyhow!("Unsupported audio source: {other}")),
        }
    }
}

enum WorkerCommand {
    PushAudio {
        source: AudioSource,
        pcm_s16le: Vec<u8>,
        sample_rate: u32,
    },
    FinishSource {
        source: AudioSource,
    },
    Stop,
}

struct ActiveSession {
    epoch: u64,
    command_tx: Sender<WorkerCommand>,
}

fn next_epoch() -> u64 {
    static EPOCH: AtomicU64 = AtomicU64::new(1);
    EPOCH.fetch_add(1, Ordering::Relaxed)
}

fn active_session() -> &'static Mutex<Option<ActiveSession>> {
    static ACTIVE_SESSION: OnceLock<Mutex<Option<ActiveSession>>> = OnceLock::new();
    ACTIVE_SESSION.get_or_init(|| Mutex::new(None))
}

struct SharedSessionClock {
    start: Option<Instant>,
}

impl SharedSessionClock {
    fn new() -> Self {
        Self { start: None }
    }

    fn offset_samples(&mut self, sample_rate: u32) -> usize {
        let now = Instant::now();
        match self.start {
            Some(start) => {
                let elapsed = now.saturating_duration_since(start);
                (elapsed.as_secs_f64() * sample_rate as f64).round() as usize
            }
            None => {
                self.start = Some(now);
                0
            }
        }
    }
}

struct SourceState {
    source: AudioSource,
    processor: AudioProcessor,
    vad: VadStreamOnnx,
    audio_buffer: Vec<f32>,
    samples_seen: usize,
    base_offset_samples: Option<usize>,
}

impl SourceState {
    fn new(source: AudioSource, vad_config: &SileroVadModelConfig) -> Result<Self> {
        Ok(Self {
            source,
            processor: AudioProcessor::new(TARGET_SAMPLE_RATE),
            vad: VadStreamOnnx::new(
                &vad_config.model,
                vad_config.threshold,
                vad_config.min_silence_duration,
                vad_config.min_speech_duration,
                vad_config.max_speech_duration,
                vad_config.speech_pad_ms,
            )?,
            audio_buffer: Vec::new(),
            samples_seen: 0,
            base_offset_samples: None,
        })
    }

    fn push_audio(
        &mut self,
        pcm_s16le: &[u8],
        sample_rate: u32,
        clock: &mut SharedSessionClock,
        asr_model: &mut SenseVoiceModel,
        runtime: &Runtime,
        event_tx: &UnboundedSender<String>,
    ) -> Result<()> {
        let decoded = decode_pcm16le(pcm_s16le);
        if decoded.is_empty() {
            return Ok(());
        }

        let samples_16k = self.processor.resample_if_needed(&decoded, sample_rate)?;
        if samples_16k.is_empty() {
            return Ok(());
        }

        if self.base_offset_samples.is_none() {
            self.base_offset_samples = Some(clock.offset_samples(TARGET_SAMPLE_RATE));
        }

        self.audio_buffer.extend_from_slice(&samples_16k);
        let segments = self.vad.process_chunk(&samples_16k)?;
        for segment in segments {
            self.emit_segment(
                segment.start_sample,
                segment.end_sample,
                asr_model,
                runtime,
                event_tx,
            )?;
        }
        self.trim_buffer();
        Ok(())
    }

    fn finish(
        &mut self,
        asr_model: &mut SenseVoiceModel,
        runtime: &Runtime,
        event_tx: &UnboundedSender<String>,
    ) -> Result<()> {
        if let Some(segment) = self.vad.finish() {
            self.emit_segment(
                segment.start_sample,
                segment.end_sample,
                asr_model,
                runtime,
                event_tx,
            )?;
        }
        Ok(())
    }

    fn emit_segment(
        &mut self,
        local_start_sample: usize,
        local_end_sample: usize,
        asr_model: &mut SenseVoiceModel,
        runtime: &Runtime,
        event_tx: &UnboundedSender<String>,
    ) -> Result<()> {
        let buffer_end_abs = self.samples_seen + self.audio_buffer.len();
        let seg_start = local_start_sample.max(self.samples_seen);
        let seg_end = local_end_sample.min(buffer_end_abs);
        if seg_end <= seg_start {
            return Ok(());
        }

        let start_idx = seg_start - self.samples_seen;
        let end_idx = seg_end - self.samples_seen;
        if end_idx > self.audio_buffer.len() || start_idx >= end_idx {
            return Ok(());
        }

        let segment_samples = &self.audio_buffer[start_idx..end_idx];
        if segment_samples.is_empty() {
            return Ok(());
        }

        let voice_text = runtime.block_on(asr_model.recognize_audio(segment_samples))?;
        let source_offset = self.base_offset_samples.unwrap_or(0);
        let start_ms = samples_to_ms(source_offset + local_start_sample);
        let end_ms = samples_to_ms(source_offset + local_end_sample);
        let payload = format!(
            "{{\"kind\":\"final\",\"source\":\"{}\",\"text\":\"{}\",\"confidence\":{},\"language\":\"{}\",\"start_ms\":{},\"end_ms\":{}}}",
            self.source.as_str(),
            escape_json(&voice_text.content),
            normalize_confidence(voice_text.confidence),
            escape_json(voice_text.language.as_deref().unwrap_or_default()),
            start_ms,
            end_ms,
        );
        let _ = event_tx.send(payload);
        Ok(())
    }

    fn trim_buffer(&mut self) {
        if self.audio_buffer.len() <= HARD_LIMIT_SAMPLES {
            return;
        }

        let keep = if self.vad.is_speech_active() {
            TARGET_SAMPLE_RATE as usize * 30
        } else {
            TARGET_SAMPLE_RATE as usize * 3
        };
        if self.audio_buffer.len() <= keep {
            return;
        }

        let remove_count = self.audio_buffer.len() - keep;
        self.audio_buffer.drain(0..remove_count);
        self.samples_seen += remove_count;
    }
}

struct OnlineWorker {
    runtime: Runtime,
    asr_model: SenseVoiceModel,
    mic_state: SourceState,
    playback_state: SourceState,
    clock: SharedSessionClock,
    event_tx: UnboundedSender<String>,
}

impl OnlineWorker {
    fn new(
        asr_config: SenseVoiceConfig,
        vad_config: SileroVadModelConfig,
        session_config: SessionConfig,
        event_tx: UnboundedSender<String>,
    ) -> Result<Self> {
        let runtime = RuntimeBuilder::new_current_thread().enable_all().build()?;
        let asr_model = runtime.block_on(SenseVoiceModel::new_with_session(
            &asr_config,
            &session_config,
        ))?;

        Ok(Self {
            runtime,
            asr_model,
            mic_state: SourceState::new(AudioSource::Mic, &vad_config)?,
            playback_state: SourceState::new(AudioSource::Playback, &vad_config)?,
            clock: SharedSessionClock::new(),
            event_tx,
        })
    }

    fn run(mut self, command_rx: Receiver<WorkerCommand>) {
        while let Ok(command) = command_rx.recv() {
            let result = match command {
                WorkerCommand::PushAudio {
                    source,
                    pcm_s16le,
                    sample_rate,
                } => self.process_audio(source, &pcm_s16le, sample_rate),
                WorkerCommand::FinishSource { source } => self.finish_source(source),
                WorkerCommand::Stop => {
                    let _ = self.finish_source(AudioSource::Mic);
                    let _ = self.finish_source(AudioSource::Playback);
                    break;
                }
            };

            if let Err(error) = result {
                self.emit_error(None, &error.to_string());
            }
        }
    }

    fn process_audio(
        &mut self,
        source: AudioSource,
        pcm_s16le: &[u8],
        sample_rate: u32,
    ) -> Result<()> {
        match source {
            AudioSource::Mic => self.mic_state.push_audio(
                pcm_s16le,
                sample_rate,
                &mut self.clock,
                &mut self.asr_model,
                &self.runtime,
                &self.event_tx,
            ),
            AudioSource::Playback => self.playback_state.push_audio(
                pcm_s16le,
                sample_rate,
                &mut self.clock,
                &mut self.asr_model,
                &self.runtime,
                &self.event_tx,
            ),
        }
    }

    fn finish_source(&mut self, source: AudioSource) -> Result<()> {
        match source {
            AudioSource::Mic => {
                self.mic_state
                    .finish(&mut self.asr_model, &self.runtime, &self.event_tx)
            }
            AudioSource::Playback => {
                self.playback_state
                    .finish(&mut self.asr_model, &self.runtime, &self.event_tx)
            }
        }
    }

    fn emit_error(&self, source: Option<AudioSource>, message: &str) {
        let source_part = source
            .map(|value| format!("\"source\":\"{}\",", value.as_str()))
            .unwrap_or_default();
        let payload = format!(
            "{{\"kind\":\"error\",{}\"message\":\"{}\"}}",
            source_part,
            escape_json(message),
        );
        let _ = self.event_tx.send(payload);
    }
}

pub async fn run_online_session(
    asr_config: SenseVoiceConfig,
    vad_config: SileroVadModelConfig,
    session_config: SessionConfig,
) -> Result<(UnboundedReceiver<String>, u64)> {
    {
        let guard = active_session().lock().unwrap_or_else(|e| e.into_inner());
        if guard.is_some() {
            return Err(anyhow!("在线识别已在运行"));
        }
    }

    let epoch = next_epoch();
    let (command_tx, command_rx) = mpsc::channel::<WorkerCommand>();
    let (event_tx, event_rx) = tokio::sync::mpsc::unbounded_channel::<String>();
    let (ready_tx, ready_rx) = mpsc::sync_channel::<Result<()>>(1);

    {
        let mut guard = active_session().lock().unwrap_or_else(|e| e.into_inner());
        *guard = Some(ActiveSession {
            epoch,
            command_tx: command_tx.clone(),
        });
    }

    thread::Builder::new()
        .name("online-transcription-worker".into())
        .spawn(move || {
            match OnlineWorker::new(asr_config, vad_config, session_config, event_tx) {
                Ok(worker) => {
                    let _ = ready_tx.send(Ok(()));
                    worker.run(command_rx);
                }
                Err(error) => {
                    let _ = ready_tx.send(Err(error));
                }
            }
        })?;

    let ready_result = tokio::task::spawn_blocking(move || ready_rx.recv())
        .await
        .map_err(|error| anyhow!("在线识别初始化等待失败: {error}"))?
        .map_err(|error| anyhow!("在线识别初始化通道异常: {error}"))?;

    if let Err(error) = ready_result {
        let mut guard = active_session().lock().unwrap_or_else(|e| e.into_inner());
        if guard.as_ref().is_some_and(|s| s.epoch == epoch) {
            *guard = None;
        }
        return Err(error);
    }

    Ok((event_rx, epoch))
}

pub fn push_audio_to_online_session(
    source: AudioSource,
    pcm_s16le: Vec<u8>,
    sample_rate: u32,
) -> Result<()> {
    with_active_session(|session| {
        session
            .command_tx
            .send(WorkerCommand::PushAudio {
                source,
                pcm_s16le,
                sample_rate,
            })
            .map_err(|error| anyhow!("在线识别音频发送失败: {error}"))
    })
}

pub fn finish_online_source(source: AudioSource) -> Result<()> {
    with_active_session(|session| {
        session
            .command_tx
            .send(WorkerCommand::FinishSource { source })
            .map_err(|error| anyhow!("在线识别 source 收尾失败: {error}"))
    })
}

pub fn stop_online_session(epoch: Option<u64>) {
    let command_tx = {
        let mut guard = active_session().lock().unwrap_or_else(|e| e.into_inner());
        let matched = match guard.as_ref() {
            Some(session) => epoch.is_none_or(|e| session.epoch == e),
            None => false,
        };
        if matched {
            guard.take().map(|session| session.command_tx)
        } else {
            None
        }
    };

    if let Some(command_tx) = command_tx {
        let _ = command_tx.send(WorkerCommand::Stop);
    }
}

fn with_active_session<T>(callback: impl FnOnce(&ActiveSession) -> Result<T>) -> Result<T> {
    let guard = active_session().lock().unwrap_or_else(|e| e.into_inner());
    let session = guard.as_ref().ok_or_else(|| anyhow!("在线识别尚未启动"))?;
    callback(session)
}

fn decode_pcm16le(bytes: &[u8]) -> Vec<f32> {
    bytes
        .chunks_exact(2)
        .map(|chunk| i16::from_le_bytes([chunk[0], chunk[1]]) as f32 / 32768.0)
        .collect()
}

fn samples_to_ms(samples: usize) -> u64 {
    ((samples as u64) * 1000) / TARGET_SAMPLE_RATE as u64
}

fn normalize_confidence(confidence: f32) -> f32 {
    if confidence.is_finite() {
        confidence
    } else {
        0.0
    }
}

fn escape_json(input: &str) -> String {
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
