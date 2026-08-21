use anyhow::Result;
use kaldi_fbank_rust_kautism::{
    FbankOptions, FrameExtractionOptions, MelBanksOptions, OnlineFbank,
};
use ort::{
    session::{builder::GraphOptimizationLevel, Session, SessionInputValue},
    value::TensorRef,
};
use std::collections::VecDeque;
use std::path::Path;

use super::VadState;

struct SendOnlineFbank(OnlineFbank);
unsafe impl Send for SendOnlineFbank {}
unsafe impl Sync for SendOnlineFbank {}

fn make_fbank_opts() -> FbankOptions {
    FbankOptions {
        frame_opts: FrameExtractionOptions {
            samp_freq: 16000.0,
            dither: 0.0,
            ..Default::default()
        },
        mel_opts: MelBanksOptions {
            num_bins: 80,
            ..Default::default()
        },
        use_log_fbank: true,
        use_power: true,
        ..Default::default()
    }
}

pub struct VadStreamOnnx {
    session: Session,
    cache: ndarray::Array4<f32>,
    fbank: SendOnlineFbank,
    last_frame_processed: usize,

    threshold: f32,
    min_silence_frames: usize,
    min_speech_frames: usize,
    max_speech_frames: usize,
    pad_start_frame: usize,
    smooth_window_size: usize,

    state: VadState,
    speech_count: usize,
    silence_count: usize,
    smooth_window: VecDeque<f32>,
    frame_cnt: usize,
    last_speech_start_frame: Option<usize>,
    last_speech_end_frame: Option<usize>,
    hit_max_speech: bool,

    samples_processed_in_session: usize,
    sample_offset: usize,

    base_threshold: f32,
    base_min_silence_frames: usize,
    soft_limit_frames: usize,

    scaled_buffer: Vec<f32>,
}

impl VadStreamOnnx {
    const SMOOTH_WINDOW_SIZE: usize = 5;

    pub fn new<P: AsRef<Path>>(
        model_path: P,
        threshold: f32,
        min_silence_duration: f32,
        min_speech_duration: f32,
        max_speech_duration: f32,
        speech_pad_ms: i32,
    ) -> Result<Self> {
        let session = Session::builder()
            .map_err(|e| anyhow::anyhow!("VAD session builder error: {}", e))?
            .with_optimization_level(GraphOptimizationLevel::Level3)
            .map_err(|e| anyhow::anyhow!("VAD optimization level error: {}", e))?
            .with_intra_threads(1)
            .map_err(|e| anyhow::anyhow!("VAD intra threads error: {}", e))?
            .with_inter_threads(1)
            .map_err(|e| anyhow::anyhow!("VAD inter threads error: {}", e))?
            .commit_from_file(model_path)
            .map_err(|e| anyhow::anyhow!("VAD commit error: {}", e))?;

        let cache = ndarray::Array4::<f32>::zeros((8, 1, 128, 19));

        let opts = make_fbank_opts();

        let min_silence_frames = (min_silence_duration * 100.0).round() as usize;
        let min_speech_frames = (min_speech_duration * 100.0).round() as usize;
        let max_speech_frames = (max_speech_duration * 100.0).round() as usize;
        let pad_start_frame =
            ((speech_pad_ms as f32 / 10.0).round() as usize).max(Self::SMOOTH_WINDOW_SIZE);

        Ok(Self {
            session,
            cache,
            fbank: SendOnlineFbank(OnlineFbank::new(opts)),
            last_frame_processed: 0,
            threshold,
            min_silence_frames,
            min_speech_frames,
            max_speech_frames,
            pad_start_frame,
            smooth_window_size: Self::SMOOTH_WINDOW_SIZE,
            state: VadState::Silence,
            speech_count: 0,
            silence_count: 0,
            smooth_window: VecDeque::with_capacity(Self::SMOOTH_WINDOW_SIZE),
            frame_cnt: 0,
            last_speech_start_frame: None,
            last_speech_end_frame: None,
            hit_max_speech: false,
            samples_processed_in_session: 0,
            sample_offset: 0,
            base_threshold: threshold,
            base_min_silence_frames: min_silence_frames,
            soft_limit_frames: (max_speech_frames as f32 * 0.6) as usize,
            scaled_buffer: Vec::new(),
        })
    }

    pub fn reset(&mut self) {
        self.reset_internal();
        self.sample_offset = 0;
    }

