pub mod audio;
pub mod db;
pub mod metadata;

use audio::{AudioEngine, PlaybackState, PlaybackStatus};
use metadata::{
    get_lyrics_for_track, parse_metadata, scan_directory_async, scan_files_async, LyricLine,
    TrackMetadata,
};
use std::sync::Arc;

use tauri::{AppHandle, Emitter, Manager, State};

pub struct AppState {
    pub audio_engine: Arc<AudioEngine>,
}

#[tauri::command]
fn load_track(state: State<'_, AppState>, path: String) -> Result<TrackMetadata, String> {
    state.audio_engine.load_track(path)
}

#[tauri::command]
fn play(state: State<'_, AppState>) -> Result<(), String> {
    state.audio_engine.play()
}

#[tauri::command]
fn pause(state: State<'_, AppState>) -> Result<(), String> {
    state.audio_engine.pause()
}

#[tauri::command]
fn stop(state: State<'_, AppState>) -> Result<(), String> {
    state.audio_engine.stop()
}

#[tauri::command]
fn seek(state: State<'_, AppState>, position_ms: u64) -> Result<(), String> {
    state.audio_engine.seek(position_ms)
}

#[tauri::command]
fn set_volume(state: State<'_, AppState>, volume: f32) -> Result<(), String> {
    state.audio_engine.set_volume(volume)
}

#[tauri::command]
fn get_playback_state(state: State<'_, AppState>) -> Result<PlaybackState, String> {
    Ok(state.audio_engine.get_playback_state())
}

#[tauri::command]
fn read_track_metadata(path: String) -> Result<TrackMetadata, String> {
    parse_metadata(path)
}

#[tauri::command]
fn get_lyrics(path: String) -> Result<Vec<LyricLine>, String> {
    Ok(get_lyrics_for_track(path))
}

#[tauri::command]
fn scan_directory(app: AppHandle, dir_path: String) -> Result<(), String> {

    scan_directory_async(dir_path, app);
    Ok(())
}

#[tauri::command]
fn scan_files(app: AppHandle, paths: Vec<String>) -> Result<(), String> {
    scan_files_async(paths, app);
    Ok(())
}

#[tauri::command]
fn set_window_effect(app: AppHandle, effect: String) -> Result<(), String> {
    #[cfg(target_os = "windows")]
    if let Some(window) = app.get_webview_window("main") {
        let _ = window_vibrancy::clear_vibrancy(&window);
        match effect.as_str() {
            "Mica" | "Mica Alt" => {
                let _ = window_vibrancy::apply_mica(&window, Some(true));
            }
            "Acrylic" | "Acrylic Blur" => {
                let _ = window_vibrancy::apply_acrylic(&window, Some((18, 18, 22, 120)));
            }
            _ => {
                let _ = window_vibrancy::clear_vibrancy(&window);
            }
        }
    }
    Ok(())
}

#[tauri::command]
fn set_eq_enabled(state: State<'_, AppState>, enabled: bool) -> Result<(), String> {
    state.audio_engine.set_eq_enabled(enabled)
}

#[tauri::command]
fn set_eq_bands(state: State<'_, AppState>, bands: Vec<f32>) -> Result<(), String> {
    state.audio_engine.set_eq_bands(bands)
}

#[tauri::command]
fn set_eq_preamp(state: State<'_, AppState>, preamp_db: f32) -> Result<(), String> {
    state.audio_engine.set_eq_preamp(preamp_db)
}

#[derive(serde::Serialize, Clone)]
#[serde(rename_all = "camelCase")]
struct PositionUpdatePayload {
    position_ms: u64,
    duration_ms: u64,
    status: PlaybackStatus,
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_opener::init())
        .setup(move |app| {
            let handle = app.handle().clone();

            if let Some(window) = app.get_webview_window("main") {
                #[cfg(target_os = "windows")]
                let _ = window_vibrancy::apply_mica(&window, Some(true));

                if let Some(icon) = app.default_window_icon() {
                    let _ = window.set_icon(icon.clone());
                }
            }



            let audio_engine = match AudioEngine::new(handle.clone()) {
                Ok(engine) => Arc::new(engine),
                Err(e) => {
                    eprintln!("Failed to initialize audio engine: {}", e);
                    panic!("Audio engine init error: {}", e);
                }
            };

            let app_state = AppState {
                audio_engine: audio_engine.clone(),
            };
            app.manage(app_state);

            // Throttled background heartbeat task for position updates (100ms, only when playing)
            let emit_handle = handle.clone();
            let engine_clone = audio_engine.clone();

            tauri::async_runtime::spawn(async move {
                let mut interval = tokio::time::interval(std::time::Duration::from_millis(100));
                let mut last_state = PlaybackStatus::Stopped;

                loop {
                    interval.tick().await;
                    let state = engine_clone.get_playback_state();

                    if state.status == PlaybackStatus::Playing || state.status != last_state {
                        last_state = state.status;
                        let payload = PositionUpdatePayload {
                            position_ms: state.position_ms,
                            duration_ms: state.duration_ms,
                            status: state.status,
                        };
                        let _ = emit_handle.emit("playback-position-update", payload);
                    }
                }
            });

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            load_track,
            play,
            pause,
            stop,
            seek,
            set_volume,
            get_playback_state,
            read_track_metadata,
            get_lyrics,
            scan_directory,
            scan_files,
            set_window_effect,
            set_eq_enabled,
            set_eq_bands,
            set_eq_preamp,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

