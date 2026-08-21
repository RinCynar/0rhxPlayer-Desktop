import { invoke } from '@tauri-apps/api/core';
import { listen, UnlistenFn } from '@tauri-apps/api/event';
import { open } from '@tauri-apps/plugin-dialog';
import {
  PlaybackState,
  PositionUpdatePayload,
  ScanBatchPayload,
  ScanFinishPayload,
  TrackMetadata,
  LyricLine,
} from '../types/audio';


export async function openAudioFilesDialog(): Promise<string[]> {
  try {
    const selected = await open({
      multiple: true,
      directory: false,
      filters: [
        {
          name: 'Audio Files (*.mp3, *.flac, *.wav, *.m4a, *.ogg, *.aac, *.opus, *.aiff)',
          extensions: ['mp3', 'flac', 'wav', 'm4a', 'ogg', 'aac', 'opus', 'aiff', 'wma'],
        },
      ],
    });

    if (Array.isArray(selected)) {
      return selected;
    } else if (typeof selected === 'string') {
      return [selected];
    }
    return [];
  } catch (err) {
    console.error('Failed to open files dialog:', err);
    return [];
  }
}

export async function openDirectoryDialog(): Promise<string | null> {
  try {
    const selected = await open({
      multiple: false,
      directory: true,
    });

    if (typeof selected === 'string') {
      return selected;
    }
    return null;
  } catch (err) {
    console.error('Failed to open directory dialog:', err);
    return null;
  }
}

export async function loadTrack(path: string): Promise<TrackMetadata> {
  return await invoke<TrackMetadata>('load_track', { path });
}

export async function play(): Promise<void> {
  return await invoke<void>('play');
}

export async function pause(): Promise<void> {
  return await invoke<void>('pause');
}

export async function stop(): Promise<void> {
  return await invoke<void>('stop');
}

export async function seek(positionMs: number): Promise<void> {
  return await invoke<void>('seek', { positionMs: Math.round(positionMs) });
}

export async function setVolume(volume: number): Promise<void> {
  return await invoke<void>('set_volume', { volume });
}

export async function getPlaybackState(): Promise<PlaybackState> {
  return await invoke<PlaybackState>('get_playback_state');
}

export async function readTrackMetadata(path: string): Promise<TrackMetadata> {
  return await invoke<TrackMetadata>('read_track_metadata', { path });
}

export async function getLyrics(path: string): Promise<LyricLine[]> {
  try {
    return await invoke<LyricLine[]>('get_lyrics', { path });
  } catch (e) {
    console.warn('Failed to load lyrics:', e);
    return [];
  }
}

export async function setWindowEffect(effect: string): Promise<void> {
  try {
    await invoke<void>('set_window_effect', { effect });
  } catch (e) {
    console.warn('Failed to set window effect:', e);
  }
}

export async function setEqEnabled(enabled: boolean): Promise<void> {
  try {
    await invoke<void>('set_eq_enabled', { enabled });
  } catch (e) {
    console.warn('Failed to set EQ enabled:', e);
  }
}

export async function setEqBands(bands: number[]): Promise<void> {
  try {
    await invoke<void>('set_eq_bands', { bands });
  } catch (e) {
    console.warn('Failed to set EQ bands:', e);
  }
}

export async function setEqPreamp(preampDb: number): Promise<void> {
  try {
    await invoke<void>('set_eq_preamp', { preampDb });
  } catch (e) {
    console.warn('Failed to set EQ preamp:', e);
  }
}

export async function setMinimizeToTray(enabled: boolean): Promise<void> {
  try {
    await invoke<void>('set_minimize_to_tray', { enabled });
  } catch (e) {
    console.warn('Failed to set minimize to tray:', e);
  }
}

export async function scanDirectory(dirPath: string): Promise<void> {
  return await invoke<void>('scan_directory', { dirPath });
}

export async function scanFiles(paths: string[]): Promise<void> {
  return await invoke<void>('scan_files', { paths });
}

export async function subscribePositionUpdates(
  callback: (payload: PositionUpdatePayload) => void
): Promise<UnlistenFn> {
  return await listen<PositionUpdatePayload>('playback-position-update', (event) => {
    callback(event.payload);
  });
}

export async function subscribeMetadataUpdates(
  callback: (payload: TrackMetadata) => void
): Promise<UnlistenFn> {
  return await listen<TrackMetadata>('track-metadata-updated', (event) => {
    callback(event.payload);
  });
}

export async function subscribeTrackEnded(
  callback: () => void
): Promise<UnlistenFn> {
  return await listen<void>('track-ended', () => {
    callback();
  });
}

export async function subscribeScanBatch(
  callback: (payload: ScanBatchPayload) => void
): Promise<UnlistenFn> {
  return await listen<ScanBatchPayload>('library-scan-batch', (event) => {
    callback(event.payload);
  });
}

export async function subscribeScanFinished(
  callback: (payload: ScanFinishPayload) => void
): Promise<UnlistenFn> {
  return await listen<ScanFinishPayload>('library-scan-finished', (event) => {
    callback(event.payload);
  });
}

export async function subscribeTrayPlayPause(
  callback: () => void
): Promise<UnlistenFn> {
  return await listen<void>('tray-play-pause', () => {
    callback();
  });
}

export async function subscribeTrayPlayNext(
  callback: () => void
): Promise<UnlistenFn> {
  return await listen<void>('tray-play-next', () => {
    callback();
  });
}
