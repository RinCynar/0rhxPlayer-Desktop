import React, { useRef } from 'react';
import { usePlayer } from '../context/PlayerContext';
import { I18N } from '../i18n';
import { M3CoverImage } from './M3CoverImage';

export const BottomPlayerBar: React.FC = () => {

  const {
    currentTrack, playbackStatus, positionMs, durationMs,
    isDarkMode, isNowPlayingOpen, setIsNowPlayingOpen,
    playMode, cyclePlayMode,
    lang, showTrans, setShowTrans,
    togglePlayPause, playNext, playPrevious, seekTo,
    activeTab, setActiveTab,
  } = usePlayer();

  const t = I18N[lang];
  const progressRef = useRef<HTMLDivElement>(null);
  const progress = durationMs > 0 ? (positionMs / durationMs) * 100 : 0;

  const handleSeekClick = (e: React.MouseEvent<HTMLDivElement>) => {
    const rect = e.currentTarget.getBoundingClientRect();
    const pct = (e.clientX - rect.left) / rect.width;
    seekTo(Math.floor(pct * durationMs));
  };

  const surface = isDarkMode ? 'bg-[#1C1B20]' : 'bg-[#EDE7F0]';
  const primaryText = isDarkMode ? 'text-[#39C5BB]' : 'text-[#006A6B]';

  const getPlayModeIcon = () => {
    switch (playMode) {
      case 'one':
        return (
          <div className="relative inline-flex items-center justify-center">
            <i className={`fa-solid fa-repeat text-base ${primaryText}`} />
            <span className="absolute -top-1 -right-1 text-[9px] font-extrabold bg-current text-white dark:text-black rounded-full px-0.5 leading-none">
              1
            </span>
          </div>
        );
      case 'shuffle':
        return <i className={`fa-solid fa-shuffle text-base ${primaryText}`} />;
      case 'sequential':
        return <i className={`fa-solid fa-arrow-right-long text-base ${primaryText}`} />;
      case 'all':
      default:
        return <i className={`fa-solid fa-repeat text-base ${primaryText}`} />;
    }
  };

  const getPlayModeTitle = () => {
    switch (playMode) {
      case 'one':
        return t.repeatOne;
      case 'shuffle':
        return t.shuffle;
      case 'sequential':
        return t.sequential;
      case 'all':
      default:
        return t.repeatAll;
    }
  };

  return (
    <footer className={`h-20 ${surface} border-t border-black/5 dark:border-white/5 px-6 flex items-center justify-between shrink-0 z-50 relative shadow-xl`}>
      {/* Seek progress bar at top (hidden in NowPlaying immersive mode) */}
      <div
        className={`absolute top-0 left-0 right-0 h-1 bg-black/10 dark:bg-white/10 cursor-pointer group transition-opacity duration-200 ${
          isNowPlayingOpen ? 'opacity-0 pointer-events-none' : 'opacity-100'
        }`}
        onClick={handleSeekClick}
        ref={progressRef}
      >
        <div
          className={`h-full ${isDarkMode ? 'bg-[#39C5BB]' : 'bg-[#006A6B]'} transition-all duration-100 relative`}
          style={{ width: `${progress}%` }}
        >
          <div className="absolute right-0 top-1/2 -translate-y-1/2 w-3 h-3 rounded-full bg-current shadow opacity-0 group-hover:opacity-100 transition" />
        </div>
      </div>

      {/* Left: Track info / Collapse Button in NowPlaying */}
      <div
        onClick={() => setIsNowPlayingOpen(!isNowPlayingOpen)}
        className="flex items-center space-x-3.5 cursor-pointer group w-1/3 min-w-0 select-none"
        title={isNowPlayingOpen ? t.collapseNowPlaying : t.nowPlayingTitle}
      >
        {isNowPlayingOpen ? (
          <div
            className={`w-12 h-12 rounded-xl flex items-center justify-center transition shrink-0 ${
              isDarkMode ? 'bg-white/10 group-hover:bg-[#39C5BB]/20 text-[#39C5BB]' : 'bg-black/5 group-hover:bg-[#006A6B]/15 text-[#006A6B]'
            }`}
          >
            <i className="fa-solid fa-chevron-down text-base transition-transform group-hover:translate-y-0.5" />
          </div>
        ) : (
          <div className="w-12 h-12 rounded-xl overflow-hidden shrink-0 shadow-sm">
            <M3CoverImage
              src={currentTrack?.coverUrl}
              alt={currentTrack?.title}
              placeholderType="music"
              className="w-12 h-12 rounded-xl"
              iconClassName="text-lg"
              imageClassName="group-hover:opacity-80 transition"
            />
          </div>
        )}
        <div className="truncate min-w-0">
          <div className={`text-sm font-semibold truncate transition ${isDarkMode ? 'group-hover:text-[#39C5BB]' : 'group-hover:text-[#006A6B]'}`}>
            {currentTrack?.title || '0rhxPlayer'}
          </div>
          <div className="text-xs text-gray-500 dark:text-gray-400 truncate mt-0.5">
            {currentTrack?.artist || 'Ready'}
          </div>
        </div>
      </div>


      {/* Right: Controls */}
      <div className="flex items-center space-x-3 sm:space-x-4 justify-end w-2/3">
        {/* 译 quick toggle only when NowPlaying is open */}
        {isNowPlayingOpen && (
          <div className="flex items-center mr-1">
            <button
              onClick={() => setShowTrans(!showTrans)}
              title={t.showTrans}
              className={`w-8 h-8 rounded-full text-xs font-semibold flex items-center justify-center transition active:scale-95 ${
                showTrans
                  ? isDarkMode
                    ? 'bg-[#39C5BB]/20 text-[#39C5BB]'
                    : 'bg-[#39C5BB]/15 text-[#006A6B]'
                  : 'bg-black/5 dark:bg-white/5 text-gray-400 hover:text-white'
              }`}
            >
              译
            </button>
          </div>
        )}

        {/* 4-State Playback Mode Button */}
        <button
          onClick={cyclePlayMode}
          title={getPlayModeTitle()}
          className="w-9 h-9 rounded-full hover:bg-black/10 dark:hover:bg-white/10 flex items-center justify-center text-sm transition active:scale-95"
        >
          {getPlayModeIcon()}
        </button>

        {/* Prev */}
        <button
          onClick={playPrevious}
          className="w-9 h-9 rounded-full hover:bg-black/10 dark:hover:bg-white/10 text-gray-400 hover:text-gray-200 text-sm flex items-center justify-center transition active:scale-95"
        >
          <i className="fa-solid fa-backward-step" />
        </button>

        {/* Play/Pause Main FAB */}
        <button
          onClick={togglePlayPause}
          className={`w-11 h-11 rounded-full ${
            isDarkMode
              ? 'bg-[#39C5BB] text-[#003738] shadow-[0_0_14px_rgba(57,197,187,0.35)]'
              : 'bg-[#006A6B] text-white shadow-md'
          } flex items-center justify-center hover:scale-105 active:scale-95 transition-all`}
        >
          <i className={`fa-solid ${playbackStatus === 'playing' ? 'fa-pause' : 'fa-play pl-0.5'} text-base`} />
        </button>

        {/* Next */}
        <button
          onClick={playNext}
          className="w-9 h-9 rounded-full hover:bg-black/10 dark:hover:bg-white/10 text-gray-400 hover:text-gray-200 text-sm flex items-center justify-center transition active:scale-95"
        >
          <i className="fa-solid fa-forward-step" />
        </button>

        {/* Queue button */}
        <button
          onClick={() => { setActiveTab('queue'); setIsNowPlayingOpen(false); }}
          className={`w-9 h-9 rounded-full hover:bg-black/10 dark:hover:bg-white/10 flex items-center justify-center text-sm transition active:scale-95 ${
            activeTab === 'queue'
              ? isDarkMode
                ? 'text-[#39C5BB]'
                : 'text-[#006A6B]'
              : 'text-gray-400 hover:text-gray-200'
          }`}
          title={t.queue}
        >
          <i className="fa-solid fa-list-ol" />
        </button>
      </div>
    </footer>
  );

};
