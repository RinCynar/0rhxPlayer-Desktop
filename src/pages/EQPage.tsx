import React from 'react';
import { usePlayer, EQ_PRESETS } from '../context/PlayerContext';
import { I18N } from '../i18n';
import { M3NumberInput } from '../components/M3NumberInput';


const BAND_FREQUENCIES = [
  { label: '31 Hz', freq: '31.25' },
  { label: '62 Hz', freq: '62.5' },
  { label: '125 Hz', freq: '125' },
  { label: '250 Hz', freq: '250' },
  { label: '500 Hz', freq: '500' },
  { label: '1 kHz', freq: '1k' },
  { label: '2 kHz', freq: '2k' },
  { label: '4 kHz', freq: '4k' },
  { label: '8 kHz', freq: '8k' },
  { label: '16 kHz', freq: '16k' },
];

export const EQPage: React.FC = () => {
  const {
    isDarkMode,
    lang,
    eqSettings,
    setEqBand,
    setEqPreamp,
    setEqEnabled,
    applyEqPreset,
    resetEq,
  } = usePlayer();

  const t = I18N[lang];
  const card = isDarkMode ? 'bg-[#1E1D24] border-white/5' : 'bg-white/90 border-black/5 shadow-sm';
  const containerCard = isDarkMode ? 'bg-[#28272F]' : 'bg-[#EAE4EE]';
  const primaryBg = isDarkMode ? 'bg-[#39C5BB] text-[#003738]' : 'bg-[#006A6B] text-white';
  const primaryText = isDarkMode ? 'text-[#39C5BB]' : 'text-[#006A6B]';
  const activePresetBg = isDarkMode ? 'bg-[#39C5BB] text-[#003738] font-bold' : 'bg-[#006A6B] text-white font-bold';
  const inactivePresetBg = isDarkMode ? 'bg-white/5 text-gray-300 hover:bg-white/10' : 'bg-black/5 text-gray-700 hover:bg-black/10';

  return (
    <div className="max-w-6xl w-full mx-auto p-8 space-y-8 animate-fade-in">
      {/* Header Banner */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-3xl font-extrabold tracking-tight flex items-center gap-3">
            <i className={`fa-solid fa-sliders ${primaryText}`} />
            {t.eq}
          </h1>
          <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">
            {t.eqSubtitle}
          </p>
        </div>

        {/* Master Toggle & Reset */}
        <div className="flex items-center gap-4">
          <button
            onClick={resetEq}
            className={`px-4 py-2 rounded-xl text-xs font-semibold border border-current opacity-60 hover:opacity-100 transition`}
          >
            <i className="fa-solid fa-rotate-left mr-1.5" />
            {t.reset}
          </button>

          <label className="flex items-center gap-3 cursor-pointer select-none p-1.5 -m-1.5">
            <span className="text-sm font-semibold">
              {eqSettings.enabled ? t.eqEnabled : t.eqBypass}
            </span>
            <input
              type="checkbox"
              checked={eqSettings.enabled}
              onChange={e => setEqEnabled(e.target.checked)}
              className="sr-only peer"
            />
            <div
              className={`w-14 h-8 rounded-full transition-colors duration-200 relative p-1 ${
                eqSettings.enabled
                  ? isDarkMode
                    ? 'bg-[#39C5BB]'
                    : 'bg-[#006A6B]'
                  : isDarkMode
                  ? 'bg-white/20'
                  : 'bg-black/20'
              }`}
            >
              <div
                className={`w-6 h-6 rounded-full bg-white shadow-md transform transition-transform duration-200 pointer-events-none ${
                  eqSettings.enabled ? 'translate-x-6' : 'translate-x-0'
                }`}
              />
            </div>
          </label>
        </div>
      </div>

      {/* Preset Chips */}
      <div className={`${card} border rounded-3xl p-6 space-y-3`}>
        <div className="text-xs font-bold uppercase tracking-wider text-gray-400">
          {t.soundPresets}
        </div>
        <div className="flex flex-wrap gap-2">
          {Object.keys(EQ_PRESETS).map((name) => {
            const isActive = eqSettings.preset === name;
            return (
              <button
                key={name}
                onClick={() => applyEqPreset(name)}
                className={`px-4 py-2 rounded-full text-xs transition duration-200 ${
                  isActive ? activePresetBg : inactivePresetBg
                }`}
              >
                {name}
              </button>
            );
          })}
          {eqSettings.preset === 'Custom' && (
            <span className={`px-4 py-2 rounded-full text-xs ${activePresetBg}`}>
              {t.customPreset}
            </span>
          )}
        </div>
      </div>

      {/* Preamp & 10 Bands Equalizer Box */}
      <div
        className={`${card} border rounded-3xl p-8 space-y-8 transition-opacity ${
          eqSettings.enabled ? 'opacity-100' : 'opacity-50 pointer-events-none'
        }`}
      >
        {/* Preamp Slider */}
        <div className={`${containerCard} p-5 rounded-2xl flex flex-col sm:flex-row sm:items-center justify-between gap-4`}>
          <div className="flex items-center gap-3">
            <div className={`w-9 h-9 rounded-xl flex items-center justify-center ${primaryBg}`}>
              <i className="fa-solid fa-gauge-high text-xs" />
            </div>
            <div>
              <div className="font-semibold text-sm">{t.preamp}</div>
              <div className="text-xs text-gray-500 dark:text-gray-400">
                {t.preampDesc}
              </div>
            </div>
          </div>


          <div className="flex items-center gap-4 min-w-[260px]">
            <span className="text-xs font-mono font-bold text-gray-400">-12dB</span>
            <input
              type="range"
              min="-12"
              max="12"
              step="0.1"
              value={eqSettings.preampDb}
              onDoubleClick={() => setEqPreamp(0)}
              onChange={(e) => setEqPreamp(parseFloat(e.target.value))}
              className="flex-1 accent-[#39C5BB] dark:accent-[#39C5BB] cursor-pointer"
            />
            <M3NumberInput
              value={eqSettings.preampDb}
              min={-12}
              max={12}
              step={0.1}
              precision={1}
              unit="dB"
              onChange={setEqPreamp}
              onDoubleClick={() => setEqPreamp(0)}
              title={`${eqSettings.preampDb.toFixed(1)} dB`}
            />
          </div>
        </div>

        {/* 10 Vertical Sliders Grid */}
        <div>
          <div className="grid grid-cols-5 md:grid-cols-10 gap-3 sm:gap-4 justify-items-center">
            {BAND_FREQUENCIES.map((band, idx) => {
              const gain = eqSettings.bands[idx] ?? 0;
              return (
                <div
                  key={band.freq}
                  className="flex flex-col items-center gap-2.5 w-full max-w-[76px] bg-black/5 dark:bg-white/5 p-2.5 rounded-2xl hover:bg-black/10 dark:hover:bg-white/10 transition group"
                >
                  {/* Gain Value Input (M3NumberInput with double-click reset) */}
                  <M3NumberInput
                    value={gain}
                    min={-12}
                    max={12}
                    step={0.1}
                    precision={1}
                    onChange={(val) => setEqBand(idx, val)}
                    onDoubleClick={() => setEqBand(idx, 0)}
                    title={`${gain > 0 ? '+' : ''}${gain.toFixed(1)} dB`}
                    className="w-full py-0.5"
                    inputClassName="w-full text-[11px]"
                  />

                  {/* Vertical Slider Wrapper (double-click resets to 0) */}
                  <div
                    onDoubleClick={() => setEqBand(idx, 0)}
                    title={`${band.label}: ${gain > 0 ? '+' : ''}${gain.toFixed(1)} dB`}
                    className="h-44 sm:h-52 flex items-center justify-center py-2 cursor-pointer"
                  >


                    <input
                      type="range"
                      min="-12"
                      max="12"
                      step="0.1"
                      value={gain}
                      onChange={(e) => setEqBand(idx, parseFloat(e.target.value))}
                      style={{
                        writingMode: 'vertical-lr',
                        direction: 'rtl',
                        width: '8px',
                        height: '100%',
                      }}
                      className="accent-[#39C5BB] dark:accent-[#39C5BB] cursor-pointer"
                    />
                  </div>

                  {/* Frequency Label */}
                  <div className="text-center">
                    <span className="text-[11px] font-bold tracking-tight block text-gray-500 dark:text-gray-400 group-hover:text-[#39C5BB] transition">
                      {band.label}
                    </span>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </div>
  );
};