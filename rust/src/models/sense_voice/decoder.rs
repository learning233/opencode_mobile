use super::SenseVoiceModel;
use crate::process::voice_text::VoiceText;
use anyhow::Result;

impl SenseVoiceModel {
    pub(crate) fn decode_tokens_static(
        vocab: &std::collections::HashMap<i32, String>,
        meta: &super::SenseVoiceMetaData,
        decoded_ids: Vec<u32>,
        decoded_probs: Vec<f32>,
    ) -> Result<VoiceText> {
        let mut language_detected: Option<String> = None;
        let mut emotion_detected: Option<String> = None;
        let mut event_detected: Option<String> = None;

        let decoded_tokens: Vec<(u32, String)> = decoded_ids
            .iter()
            .filter_map(|&tid| vocab.get(&(tid as i32)).map(|s| (tid, s.clone())))
            .collect();

        if decoded_tokens.len() >= 3 {
            let t0 = decoded_tokens[0].1.as_str();
            let t1 = decoded_tokens[1].1.as_str();
            let t2 = decoded_tokens[2].1.as_str();
            if t0.starts_with("<|") && t0.ends_with("|>") {
                let l = t0
                    .trim_matches(|c| c == '<' || c == '|' || c == '>')
                    .to_lowercase();
                let lang_ok = matches!(l.as_str(), "zh" | "en" | "ja" | "ko" | "yue" | "auto");
                if lang_ok {
                    language_detected = Some(l);
                }
            }
            if t1.starts_with("<|") && t1.ends_with("|>") {
                let e = t1
                    .trim_matches(|c| c == '<' || c == '|' || c == '>')
                    .to_lowercase();
                let emo = match e.as_str() {
                    "happy" => Some("happy"),
                    "sad" => Some("sad"),
                    "angry" => Some("angry"),
                    "neutral" => Some("neutral"),
                    "fearful" => Some("fearful"),
                    "disgusted" => Some("disgusted"),
                    "surprised" => Some("surprised"),
                    "emo_unknown" | "other" => Some("unknown"),
                    _ => None,
                };
                if let Some(e2) = emo {
                    emotion_detected = Some(e2.to_string());
                }
            }
            if t2.starts_with("<|") && t2.ends_with("|>") {
                let e = t2
                    .trim_matches(|c| c == '<' || c == '|' || c == '>')
                    .to_lowercase();
                let evt = match e.as_str() {
                    "nospeech" => Some("nospeech"),
                    "/speech" | "endofspeech" => Some("end_speech"),
                    "speech" => Some("speech"),
                    "bgm" | "/bgm" => Some("bgm"),
                    "applause" | "/applause" => Some("applause"),
                    "laughter" | "/laughter" => Some("laughter"),
                    "cry" => Some("cry"),
                    "sneeze" => Some("sneeze"),
                    "breath" => Some("breath"),
                    "cough" => Some("cough"),
                    "sing" => Some("sing"),
                    _ => None,
                };
                if let Some(e2) = evt {
                    event_detected = Some(e2.to_string());
                }
            }
        }
        if language_detected.is_none() {
            for (_, tok) in decoded_tokens.iter() {
                let t = tok.as_str();
                if matches!(
                    t,
                    "<|zh|>" | "<|en|>" | "<|ja|>" | "<|ko|>" | "<|yue|>" | "<|auto|>"
                ) {
                    language_detected = Some(
                        t.trim_matches(|c| c == '<' || c == '|' || c == '>')
                            .to_string(),
                    );
                    break;
                }
            }
        }
        if emotion_detected.is_none() {
            for (_, tok) in decoded_tokens.iter() {
                let t = tok.to_lowercase();
                let emo = if t.contains("<|happy|>") {
                    Some("happy")
                } else if t.contains("<|sad|>") {
                    Some("sad")
                } else if t.contains("<|angry|>") {
                    Some("angry")
                } else if t.contains("<|neutral|>") {
                    Some("neutral")
                } else if t.contains("<|fearful|>") {
                    Some("fearful")
                } else if t.contains("<|disgusted|>") {
                    Some("disgusted")
                } else if t.contains("<|surprised|>") {
                    Some("surprised")
                } else if t.contains("<|emo_unknown|>") || t.contains("<|other|>") {
                    Some("unknown")
                } else {
                    None
                };
                if let Some(e) = emo {
                    emotion_detected = Some(e.to_string());
                    break;
                }
            }
        }
        if event_detected.is_none() {
            for (_, tok) in decoded_tokens.iter() {
                let t = tok.to_lowercase();
                let evt = if t.contains("<|nospeech|>") {
                    Some("nospeech")
                } else if t.contains("<|/speech|>") || t.contains("<|endofspeech|>") {
                    Some("end_speech")
                } else if t.contains("<|speech|>") {
                    Some("speech")
                } else if t.contains("<|bgm|>") || t.contains("<|/bgm|>") {
                    Some("bgm")
                } else if t.contains("<|applause|>") || t.contains("<|/applause|>") {
                    Some("applause")
                } else if t.contains("<|laughter|>") || t.contains("<|/laughter|>") {
                    Some("laughter")
                } else if t.contains("<|cry|>") {
                    Some("cry")
                } else if t.contains("<|sneeze|>") {
                    Some("sneeze")
                } else if t.contains("<|breath|>") {
                    Some("breath")
                } else if t.contains("<|cough|>") {
                    Some("cough")
                } else {
                    None
                };
                if let Some(e) = evt {
                    event_detected = Some(e.to_string());
                    break;
                }
            }
        }

        let mut raw_text = String::new();
        let mut text_token_probs: Vec<f32> = Vec::new();

        for (idx, (tid, tok)) in decoded_tokens.iter().enumerate() {
            if *tid as i32 == meta.with_itn_id || *tid as i32 == meta.without_itn_id {
                continue;
            }
            if tok == "<|withitn|>" || tok == "<|woitn|>" || tok == "<|endutterance|>" {
                continue;
            }
            if tok.starts_with("<|") && tok.ends_with("|>") {
                continue;
            }

            raw_text.push_str(tok);

            if idx < decoded_probs.len() {
                text_token_probs.push(decoded_probs[idx]);
            }
        }

        let is_japanese = language_detected.as_deref() == Some("ja");
        let processed_text = if is_japanese {
            raw_text.replace('▁', "")
        } else {
            raw_text.replace('▁', " ")
        };

        let result = processed_text
            .split_whitespace()
            .map(|s| match s {
                "i" => "I",
                "i'm" => "I'm",
                "i've" => "I've",
                "i'll" => "I'll",
                _ => s,
            })
            .collect::<Vec<_>>()
            .join(" ");

        let confidence = if text_token_probs.is_empty() {
            0.0
        } else {
            text_token_probs.iter().copied().sum::<f32>() / (text_token_probs.len() as f32)
        };

        let result = result
            .replace("<|withitn|>", "")
            .replace("<|woitn|>", "")
            .trim()
            .split_whitespace()
            .collect::<Vec<_>>()
            .join(" ");

        let use_itn = decoded_ids
            .iter()
            .any(|&tid| tid as i32 == meta.with_itn_id);
        let result = if use_itn {
            result
        } else {
            normalize_chinese_acronyms(&result, language_detected.as_deref())
        };

        let event_detected = event_detected.or_else(|| Some("speech".to_string()));
        let emotion_detected = emotion_detected.or_else(|| Some("neutral".to_string()));

        Ok(VoiceText {
            content: result,
            language: language_detected,
            emotion: emotion_detected,
            event: event_detected,
            confidence,
            timestamp: None,
            segments: Vec::new(),
            segments_info: None,
        })
    }

