import React, { useState } from 'react';
import { usePlayer } from '../context/PlayerContext';
import { TrackMetadata } from '../types/audio';
import { I18N } from '../i18n';

interface TrackActionMenuProps {
  track: TrackMetadata | null;
  isOpen: boolean;
  onClose: () => void;
}

export const TrackActionMenu: React.FC<TrackActionMenuProps> = ({ track, isOpen, onClose }) => {
  const {
    isDarkMode, lang,
    playlists, addTrackToPlaylist, createPlaylist,
    addToQueue, playNextTrack,
    isFavorite, toggleFavorite,
  } = usePlayer();

  const t = I18N[lang];
  const [isCreatingPl, setIsCreatingPl] = useState(false);
  const [newPlName, setNewPlName] = useState('');

  if (!isOpen || !track) return null;

  const isFav = isFavorite(track.path);
  const cardBg = isDarkMode ? 'bg-[#28272F]' : 'bg-white';
  const itemHover = isDarkMode ? 'hover:bg-white/10' : 'hover:bg-black/5';

  const handleAddToPl = (plId: string) => {
    addTrackToPlaylist(plId, track.path);
    onClose();
  };

  const handleCreateAndAdd = () => {
    const name = newPlName.trim();
    if (name) {
      const plId = createPlaylist(name);
      addTrackToPlaylist(plId, track.path);
      setNewPlName('');
      setIsCreatingPl(false);
      onClose();
    }
  };

  return (
    <div
      className="fixed inset-0 bg-black/60 backdrop-blur-xs z-50 flex items-center justify-center p-4 animate-fade-in"
      onClick={onClose}
    >
      <div
        className={`${cardBg} rounded-3xl p-5 max-w-sm w-full space-y-4 shadow-2xl`}
        onClick={e => e.stopPropagation()}
      >
        {/* Track header */}
        <div className="flex items-center justify-between pb-3 border-b border-black/5 dark:border-white/5">
          <div className="min-w-0 flex-1 pr-2">
            <div className="font-bold text-sm truncate">{track.title}</div>
            <div className="text-xs text-gray-400 truncate mt-0.5">{track.artist}</div>
          </div>
          <button
            onClick={() => toggleFavorite(track.path)}
            className={`w-8 h-8 rounded-full flex items-center justify-center transition ${isFav ? 'text-red-500 bg-red-500/10' : 'text-gray-400 hover:text-red-400 bg-black/5 dark:bg-white/5'}`}
            title={isFav ? t.favorited : t.addToFavorites}
          >
            <i className="fa-solid fa-heart text-sm" />
          </button>
        </div>

        {/* Quick Actions */}
        <div className="space-y-1 text-xs">
          <button
            onClick={() => { playNextTrack(track); onClose(); }}
            className={`w-full flex items-center gap-3 px-3.5 py-2.5 rounded-2xl ${itemHover} transition text-left`}
          >
            <i className="fa-solid fa-arrow-right-to-bracket text-sm opacity-60 w-4 text-center" />
            <span className="font-medium">{t.playNextAction}</span>
          </button>

          <button
            onClick={() => { addToQueue(track); onClose(); }}
            className={`w-full flex items-center gap-3 px-3.5 py-2.5 rounded-2xl ${itemHover} transition text-left`}
          >
            <i className="fa-solid fa-list-plus text-sm opacity-60 w-4 text-center" />
            <span className="font-medium">{t.addToQueueAction}</span>
          </button>
        </div>

        {/* Add to Playlist section */}
        <div className="pt-2 border-t border-black/5 dark:border-white/5 space-y-2">
          <div className="text-xs font-bold text-gray-400 flex items-center justify-between px-1">
            <span>{t.addToPlaylistAction}</span>
            <button
              onClick={() => setIsCreatingPl(!isCreatingPl)}
              className="text-[#39C5BB] dark:text-[#39C5BB] text-[11px] hover:underline flex items-center gap-1 font-semibold"
            >
              <i className="fa-solid fa-plus text-[10px]" />
              <span>{t.newPlaylistAction}</span>
            </button>
          </div>

          {isCreatingPl && (
            <div className="flex items-center gap-2 p-1">
              <input
                type="text"
                value={newPlName}
                onChange={e => setNewPlName(e.target.value)}
                onKeyDown={e => e.key === 'Enter' && handleCreateAndAdd()}
                placeholder={t.newPlaylistPlaceholder}
                autoFocus
                className={`flex-1 ${isDarkMode ? 'bg-white/5' : 'bg-black/5'} rounded-xl px-3 py-1.5 text-xs focus:outline-none focus:ring-1 focus:ring-[#39C5BB]`}
              />
              <button
                onClick={handleCreateAndAdd}
                className="px-3 py-1.5 rounded-xl bg-[#006A6B] dark:bg-[#39C5BB] text-white dark:text-[#003738] font-bold text-xs transition"
              >
                {t.confirm}
              </button>
            </div>
          )}

          <div className="max-h-40 overflow-y-auto space-y-1 no-scrollbar">
            {playlists.map(pl => {
              const inPlaylist = pl.trackPaths.includes(track.path);
              return (
                <button
                  key={pl.id}
                  onClick={() => handleAddToPl(pl.id)}
                  className={`w-full flex items-center justify-between px-3 py-2 rounded-xl ${itemHover} text-xs transition text-left`}
                >
                  <div className="flex items-center gap-2.5 truncate">
                    <i className="fa-solid fa-compact-disc text-xs opacity-50" />
                    <span className="truncate font-medium">{pl.name}</span>
                  </div>
                  {inPlaylist && (
                    <span className="text-[10px] text-green-400 font-semibold">{t.added}</span>
                  )}
                </button>
              );
            })}
            {playlists.length === 0 && !isCreatingPl && (
              <div className="text-[11px] text-gray-500 text-center py-2">
                {t.noCustomPlaylists}
              </div>
            )}
          </div>
        </div>


        {/* Close button */}
        <div className="flex justify-end pt-1">
          <button
            onClick={onClose}
            className="px-4 py-1.5 rounded-full text-xs text-gray-400 hover:text-white transition"
          >
            {t.cancel}
          </button>
        </div>
      </div>
    </div>
  );
};