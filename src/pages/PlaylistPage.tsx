import React, { useState, useMemo } from 'react';
import { usePlayer } from '../context/PlayerContext';
import { I18N } from '../i18n';
import { M3CoverImage } from '../components/M3CoverImage';
import { M3CoverPlaceholder } from '../components/M3CoverPlaceholder';
import { M3MediaCard } from '../components/M3MediaCard';
import { M3ListItem } from '../components/M3ListItem';
import { M3MediaGrid } from '../components/M3MediaGrid';
import { TrackMetadata } from '../types/audio';
import { TrackActionMenu } from '../components/TrackActionMenu';
import { formatDuration } from '../utils/formatters';

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

  const card = 'bg-md-surface-container hover:bg-md-surface-container-high shadow-sm';
  const primaryBg = 'bg-md-primary text-md-on-primary';
  const primaryText = 'text-md-primary';


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
            <div className="w-36 h-36 rounded-2xl overflow-hidden shrink-0 shadow-lg relative flex items-center justify-center">
              {selectedDetail.isFavorites ? (
                <M3CoverPlaceholder
                  type="heart"
                  className="w-36 h-36 rounded-2xl bg-gradient-to-br from-red-500/20 to-pink-500/20"
                  iconClassName="text-6xl text-red-400 opacity-90"
                />
              ) : (
                <M3CoverImage
                  src={selectedDetail.coverUrl}
                  alt={selectedDetail.name}
                  placeholderType="disc"
                  className="w-36 h-36 rounded-2xl"
                  iconClassName="text-6xl"
                />
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
            <div className="space-y-2">
              {selectedDetail.tracks.map((tr, idx) => {
                const isFav = isFavorite(tr.path);
                return (
                  <M3ListItem
                    key={tr.path}
                    coverUrl={tr.coverUrl}
                    placeholderType="music"
                    indexNumber={idx + 1}
                    title={tr.title}
                    subTitle={`${tr.artist} ${tr.album ? `• ${tr.album}` : ''}`}
                    badge={tr.format}
                    duration={formatDuration(tr.durationMs)}
                    isFavorited={isFav}
                    onFavorite={() => toggleFavorite(tr.path)}
                    onDelete={!selectedDetail.isFavorites ? () => removeTrackFromPlaylist(selectedDetail.id, tr.path) : undefined}
                    onMenu={() => { setMenuTrack(tr); setIsMenuOpen(true); }}
                    onClick={() => playTrack(tr, selectedDetail.tracks)}
                  />
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
          <M3MediaGrid>
            {/* Favorites Card */}
            <M3MediaCard
              icon="fa-solid fa-heart"
              iconBgClass="bg-gradient-to-br from-red-500/30 to-pink-500/30 text-red-400"
              title={t.favoritesPlaylist}
              subTitle={t.updatedToday}
              bottomBadge={`${favoriteCount} ${t.trackCount}`}
              onClick={() => setSelectedPlaylistId('__favorites__')}
            />

            {/* User Playlists */}
            {playlists.map(pl => (
              <M3MediaCard
                key={pl.id}
                icon="fa-solid fa-compact-disc"
                title={pl.name}
                subTitle={t.updatedToday}
                bottomBadge={`${pl.trackPaths.length} ${t.trackCount}`}
                onClick={() => setSelectedPlaylistId(pl.id)}
                customActions={
                  <button
                    onClick={e => {
                      e.stopPropagation();
                      deletePlaylist(pl.id);
                    }}
                    className="absolute top-2 right-2 w-7 h-7 rounded-full bg-black/50 text-white flex items-center justify-center hover:bg-red-500 transition opacity-0 group-hover:opacity-100 z-10"
                    title={t.deletePlaylist}
                  >
                    <i className="fa-solid fa-trash text-[11px]" />
                  </button>
                }
              />
            ))}
          </M3MediaGrid>

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
          <div className="bg-md-surface-container-high rounded-3xl p-6 max-w-sm w-full space-y-4 shadow-2xl">
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
              className={`w-full ${isDarkMode ? 'bg-white/5' : 'bg-black/5'} rounded-xl p-3 text-sm focus:outline-none focus:ring-2 focus:ring-md-primary`}
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