    pub(crate) fn decode_tokens(
        &self,
        decoded_ids: Vec<u32>,
        decoded_probs: Vec<f32>,
    ) -> Result<VoiceText> {
        Self::decode_tokens_static(&self.vocab, &self.meta, decoded_ids, decoded_probs)
    }
}

fn is_cjk(ch: char) -> bool {
    ('\u{4E00}'..='\u{9FFF}').contains(&ch)
        || ('\u{3400}'..='\u{4DBF}').contains(&ch)
        || ('\u{F900}'..='\u{FAFF}').contains(&ch)
}

fn has_cjk(s: &str) -> bool {
    s.chars().any(is_cjk)
}

fn normalize_chinese_acronyms(text: &str, language: Option<&str>) -> String {
    let apply = match language {
        Some("en") => false,
        Some("zh") | Some("yue") => true,
        _ => has_cjk(text),
    };
    if !apply {
        return text.to_string();
    }

    let chars: Vec<char> = text.chars().collect();
    let mut out = String::with_capacity(text.len());
    let mut i = 0usize;

    fn parse_acronym(chars: &[char], mut j: usize) -> Option<(String, usize)> {
        let mut letters = String::new();
        let mut groups = 0usize;
        loop {
            let mut run_len = 0usize;
            while j < chars.len() && chars[j].is_ascii_alphabetic() {
                run_len += 1;
                letters.push(chars[j]);
                j += 1;
            }
            if run_len == 0 {
                break;
            }
            groups += 1;
            if run_len != 1 {
                return None;
            }
            let mut k = j;
            while k < chars.len() && chars[k].is_whitespace() {
                k += 1;
            }
            if k < chars.len() && chars[k].is_ascii_alphabetic() {
                j = k;
                continue;
            }
            j = k;
            break;
        }
        if groups >= 1 && groups <= 6 {
            Some((letters.to_uppercase(), j))
        } else {
            None
        }
    }

    while i < chars.len() {
        let c = chars[i];
        if c.is_ascii_alphabetic() {
            let prev_cjk = out.chars().last().map(is_cjk).unwrap_or(false);
            if prev_cjk || i == 0 {
                if let Some((acr, next)) = parse_acronym(&chars, i) {
                    out.push_str(&acr);
                    i = next;
                    continue;
                }
            }
            out.push(c);
            i += 1;
            continue;
        }
        if c.is_whitespace() {
            let mut k = i;
            while k < chars.len() && chars[k].is_whitespace() {
                k += 1;
            }
            let prev_cjk = out.chars().last().map(is_cjk).unwrap_or(false);
            if prev_cjk && k < chars.len() && chars[k].is_ascii_alphabetic() {
                if let Some((acr, next)) = parse_acronym(&chars, k) {
                    out.push_str(&acr);
                    i = next;
                    continue;
                }
            }
            if !out.ends_with(' ') {
                out.push(' ');
            }
            i = k;
            continue;
        }

        out.push(c);
        i += 1;
    }
    out
}

#[cfg(test)]
mod tests {
    use super::normalize_chinese_acronyms;

    #[test]
    fn test_merge_ctc() {
        let t = normalize_chinese_acronyms("c t c低温", Some("zh"));
        assert!(t.starts_with("CTC"));
    }

    #[test]
    fn test_merge_cltc() {
        let t = normalize_chinese_acronyms("c l t c 综合续航里程", Some("zh"));
        assert!(t.starts_with("CLTC"));
    }

    #[test]
    fn test_san_c() {
        let t = normalize_chinese_acronyms("三 c 超充", Some("zh"));
        assert!(t.contains("三C"));
    }

    #[test]
    fn test_keep_english() {
        let t = normalize_chinese_acronyms("a b test", Some("en"));
        assert_eq!(t, "a b test");
    }

    #[test]
    fn test_long_acronym_six_letters() {
        let t = normalize_chinese_acronyms("a b c d e f 综合", Some("zh"));
        assert!(t.starts_with("ABCDEF综合"));
    }
}
