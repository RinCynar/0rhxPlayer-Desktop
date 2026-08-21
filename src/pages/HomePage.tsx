import React, { useState, useEffect, useRef, useCallback } from 'react';
import { usePlayer } from '../context/PlayerContext';
import { I18N } from '../i18n';
import { getCoverSrc } from '../utils/assetUrl';
import { TrackMetadata } from '../types/audio';

interface RecommendedAlbum {
  name: string;
  artist: string;
  coverUrl?: string;
  tracks: TrackMetadata[];
}

export const HomePage: React.FC = () => {
  const {
    isDarkMode, toggleDarkMode,
    lang, userProfile, setActiveTab,
    libraryTracks, playTrack,
    scanDirectoryAction,
  } = usePlayer();

  const t = I18N[lang];
  const [recommendedTracks, setRecommendedTracks] = useState<TrackMetadata[]>([]);
  const [recommendedAlbums, setRecommendedAlbums] = useState<RecommendedAlbum[]>([]);
  const [isRefreshing, setIsRefreshing] = useState<boolean>(false);
  const libraryLengthRef = useRef(libraryTracks.length);

  // Helper to sample recommendations without triggering on playback/re-renders
  const generateRecommendations = useCallback((tracks: TrackMetadata[]) => {
    if (tracks.length === 0) {
      setRecommendedTracks([]);
      setRecommendedAlbums([]);
      return;
    }

    // 1. 4 Random Tracks
    const pool = [...tracks];
    for (let i = pool.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [pool[i], pool[j]] = [pool[j], pool[i]];
    }
    setRecommendedTracks(pool.slice(0, 4));

    // 2. 11 Random Albums
    const map = new Map<string, RecommendedAlbum>();
    for (const tr of tracks) {
      const albumName = tr.album && tr.album.trim() ? tr.album.trim() : 'Unknown Album';
      if (!map.has(albumName)) {
        map.set(albumName, {
          name: albumName,
          artist: tr.artist || '—',
          coverUrl: tr.coverUrl,
          tracks: [tr],
        });
      } else {
        const entry = map.get(albumName)!;
        entry.tracks.push(tr);
        if (!entry.coverUrl && tr.coverUrl) {
          entry.coverUrl = tr.coverUrl;
        }
      }
    }
    const albums = Array.from(map.values());
    for (let i = albums.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [albums[i], albums[j]] = [albums[j], albums[i]];
    }
    setRecommendedAlbums(albums.slice(0, 11));
  }, []);

  // Lifecycle: Sample on mount
  useEffect(() => {
    generateRecommendations(libraryTracks);
  }, []); // Mount only

  // If library was empty and is now loaded, generate initial recommendations
  useEffect(() => {
    if (libraryLengthRef.current === 0 && libraryTracks.length > 0) {
      generateRecommendations(libraryTracks);
    }
    libraryLengthRef.current = libraryTracks.length;
  }, [libraryTracks.length, generateRecommendations]);

  const handleRefreshRecommendations = () => {
    setIsRefreshing(true);
    generateRecommendations(libraryTracks);
    setTimeout(() => setIsRefreshing(false), 300);
  };

  const getGreeting = (): string => {
    const hour = new Date().getHours();
    if (hour >= 5 && hour < 12) return t.greetingMorning;
    if (hour >= 12 && hour < 18) return t.greetingAfternoon;
    if (hour >= 18 && hour < 23) return t.greetingEvening;
    return t.greetingNight;
  };

  const card = isDarkMode ? 'bg-[#28272F]' : 'bg-[#E2DBE8]';
  const primaryText = isDarkMode ? 'text-[#39C5BB]' : 'text-[#006A6B]';

  const playAlbum = (albumTracks: TrackMetadata[]) => {
    if (albumTracks.length > 0) {
      playTrack(albumTracks[0], albumTracks);
    }
  };


  return (
    <div className="max-w-6xl w-full mx-auto space-y-8 p-8 animate-fade-in">
      {/* Header: User Greeting */}
      <div className="flex items-center justify-between">
        <div className="flex items-center space-x-4">
          {userProfile.avatar ? (
            <img
              src={userProfile.avatar}
              loading="lazy"
              decoding="async"
              className="w-12 h-12 rounded-full object-cover cursor-pointer hover:scale-105 transition shadow-md"
              onClick={() => setActiveTab('settings')}
            />
          ) : (
            <div
              className={`w-12 h-12 rounded-full flex items-center justify-center cursor-pointer hover:scale-105 transition ${isDarkMode ? 'bg-[#39C5BB]/20' : 'bg-[#39C5BB]/15'}`}
              onClick={() => setActiveTab('settings')}
            >
              <i className={`fa-solid fa-user text-lg ${primaryText}`} />
            </div>
          )}
          <div>
            <h1 className="text-2xl font-bold tracking-tight">{userProfile.nickname}</h1>
            <p className="text-sm text-gray-500 dark:text-gray-400 mt-0.5 font-medium">{getGreeting()}</p>
          </div>
        </div>
        <button
          onClick={toggleDarkMode}
          className="w-10 h-10 rounded-full bg-black/5 dark:bg-white/5 flex items-center justify-center hover:bg-black/10 dark:hover:bg-white/10 transition"
        >
          <i className={`fa-solid ${isDarkMode ? 'fa-sun text-amber-400' : 'fa-moon text-[#39C5BB]'}`} />
        </button>
      </div>

      {libraryTracks.length === 0 ? (
        <div className={`${card} rounded-3xl p-16 flex flex-col items-center justify-center gap-4 text-center mt-4`}>
          <i className={`fa-solid fa-music text-5xl ${primaryText} opacity-40`} />
          <p className="text-sm text-gray-500 dark:text-gray-400">{t.emptyLibrary}</p>
          <button
            onClick={scanDirectoryAction}
            className={`px-5 py-2.5 rounded-full ${isDarkMode ? 'bg-[#39C5BB] text-[#003738]' : 'bg-[#006A6B] text-white'} text-xs font-bold flex items-center gap-2 shadow hover:scale-105 transition`}
          >
            <i className="fa-solid fa-folder-open" />
            <span>{t.openFolder}</span>
          </button>
        </div>
      ) : (
        <>
          {/* Section: Top 4 Real Song Recommendations */}
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="text-lg font-bold">{t.featuredTracksTitle}</div>
                <button
                  onClick={handleRefreshRecommendations}
                  className="px-3 py-1 text-xs rounded-full bg-black/5 dark:bg-white/5 hover:bg-black/10 dark:hover:bg-white/10 text-[#006A6B] dark:text-[#39C5BB] font-semibold transition flex items-center gap-1.5 active:scale-95 shadow-xs"
                  title={t.refreshRecommendations}
                >
                  <i className={`fa-solid fa-arrows-rotate text-[11px] ${isRefreshing ? 'animate-spin' : ''}`} />
                  <span>{t.refreshRecommendations}</span>
                </button>
              </div>
              <button
                onClick={() => setActiveTab('library')}
                className="px-3.5 py-1 text-xs rounded-full bg-black/5 dark:bg-white/5 hover:bg-black/10 dark:hover:bg-white/10 text-[#006A6B] dark:text-[#39C5BB] font-semibold transition flex items-center gap-1.5 active:scale-95 shadow-xs"
              >
                <span>{t.showAll}</span>
                <i className="fa-solid fa-chevron-right text-[10px] opacity-70" />
              </button>
            </div>

            <div className="grid grid-cols-2 sm:grid-cols-4 gap-6">
              {recommendedTracks.map(tr => {
                const cover = getCoverSrc(tr.coverUrl);
                return (
                  <div
                    key={tr.path}
                    onClick={() => playTrack(tr, libraryTracks)}
                    className={`${card} p-4 rounded-3xl cursor-pointer group flex items-center space-x-3.5 hover:scale-[1.02] transition shadow-sm`}
                  >
                    <div className={`w-14 h-14 rounded-2xl ${isDarkMode ? 'bg-[#39C5BB]/20' : 'bg-[#39C5BB]/15'} flex items-center justify-center shrink-0 relative overflow-hidden bg-white/5`}>
                      {cover ? (
                        <img
                          src={cover}
                          loading="lazy"
                          decoding="async"
                          className="w-full h-full object-cover group-hover:scale-105 transition duration-300"
                        />
                      ) : (
                        <i className={`fa-solid fa-music text-lg ${primaryText}`} />
                      )}
                      <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 flex items-center justify-center transition">
                        <i className="fa-solid fa-play text-white text-xs" />
                      </div>
                    </div>
                    <div className="min-w-0 flex-1">
                      <div className={`font-bold text-xs truncate transition ${isDarkMode ? 'group-hover:text-[#39C5BB]' : 'group-hover:text-[#006A6B]'}`}>{tr.title}</div>
                      <div className="text-[11px] text-gray-500 dark:text-gray-400 mt-0.5 truncate">{tr.artist}</div>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          {/* Section: Real Album Recommendations (2 Rows, 11 Albums) */}
          {recommendedAlbums.length > 0 && (
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <div className="text-lg font-bold">{t.featuredAlbumsTitle}</div>
                <button
                  onClick={() => setActiveTab('library')}
                  className="px-3.5 py-1 text-xs rounded-full bg-black/5 dark:bg-white/5 hover:bg-black/10 dark:hover:bg-white/10 text-[#006A6B] dark:text-[#39C5BB] font-semibold transition flex items-center gap-1.5 active:scale-95 shadow-xs"
                >
                  <span>{t.showAll}</span>
                  <i className="fa-solid fa-chevron-right text-[10px] opacity-70" />
                </button>
              </div>
              <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-6 gap-4 sm:gap-5">
                {recommendedAlbums.map(album => {
                  const cover = getCoverSrc(album.coverUrl);
                  return (
                    <div
                      key={album.name}
                      onClick={() => playAlbum(album.tracks)}
                      className={`${card} p-3.5 rounded-3xl cursor-pointer group flex flex-col justify-between hover:-translate-y-1 transition-all duration-200 shadow-sm relative`}
                    >
                      <div className="w-full aspect-square rounded-2xl overflow-hidden relative mb-2.5 bg-white/5">
                        {cover ? (
                          <img
                            src={cover}
                            loading="lazy"
                            decoding="async"
                            className="w-full h-full object-cover group-hover:scale-105 transition duration-300"
                          />
                        ) : (
                          <div className={`w-full h-full flex items-center justify-center ${isDarkMode ? 'bg-white/5' : 'bg-black/5'}`}>
                            <i className="fa-solid fa-compact-disc text-4xl opacity-30" />
                          </div>
                        )}

                        <span className="absolute bottom-2 left-2 text-white text-[10px] font-semibold bg-black/50 backdrop-blur-xs px-2 py-0.5 rounded-md">
                          {album.tracks.length} {t.titles}
                        </span>

                        <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 flex items-center justify-center transition">
                          <div className="w-9 h-9 rounded-full bg-[#006A6B] dark:bg-[#39C5BB] text-white dark:text-[#003738] flex items-center justify-center shadow-lg">
                            <i className="fa-solid fa-play text-xs pl-0.5" />
                          </div>
                        </div>
                      </div>
                      <div>
                        <div className="font-bold text-xs truncate">{album.name}</div>
                        <div className="text-[11px] text-gray-500 dark:text-gray-400 mt-0.5 truncate">{album.artist}</div>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          )}


        </>
      )}
    </div>
  );
};

