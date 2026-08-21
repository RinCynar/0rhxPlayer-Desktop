import React, { useState, useMemo } from 'react';
import { usePlayer } from '../context/PlayerContext';
import { I18N } from '../i18n';
import { getCoverSrc } from '../utils/assetUrl';
import { TrackMetadata } from '../types/audio';
import { TrackActionMenu } from '../components/TrackActionMenu';

function formatDuration(ms: number): string {
  if (!ms || isNaN(ms)) return '0:00';
  const totalSeconds = Math.floor(ms / 1000);
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${minutes}:${seconds < 10 ? '0' : ''}${seconds}`;
}

export const PlaylistPage: React.FC = () => {
  const {
    isDarkMode, lang,
    playlists, createPlaylist, deletePlaylist, renamePlaylist,
    removeTrackFromPlaylist, playTrack,
    libraryTracks, favorites, toggleFavorite, isFavorite,
  } = usePlayer();

  const t = I18N[lang];
  const [isCreating, setIsCreating] = useState(false);
  const [newPlaylistName, setNewPlaylistName] = useState('');
  const [selectedPlaylistId, setSelectedPlaylistId] = useState<string | null>(null);
  const [isRenaming, setIsRenaming] = useState(false);
  const [renameValue, setRenameValue] = useState('');

  // Context action menu
  const [menuTrack, setMenuTrack] = useState<TrackMetadata | null>(null);
  const [isMenuOpen, setIsMenuOpen] = useState(false);

  const card = isDarkMode ? 'bg-[#28272F]' : 'bg-[#E2DBE8]';
  const primaryBg = isDarkMode ? 'bg-[#39C5BB] text-[#003738]' : 'bg-[#006A6B] text-white';
  const primaryText = isDarkMode ? 'text-[#39C5BB]' : 'text-[#006A6B]';


  // Selected playlist tracks & metadata
  const selectedDetail = useMemo(() => {
    if (!selectedPlaylistId) return null;
    if (selectedPlaylistId === '__favorites__') {
      const favTracks = libraryTracks.filter(tr => favorites.includes(tr.path));
      return {
        id: '__favorites__',
        name: t.favoritesPlaylist,
        isFavorites: true,
        tracks: favTracks,
        coverUrl: favTracks[0]?.coverUrl,
      };
    }
    const pl = playlists.find(p => p.id === selectedPlaylistId);
    if (!pl) return null;
    const tracks = pl.trackPaths
      .map(path => libraryTracks.find(t => t.path === path))
      .filter((t): t is TrackMetadata => t !== undefined);
    return {
      id: pl.id,
      name: pl.name,
      isFavorites: false,
      tracks,
      coverUrl: tracks[0]?.coverUrl,
      createdAt: pl.createdAt,
    };
  }, [selectedPlaylistId, playlists, libraryTracks, favorites, t.favoritesPlaylist]);

  const handleCreate = () => {
    const name = newPlaylistName.trim();
    if (name) {
      createPlaylist(name);
      setNewPlaylistName('');
      setIsCreating(false);
    }
  };

  const handleSaveRename = () => {
    if (selectedPlaylistId && renameValue.trim()) {
      renamePlaylist(selectedPlaylistId, renameValue.trim());
      setIsRenaming(false);
    }
  };

  const playAllInDetail = () => {
    if (selectedDetail && selectedDetail.tracks.length > 0) {
      playTrack(selectedDetail.tracks[0], selectedDetail.tracks);
    }
  };

  const shufflePlayAll = () => {
    if (selectedDetail && selectedDetail.tracks.length > 0) {
      const shuffled = [...selectedDetail.tracks].sort(() => Math.random() - 0.5);
      playTrack(shuffled[0], shuffled);
    }
  };

  // FAVORITES count
  const favoriteCount = useMemo(() => {
    return libraryTracks.filter(tr => favorites.includes(tr.path)).length;
  }, [libraryTracks, favorites]);

  return (
    <div className="max-w-6xl w-full mx-auto p-8 space-y-6 animate-fade-in">
      {/* 1. PLAYLIST DETAIL VIEW */}
      {selectedPlaylistId && selectedDetail ? (
        <div className="space-y-6">
          {/* Back button */}
          <button
            onClick={() => { setSelectedPlaylistId(null); setIsRenaming(false); }}
            className={`flex items-center gap-2 text-xs font-semibold ${primaryText} hover:underline mb-2`}
          >
            <i className="fa-solid fa-arrow-left" />
            <span>{t.backToPlaylists}</span>
          </button>

          {/* Playlist Header Banner */}
          <div className={`${card} p-6 rounded-3xl flex flex-col sm:flex-row items-center sm:items-end gap-6`}>
            <div className="w-36 h-36 rounded-2xl overflow-hidden shrink-0 shadow-lg relative bg-gradient-to-br from-[#39C5BB]/30 to-[#006A6B]/30 flex items-center justify-center">
              {selectedDetail.isFavorites ? (
                <i className="fa-solid fa-heart text-6xl text-red-400 opacity-80" />
              ) : selectedDetail.coverUrl ? (
                <img
                  src={getCoverSrc(selectedDetail.coverUrl)}
                  loading="lazy"
                  decoding="async"
                  className="w-full h-full object-cover"
                />
              ) : (
                <i className={`fa-solid fa-compact-disc text-6xl ${primaryText} opacity-40`} />
              )}
            </div>

            <div className="flex-1 min-w-0 space-y-3 text-center sm:text-left">
              <span className="text-xs font-bold uppercase tracking-wider text-gray-400">
                {selectedDetail.isFavorites ? t.systemPlaylist : t.customPlaylist}
              </span>

              {isRenaming ? (
                <div className="flex items-center gap-2">
                  <input
                    type="text"
                    value={renameValue}
                    onChange={e => setRenameValue(e.target.value)}
                    onKeyDown={e => e.key === 'Enter' && handleSaveRename()}
                    autoFocus
                    className={`text-2xl font-bold rounded-xl px-3 py-1 ${isDarkMode ? 'bg-white/10' : 'bg-black/5'} focus:outline-none`}
                  />
                  <button onClick={handleSaveRename} className={`px-4 py-1.5 rounded-full ${primaryBg} text-xs font-semibold`}>
                    {t.save}
                  </button>
                  <button onClick={() => setIsRenaming(false)} className="px-3 py-1.5 text-xs text-gray-400">
                    {t.cancel}
                  </button>
                </div>
              ) : (
                <h1 className="text-3xl font-bold tracking-tight truncate">{selectedDetail.name}</h1>
              )}

              <div className="text-xs text-gray-500 dark:text-gray-400">
                <span>{selectedDetail.tracks.length} {t.trackCount}</span>
              </div>

              {/* Action Buttons */}
              <div className="flex items-center gap-3 pt-2 flex-wrap justify-center sm:justify-start">
                <button
                  onClick={playAllInDetail}
                  disabled={selectedDetail.tracks.length === 0}
                  className={`px-5 py-2.5 rounded-full ${primaryBg} text-xs font-semibold flex items-center gap-2 shadow-md hover:scale-105 disabled:opacity-50 transition`}
                >
                  <i className="fa-solid fa-play text-xs" />
                  <span>{t.playAll}</span>
                </button>

                <button
                  onClick={shufflePlayAll}
                  disabled={selectedDetail.tracks.length === 0}
                  className="px-4 py-2.5 rounded-full bg-black/5 dark:bg-white/5 hover:bg-black/10 dark:hover:bg-white/10 text-xs font-semibold flex items-center gap-2 transition disabled:opacity-50"
                >
                  <i className="fa-solid fa-shuffle text-xs" />
                  <span>{t.shufflePlay}</span>
                </button>

                {!selectedDetail.isFavorites && (
                  <>
                    <button
                      onClick={() => { setRenameValue(selectedDetail.name); setIsRenaming(true); }}
                      className="w-9 h-9 rounded-full bg-black/5 dark:bg-white/5 hover:bg-black/10 dark:hover:bg-white/10 flex items-center justify-center transition text-gray-400"
                      title={t.renamePlaylist}
                    >
                      <i className="fa-solid fa-pen text-xs" />
                    </button>

                    <button
                      onClick={() => { deletePlaylist(selectedDetail.id); setSelectedPlaylistId(null); }}
                      className="w-9 h-9 rounded-full bg-black/5 dark:bg-white/5 hover:bg-red-500 hover:text-white flex items-center justify-center transition text-gray-400"
                      title={t.deletePlaylist}
                    >
                      <i className="fa-solid fa-trash text-xs" />
                    </button>
                  </>
                )}
              </div>
            </div>
          </div>

          {/* Track List */}
          {selectedDetail.tracks.length === 0 ? (
            <div className={`${card} rounded-3xl p-16 flex flex-col items-center justify-center gap-3 text-center`}>
              <i className={`fa-solid fa-music text-4xl ${primaryText} opacity-30`} />
              <p className="text-sm text-gray-500">{t.emptyPlaylistHint}</p>
            </div>
          ) : (
            <div className="space-y-1.5">
              {selectedDetail.tracks.map((tr, idx) => {
                const cover = getCoverSrc(tr.coverUrl);
                const isFav = isFavorite(tr.path);
                return (
                  <div
                    key={tr.path}
                    onClick={() => playTrack(tr, selectedDetail.tracks)}
                    className={`${card} p-3 rounded-2xl flex items-center justify-between cursor-pointer group hover:bg-[#36343B] dark:hover:bg-[#36343B] transition`}
                  >
                    <div className="flex items-center space-x-3.5 min-w-0 flex-1">
                      <span className="text-xs font-mono text-gray-400 w-5 text-center shrink-0">
                        {idx + 1}
                      </span>
                      <div className="w-10 h-10 rounded-xl overflow-hidden shrink-0 bg-white/5">
                        {cover ? (
                          <img
                            src={cover}
                            loading="lazy"
                            decoding="async"
                            className="w-full h-full object-cover"
                          />
                        ) : (
                          <div className={`w-full h-full flex items-center justify-center ${isDarkMode ? 'bg-white/5' : 'bg-black/5'}`}>
                            <i className="fa-solid fa-music opacity-30 text-xs" />
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
                      <span className="text-xs font-mono text-gray-400 w-12 text-right hidden sm:inline">
                        {formatDuration(tr.durationMs)}
                      </span>

                      {/* Favorite button */}
                      <button
                        onClick={e => { e.stopPropagation(); toggleFavorite(tr.path); }}
                        className={`w-8 h-8 rounded-full flex items-center justify-center transition ${isFav ? 'text-red-500' : 'text-gray-400 opacity-0 group-hover:opacity-100 hover:text-red-400'}`}
                      >
                        <i className="fa-solid fa-heart text-xs" />
                      </button>

                      {/* Remove from playlist button */}
                      {!selectedDetail.isFavorites && (
                        <button
                          onClick={e => { e.stopPropagation(); removeTrackFromPlaylist(selectedDetail.id, tr.path); }}
                          className="w-8 h-8 rounded-full text-gray-400 hover:text-red-400 flex items-center justify-center opacity-0 group-hover:opacity-100 transition"
                          title={t.removeFromPlaylist}
                        >
                          <i className="fa-solid fa-xmark text-xs" />
                        </button>
                      )}


                      {/* Menu */}
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
        </div>
      ) : (
        /* 2. PLAYLISTS GRID VIEW */
        <>
          <div className="flex items-center justify-between">
            <h1 className="text-3xl font-bold tracking-tight">{t.myPlaylists}</h1>
            <button
              onClick={() => setIsCreating(true)}
              className={`px-4 py-2.5 rounded-full ${primaryBg} text-xs font-semibold flex items-center gap-2 shadow-md hover:scale-105 transition`}
            >
              <i className="fa-solid fa-plus" />
              <span>{t.createPlaylist}</span>
            </button>
          </div>

          {/* Playlists Grid */}
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-5">
            {/* Favorites Card */}
            <div
              onClick={() => setSelectedPlaylistId('__favorites__')}
              className={`${card} p-4 rounded-3xl cursor-pointer group flex flex-col justify-between hover:-translate-y-1 transition-all duration-200 shadow-sm`}
            >
              <div className="w-full aspect-square rounded-2xl overflow-hidden relative mb-3 bg-gradient-to-br from-red-500/30 to-pink-500/30 flex items-center justify-center group-hover:scale-[1.02] transition">
                <i className="fa-solid fa-heart text-4xl text-red-400 opacity-70" />
                <span className="absolute bottom-2 left-2 text-white text-[11px] font-semibold bg-black/40 backdrop-blur-xs px-2 py-0.5 rounded-md">
                  {favoriteCount} {t.trackCount}
                </span>
              </div>
              <div>
                <div className="font-bold text-sm truncate">{t.favoritesPlaylist}</div>
                <div className="text-xs text-gray-500 dark:text-gray-400 mt-0.5">{t.updatedToday}</div>
              </div>
            </div>

            {/* User Playlists */}
            {playlists.map(pl => (
              <div
                key={pl.id}
                onClick={() => setSelectedPlaylistId(pl.id)}
                className={`${card} p-4 rounded-3xl cursor-pointer group flex flex-col justify-between hover:-translate-y-1 transition-all duration-200 shadow-sm relative`}
              >
                <div className="w-full aspect-square rounded-2xl overflow-hidden relative mb-3 bg-gradient-to-br from-[#39C5BB]/20 to-[#006A6B]/20 flex items-center justify-center group-hover:scale-[1.02] transition">
                  <i className={`fa-solid fa-compact-disc text-4xl ${primaryText} opacity-50`} />
                  <span className="absolute bottom-2 left-2 text-white text-[11px] font-semibold bg-black/40 backdrop-blur-xs px-2 py-0.5 rounded-md">
                    {pl.trackPaths.length} {t.trackCount}
                  </span>
                  <button
                    onClick={e => { e.stopPropagation(); deletePlaylist(pl.id); }}
                    className="absolute top-2 right-2 w-7 h-7 rounded-full bg-black/50 text-white flex items-center justify-center hover:bg-red-500 transition opacity-0 group-hover:opacity-100"
                    title={t.deletePlaylist}
                  >
                    <i className="fa-solid fa-trash text-[11px]" />
                  </button>

                </div>
                <div>
                  <div className="font-bold text-sm truncate">{pl.name}</div>
                  <div className="text-xs text-gray-500 dark:text-gray-400 mt-0.5">{t.updatedToday}</div>
                </div>
              </div>
            ))}
          </div>

          {playlists.length === 0 && (
            <div className={`${card} rounded-3xl p-16 flex flex-col items-center gap-4 text-center mt-4`}>
              <i className={`fa-solid fa-compact-disc text-5xl ${primaryText} opacity-40`} />
              <p className="text-sm text-gray-500">{t.createPlaylist}</p>
            </div>
          )}
        </>
      )}

      {/* Create Playlist Modal */}
      {isCreating && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className={`${isDarkMode ? 'bg-[#28272F]' : 'bg-white'} rounded-3xl p-6 max-w-sm w-full space-y-4 shadow-2xl`}>
            <h3 className={`text-base font-bold ${primaryText}`}>
              <i className="fa-solid fa-plus mr-2" />{t.createPlaylist}
            </h3>
            <input
              type="text"
              value={newPlaylistName}
              onChange={e => setNewPlaylistName(e.target.value)}
              onKeyDown={e => e.key === 'Enter' && handleCreate()}
              placeholder={t.myPlaylists}
              autoFocus
              className={`w-full ${isDarkMode ? 'bg-white/5' : 'bg-black/5'} rounded-xl p-3 text-sm focus:outline-none focus:ring-2 focus:ring-[#39C5BB]`}
            />


            <div className="flex justify-end gap-3">
              <button
                onClick={() => { setIsCreating(false); setNewPlaylistName(''); }}
                className="px-4 py-2 rounded-full text-xs font-semibold text-gray-400 hover:text-white transition"
              >
                {t.cancel}
              </button>
              <button
                onClick={handleCreate}
                className={`px-5 py-2 rounded-full ${primaryBg} font-semibold text-xs hover:opacity-90 transition shadow`}
              >
                {t.saveNavCustom}
              </button>
            </div>
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

