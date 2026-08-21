import React, { useState, useMemo } from 'react';
import { usePlayer } from '../context/PlayerContext';
import { I18N, formatCount } from '../i18n';
import { getCoverSrc } from '../utils/assetUrl';

import { TrackMetadata } from '../types/audio';
import { TrackActionMenu } from '../components/TrackActionMenu';

const STORAGE_KEY_SEARCH_HISTORY = '0rhx_search_history';

export const SearchPage: React.FC = () => {
  const { isDarkMode, lang, libraryTracks, playTrack, isFavorite, toggleFavorite } = usePlayer();
  const t = I18N[lang];
  const [query, setQuery] = useState('');
  const [history, setHistory] = useState<string[]>(() => {
    try {
      const saved = localStorage.getItem(STORAGE_KEY_SEARCH_HISTORY);
      return saved ? JSON.parse(saved) : [];
    } catch {
      return [];
    }
  });

  // Action Menu
  const [menuTrack, setMenuTrack] = useState<TrackMetadata | null>(null);
  const [isMenuOpen, setIsMenuOpen] = useState(false);

  const card = isDarkMode ? 'bg-[#28272F]' : 'bg-[#E2DBE8]';
  const primaryText = isDarkMode ? 'text-[#39C5BB]' : 'text-[#006A6B]';

  // Save query to history on enter
  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter' && query.trim()) {
      const trimmed = query.trim();
      setHistory(prev => {
        const next = [trimmed, ...prev.filter(x => x !== trimmed)].slice(0, 8);
        try { localStorage.setItem(STORAGE_KEY_SEARCH_HISTORY, JSON.stringify(next)); } catch { /* ignore */ }
        return next;
      });
    }
  };

  const removeHistoryItem = (item: string, e: React.MouseEvent) => {
    e.stopPropagation();
    setHistory(prev => {
      const next = prev.filter(x => x !== item);
      try { localStorage.setItem(STORAGE_KEY_SEARCH_HISTORY, JSON.stringify(next)); } catch { /* ignore */ }
      return next;
    });
  };

  const clearAllHistory = () => {
    setHistory([]);
    try { localStorage.removeItem(STORAGE_KEY_SEARCH_HISTORY); } catch { /* ignore */ }
  };

  const results = useMemo(() => {
    if (!query.trim()) return [];
    const q = query.toLowerCase();
    return libraryTracks.filter(tr =>
      (tr.title || '').toLowerCase().includes(q) ||
      (tr.artist || '').toLowerCase().includes(q) ||
      (tr.album || '').toLowerCase().includes(q)
    );
  }, [query, libraryTracks]);

  return (
    <div className="max-w-5xl w-full mx-auto p-8 space-y-6 animate-fade-in">
      <div className="flex items-center justify-between">
        <h1 className="text-3xl font-bold tracking-tight">{t.search}</h1>
      </div>

      {/* Capsule Search Bar */}
      <div className="relative w-full">
        <div className={`flex items-center ${card} rounded-full px-5 py-3.5 shadow-sm transition-all focus-within:ring-2 focus-within:ring-[#39C5BB]`}>
          <i className="fa-solid fa-magnifying-glass text-base opacity-50 mr-3.5" />
          <input
            type="text"
            value={query}
            onChange={e => setQuery(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder={t.hintedSearch}
            className="w-full bg-transparent text-sm focus:outline-none placeholder:text-gray-400"
            autoFocus
          />

          {query && (
            <button
              onClick={() => setQuery('')}
              className="w-6 h-6 rounded-full hover:bg-black/10 dark:hover:bg-white/10 flex items-center justify-center transition text-gray-400"
            >
              <i className="fa-solid fa-xmark text-xs" />
            </button>
          )}
        </div>
      </div>

      {/* Search History Chips */}
      {history.length > 0 && !query && (
        <div className="space-y-2">
          <div className="flex items-center justify-between text-xs font-semibold text-gray-400">
            <span>{t.searchHistory}</span>
            <button onClick={clearAllHistory} className="hover:text-gray-200 transition">{t.clear}</button>
          </div>
          <div className="flex flex-wrap gap-2">
            {history.map(item => (
              <button
                key={item}
                onClick={() => setQuery(item)}
                className={`px-3.5 py-1.5 rounded-full text-xs font-medium ${isDarkMode ? 'bg-[#28272F] hover:bg-[#36343B]' : 'bg-[#E2DBE8] hover:bg-[#D8D0DF]'} flex items-center gap-2 transition`}
              >
                <span>{item}</span>
                <i
                  onClick={e => removeHistoryItem(item, e)}
                  className="fa-solid fa-xmark text-[10px] opacity-40 hover:opacity-100"
                />
              </button>
            ))}
          </div>
        </div>
      )}

      {/* Real-time Search Results */}
      {query && (
        <div className="space-y-3">
          <div className="flex items-center justify-between text-sm font-bold">
            <span>{results.length > 0 ? `${t.searchTrackResults} (${results.length})` : t.noMatchResults}</span>
          </div>

          {results.length === 0 ? (
            <div className={`${card} rounded-3xl p-12 flex flex-col items-center gap-3 text-center`}>
              <i className={`fa-solid fa-magnifying-glass text-4xl ${primaryText} opacity-30`} />
              <p className="text-sm text-gray-500">{t.noMatchDesc}</p>
            </div>
          ) : (

            results.map(tr => {
              const cover = getCoverSrc(tr.coverUrl);
              const isFav = isFavorite(tr.path);
              return (
                <div
                  key={tr.path}
                  onClick={() => playTrack(tr, results)}
                  className={`${card} p-3.5 rounded-2xl flex items-center justify-between cursor-pointer group hover:bg-[#36343B] dark:hover:bg-[#36343B] transition`}
                >
                  <div className="flex items-center space-x-3.5 min-w-0 flex-1">
                    <div className="w-11 h-11 rounded-xl overflow-hidden shrink-0 bg-white/5">
                      {cover ? (
                        <img
                          src={cover}
                          loading="lazy"
                          decoding="async"
                          className="w-full h-full object-cover"
                        />
                      ) : (
                        <div className={`w-full h-full flex items-center justify-center ${isDarkMode ? 'bg-white/5' : 'bg-black/5'}`}>
                          <i className="fa-solid fa-music opacity-30" />
                        </div>
                      )}
                    </div>

                    <div className="min-w-0 flex-1">
                      <div className="font-semibold text-sm truncate">{tr.title}</div>
                      <div className="text-xs text-gray-500 dark:text-gray-400 truncate">{tr.artist} {tr.album ? `• ${tr.album}` : ''}</div>
                    </div>
                  </div>

                  <div className="flex items-center space-x-2 shrink-0">
                    {tr.format && (
                      <span className="text-[10px] font-mono text-amber-400 hidden sm:inline mr-2">{tr.format.split(' ')[0]}</span>
                    )}
                    <button
                      onClick={e => { e.stopPropagation(); toggleFavorite(tr.path); }}
                      className={`w-8 h-8 rounded-full flex items-center justify-center transition ${isFav ? 'text-red-500' : 'text-gray-400 opacity-0 group-hover:opacity-100 hover:text-red-400'}`}
                    >
                      <i className="fa-solid fa-heart text-xs" />
                    </button>
                    <button
                      onClick={e => { e.stopPropagation(); setMenuTrack(tr); setIsMenuOpen(true); }}
                      className="w-8 h-8 rounded-full hover:bg-black/10 dark:hover:bg-white/10 flex items-center justify-center opacity-0 group-hover:opacity-100 transition"
                    >
                      <i className="fa-solid fa-ellipsis-vertical text-xs opacity-70" />
                    </button>
                  </div>
                </div>
              );
            })
          )}
        </div>
      )}

      {/* Default: Library Tracks when not searching */}
      {!query && libraryTracks.length > 0 && (
        <div className="space-y-3 pt-2">
          <div className="flex items-center justify-between text-sm font-bold">
            <span>{t.libraryTracksHeader}</span>
            <span className="text-xs text-gray-500 font-mono">{formatCount(libraryTracks.length, 'track', lang)}</span>
          </div>

          {libraryTracks.slice(0, 10).map(tr => {
            const cover = getCoverSrc(tr.coverUrl);
            const isFav = isFavorite(tr.path);
            return (
              <div
                key={tr.path}
                onClick={() => playTrack(tr, libraryTracks)}
                className={`${card} p-3.5 rounded-2xl flex items-center justify-between cursor-pointer group hover:bg-[#36343B] dark:hover:bg-[#36343B] transition`}
              >
                <div className="flex items-center space-x-3.5 min-w-0 flex-1">
                  <div className="w-11 h-11 rounded-xl overflow-hidden shrink-0">
                    {cover ? (
                      <img src={cover} className="w-full h-full object-cover" />
                    ) : (
                      <div className={`w-full h-full flex items-center justify-center ${isDarkMode ? 'bg-white/5' : 'bg-black/5'}`}>
                        <i className="fa-solid fa-music opacity-30" />
                      </div>
                    )}
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="font-semibold text-sm truncate">{tr.title}</div>
                    <div className="text-xs text-gray-500 dark:text-gray-400 truncate">{tr.artist} {tr.album ? `• ${tr.album}` : ''}</div>
                  </div>
                </div>

                <div className="flex items-center space-x-2 shrink-0">
                  {tr.format && (
                    <span className="text-[10px] font-mono text-amber-400 hidden sm:inline mr-2">{tr.format.split(' ')[0]}</span>
                  )}
                  <button
                    onClick={e => { e.stopPropagation(); toggleFavorite(tr.path); }}
                    className={`w-8 h-8 rounded-full flex items-center justify-center transition ${isFav ? 'text-red-500' : 'text-gray-400 opacity-0 group-hover:opacity-100 hover:text-red-400'}`}
                  >
                    <i className="fa-solid fa-heart text-xs" />
                  </button>
                  <button
                    onClick={e => { e.stopPropagation(); setMenuTrack(tr); setIsMenuOpen(true); }}
                    className="w-8 h-8 rounded-full hover:bg-black/10 dark:hover:bg-white/10 flex items-center justify-center opacity-0 group-hover:opacity-100 transition"
                  >
                    <i className="fa-solid fa-ellipsis-vertical text-xs opacity-70" />
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Track Action Menu Modal */}
      <TrackActionMenu
        track={menuTrack}
        isOpen={isMenuOpen}
        onClose={() => { setIsMenuOpen(false); setMenuTrack(null); }}
      />
    </div>
  );
};


