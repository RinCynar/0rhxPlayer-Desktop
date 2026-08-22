import React, { createContext, useContext, useEffect, useState, useCallback, useRef } from 'react';
import { PlaybackStatus, Playlist, TrackMetadata, LyricLine } from '../types/audio';
import * as audioService from '../services/tauriAudio';

import {
  applyTheme,
  DEFAULT_SEED_HEX,
  ThemeMode,
  DEFAULT_THEME_MODE,
  resolveEffectiveTheme,
  initSystemThemeListener,
} from '../theme/theme';

import { LangKey } from '../i18n';


export type NavTab = 'home' | 'library' | 'playlist' | 'search' | 'settings' | 'queue' | 'eq';

export type LyricsAlign = 'right' | 'center' | 'left';
export type PlayMode = 'all' | 'one' | 'shuffle' | 'sequential';

export interface EqSettings {
  enabled: boolean;
  preampDb: number;
  bands: number[];
  preset: string;
}

export const EQ_PRESETS: Record<string, number[]> = {
  Flat: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  Rock: [4.5, 3.0, 1.5, 0, -1.0, -0.5, 1.0, 2.5, 3.5, 4.0],
  Pop: [-1.5, -0.5, 1.0, 3.0, 4.5, 3.5, 1.5, 0.5, -0.5, -1.0],
  Classical: [4.0, 3.0, 2.5, 2.0, -1.0, -1.0, 0, 2.0, 3.0, 3.5],
  'Bass Boost': [6.0, 5.0, 4.0, 2.5, 1.0, 0, 0, 0, 0, 0],
  Vocal: [-2.0, -1.5, -1.0, 1.5, 4.0, 4.5, 3.0, 1.5, 0, -1.0],
  Electronic: [4.5, 4.0, 1.0, 0, -2.0, 2.0, 1.0, 2.0, 4.0, 4.5],
  Jazz: [3.5, 2.5, 1.0, 1.5, -1.5, -1.5, 0, 1.5, 2.5, 3.0],
};

export interface UserProfile {
  nickname: string;
  avatar: string; // data URL or http URL
}

export interface AudioSettings {
  driver: string;
  resampler: string;
  bufferMs: number;
  replayGain: string;
  cueAutoScan: boolean;
  globalHotkeys: boolean;
  systemTray: boolean;
}

