import React, { useEffect, useRef, useMemo } from 'react';
import { usePlayer, splitArtists } from '../context/PlayerContext';
import { I18N } from '../i18n';
import { getCoverSrc } from '../utils/assetUrl';

export const NowPlayingDrawer: React.FC = () => {
  const {
    currentTrack, positionMs, isDarkMode,
    isNowPlayingOpen,
    lang, lyricsAlign, lyricsFontSize, showTrans,
    artistSeparators, audioSettings, currentLyrics, seekTo,
  } = usePlayer();


  const t = I18N[lang];
  const coverSrc = getCoverSrc(currentTrack?.coverUrl);

  const hasLyrics = currentLyrics && currentLyrics.length > 0;
  const positionSec = positionMs / 1000;

  // Split artist names
  const artists = useMemo(
    () => splitArtists(currentTrack?.artist, artistSeparators),
    [currentTrack?.artist, artistSeparators]
  );

  // Find active lyric index
  let activeLyricIdx = -1;
  if (hasLyrics) {
    for (let i = 0; i < currentLyrics.length; i++) {
      if (positionSec >= currentLyrics[i].time) {
        activeLyricIdx = i;
      } else {
        break;
      }
    }
  }

  // Auto-scroll active lyric into center during natural playback
  const activeLineRef = useRef<HTMLDivElement>(null);
  const isUserScrollingRef = useRef(false);
  const scrollTimeoutRef = useRef<NodeJS.Timeout | null>(null);

  const handleUserScroll = () => {
    isUserScrollingRef.current = true;
    if (scrollTimeoutRef.current) {
      clearTimeout(scrollTimeoutRef.current);
    }
    scrollTimeoutRef.current = setTimeout(() => {
      isUserScrollingRef.current = false;
      // Re-center active line smoothly after inactivity timeout
      if (activeLineRef.current && isNowPlayingOpen) {
        activeLineRef.current.scrollIntoView({ behavior: 'smooth', block: 'center' });
      }
    }, 3000);
  };

  // Clean up timer on unmount
  useEffect(() => {
    return () => {
      if (scrollTimeoutRef.current) {
        clearTimeout(scrollTimeoutRef.current);
      }
    };
  }, []);

  useEffect(() => {
    if (activeLineRef.current && isNowPlayingOpen && !isUserScrollingRef.current) {
      activeLineRef.current.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }
  }, [activeLyricIdx, isNowPlayingOpen]);

  const handleLineClick = (timeSec: number) => {
    isUserScrollingRef.current = false;
    if (scrollTimeoutRef.current) {
      clearTimeout(scrollTimeoutRef.current);
    }
    seekTo(Math.floor(timeSec * 1000));
  };


  const lyricsAlignClass =
    lyricsAlign === 'right'
      ? 'text-right'
      : lyricsAlign === 'center'
      ? 'text-center'
      : 'text-left';

  const bg = isDarkMode ? 'bg-[#131317]' : 'bg-[#F6F2F8]';
  const infoBoxBg = isDarkMode ? 'bg-[#1C1B20]' : 'bg-[#EDE7F0]';

  return (
    <div
      className={`absolute inset-0 ${bg} z-40 transition-all duration-350 [transition-timing-function:cubic-bezier(0.05,0.7,0.1,1.0)] transform flex flex-col p-6 overflow-hidden ${
        isNowPlayingOpen
          ? 'translate-y-0 opacity-100 pointer-events-auto visible'
          : 'translate-y-full opacity-0 pointer-events-none invisible'
      }`}
    >

      {/* Main Content Area: Compact max-w-5xl viewport-adaptive layout */}
      <div className="max-w-5xl w-full mx-auto flex-1 flex flex-col md:flex-row items-center justify-center gap-6 lg:gap-12 my-auto overflow-hidden px-6 h-full">
        {/* Left Column: Full-Viewport Elastic Responsive (Width + Height Bound) */}
        <div className="flex flex-col justify-center items-center h-full max-h-[calc(100vh-6rem)] shrink-0 gap-3 py-2 select-none">
          {/* 1. Cover container: Dynamic square bound to min(380px, 36vw, 38vh) */}
          <div className="w-[min(380px,36vw,38vh)] aspect-square rounded-3xl overflow-hidden shadow-2xl relative group shrink-0 transition-all duration-150">
            {coverSrc ? (
              <img
                src={coverSrc}
                alt={currentTrack?.title}
                loading="lazy"
                decoding="async"
                className="w-full h-full object-cover group-hover:scale-105 transition duration-500"
              />
            ) : (

              <div className="w-full h-full bg-[#1C1B20] dark:bg-[#28272F] flex items-center justify-center">
                <i className="fa-solid fa-music text-6xl opacity-30" />
              </div>
            )}
          </div>

          {/* 2. Audio spec card: Width strictly bound to min(380px, 36vw, 38vh) */}
          <div className={`w-[min(380px,36vw,38vh)] ${infoBoxBg} rounded-2xl p-3.5 sm:p-4 text-left shadow-sm space-y-2.5 shrink-0 transition-all duration-150`}>
            <div>
              <h2 className="text-sm sm:text-base font-bold tracking-tight truncate max-w-full leading-snug">
                {currentTrack?.title || '0rhxPlayer'}
              </h2>
              <p
                className={`font-semibold text-xs mt-0.5 truncate max-w-full ${
                  isDarkMode ? 'text-[#39C5BB]' : 'text-[#006A6B]'
                }`}
              >
                {artists.join(' / ')}
              </p>
              <p className="text-[11px] text-gray-400 mt-0.5 truncate max-w-full">
                {currentTrack?.album || '—'}
              </p>
            </div>

            <div className="h-px bg-white/10 dark:bg-white/10" />

            {/* Extended Foobar2000 Grade Audio Specs */}
            <div className="font-mono text-[11px] space-y-1.5 leading-normal">
              <div className="flex items-center justify-between">
                <span className="text-gray-400">{t.specFormat}:</span>
                <span className="text-amber-300 font-semibold truncate ml-2">
                  {currentTrack?.format || 'FLAC 24bit / 96.0 kHz'}
                </span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-gray-400">{t.specBitrate}:</span>
                <span className="text-cyan-300 font-semibold truncate ml-2">
                  {currentTrack?.bitrate ? `${currentTrack.bitrate} kbps` : '1001 kbps'} (
                  {currentTrack?.channels === 1 ? 'Mono 1.0' : 'Stereo 2.0'})
                </span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-gray-400">{t.specDriver}:</span>
                <span
                  className={`font-semibold truncate ml-2 ${
                    isDarkMode ? 'text-[#39C5BB]' : 'text-[#006A6B]'
                  }`}
                >
                  {audioSettings.driver} / {audioSettings.bufferMs || 46}ms
                </span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-gray-400">{t.specReplayGain}:</span>
                <span className="text-gray-300 truncate ml-2">
                  {audioSettings.replayGain && audioSettings.replayGain !== 'Disabled'
                    ? 'ReplayGain: -4.8 dB (Peak 0.98)'
                    : 'ReplayGain: Bypass'}
                </span>
              </div>
            </div>
          </div>
        </div>



        {/* Right Column: Real-time scrolling Lyrics / No Lyrics Notice */}
        {hasLyrics ? (
          <div
            onWheel={handleUserScroll}
            onTouchMove={handleUserScroll}
            onScroll={handleUserScroll}
            className="flex-1 h-full max-h-[calc(100vh-140px)] flex flex-col justify-start overflow-y-auto py-[40vh] px-2 sm:px-4 pr-3 relative"
          >
            <div className={`space-y-6 my-auto ${lyricsAlignClass}`}>

              {currentLyrics.map((line, idx) => {
                const isActive = idx === activeLyricIdx;
                return (
                  <div
                    key={idx}
                    ref={isActive ? activeLineRef : undefined}
                    onClick={() => handleLineClick(line.time)}
                    className={`cursor-pointer transition-all duration-300 ${
                      isActive ? 'opacity-100 scale-[1.03]' : 'opacity-30 hover:opacity-75'
                    }`}
                  >
                    {/* Main line */}
                    <div
                      style={{
                        fontSize: isActive
                          ? `${lyricsFontSize}px`
                          : `${Math.max(13, Math.round(lyricsFontSize * 0.78))}px`,
                      }}
                      className={`font-bold tracking-wide transition-all leading-relaxed ${
                        isActive
                          ? isDarkMode
                            ? 'text-white'
                            : 'text-gray-900'
                          : isDarkMode
                          ? 'text-gray-300'
                          : 'text-gray-600'
                      }`}
                    >
                      {line.text}
                    </div>
                    {/* Translation */}
                    {showTrans && line.trans && (
                      <div
                        style={{
                          fontSize: `${Math.max(11, Math.round(lyricsFontSize * 0.65))}px`,
                        }}
                        className={`mt-1 font-normal ${
                          isActive
                            ? isDarkMode
                              ? 'text-gray-200'
                              : 'text-gray-700'
                            : 'text-gray-500'
                        }`}
                      >
                        {line.trans}
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          </div>
        ) : (
          <div className="flex-1 flex flex-col items-center justify-center text-center p-8">
            <i className="fa-solid fa-music text-5xl opacity-20 mb-3" />
            <p className="text-sm text-gray-500">{t.noLyrics}</p>
          </div>
        )}
      </div>
    </div>
  );
};



