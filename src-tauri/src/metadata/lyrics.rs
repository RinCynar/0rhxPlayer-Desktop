use lofty::file::TaggedFileExt;
use serde::{Deserialize, Serialize};

use std::fs;
use std::path::Path;


#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct LyricLine {
    pub time: f64,
    pub text: String,
    pub roma: Option<String>,
    pub trans: Option<String>,
}

/// Search for lyrics from embedded tags or sibling directory .lrc file
pub fn get_lyrics_for_track<P: AsRef<Path>>(audio_path: P) -> Vec<LyricLine> {
    let p = audio_path.as_ref();

    // 1. Try external .lrc file first
    let lrc_path = p.with_extension("lrc");
    if lrc_path.exists() && lrc_path.is_file() {
        if let Ok(content) = read_file_with_encoding(&lrc_path) {
            let lines = parse_lrc(&content);
            if !lines.is_empty() {
                return lines;
            }
        }
    }

    let lrc_upper = p.with_extension("LRC");
    if lrc_upper.exists() && lrc_upper.is_file() {
        if let Ok(content) = read_file_with_encoding(&lrc_upper) {
            let lines = parse_lrc(&content);
            if !lines.is_empty() {
                return lines;
            }
        }
    }

    // 2. Try embedded lyrics using lofty
    if let Ok(tagged_file) = lofty::probe::Probe::open(p).and_then(|pr| pr.read()) {
        for tag in tagged_file.tags() {
            if let Some(lyrics_str) = tag.get_string(&lofty::tag::ItemKey::Lyrics) {
                let lines = parse_lrc(lyrics_str);
                if !lines.is_empty() {
                    return lines;
                }
            }
        }
    }

    Vec::new()
}

fn read_file_with_encoding(path: &Path) -> Result<String, String> {
    let bytes = fs::read(path).map_err(|e| e.to_string())?;

    let slice = if bytes.starts_with(&[0xEF, 0xBB, 0xBF]) {
        &bytes[3..]
    } else {
        &bytes[..]
    };

    if let Ok(s) = std::str::from_utf8(slice) {
        return Ok(s.to_string());
    }

    let (cow, _encoding_used, _had_errors) = encoding_rs::GB18030.decode(slice);
    Ok(cow.into_owned())
}

pub fn parse_lrc(content: &str) -> Vec<LyricLine> {
    let mut raw_items: Vec<(f64, String)> = Vec::new();

    for raw_line in content.lines() {
        let line = raw_line.trim();
        if line.is_empty() {
            continue;
        }

        let mut timestamps = Vec::new();
        let mut text_start = 0;
        let bytes = line.as_bytes();
        let mut i = 0;

        while i < bytes.len() {
            if bytes[i] == b'[' {
                if let Some(end) = line[i..].find(']') {
                    let tag_content = &line[i + 1..i + end];
                    if let Some(sec) = parse_timestamp(tag_content) {
                        timestamps.push(sec);
                        i += end + 1;
                        text_start = i;
                        continue;
                    }
                }
            }
            break;
        }

        let lyric_text = line[text_start..].trim().to_string();

        if !timestamps.is_empty() {
            for t in timestamps {
                raw_items.push((t, lyric_text.clone()));
            }
        } else if !line.starts_with('[') {
            raw_items.push((0.0, line.to_string()));
        }
    }

    raw_items.sort_by(|a, b| a.0.partial_cmp(&b.0).unwrap_or(std::cmp::Ordering::Equal));

    let mut result = Vec::new();
    let mut i = 0;
    while i < raw_items.len() {
        let (time, ref text) = raw_items[i];
        let mut trans = None;
        let mut roma = None;

        let mut j = i + 1;
        while j < raw_items.len() && (raw_items[j].0 - time).abs() < 0.05 {
            let next_text = &raw_items[j].1;
            if trans.is_none() && is_likely_translation(next_text) {
                trans = Some(next_text.clone());
            } else if roma.is_none() && is_likely_romaji(next_text) {
                roma = Some(next_text.clone());
            }
            j += 1;
        }

        result.push(LyricLine {
            time,
            text: text.clone(),
            roma,
            trans,
        });

        i = if j > i + 1 { j } else { i + 1 };
    }

    result
}

fn parse_timestamp(s: &str) -> Option<f64> {
    let parts: Vec<&str> = s.split(':').collect();
    if parts.len() < 2 {
        return None;
    }

    let mins: f64 = parts[0].parse().ok()?;
    let secs_part = parts[1];

    let secs: f64 = if parts.len() == 3 {
        let s: f64 = secs_part.parse().ok()?;
        let f: f64 = parts[2].parse().ok()?;
        s + f / 100.0
    } else {
        secs_part.parse().ok()?
    };

    Some(mins * 60.0 + secs)
}

fn is_likely_romaji(s: &str) -> bool {
    s.chars().all(|c| c.is_ascii() || c.is_whitespace() || c.is_ascii_punctuation())
}

fn is_likely_translation(s: &str) -> bool {
    s.chars().any(|c| c >= '\u{4E00}' && c <= '\u{9FFF}')
}
