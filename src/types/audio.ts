export type PlaybackStatus = 'stopped' | 'playing' | 'paused' | 'buffering';

export interface TrackMetadata {
  id?: string;
  path: string;
  title: string;
  artist: string;
  album: string;
  durationMs: number;
  trackNumber?: number;
  discNumber?: number;
  year?: number;
  genre?: string;
  sampleRate?: number;
  bitDepth?: number;
  channels?: number;
  bitrate?: number;
  format?: string;
  hasCover: boolean;
  coverUrl?: string;
}

export interface LyricLine {
  time: number;
  text: string;
  roma?: string;
  trans?: string;
}

export interface PlaybackState {

  status: PlaybackStatus;
  currentTrack: TrackMetadata | null;
  positionMs: number;
  durationMs: number;
  volume: number;
  isMuted: boolean;
  shuffle: boolean;
  repeatMode: 'off' | 'one' | 'all';
}

export interface PositionUpdatePayload {
  positionMs: number;
  durationMs: number;
  status: PlaybackStatus;
}

export interface ScanBatchPayload {
  tracks: TrackMetadata[];
  scannedCount: number;
}

export interface ScanFinishPayload {
  totalTracks: number;
}

export interface Playlist {
  id: string;
  name: string;
  description?: string;
  trackPaths: string[];
  createdAt: number;
  coverUrl?: string;
}