    pub fn reset_state_preserve_timeline(&mut self) {
        self.sample_offset += self.samples_processed_in_session;
        self.reset_internal();
    }

    fn reset_internal(&mut self) {
        self.cache.fill(0.0);
        self.fbank = SendOnlineFbank(OnlineFbank::new(make_fbank_opts()));
        self.last_frame_processed = 0;
        self.state = VadState::Silence;
        self.speech_count = 0;
        self.silence_count = 0;
        self.smooth_window.clear();
        self.frame_cnt = 0;
        self.last_speech_start_frame = None;
        self.last_speech_end_frame = None;
        self.hit_max_speech = false;
        self.samples_processed_in_session = 0;
        self.scaled_buffer.clear();
    }

    pub fn is_speech_active(&self) -> bool {
        self.state == VadState::Speech || self.state == VadState::PossibleSilence
    }

    pub fn current_speech_start(&self) -> Option<usize> {
        self.last_speech_start_frame
            .map(|f| self.sample_offset + (f.saturating_sub(1) * 160))
    }

    pub fn window_shift(&self) -> usize {
        160
    }

    pub fn process_chunk(&mut self, samples: &[f32]) -> Result<Vec<super::SileroVadSegment>> {
        self.scaled_buffer.clear();
        self.scaled_buffer
            .extend(samples.iter().map(|&x| x * 32768.0));
        self.fbank.0.accept_waveform(16000.0, &self.scaled_buffer);

        let n_total_frames = self.fbank.0.num_ready_frames();
        let mut segments = Vec::new();

        let mut frame_buf = [0.0f32; 80];
        for i in (self.last_frame_processed as i32)..n_total_frames {
            if let Some(frame) = self.fbank.0.get_frame(i) {
                frame_buf.copy_from_slice(&frame[..80]);
                let raw_prob = self.forward(&frame_buf)?;
                self.frame_cnt += 1;

                let smoothed_prob = self.smooth_prob(raw_prob);

                let (effective_threshold, effective_min_silence_frames) = if self.speech_count
                    > self.soft_limit_frames
                    && (self.state == VadState::Speech || self.state == VadState::PossibleSilence)
                {
                    let range = self
                        .max_speech_frames
                        .saturating_sub(self.soft_limit_frames)
                        .max(1);
                    let progress = ((self.speech_count - self.soft_limit_frames) as f32
                        / range as f32)
                        .clamp(0.0, 1.0);

                    let boosted_threshold =
                        (self.base_threshold * (1.0 + 0.6 * progress)).min(0.95);
                    let reduced_silence = (self.base_min_silence_frames as f32
                        * (1.0 - 0.7 * progress))
                        .round() as usize;
                    let reduced_silence = reduced_silence.max(1);

                    if progress > 0.01 {
                        tracing::debug!(
                            "[VAD] Dynamic tuning: progress={:.2}, threshold={:.3}->{:.3}, min_silence={}->{}",
                            progress,
                            self.base_threshold, boosted_threshold,
                            self.base_min_silence_frames, reduced_silence
                        );
                    }

                    (boosted_threshold, reduced_silence)
                } else {
                    (self.threshold, self.min_silence_frames)
                };

                let is_speech_frame = smoothed_prob >= effective_threshold;

                if self.hit_max_speech {
                    self.last_speech_start_frame = Some(self.frame_cnt);
                    self.hit_max_speech = false;
                }

                match self.state {
                    VadState::Silence => {
                        if is_speech_frame {
                            self.state = VadState::PossibleSpeech;
                            self.speech_count = 1;
                        } else {
                            self.silence_count += 1;
                            self.speech_count = 0;
                        }
                    }
                    VadState::PossibleSpeech => {
                        if is_speech_frame {
                            self.speech_count += 1;
                            if self.speech_count >= self.min_speech_frames {
                                self.state = VadState::Speech;
                                let start_frame = self
                                    .frame_cnt
                                    .saturating_sub(self.speech_count)
                                    .saturating_add(1)
                                    .saturating_sub(self.pad_start_frame)
                                    .max(1);
                                let start_frame = if let Some(last_end) = self.last_speech_end_frame
                                {
                                    std::cmp::max(start_frame, last_end + 1)
                                } else {
                                    start_frame
                                };
                                self.last_speech_start_frame = Some(start_frame);
                                self.silence_count = 0;
                            }
                        } else {
                            self.state = VadState::Silence;
                            self.silence_count = 1;
                            self.speech_count = 0;
                        }
                    }
                    VadState::Speech => {
                        self.speech_count += 1;
                        if is_speech_frame {
                            self.silence_count = 0;
                            if self.speech_count >= self.max_speech_frames {
                                self.trigger_end_of_speech(&mut segments, true);
                            }
                        } else {
                            self.state = VadState::PossibleSilence;
                            self.silence_count = 1;
                        }
                    }
                    VadState::PossibleSilence => {
                        self.speech_count += 1;
                        if is_speech_frame {
                            self.state = VadState::Speech;
                            self.silence_count = 0;
                            if self.speech_count >= self.max_speech_frames {
                                self.trigger_end_of_speech(&mut segments, true);
                            }
                        } else {
                            self.silence_count += 1;
                            if self.silence_count >= effective_min_silence_frames {
                                self.state = VadState::Silence;
                                self.trigger_end_of_speech(&mut segments, false);
                            }
                        }
                    }
                }
            }
        }

        self.last_frame_processed = n_total_frames as usize;
        self.samples_processed_in_session = n_total_frames as usize * 160;

        Ok(segments)
    }

