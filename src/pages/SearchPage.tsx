import React, { useState, useMemo } from 'react';
import { usePlayer } from '../context/PlayerContext';
import { I18N, formatCount } from '../i18n';
import { M3ListItem } from '../components/M3ListItem';
import { TrackMetadata } from '../types/audio';
import { TrackActionMenu } from '../components/TrackActionMenu';

const STORAGE_KEY_SEARCH_HISTORY = '0rhx_search_history';

export const SearchPage: React.FC = () => {
  const { lang, libraryTracks, playTrack, isFavorite, toggleFavorite } = usePlayer();
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

  const card = 'bg-md-surface-container hover:bg-md-surface-container-high shadow-sm';
  const primaryText = 'text-md-primary';

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
        <div className={`flex items-center ${card} rounded-full px-5 py-3.5 shadow-sm transition-all focus-within:ring-2 focus-within:ring-md-primary`}>
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
                className="px-3.5 py-1.5 rounded-full text-xs font-medium bg-md-surface-container hover:bg-md-surface-container-high shadow-xs flex items-center gap-2 transition"
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
              const isFav = isFavorite(tr.path);
              return (
                <M3ListItem
                  key={tr.path}
                  coverUrl={tr.coverUrl}
                  placeholderType="music"
                  title={tr.title || tr.path.split(/[/\\]/).pop() || ''}
                  subTitle={`${tr.artist || '—'}${tr.album ? ` • ${tr.album}` : ''}`}
                  badge={tr.format}
                  isFavorited={isFav}
                  onFavorite={() => toggleFavorite(tr.path)}
                  onMenu={() => { setMenuTrack(tr); setIsMenuOpen(true); }}
                  onClick={() => playTrack(tr, results)}
                />
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
            <span className="text-xs text-gray-500">{formatCount(libraryTracks.length, 'track', lang)}</span>
          </div>

          <div className="space-y-2">
            {libraryTracks.slice(0, 10).map(tr => {
              const isFav = isFavorite(tr.path);
              return (
                <M3ListItem
                  key={tr.path}
                  coverUrl={tr.coverUrl}
                  placeholderType="music"
                  title={tr.title || tr.path.split(/[/\\]/).pop() || ''}
                  subTitle={`${tr.artist || '—'}${tr.album ? ` • ${tr.album}` : ''}`}
                  badge={tr.format}
                  isFavorited={isFav}
                  onFavorite={() => toggleFavorite(tr.path)}
                  onMenu={() => { setMenuTrack(tr); setIsMenuOpen(true); }}
                  onClick={() => playTrack(tr, libraryTracks)}
                />
              );
            })}
          </div>
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


