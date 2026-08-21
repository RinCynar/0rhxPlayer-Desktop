import React, { useState, useRef } from 'react';
import { useVirtualizer } from '@tanstack/react-virtual';
import { usePlayer } from '../context/PlayerContext';
import { I18N } from '../i18n';
import { getCoverSrc } from '../utils/assetUrl';
import { M3CoverImage } from '../components/M3CoverImage';
import { TrackMetadata } from '../types/audio';
import { TrackActionMenu } from '../components/TrackActionMenu';

type QueueSubTab = 'played' | 'nexts';

export const QueuePage: React.FC = () => {
  const {
    isDarkMode, lang,
    queue, currentTrackIndex, currentTrack,
    playTrackAtIndex, removeFromQueue, clearQueue,
    isFavorite, toggleFavorite,
  } = usePlayer();

  const t = I18N[lang];
  const [subTab, setSubTab] = useState<QueueSubTab>('nexts');

  // Context menu
  const [menuTrack, setMenuTrack] = useState<TrackMetadata | null>(null);
  const [isMenuOpen, setIsMenuOpen] = useState(false);

  const card = isDarkMode ? 'bg-[#28272F]' : 'bg-[#E2DBE8]';
  const primaryBg = isDarkMode ? 'bg-[#39C5BB] text-[#003738]' : 'bg-[#006A6B] text-white';
  const primaryText = isDarkMode ? 'text-[#39C5BB]' : 'text-[#006A6B]';

  const coverSrc = getCoverSrc(currentTrack?.coverUrl);

  const playedTracks = queue.slice(0, Math.max(0, currentTrackIndex));
  const nextTracks = queue.slice(currentTrackIndex + 1);
  const displayTracks = subTab === 'played' ? playedTracks : nextTracks;
  const displayOffset = subTab === 'played' ? 0 : currentTrackIndex + 1;

  const parentRef = useRef<HTMLDivElement>(null);
  const rowVirtualizer = useVirtualizer({
    count: displayTracks.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 72,
    overscan: 5,
  });

  return (
    <div ref={parentRef} className="h-full overflow-y-auto p-8 space-y-6 animate-fade-in">
      <div className="max-w-6xl w-full mx-auto space-y-6 pb-20">
        {/* Transparent Hero Banner */}
        <div className="relative h-64 rounded-3xl overflow-hidden shadow-2xl bg-[#131317] p-8 flex flex-col justify-end">
          {coverSrc && (
            <img
              src={coverSrc}
              decoding="async"
              className="absolute inset-0 w-full h-full object-cover object-center"
            />
          )}
          {/* Transparent modern dark gradient (Task 2) */}
          <div
            className="absolute inset-0"
            style={{
              background:
                'linear-gradient(90deg, rgba(19, 19, 23, 0.90) 0%, rgba(19, 19, 23, 0.5) 60%, rgba(19, 19, 23, 0.15) 100%)',
            }}
          />

          <div className="relative z-10">
            <h1 className="text-4xl font-extrabold tracking-tight text-white">{t.nowPlayingTitle}</h1>
            <p className="text-sm text-gray-300 mt-1 font-medium">
              {currentTrack ? `${currentTrack.artist} • ${currentTrack.album}` : '—'}
            </p>
          </div>

          {/* Queue count badge */}
          <div className="absolute top-6 right-6 flex items-center gap-3 z-10">
            <span className="bg-black/50 backdrop-blur-md border border-white/10 rounded-full px-3.5 py-1 text-xs text-white font-mono shadow-sm">
              {queue.length} {t.trackCount}
            </span>
            {queue.length > 0 && (
              <button
                onClick={clearQueue}
                className="bg-black/50 backdrop-blur-md border border-white/10 rounded-full px-3.5 py-1 text-xs text-red-300 hover:text-red-200 hover:bg-red-500/20 transition cursor-pointer"
              >
                {t.clear}
              </button>
            )}
          </div>
        </div>

        {/* Segmented control: Played / Nexts */}
        <div className="flex justify-center">
          <div className={`${card} p-1 rounded-full flex items-center space-x-1 shadow-sm`}>
            {(['played', 'nexts'] as QueueSubTab[]).map(tab => (
              <button
                key={tab}
                onClick={() => setSubTab(tab)}
                className={`px-6 py-2 rounded-full text-xs font-semibold transition cursor-pointer ${subTab === tab ? `${primaryBg} shadow-md` : 'opacity-70 hover:opacity-100'}`}
              >
                {tab === 'played' ? `✓ ${t.played}` : t.nexts}
              </button>
            ))}
          </div>
        </div>

        {/* Track list (Virtualized for smooth 60fps scrolling) */}
        {displayTracks.length === 0 ? (
          <div className={`${card} rounded-3xl p-12 flex flex-col items-center gap-3 text-center`}>
            <i className={`fa-solid fa-list-ol text-4xl ${primaryText} opacity-40`} />
            <p className="text-sm text-gray-500 font-medium">
              {subTab === 'played' ? t.noPlayedTracks : t.noQueueTracks}
            </p>
          </div>
        ) : (
          <div
            style={{
              height: `${rowVirtualizer.getTotalSize()}px`,
              width: '100%',
              position: 'relative',
            }}
          >
            {rowVirtualizer.getVirtualItems().map(virtualRow => {
              const localIdx = virtualRow.index;
              const tr = displayTracks[localIdx];
              const globalIdx = displayOffset + localIdx;
              const isFav = isFavorite(tr.path);

              return (
                <div
                  key={tr.path + localIdx}
                  style={{
                    position: 'absolute',
                    top: 0,
                    left: 0,
                    width: '100%',
                    transform: `translateY(${virtualRow.start}px)`,
                  }}
                  className="py-1"
                >
                  <div
                    className={`${card} p-3.5 rounded-2xl flex items-center justify-between hover:bg-[#36343B] dark:hover:bg-[#36343B] transition group`}
                  >
                    <div
                      className="flex items-center space-x-4 cursor-pointer flex-1 min-w-0"
                      onClick={() => playTrackAtIndex(globalIdx)}
                    >
                      <div className="w-12 h-12 rounded-xl overflow-hidden shrink-0">
                        <M3CoverImage
                          src={tr.coverUrl}
                          alt={tr.title}
                          placeholderType="music"
                          className="w-12 h-12 rounded-xl"
                          iconClassName="text-base"
                        />
                      </div>
                      <div className="min-w-0 flex-1">
                        <div className={`font-semibold text-sm truncate ${isDarkMode ? 'group-hover:text-[#39C5BB]' : 'group-hover:text-[#006A6B]'} transition`}>
                          {tr.title || tr.path.split(/[/\\]/).pop()}
                        </div>
                        <div className="text-xs text-gray-500 dark:text-gray-400 mt-0.5 truncate">
                          {tr.artist || '—'} {tr.album ? `• ${tr.album}` : ''}
                        </div>
                      </div>
                    </div>

                    {/* Right Actions: Favorite, Menu, and Remove (Task 3: No ratings) */}
                    <div className="flex items-center space-x-2 shrink-0 ml-4">
                      {/* Favorite */}
                      <button
                        onClick={() => toggleFavorite(tr.path)}
                        className="w-8 h-8 rounded-full flex items-center justify-center transition hover:scale-110 cursor-pointer"
                        title={isFav ? t.favorited : t.favorite}
                      >
                        <i className={`${isFav ? 'fa-solid text-red-500' : 'fa-regular opacity-40 hover:opacity-80'} fa-heart text-sm`} />
                      </button>

                      {/* Action Menu */}
                      <button
                        onClick={() => { setMenuTrack(tr); setIsMenuOpen(true); }}
                        className="w-8 h-8 rounded-full hover:bg-black/10 dark:hover:bg-white/10 flex items-center justify-center opacity-0 group-hover:opacity-100 transition cursor-pointer"
                        title={t.moreActions}
                      >
                        <i className="fa-solid fa-ellipsis-vertical text-xs opacity-70" />
                      </button>

                      {/* Remove from queue */}
                      <button
                        onClick={() => removeFromQueue(globalIdx)}
                        className="w-8 h-8 rounded-full hover:bg-black/10 dark:hover:bg-white/10 flex items-center justify-center opacity-40 hover:opacity-100 hover:text-red-400 transition cursor-pointer"
                        title={t.removeFromQueue}
                      >
                        <i className="fa-solid fa-xmark text-sm" />
                      </button>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Track Action Menu Modal */}
      <TrackActionMenu
        track={menuTrack}
        isOpen={isMenuOpen}
        onClose={() => { setIsMenuOpen(false); setMenuTrack(null); }}
      />
    </div>
  );
};