    fn smooth_prob(&mut self, prob: f32) -> f32 {
        if self.smooth_window_size <= 1 {
            return prob;
        }
        self.smooth_window.push_back(prob);
        if self.smooth_window.len() > self.smooth_window_size {
            self.smooth_window.pop_front();
        }
        let sum: f32 = self.smooth_window.iter().sum();
        sum / self.smooth_window.len() as f32
    }

    fn trigger_end_of_speech(
        &mut self,
        segments: &mut Vec<super::SileroVadSegment>,
        hit_max: bool,
    ) {
        if let Some(start_frame) = self.last_speech_start_frame.take() {
            let start_sample = self.sample_offset + (start_frame.saturating_sub(1) * 160);
            let end_sample = self.sample_offset + (self.frame_cnt * 160);

            segments.push(super::SileroVadSegment {
                start_sample,
                end_sample,
            });

            self.last_speech_end_frame = Some(self.frame_cnt);
            self.speech_count = 0;
            if hit_max {
                self.hit_max_speech = true;
            }
        }
    }

    pub fn finish(&mut self) -> Option<super::SileroVadSegment> {
        if let Some(start_frame) = self.last_speech_start_frame.take() {
            let start_sample = self.sample_offset + (start_frame.saturating_sub(1) * 160);
            let end_sample = self.sample_offset + (self.frame_cnt * 160);
            return Some(super::SileroVadSegment {
                start_sample,
                end_sample,
            });
        }
        None
    }

    fn forward(&mut self, feat: &[f32]) -> Result<f32> {
        let feat_shape = [1usize, 1usize, 80usize];
        let feat_ref = TensorRef::from_array_view((feat_shape, feat))?;

        let cache_shape = [8usize, 1usize, 128usize, 19usize];
        let cache_slice = self.cache.as_slice().unwrap();
        let cache_ref = TensorRef::from_array_view((cache_shape, cache_slice))?;

        let inputs: Vec<(&str, SessionInputValue)> = vec![
            ("feat", SessionInputValue::from(feat_ref.into_dyn())),
            ("in_caches", SessionInputValue::from(cache_ref.into_dyn())),
        ];

        let mut outputs = self.session.run(inputs)?;

        if let Some(out_cache_v) = outputs.remove("out_caches") {
            let (shape, data) = out_cache_v.try_extract_tensor::<f32>()?;
            debug_assert!(
                shape.len() == 4
                    && shape[0] as usize == 8
                    && shape[1] as usize == 1
                    && shape[2] as usize == 128
                    && shape[3] as usize == 19,
                "Unexpected cache output shape: {:?}",
                shape
            );
            self.cache.as_slice_mut().unwrap().copy_from_slice(&data);
        }

        if let Some(probs_v) = outputs.remove("probs") {
            let (_shape, data) = probs_v.try_extract_tensor::<f32>()?;
            if data.is_empty() {
                return Err(anyhow::anyhow!("VAD model returned empty probabilities"));
            }
            return Ok(data[data.len() - 1]);
        }

        Err(anyhow::anyhow!("VAD model missing output 'probs'"))
    }
}
