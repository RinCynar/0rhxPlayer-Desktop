use lofty::file::{AudioFile, TaggedFileExt};
use lofty::probe::Probe;
use lofty::tag::Accessor;
use serde::{Deserialize, Serialize};
use std::fs;
use std::hash::{Hash, Hasher};
use std::path::{Path, PathBuf};
use tauri::{AppHandle, Emitter};
use walkdir::WalkDir;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TrackMetadata {
    pub id: Option<String>,
    pub path: String,
    pub title: String,
    pub artist: String,
    pub album: String,
    pub duration_ms: u64,
    pub track_number: Option<u32>,
    pub disc_number: Option<u32>,
    pub year: Option<u32>,
    pub genre: Option<String>,
    pub sample_rate: Option<u32>,
    pub bit_depth: Option<u8>,
    pub channels: Option<u16>,
    pub bitrate: Option<u32>,
    pub format: Option<String>,
    pub has_cover: bool,
    pub cover_url: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ScanBatchPayload {
    pub tracks: Vec<TrackMetadata>,
    pub scanned_count: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ScanFinishPayload {
    pub total_tracks: usize,
}

/// Returns the cache directory for cover artwork
pub fn get_covers_cache_dir() -> PathBuf {
    let dir = std::env::temp_dir().join("0rhxplayer_cache").join("covers");
    let _ = fs::create_dir_all(&dir);
    dir
}

fn compute_hash(input: &str) -> String {
    use std::collections::hash_map::DefaultHasher;
    let mut hasher = DefaultHasher::new();
    input.hash(&mut hasher);
    format!("{:016x}", hasher.finish())
}

/// Instant lightweight metadata extraction without reading disk tags
pub fn fast_metadata<P: AsRef<Path>>(path: P) -> TrackMetadata {
    let p = path.as_ref();
    let file_format = p.extension().and_then(|e| e.to_str()).map(|s| s.to_uppercase());
    let default_title = p
        .file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or("Unknown Title")
        .to_string();

    let parent_name = p
        .parent()
        .and_then(|parent| parent.file_name())
        .and_then(|s| s.to_str())
        .unwrap_or("Unknown Album")
        .to_string();

    let track_id = compute_hash(&p.to_string_lossy());

    TrackMetadata {
        id: Some(track_id),
        path: p.to_string_lossy().to_string(),
        title: default_title,
        artist: "Unknown Artist".to_string(),
        album: parent_name,
        duration_ms: 0,
        track_number: None,
        disc_number: None,
        year: None,
        genre: None,
        sample_rate: None,
        bit_depth: None,
        channels: None,
        bitrate: None,
        format: file_format,
        has_cover: false,
        cover_url: None,
    }
}

/// Full metadata and cover image parser using Lofty with disk thumbnail caching
pub fn parse_metadata<P: AsRef<Path>>(path: P) -> Result<TrackMetadata, String> {
    let path_ref = path.as_ref();
    let path_str = path_ref.to_string_lossy().to_string();
    let track_id = compute_hash(&path_str);

    let file_format = path_ref
        .extension()
        .and_then(|ext| ext.to_str())
        .map(|s| s.to_uppercase());

    let default_title = path_ref
        .file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or("Unknown Title")
        .to_string();

    let tagged_file_res = Probe::open(path_ref)
        .map_err(|e| format!("Failed to open file for metadata: {}", e))
        .and_then(|p| p.read().map_err(|e| format!("Failed to read metadata tags: {}", e)));

    match tagged_file_res {
        Ok(tagged_file) => {
            let properties = tagged_file.properties();
            let duration_ms = properties.duration().as_millis() as u64;
            let sample_rate = properties.sample_rate();
            let bit_depth = properties.bit_depth();
            let channels = properties.channels().map(|c| c as u16);
            let bitrate = properties.audio_bitrate();

            let mut title = default_title;
            let mut artist = "Unknown Artist".to_string();
            let mut album = path_ref
                .parent()
                .and_then(|p| p.file_name())
                .and_then(|s| s.to_str())
                .unwrap_or("Unknown Album")
                .to_string();
            let mut track_number = None;
            let mut disc_number = None;
            let mut year = None;
            let mut genre = None;
            let mut has_cover = false;
            let mut cover_url = None;

            if let Some(tag) = tagged_file.primary_tag().or_else(|| tagged_file.first_tag()) {
                if let Some(t) = tag.title() {
                    if !t.trim().is_empty() {
                        title = t.trim().to_string();
                    }
                }
                if let Some(a) = tag.artist() {
                    if !a.trim().is_empty() {
                        artist = a.trim().to_string();
                    }
                }
                if let Some(al) = tag.album() {
                    if !al.trim().is_empty() {
                        album = al.trim().to_string();
                    }
                }
                track_number = tag.track();
                disc_number = tag.disk();
                year = tag.year();
                genre = tag.genre().map(|g| g.to_string());

                // Cache embedded cover picture to disk
                if let Some(picture) = tag.pictures().first() {
                    has_cover = true;
                    let cache_dir = get_covers_cache_dir();
                    let cover_file_name = format!("{}.jpg", track_id);
                    let cover_path = cache_dir.join(cover_file_name);

                    if !cover_path.exists() {
                        let _ = fs::write(&cover_path, picture.data());
                    }

                    cover_url = Some(cover_path.to_string_lossy().to_string());
                }
            }

            Ok(TrackMetadata {
                id: Some(track_id),
                path: path_str,
                title,
                artist,
                album,
                duration_ms,
                track_number,
                disc_number,
                year,
                genre,
                sample_rate,
                bit_depth,
                channels,
                bitrate,
                format: file_format,
                has_cover,
                cover_url,
            })
        }
        Err(_) => Ok(fast_metadata(path_ref)),
    }
}

pub fn is_audio_file(path: &Path) -> bool {
    if let Some(ext) = path.extension().and_then(|e| e.to_str()) {
        matches!(
            ext.to_lowercase().as_str(),
            "mp3" | "flac" | "wav" | "ogg" | "m4a" | "aac" | "opus" | "aiff" | "wma"
        )
    } else {
        false
    }
}

/// Recursively scans a directory in background and streams batches of 50 parsed tracks to frontend
pub fn scan_directory_async(dir_path: String, app_handle: AppHandle) {
    std::thread::spawn(move || {
        let chunk_size = 50;
        let mut batch = Vec::with_capacity(chunk_size);
        let mut total_scanned = 0;

        for entry in WalkDir::new(&dir_path)
            .into_iter()
            .filter_map(|e| e.ok())
            .filter(|e| e.file_type().is_file())
        {
            let path = entry.path();
            if is_audio_file(path) {
                let meta = parse_metadata(path).unwrap_or_else(|_| fast_metadata(path));
                batch.push(meta);
                total_scanned += 1;

                if batch.len() >= chunk_size {
                    let payload = ScanBatchPayload {
                        tracks: std::mem::take(&mut batch),
                        scanned_count: total_scanned,
                    };
                    let _ = app_handle.emit("library-scan-batch", payload);
                }
            }
        }

        if !batch.is_empty() {
            let payload = ScanBatchPayload {
                tracks: batch,
                scanned_count: total_scanned,
            };
            let _ = app_handle.emit("library-scan-batch", payload);
        }

        let _ = app_handle.emit("library-scan-finished", ScanFinishPayload { total_tracks: total_scanned });
    });
}

/// Scans a list of specific file paths (multi-select / drag & drop)
pub fn scan_files_async(paths: Vec<String>, app_handle: AppHandle) {
    std::thread::spawn(move || {
        let chunk_size = 50;
        let mut batch = Vec::with_capacity(chunk_size);
        let mut total = 0;

        for p_str in paths {
            let path = Path::new(&p_str);
            if path.is_file() && is_audio_file(path) {
                let meta = parse_metadata(path).unwrap_or_else(|_| fast_metadata(path));
                batch.push(meta);
                total += 1;

                if batch.len() >= chunk_size {
                    let payload = ScanBatchPayload {
                        tracks: std::mem::take(&mut batch),
                        scanned_count: total,
                    };
                    let _ = app_handle.emit("library-scan-batch", payload);
                }
            }
        }

        if !batch.is_empty() {
            let payload = ScanBatchPayload {
                tracks: batch,
                scanned_count: total,
            };
            let _ = app_handle.emit("library-scan-batch", payload);
        }

        let _ = app_handle.emit("library-scan-finished", ScanFinishPayload { total_tracks: total });
    });
}