export function splitArtists(artistStr: string | undefined, separators: string = '/'): string[] {
  if (!artistStr || !artistStr.trim()) return ['Unknown Artist'];
  const clean = separators.trim() || '/';
  const escaped = clean
    .split('')
    .map((c) => c.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'))
    .join('|');
  const regex = new RegExp(`(?:${escaped})`, 'g');
  const parts = artistStr
    .split(regex)
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
  return parts.length > 0 ? parts : [artistStr.trim()];
}

export const ALL_NAV_ITEMS: { id: NavTab; icon: string; labelKey: string }[] = [
  { id: 'home',     icon: 'fa-star',           labelKey: 'home'     },
  { id: 'library',  icon: 'fa-folder',          labelKey: 'library'  },
  { id: 'search',   icon: 'fa-magnifying-glass', labelKey: 'search'   },
  { id: 'queue',    icon: 'fa-list-ol',          labelKey: 'queue'    },
  { id: 'playlist', icon: 'fa-compact-disc',     labelKey: 'playlist' },
  { id: 'eq',       icon: 'fa-sliders',          labelKey: 'eq'       },
];

interface PlayerContextType {
  activeTab: NavTab;
  setActiveTab: (tab: NavTab) => void;
  currentTrack: TrackMetadata | null;
  playbackStatus: PlaybackStatus;
  positionMs: number;
  durationMs: number;
  volume: number;
  isMuted: boolean;
  playMode: PlayMode;
  cyclePlayMode: () => void;
  setPlayMode: (mode: PlayMode) => void;
  isDarkMode: boolean;
  themeMode: ThemeMode;
  isNowPlayingOpen: boolean;
  setIsNowPlayingOpen: (open: boolean) => void;
  isQueueOpen: boolean;
  setIsQueueOpen: (open: boolean) => void;
  queue: TrackMetadata[];
  currentTrackIndex: number;
  libraryTracks: TrackMetadata[];
  playlists: Playlist[];
  currentLyrics: LyricLine[];
  isScanning: boolean;
  scannedCount: number;

  // I18N & UI Preferences
  lang: LangKey;
  setLang: (lang: LangKey) => void;
  lyricsAlign: LyricsAlign;
  setLyricsAlign: (align: LyricsAlign) => void;
  lyricsFontSize: number;
  setLyricsFontSize: (size: number) => void;
  showTrans: boolean;
  setShowTrans: (v: boolean) => void;

  // Artist & Theme Customization
  artistSeparators: string;
  setArtistSeparators: (separators: string) => void;
  customSeedColor: string;
  setCustomSeedColor: (color: string) => void;
  isNavCollapsed: boolean;
  setIsNavCollapsed: React.Dispatch<React.SetStateAction<boolean>>;
  autoCollapseRailOnNowPlaying: boolean;
  setAutoCollapseRailOnNowPlaying: (enabled: boolean) => void;



  // Equalizer
  eqSettings: EqSettings;
  setEqBand: (index: number, gainDb: number) => void;
  setEqPreamp: (preampDb: number) => void;
  setEqEnabled: (enabled: boolean) => void;
  applyEqPreset: (preset: string) => void;
  resetEq: () => void;

  // User Profile
  userProfile: UserProfile;
  setUserProfile: (profile: UserProfile) => void;

  // Audio settings
  audioSettings: AudioSettings;
  setAudioSettings: (s: AudioSettings) => void;

  // Navigation customization
  visibleNavIds: NavTab[];
  setVisibleNavIds: (ids: NavTab[]) => void;

  toggleDarkMode: () => void;
  setThemeMode: (mode: ThemeMode) => void;
  playTrack: (track: TrackMetadata, newQueue?: TrackMetadata[]) => Promise<void>;
  playTrackAtIndex: (index: number) => Promise<void>;
  playNext: () => Promise<void>;
  playPrevious: () => Promise<void>;
  togglePlayPause: () => Promise<void>;
  seekTo: (ms: number) => Promise<void>;
  changeVolume: (vol: number) => Promise<void>;
  toggleMute: () => Promise<void>;

  // Queue actions
  addToQueue: (tracks: TrackMetadata | TrackMetadata[]) => void;
  removeFromQueue: (index: number) => void;
  clearQueue: () => void;

  // Favorites
  favorites: string[];
  isFavorite: (path: string) => boolean;
  toggleFavorite: (path: string) => void;

  // Library & File imports
  scannedFolders: string[];
  importFilesAction: () => Promise<void>;
  scanDirectoryAction: () => Promise<void>;
  addScanFolderAction: () => Promise<void>;
  removeScanFolder: (folderPath: string) => void;
  rescanLibraryAction: () => Promise<void>;
  clearLibrary: () => void;
  removeTracksFromLibrary: (paths: string[]) => void;


  // Playlists

  createPlaylist: (name: string, description?: string) => string;
  deletePlaylist: (id: string) => void;
  renamePlaylist: (id: string, name: string) => void;
  addTrackToPlaylist: (playlistId: string, trackPath: string) => void;
  removeTrackFromPlaylist: (playlistId: string, trackPath: string) => void;
  playPlaylist: (playlistId: string) => Promise<void>;
  playNextTrack: (track: TrackMetadata) => void;
}




const PlayerContext = createContext<PlayerContextType | null>(null);

const STORAGE_KEY_LIBRARY = '0rhx_library_v3';
const STORAGE_KEY_PLAYLISTS = '0rhx_playlists_v3';
const STORAGE_KEY_QUEUE = '0rhx_queue_v3';
const STORAGE_KEY_FAVORITES = '0rhx_favorites_v3';

export const PlayerProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [activeTab, setActiveTab] = useState<NavTab>('home');
  const [currentTrack, setCurrentTrack] = useState<TrackMetadata | null>(null);
  const [playbackStatus, setPlaybackStatus] = useState<PlaybackStatus>('stopped');
  const [positionMs, setPositionMs] = useState<number>(0);
  const [durationMs, setDurationMs] = useState<number>(0);
  const [volume, setVolume] = useState<number>(1.0);
  const [isMuted, setIsMuted] = useState<boolean>(false);
  const [playMode, setPlayMode] = useState<PlayMode>(() => {
    return (localStorage.getItem('0rhx_play_mode_v4') as PlayMode) || 'all';
  });
  const [themeMode, setThemeModeState] = useState<ThemeMode>(() => {
    const saved = (localStorage.getItem('theme_mode') || localStorage.getItem('0rhx_theme_mode')) as ThemeMode;
    if (saved === 'dark' || saved === 'light' || saved === 'system') return saved;
    return DEFAULT_THEME_MODE;
  });
  const [isDarkMode, setIsDarkMode] = useState<boolean>(() => {
    const saved = (localStorage.getItem('theme_mode') || localStorage.getItem('0rhx_theme_mode')) as ThemeMode;
    const mode = (saved === 'dark' || saved === 'light' || saved === 'system') ? saved : DEFAULT_THEME_MODE;
    return resolveEffectiveTheme(mode) === 'dark';
  });


  const [isNowPlayingOpen, setIsNowPlayingOpen] = useState<boolean>(false);
  const [isQueueOpen, setIsQueueOpen] = useState<boolean>(false);

  const [lang, setLang] = useState<LangKey>(() => {
    const saved = localStorage.getItem('0rhx_lang') as LangKey;
    const initialLang = (saved && (saved === 'zh' || saved === 'en' || saved === 'ja')) ? saved : 'zh';
    if (typeof document !== 'undefined') {
      document.documentElement.lang = initialLang;
    }
    return initialLang;
  });
  const [lyricsAlign, setLyricsAlign] = useState<LyricsAlign>(() => {
    return (localStorage.getItem('0rhx_lyrics_align') as LyricsAlign) || 'right';
  });
  const [lyricsFontSize, setLyricsFontSize] = useState<number>(() => {
    const saved = localStorage.getItem('0rhx_lyrics_font_size');
    return saved ? parseInt(saved, 10) : 30;
  });
  const [showTrans, setShowTrans] = useState<boolean>(() => {
    return localStorage.getItem('0rhx_show_trans') !== 'false';
  });
  const [isNavCollapsed, setIsNavCollapsed] = useState<boolean>(() => {
    return localStorage.getItem('0rhx_nav_collapsed') === 'true';
  });
  const [autoCollapseRailOnNowPlaying, setAutoCollapseRailOnNowPlaying] = useState<boolean>(() => {
    return localStorage.getItem('0rhx_auto_collapse_rail') !== 'false';
  });

  // Equalizer State
  const [eqSettings, setEqSettings] = useState<EqSettings>(() => {
    try {
      const saved = localStorage.getItem('0rhx_eq_settings_v1');
      return saved ? JSON.parse(saved) : {
        enabled: false,
        preampDb: 0,
        bands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        preset: 'Flat',
      };
    } catch {
      return {
        enabled: false,
        preampDb: 0,
        bands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        preset: 'Flat',
      };
    }
  });

  // Initial sync of EQ to backend
  useEffect(() => {
    audioService.setEqEnabled(eqSettings.enabled);
    audioService.setEqPreamp(eqSettings.preampDb);
    audioService.setEqBands(eqSettings.bands);
  }, []);

  const setEqBand = useCallback((index: number, gainDb: number) => {
    setEqSettings((prev) => {
      const nextBands = [...prev.bands];
      nextBands[index] = gainDb;
      const next = { ...prev, bands: nextBands, preset: 'Custom' };
      audioService.setEqBands(nextBands);
      return next;
    });
  }, []);

  const setEqPreamp = useCallback((preampDb: number) => {
    setEqSettings((prev) => {
      const next = { ...prev, preampDb };
      audioService.setEqPreamp(preampDb);
      return next;
    });
  }, []);

  const setEqEnabled = useCallback((enabled: boolean) => {
    setEqSettings((prev) => {
      const next = { ...prev, enabled };
      audioService.setEqEnabled(enabled);
      return next;
    });
  }, []);

  const applyEqPreset = useCallback((presetName: string) => {
    const presetBands = EQ_PRESETS[presetName] || [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    setEqSettings((prev) => {
      const next = { ...prev, bands: [...presetBands], preset: presetName };
      audioService.setEqBands(next.bands);
      return next;
    });
  }, []);

  const resetEq = useCallback(() => {
    const defaultBands = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    const next = { enabled: false, preampDb: 0, bands: defaultBands, preset: 'Flat' };
    setEqSettings(next);
    audioService.setEqEnabled(false);
    audioService.setEqPreamp(0);
    audioService.setEqBands(defaultBands);
  }, []);

  const cyclePlayMode = useCallback(() => {
    setPlayMode((prev) => {
      if (prev === 'all') return 'one';
      if (prev === 'one') return 'shuffle';
      if (prev === 'shuffle') return 'sequential';
      return 'all';
    });
  }, []);

  // Artist & Theme Preferences
  const [artistSeparators, setArtistSeparators] = useState<string>(() => {
    return localStorage.getItem('0rhx_artist_separators') || '/';
  });
  const [customSeedColor, setCustomSeedColorState] = useState<string>(() => {
    return (
      localStorage.getItem('theme_seed') ||
      localStorage.getItem('0rhx_custom_seed_color') ||
      DEFAULT_SEED_HEX
    );
  });

  // Scanned Folders State
  const [scannedFolders, setScannedFolders] = useState<string[]>(() => {
    try {
      const saved = localStorage.getItem('0rhx_scanned_folders');
      return saved ? JSON.parse(saved) : [];
    } catch {
      return [];
    }
  });

  // User Profile
  const [userProfile, setUserProfile] = useState<UserProfile>(() => {
    try {
      const saved = localStorage.getItem('0rhx_user_profile');
      return saved ? JSON.parse(saved) : { nickname: 'RinCynar', avatar: '' };
    } catch {
      return { nickname: 'RinCynar', avatar: '' };
    }
  });


  // Audio Settings
  const [audioSettings, setAudioSettings] = useState<AudioSettings>(() => {
    try {
      const saved = localStorage.getItem('0rhx_audio_settings');
      return saved ? JSON.parse(saved) : {
        driver: 'WASAPI Exclusive',
        resampler: 'SoX Resampler High Quality',
        bufferMs: 100,
        replayGain: 'Track Mode (-18 LUFS)',
        cueAutoScan: true,
        globalHotkeys: true,
        systemTray: true,
      };
    } catch {
      return {
        driver: 'WASAPI Exclusive',
        resampler: 'SoX Resampler High Quality',
        bufferMs: 100,
        replayGain: 'Track Mode (-18 LUFS)',
        cueAutoScan: true,
        globalHotkeys: true,
        systemTray: true,
      };
    }
  });


  // Nav customization
  const [visibleNavIds, setVisibleNavIds] = useState<NavTab[]>(() => {
    try {
      const saved = localStorage.getItem('0rhx_visible_nav');
      return saved ? JSON.parse(saved) : ['home', 'library', 'search', 'queue', 'playlist', 'eq'];
    } catch {
      return ['home', 'library', 'search', 'queue', 'playlist', 'eq'];
    }
  });


  // Queue & Track list
  const [queue, setQueue] = useState<TrackMetadata[]>(() => {
    try {
      const saved = localStorage.getItem(STORAGE_KEY_QUEUE);
      return saved ? JSON.parse(saved) : [];
    } catch {
      return [];
    }
  });
  const [currentTrackIndex, setCurrentTrackIndex] = useState<number>(-1);

  // Library
  const [libraryTracks, setLibraryTracks] = useState<TrackMetadata[]>(() => {
    try {
      const saved = localStorage.getItem(STORAGE_KEY_LIBRARY);
      return saved ? JSON.parse(saved) : [];
    } catch {
      return [];
    }
  });

  // Playlists
  const [playlists, setPlaylists] = useState<Playlist[]>(() => {
    try {
      const saved = localStorage.getItem(STORAGE_KEY_PLAYLISTS);
      return saved ? JSON.parse(saved) : [];
    } catch {
      return [];
    }
  });

  // Favorites (favorite track paths)
  const [favorites, setFavorites] = useState<string[]>(() => {
    try {
      const saved = localStorage.getItem(STORAGE_KEY_FAVORITES);
      return saved ? JSON.parse(saved) : [];
    } catch {
      return [];
    }
  });


  // Current Lyrics state
  const [currentLyrics, setCurrentLyrics] = useState<LyricLine[]>([]);

  // Automatically fetch lyrics on track change
  useEffect(() => {
    if (currentTrack?.path) {
      audioService.getLyrics(currentTrack.path).then((lines) => {
        setCurrentLyrics(lines);
      }).catch((err) => {
        console.warn('Failed to load lyrics for track:', err);
        setCurrentLyrics([]);
      });
    } else {
      setCurrentLyrics([]);
    }
  }, [currentTrack?.path]);


  // Scan state
  const [isScanning, setIsScanning] = useState<boolean>(false);
  const [scannedCount, setScannedCount] = useState<number>(0);

  // Keep refs for callbacks to avoid stale closures in event listeners
  const queueRef = useRef(queue);
  queueRef.current = queue;
  const indexRef = useRef(currentTrackIndex);
  indexRef.current = currentTrackIndex;
  const playModeRef = useRef(playMode);
  playModeRef.current = playMode;

  // Persist library
  useEffect(() => {
    try {
      localStorage.setItem(STORAGE_KEY_LIBRARY, JSON.stringify(libraryTracks));
    } catch (e) {
      console.error('Failed to save library tracks:', e);
    }
  }, [libraryTracks]);

  // Persist playlists
  useEffect(() => {
    try {
      localStorage.setItem(STORAGE_KEY_PLAYLISTS, JSON.stringify(playlists));
    } catch (e) {
      console.error('Failed to save playlists:', e);
    }
  }, [playlists]);

  // Persist queue
  useEffect(() => {
    try {
      localStorage.setItem(STORAGE_KEY_QUEUE, JSON.stringify(queue));
    } catch (e) {
      console.error('Failed to save queue:', e);
    }
  }, [queue]);

  // Persist favorites
  useEffect(() => {
    try {
      localStorage.setItem(STORAGE_KEY_FAVORITES, JSON.stringify(favorites));
    } catch (e) {
      console.error('Failed to save favorites:', e);
    }
  }, [favorites]);

  // Persist I18N prefs & player configs
  useEffect(() => {
    localStorage.setItem('0rhx_lang', lang);
    if (typeof document !== 'undefined') {
      document.documentElement.lang = lang;
    }
    audioService.updateTrayMenu(lang);
  }, [lang]);
  useEffect(() => { localStorage.setItem('0rhx_lyrics_align', lyricsAlign); }, [lyricsAlign]);
  useEffect(() => { localStorage.setItem('0rhx_lyrics_font_size', String(lyricsFontSize)); }, [lyricsFontSize]);
  useEffect(() => { localStorage.setItem('0rhx_show_trans', String(showTrans)); }, [showTrans]);
  useEffect(() => { localStorage.setItem('0rhx_nav_collapsed', String(isNavCollapsed)); }, [isNavCollapsed]);
  useEffect(() => { localStorage.setItem('0rhx_auto_collapse_rail', String(autoCollapseRailOnNowPlaying)); }, [autoCollapseRailOnNowPlaying]);
  useEffect(() => { localStorage.setItem('0rhx_play_mode_v4', playMode); }, [playMode]);
  useEffect(() => { localStorage.setItem('0rhx_artist_separators', artistSeparators); }, [artistSeparators]);
  useEffect(() => { localStorage.setItem('0rhx_custom_seed_color', customSeedColor); }, [customSeedColor]);

  // Auto collapse sidebar on NowPlaying open/close linkage
  const preNowPlayingNavCollapsedRef = useRef<boolean | null>(null);
  useEffect(() => {
    if (!autoCollapseRailOnNowPlaying) return;
    if (isNowPlayingOpen) {
      preNowPlayingNavCollapsedRef.current = isNavCollapsed;
      if (!isNavCollapsed) {
        setIsNavCollapsed(true);
      }
    } else {
      if (preNowPlayingNavCollapsedRef.current !== null) {
        setIsNavCollapsed(preNowPlayingNavCollapsedRef.current);
        preNowPlayingNavCollapsedRef.current = null;
      }
    }
  }, [isNowPlayingOpen, autoCollapseRailOnNowPlaying]);
  useEffect(() => {
    try {
      localStorage.setItem('0rhx_eq_settings_v1', JSON.stringify(eqSettings));
    } catch { /* ignore */ }
  }, [eqSettings]);
  useEffect(() => { try { localStorage.setItem('0rhx_user_profile', JSON.stringify(userProfile)); } catch { /* ignore */ } }, [userProfile]);

  // Persist Audio settings
  useEffect(() => {
    try {
      localStorage.setItem('0rhx_audio_settings', JSON.stringify(audioSettings));
    } catch { /* ignore */ }
    audioService.setMinimizeToTray(audioSettings.systemTray);
  }, [audioSettings]);

  useEffect(() => {
    try {
      localStorage.setItem('0rhx_scanned_folders', JSON.stringify(scannedFolders));
    } catch { /* ignore */ }
  }, [scannedFolders]);

  useEffect(() => {
    try {
      localStorage.setItem('0rhx_visible_nav', JSON.stringify(visibleNavIds));
    } catch { /* ignore */ }
  }, [visibleNavIds]);


  // Sync HTML root classes for Tailwind dark: selector
  useEffect(() => {
    if (isDarkMode) {
      document.documentElement.classList.remove('light');
      document.documentElement.classList.add('dark');
      document.documentElement.style.colorScheme = 'dark';
    } else {
      document.documentElement.classList.remove('dark');
      document.documentElement.classList.add('light');
      document.documentElement.style.colorScheme = 'light';
    }
  }, [isDarkMode]);

  // Listen for system theme changes when in 'system' mode, and apply theme
  useEffect(() => {
    const updateEffectiveTheme = () => {
      const effective = resolveEffectiveTheme(themeMode);
      setIsDarkMode(effective === 'dark');
      applyTheme(customSeedColor, effective);
    };

    updateEffectiveTheme();

    if (themeMode === 'system') {
      const unlisten = initSystemThemeListener(updateEffectiveTheme);
      return unlisten;
    }
  }, [themeMode, customSeedColor]);

  const setCustomSeedColor = useCallback((hex: string) => {
    setCustomSeedColorState(hex);
    localStorage.setItem('theme_seed', hex);
    localStorage.setItem('0rhx_custom_seed_color', hex);
    const effective = resolveEffectiveTheme(themeMode);
    applyTheme(hex, effective);
  }, [themeMode]);

  const setThemeMode = useCallback((mode: ThemeMode) => {
    setThemeModeState(mode);
    localStorage.setItem('theme_mode', mode);
    localStorage.setItem('0rhx_theme_mode', mode);
    const effective = resolveEffectiveTheme(mode);
    setIsDarkMode(effective === 'dark');
    applyTheme(customSeedColor, effective);
  }, [customSeedColor]);

  const toggleDarkMode = useCallback(() => {
    const effective = resolveEffectiveTheme(themeMode);
    const nextMode: ThemeMode = effective === 'dark' ? 'light' : 'dark';
    setThemeMode(nextMode);
  }, [themeMode, setThemeMode]);




  // Subscribe to native position updates
  useEffect(() => {
    let unlisten: (() => void) | undefined;
    audioService
      .subscribePositionUpdates((payload) => {
        setPositionMs(payload.positionMs);
        if (payload.durationMs > 0) {
          setDurationMs(payload.durationMs);
        }
        if (payload.status === 'playing') {
          setPlaybackStatus('playing');
        } else if (payload.status === 'paused') {
          setPlaybackStatus('paused');
        } else if (payload.status === 'stopped') {
          setPlaybackStatus('stopped');
        }
      })
      .then((fn) => {
        unlisten = fn;
      })
      .catch((e) => console.warn('Position update subscribe error:', e));

    return () => {
      if (unlisten) unlisten();
    };
  }, []);

  // Subscribe to background full-metadata updates
  useEffect(() => {
    let unlisten: (() => void) | undefined;
    audioService
      .subscribeMetadataUpdates((meta) => {
        setCurrentTrack((prev) => {
          if (prev && prev.path === meta.path) {
            return { ...prev, ...meta };
          }
          return prev;
        });
        setDurationMs(meta.durationMs || 0);

        setLibraryTracks((prev) =>
          prev.map((t) => (t.path === meta.path ? { ...t, ...meta } : t))
        );
        setQueue((prev) =>
          prev.map((t) => (t.path === meta.path ? { ...t, ...meta } : t))
        );
      })
      .then((fn) => {
        unlisten = fn;
      })
      .catch((e) => console.warn('Metadata update subscribe error:', e));

    return () => {
      if (unlisten) unlisten();
    };
  }, []);

  // Subscribe to library scanner batch events
  useEffect(() => {
    let unlistenBatch: (() => void) | undefined;
    let unlistenFinish: (() => void) | undefined;

    audioService
      .subscribeScanBatch((payload) => {
        setScannedCount(payload.scannedCount);
        setLibraryTracks((prev) => {
          const map = new Map<string, TrackMetadata>();
          for (const t of prev) map.set(t.path, t);
          for (const t of payload.tracks) {
            if (!map.has(t.path)) {
              map.set(t.path, t);
            }
          }
          return Array.from(map.values());
        });
      })
      .then((fn) => {
        unlistenBatch = fn;
      })
      .catch((e) => console.warn('Scan batch listener notice:', e));


    audioService
      .subscribeScanFinished(() => {
        setIsScanning(false);
      })
      .then((fn) => {
        unlistenFinish = fn;
      })
      .catch((e) => console.warn('Scan finish listener notice:', e));

    return () => {
      if (unlistenBatch) unlistenBatch();
      if (unlistenFinish) unlistenFinish();
    };
  }, []);

  const playRequestCounter = useRef<number>(0);
  const playDebounceTimer = useRef<number | null>(null);

  // Core Playback Controls with Zero-latency Optimistic Updates & Debounced Scheduler
  const playTrack = useCallback(async (track: TrackMetadata, newQueue?: TrackMetadata[]) => {
    try {
      let targetQueue = newQueue || queueRef.current;
      let targetIndex = targetQueue.findIndex((t) => t.path === track.path);

      if (targetIndex === -1) {
        targetQueue = [...targetQueue, track];
        targetIndex = targetQueue.length - 1;
      }

      // 1. Optimistic instant state updates (<5ms UI reaction)
      setQueue(targetQueue);
      setCurrentTrackIndex(targetIndex);
      setCurrentTrack(track);
      setPositionMs(0);
      setDurationMs(track.durationMs || 0);
      setPlaybackStatus('playing');

      // 2. Playback Scheduler with Request Cancellation
      const currentRequestId = ++playRequestCounter.current;
      if (playDebounceTimer.current !== null) {
        window.clearTimeout(playDebounceTimer.current);
        playDebounceTimer.current = null;
      }

      // Fast async invocation with superseding check
      playDebounceTimer.current = window.setTimeout(async () => {
        try {
          if (currentRequestId !== playRequestCounter.current) return;
          await audioService.loadTrack(track.path);
          if (currentRequestId !== playRequestCounter.current) return;
          await audioService.play();
        } catch (ipcErr) {
          console.error('Backend playback IPC failed:', ipcErr);
        }
      }, 40);

      // Auto add to library if missing (non-blocking)
      setLibraryTracks((prev) => {
        if (prev.some((t) => t.path === track.path)) return prev;
        return [track, ...prev];
      });
    } catch (err) {
      console.error('Failed to play track:', err);
    }
  }, []);



  const playTrackAtIndex = useCallback(
    async (index: number) => {
      const q = queueRef.current;
      if (index >= 0 && index < q.length) {
        await playTrack(q[index], q);
      }
    },
    [playTrack]
  );

  const playNext = useCallback(async () => {
    const q = queueRef.current;
    if (q.length === 0) return;

    let nextIndex: number;
    const mode = playModeRef.current;

    if (mode === 'shuffle') {
      if (q.length === 1) {
        nextIndex = 0;
      } else {
        let rnd = Math.floor(Math.random() * q.length);
        if (rnd === indexRef.current) rnd = (rnd + 1) % q.length;
        nextIndex = rnd;
      }
    } else if (mode === 'one') {
      nextIndex = indexRef.current >= 0 ? indexRef.current : 0;
    } else if (mode === 'sequential') {
      nextIndex = indexRef.current + 1;
      if (nextIndex >= q.length) {
        await audioService.stop();
        setPlaybackStatus('stopped');
        return;
      }
    } else {
      // 'all'
      nextIndex = (indexRef.current + 1) % q.length;
    }

    await playTrackAtIndex(nextIndex);
  }, [playTrackAtIndex]);

  const playPrevious = useCallback(async () => {
    const q = queueRef.current;
    if (q.length === 0) return;

    let prevIndex = indexRef.current - 1;
    if (prevIndex < 0) {
      prevIndex = q.length - 1;
    }
    await playTrackAtIndex(prevIndex);
  }, [playTrackAtIndex]);

  // Auto-play next on track-ended
  useEffect(() => {
    let unlisten: (() => void) | undefined;
    audioService
      .subscribeTrackEnded(() => {
        const mode = playModeRef.current;
        const q = queueRef.current;
        const curIdx = indexRef.current;

        if (mode === 'one') {
          if (curIdx >= 0 && curIdx < q.length) {
            playTrackAtIndex(curIdx);
          }
        } else if (mode === 'sequential') {
          if (curIdx + 1 < q.length) {
            playTrackAtIndex(curIdx + 1);
          } else {
            audioService.stop();
            setPlaybackStatus('stopped');
          }
        } else {
          playNext();
        }
      })
      .then((fn) => {
        unlisten = fn;
      })
      .catch((e) => console.warn('Track ended listener error:', e));

    return () => {
      if (unlisten) unlisten();
    };
  }, [playNext, playTrackAtIndex]);

  const togglePlayPause = useCallback(async () => {
    try {
      if (playbackStatus === 'playing') {
        await audioService.pause();
        setPlaybackStatus('paused');
      } else {
        if (!currentTrack && queueRef.current.length > 0) {
          await playTrackAtIndex(0);
        } else {
          await audioService.play();
          setPlaybackStatus('playing');
        }
      }
    } catch (err) {
      console.error('Error toggling play/pause:', err);
    }
  }, [playbackStatus, currentTrack, playTrackAtIndex]);

  // Subscribe to tray menu events
  useEffect(() => {
    let unlistenPlayPause: (() => void) | undefined;
    let unlistenPlayNext: (() => void) | undefined;

    audioService
      .subscribeTrayPlayPause(() => {
        togglePlayPause();
      })
      .then((fn) => {
        unlistenPlayPause = fn;
      })
      .catch((e) => console.warn('Tray play/pause listener error:', e));

    audioService
      .subscribeTrayPlayNext(() => {
        playNext();
      })
      .then((fn) => {
        unlistenPlayNext = fn;
      })
      .catch((e) => console.warn('Tray play next listener error:', e));

    return () => {
      if (unlistenPlayPause) unlistenPlayPause();
      if (unlistenPlayNext) unlistenPlayNext();
    };
  }, [togglePlayPause, playNext]);

  const seekTo = useCallback(async (ms: number) => {
    try {
      setPositionMs(ms);
      await audioService.seek(ms);
    } catch (err) {
      console.error('Error seeking:', err);
    }
  }, []);

  const changeVolume = useCallback(async (vol: number) => {
    const clamped = Math.max(0, Math.min(1, vol));
    setVolume(clamped);
    if (isMuted && clamped > 0) {
      setIsMuted(false);
    }
    try {
      await audioService.setVolume(clamped);
    } catch (err) {
      console.error('Error setting volume:', err);
    }
  }, [isMuted]);

  const toggleMute = useCallback(async () => {
    const nextMuted = !isMuted;
    setIsMuted(nextMuted);
    try {
      await audioService.setVolume(nextMuted ? 0 : volume);
    } catch (err) {
      console.error('Error toggling mute:', err);
    }
  }, [isMuted, volume]);

  // Queue Operations

  const addToQueue = useCallback((tracks: TrackMetadata | TrackMetadata[]) => {
    const arr = Array.isArray(tracks) ? tracks : [tracks];
    setQueue((prev) => [...prev, ...arr]);
  }, []);

  const removeFromQueue = useCallback((index: number) => {
    setQueue((prev) => prev.filter((_, i) => i !== index));
    if (currentTrackIndex === index) {
      playNext();
    } else if (currentTrackIndex > index) {
      setCurrentTrackIndex((prev) => prev - 1);
    }
  }, [currentTrackIndex, playNext]);

  const clearQueue = useCallback(() => {
    setQueue([]);
    setCurrentTrackIndex(-1);
  }, []);

  // Import Actions
  const importFilesAction = useCallback(async () => {
    try {
      const selectedPaths = await audioService.openAudioFilesDialog();
      if (selectedPaths.length > 0) {
        setIsScanning(true);
        setScannedCount(0);
        await audioService.scanFiles(selectedPaths);
      }
    } catch (err) {
      console.error('Failed to import files:', err);
      setIsScanning(false);
    }
  }, []);

  const scanDirectoryAction = useCallback(async () => {
    try {
      const selectedDir = await audioService.openDirectoryDialog();
      if (selectedDir) {
        setScannedFolders((prev) => Array.from(new Set([...prev, selectedDir])));
        setIsScanning(true);
        setScannedCount(0);
        await audioService.scanDirectory(selectedDir);
      }
    } catch (err) {
      console.error('Failed to scan directory:', err);
      setIsScanning(false);
    }
  }, []);

  const addScanFolderAction = useCallback(async () => {
    try {
      const selectedDir = await audioService.openDirectoryDialog();
      if (selectedDir) {
        setScannedFolders((prev) => Array.from(new Set([...prev, selectedDir])));
        setIsScanning(true);
        setScannedCount(0);
        await audioService.scanDirectory(selectedDir);
      }
    } catch (err) {
      console.error('Failed to add scan folder:', err);
      setIsScanning(false);
    }
  }, []);

  const removeScanFolder = useCallback((folderPath: string) => {
    setScannedFolders((prev) => prev.filter((f) => f !== folderPath));
    const normFolder = folderPath.replace(/\\/g, '/').toLowerCase();
    setLibraryTracks((prev) =>
      prev.filter((t) => {
        const normTrack = t.path.replace(/\\/g, '/').toLowerCase();
        return !normTrack.startsWith(normFolder);
      })
    );
  }, []);

  const rescanLibraryAction = useCallback(async () => {
    if (scannedFolders.length === 0) {
      return;
    }
    try {
      setIsScanning(true);
      setScannedCount(0);
      for (const dir of scannedFolders) {
        await audioService.scanDirectory(dir);
      }
    } catch (err) {
      console.error('Failed to rescan library:', err);
    } finally {
      setIsScanning(false);
    }
  }, [scannedFolders]);

  const clearLibrary = useCallback(() => {
    setLibraryTracks([]);
    localStorage.removeItem(STORAGE_KEY_LIBRARY);
  }, []);


  const removeTracksFromLibrary = useCallback((pathsToRemove: string[]) => {
    const set = new Set(pathsToRemove);
    setLibraryTracks((prev) => prev.filter((t) => !set.has(t.path)));
  }, []);


  // Favorites Management
  const isFavorite = useCallback(
    (path: string) => favorites.includes(path),
    [favorites]
  );

  const toggleFavorite = useCallback((path: string) => {
    setFavorites((prev) =>
      prev.includes(path) ? prev.filter((p) => p !== path) : [...prev, path]
    );
  }, []);

  const playNextTrack = useCallback(
    (track: TrackMetadata) => {
      setQueue((prev) => {
        const next = prev.filter((t) => t.path !== track.path);
        const insertIdx = currentTrackIndex >= 0 ? currentTrackIndex + 1 : 0;
        next.splice(insertIdx, 0, track);
        return next;
      });
    },
    [currentTrackIndex]
  );

  // Playlist Management
  const createPlaylist = useCallback((name: string, description?: string): string => {
    const id = `pl_${Date.now()}_${Math.random().toString(36).substr(2, 5)}`;
    const newPl: Playlist = {
      id,
      name,
      description,
      trackPaths: [],
      createdAt: Date.now(),
    };
    setPlaylists((prev) => [newPl, ...prev]);
    return id;
  }, []);

  const deletePlaylist = useCallback((id: string) => {
    setPlaylists((prev) => prev.filter((p) => p.id !== id));
  }, []);

  const renamePlaylist = useCallback((id: string, name: string) => {
    setPlaylists((prev) =>
      prev.map((p) => (p.id === id ? { ...p, name } : p))
    );
  }, []);

  const addTrackToPlaylist = useCallback((playlistId: string, trackPath: string) => {
    setPlaylists((prev) =>
      prev.map((p) => {
        if (p.id === playlistId) {
          if (p.trackPaths.includes(trackPath)) return p;
          return { ...p, trackPaths: [...p.trackPaths, trackPath] };
        }
        return p;
      })
    );
  }, []);

  const removeTrackFromPlaylist = useCallback((playlistId: string, trackPath: string) => {
    setPlaylists((prev) =>
      prev.map((p) => {
        if (p.id === playlistId) {
          return { ...p, trackPaths: p.trackPaths.filter((path) => path !== trackPath) };
        }
        return p;
      })
    );
  }, []);

  const playPlaylist = useCallback(
    async (playlistId: string) => {
      let tracksToPlay: TrackMetadata[] = [];
      if (playlistId === '__favorites__' || playlistId === '') {
        tracksToPlay = libraryTracks.filter((t) => favorites.includes(t.path));
      } else {
        const pl = playlists.find((p) => p.id === playlistId);
        if (!pl || pl.trackPaths.length === 0) return;

        tracksToPlay = pl.trackPaths
          .map((path) => libraryTracks.find((t) => t.path === path))
          .filter((t): t is TrackMetadata => t !== undefined);
      }

      if (tracksToPlay.length > 0) {
        await playTrack(tracksToPlay[0], tracksToPlay);
      }
    },
    [playlists, libraryTracks, favorites, playTrack]
  );

  return (
    <PlayerContext.Provider
      value={{
        activeTab,
        setActiveTab,
        currentTrack,
        playbackStatus,
        positionMs,
        durationMs,
        volume,
        isMuted,
        playMode,
        cyclePlayMode,
        setPlayMode,
        isDarkMode,
        themeMode,
        isNowPlayingOpen,
        setIsNowPlayingOpen,
        isQueueOpen,
        setIsQueueOpen,
        queue,
        currentTrackIndex,
        libraryTracks,
        playlists,
        favorites,
        isFavorite,
        toggleFavorite,
        currentLyrics,
        isScanning,
        scannedCount,

        lang,
        setLang,
        lyricsAlign,
        setLyricsAlign,
        lyricsFontSize,
        setLyricsFontSize,
        showTrans,
        setShowTrans,

        artistSeparators,
        setArtistSeparators,
        customSeedColor,
        setCustomSeedColor,
        isNavCollapsed,
        setIsNavCollapsed,
        autoCollapseRailOnNowPlaying,
        setAutoCollapseRailOnNowPlaying,

        eqSettings,

        setEqBand,

        setEqPreamp,
        setEqEnabled,
        applyEqPreset,
        resetEq,

        userProfile,
        setUserProfile,
        audioSettings,
        setAudioSettings,
        visibleNavIds,
        setVisibleNavIds,
        toggleDarkMode,
        setThemeMode,
        playTrack,
        playTrackAtIndex,
        playNext,
        playPrevious,
        togglePlayPause,
        seekTo,
        changeVolume,
        toggleMute,
        addToQueue,
        removeFromQueue,
        clearQueue,
        importFilesAction,
        scanDirectoryAction,
        scannedFolders,
        addScanFolderAction,
        removeScanFolder,
        rescanLibraryAction,
        clearLibrary,
        removeTracksFromLibrary,
        createPlaylist,


        deletePlaylist,
        renamePlaylist,
        addTrackToPlaylist,
        removeTrackFromPlaylist,
        playPlaylist,
        playNextTrack,
      }}
    >
      {children}
    </PlayerContext.Provider>
  );
};


export function usePlayer() {
  const context = useContext(PlayerContext);
  if (!context) {
    throw new Error('usePlayer must be used within a PlayerProvider');
  }
  return context;
}
