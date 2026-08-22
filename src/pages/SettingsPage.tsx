import React, { useRef } from 'react';
import { usePlayer, LyricsAlign } from '../context/PlayerContext';
import { I18N, LangKey } from '../i18n';
import { M3Dropdown, DropdownOption } from '../components/M3Dropdown';
import { M3NumberInput } from '../components/M3NumberInput';


const SEED_COLOR_PRESETS = [
  { hex: '#39C5BB', name: 'Miku Teal (#39C5BB)' },
  { hex: '#6750A4', name: 'M3 Purple (#6750A4)' },
  { hex: '#00639B', name: 'Ocean Blue (#00639B)' },
  { hex: '#9C4146', name: 'Crimson Red (#9C4146)' },
  { hex: '#4C662B', name: 'Forest Green (#4C662B)' },
  { hex: '#825500', name: 'Amber Gold (#825500)' },
  { hex: '#7D5260', name: 'Dusty Rose (#7D5260)' },
  { hex: '#006874', name: 'Deep Cyan (#006874)' },
];


export const SettingsPage: React.FC = () => {
  const {
    isDarkMode, setThemeMode,
    lang, setLang,
    lyricsAlign, setLyricsAlign,
    lyricsFontSize, setLyricsFontSize,
    showTrans, setShowTrans,
    artistSeparators, setArtistSeparators,
    customSeedColor, setCustomSeedColor,
    autoCollapseRailOnNowPlaying, setAutoCollapseRailOnNowPlaying,
    userProfile, setUserProfile,
    audioSettings, setAudioSettings,
    setActiveTab,
  } = usePlayer();



  const t = I18N[lang];
  const fileInputRef = useRef<HTMLInputElement>(null);

  const card = 'bg-md-surface-container-high';
  const primaryText = 'text-md-primary';
  const primaryBg = 'bg-md-primary text-md-on-primary';
  const primaryContainer = 'bg-md-primary-container text-md-on-primary-container';

  const handleAvatarSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      const reader = new FileReader();
      reader.onload = ev => {
        setUserProfile({ ...userProfile, avatar: ev.target?.result as string });
      };
      reader.readAsDataURL(file);
    }
  };

  const Toggle: React.FC<{ value: boolean; onChange: (v: boolean) => void }> = ({ value, onChange }) => (
    <label
      onClick={e => e.stopPropagation()}
      className="relative inline-flex items-center cursor-pointer p-2 -m-2 select-none"
    >
      <input
        type="checkbox"
        checked={value}
        onChange={e => onChange(e.target.checked)}
        className="sr-only peer"
      />
      {/* 胶囊轨道 Track */}
      <div
        className={`w-12 h-6 rounded-full transition-colors duration-200 relative p-0.5 ${
          value ? 'bg-md-primary' : 'bg-black/20 dark:bg-white/20'
        }`}
      >
        {/* 滑块 Thumb */}
        <div
          className={`w-5 h-5 rounded-full transition-transform duration-200 pointer-events-none shadow-sm ${
            value ? 'bg-md-on-primary translate-x-6' : 'bg-white translate-x-0'
          }`}
        />
      </div>
    </label>
  );

  const driverOptions: DropdownOption<string>[] = [
    { value: 'WASAPI Exclusive', label: 'WASAPI Exclusive', subLabel: lang === 'zh' ? '独占低延迟输出' : lang === 'ja' ? '排他低遅延モード' : 'Bit-perfect Low Latency' },
    { value: 'WASAPI Shared', label: 'WASAPI Shared', subLabel: lang === 'zh' ? '系统共享混音输出' : lang === 'ja' ? 'システム共有モード' : 'Shared Mixer Output' },
    { value: 'DirectSound', label: 'DirectSound', subLabel: lang === 'zh' ? '通用兼容模式' : lang === 'ja' ? '互換モード' : 'Compatibility Mode' },
  ];

  const resamplerOptions: DropdownOption<string>[] = [
    { value: 'SoX Resampler High Quality', label: 'SoX Resampler (HQ)', subLabel: lang === 'zh' ? '高品质音频重采样' : lang === 'ja' ? '高品質リサンプリング' : '64-bit HQ Resampler' },
    { value: 'Speex DSP Resampler', label: 'Speex DSP', subLabel: lang === 'zh' ? '高效 DSP 重采样' : lang === 'ja' ? '高速 DSP リサンプリング' : 'Fast DSP Resampler' },
    { value: 'Disabled', label: 'Bypass', subLabel: lang === 'zh' ? '直通输出' : lang === 'ja' ? 'バイパス直通' : 'Direct Pass-through' },
  ];

  const replayGainOptions: DropdownOption<string>[] = [
    { value: 'Track Mode (-18 LUFS)', label: 'Track Mode (-18 LUFS)', subLabel: lang === 'zh' ? '单曲响度统一' : lang === 'ja' ? 'トラック音量均一化' : 'Per-track Normalization' },
    { value: 'Album Mode', label: 'Album Mode', subLabel: lang === 'zh' ? '专辑动态平衡' : lang === 'ja' ? 'アルバム音量バランス' : 'Album Dynamic Balance' },
    { value: 'Disabled', label: 'Disabled', subLabel: lang === 'zh' ? '原始动态输出' : lang === 'ja' ? '無効 (オリジナル)' : 'Original Dynamic Range' },
  ];


  const langOptions: DropdownOption<LangKey>[] = [
    { value: 'zh', label: '简体中文 (Chinese)' },
    { value: 'en', label: 'English (US)' },
    { value: 'ja', label: '日本語 (Japanese)' },
  ];

  return (
    <div className="max-w-3xl w-full mx-auto p-8 space-y-6 pb-12 animate-fade-in">
      {/* Header */}
      <div className="flex items-center space-x-3">
        <button
          onClick={() => setActiveTab('home')}
          className="w-9 h-9 rounded-full bg-black/5 dark:bg-white/5 flex items-center justify-center hover:bg-black/10 transition"
        >
          <i className="fa-solid fa-arrow-left text-sm" />
        </button>
        <h1 className="text-3xl font-bold tracking-tight">{t.settings}</h1>
      </div>

      <div className="space-y-5">
        {/* 1. Profile */}
        <div className={`${card} p-5 rounded-3xl space-y-4`}>
          <h2 className={`text-sm font-bold ${primaryText} flex items-center gap-2`}>
            <i className="fa-solid fa-user" /> {t.profileSettings}
          </h2>
          <div className="flex items-center space-x-5">
            <div className="relative group">
              {userProfile.avatar ? (
                <img src={userProfile.avatar} className="w-16 h-16 rounded-full object-cover" />
              ) : (
                <div className={`w-16 h-16 rounded-full flex items-center justify-center ${primaryContainer}`}>
                  <i className={`fa-solid fa-user text-2xl ${primaryText}`} />
                </div>
              )}
              <button
                onClick={() => fileInputRef.current?.click()}
                className="absolute inset-0 bg-black/50 rounded-full flex items-center justify-center opacity-0 group-hover:opacity-100 transition text-white text-xs"
              >
                <i className="fa-solid fa-camera" />
              </button>
            </div>
            <div className="flex-1 space-y-2">
              <div>
                <label className="block mb-1 text-xs text-gray-500">{t.nickname}</label>
                <input
                  type="text"
                  value={userProfile.nickname}
                  onChange={e => setUserProfile({ ...userProfile, nickname: e.target.value })}
                  className={`w-full ${isDarkMode ? 'bg-white/5' : 'bg-black/5'} rounded-xl p-2.5 text-xs focus:outline-none focus:ring-2 focus:ring-md-primary`}
                />
              </div>
              <div className="flex items-center space-x-3 pt-1">
                <input
                  type="file"
                  ref={fileInputRef}
                  accept="image/*"
                  className="hidden"
                  onChange={handleAvatarSelect}
                />
                <button
                  onClick={() => fileInputRef.current?.click()}
                  className={`px-3.5 py-1.5 rounded-xl ${primaryContainer} text-xs font-semibold hover:opacity-90 transition`}
                >
                  {t.selectAvatarFile}
                </button>
                <button
                  onClick={() => setUserProfile({ ...userProfile, avatar: '' })}
                  className="text-xs text-gray-400 hover:text-gray-200 transition"
                >
                  {t.resetAvatar}
                </button>
              </div>
            </div>
          </div>
        </div>

        {/* 2. Audio Engine & DSP */}
        <div className={`${card} p-5 rounded-3xl space-y-4`}>
          <h2 className={`text-sm font-bold ${primaryText} flex items-center gap-2`}>
            <i className="fa-solid fa-sliders" /> {t.sectionAudioEngine}
          </h2>
          <div className="space-y-4 text-xs">
            <div className="flex items-center justify-between">
              <div>
                <div className="font-semibold">{t.audioEngine}</div>
                <div className="text-gray-500 text-[11px]">{t.audioEngineSub}</div>
              </div>
              <M3Dropdown
                value={audioSettings.driver}
                onChange={v => setAudioSettings({ ...audioSettings, driver: v })}
                options={driverOptions}
              />
            </div>

            <div className="flex items-center justify-between pt-2 border-t border-black/5 dark:border-white/5">
              <div>
                <div className="font-semibold">{t.resamplerAlgorithm}</div>
                <div className="text-gray-500 text-[11px]">{t.resamplerSub}</div>
              </div>
              <M3Dropdown
                value={audioSettings.resampler}
                onChange={v => setAudioSettings({ ...audioSettings, resampler: v })}
                options={resamplerOptions}
              />
            </div>

            <div className="flex items-center justify-between pt-2 border-t border-black/5 dark:border-white/5">
              <div>
                <div className="font-semibold">{t.replayGainMode}</div>
                <div className="text-gray-500 text-[11px]">{t.replayGainSub}</div>
              </div>
              <M3Dropdown
                value={audioSettings.replayGain}
                onChange={v => setAudioSettings({ ...audioSettings, replayGain: v })}
                options={replayGainOptions}
              />
            </div>

            <div
              onClick={() => setAudioSettings({ ...audioSettings, cueAutoScan: !audioSettings.cueAutoScan })}
              className="flex items-center justify-between pt-2 border-t border-black/5 dark:border-white/5 cursor-pointer select-none py-1 hover:opacity-90 transition"
            >
              <div>
                <div className="font-semibold">{t.cueAutoScan}</div>
                <div className="text-gray-500 text-[11px]">{t.sectionLibraryNav}</div>
              </div>
              <Toggle
                value={audioSettings.cueAutoScan}
                onChange={v => setAudioSettings({ ...audioSettings, cueAutoScan: v })}
              />
            </div>
          </div>
        </div>

        {/* 3. Library & Metadata */}
        <div className={`${card} p-5 rounded-3xl space-y-4`}>
          <h2 className={`text-sm font-bold ${primaryText} flex items-center gap-2`}>
            <i className="fa-solid fa-tags" /> {t.sectionLibraryNav}
          </h2>
          <div className="space-y-3 text-xs">
            <div className="flex items-center justify-between">
              <div>
                <div className="font-semibold">{t.artistSeparators}</div>
                <div className="text-gray-500 text-[11px]">{t.artistSeparatorsSub}</div>
              </div>
              <div className="flex items-center gap-2">
                <input
                  type="text"
                  value={artistSeparators}
                  onChange={e => setArtistSeparators(e.target.value)}
                  placeholder="/"
                  className={`w-24 ${isDarkMode ? 'bg-white/5' : 'bg-black/5'} rounded-xl px-3 py-1.5 text-center font-bold text-xs focus:outline-none focus:ring-2 focus:ring-md-primary`}
                />
              </div>
            </div>
          </div>
        </div>

        {/* 4. Interface & Themes */}
        <div className={`${card} p-5 rounded-3xl space-y-4`}>
          <h2 className={`text-sm font-bold ${primaryText} flex items-center gap-2`}>
            <i className="fa-solid fa-palette" /> {t.sectionInterface}
          </h2>

          {/* Seed Color Configuration */}
          <div className="space-y-3">
            <div>
              <div className="font-semibold text-xs">{t.customSeedColor}</div>
              <div className="text-gray-500 text-[11px]">{t.customSeedColorSub}</div>
            </div>

            <div className="flex flex-wrap items-center gap-2.5">
              {SEED_COLOR_PRESETS.map(preset => {
                const isSelected = customSeedColor.toLowerCase() === preset.hex.toLowerCase();
                return (
                  <button
                    key={preset.hex}
                    onClick={() => setCustomSeedColor(preset.hex)}
                    title={preset.name}
                    className={`w-8 h-8 rounded-full transition-transform flex items-center justify-center shadow-sm relative ${
                      isSelected ? 'scale-110 ring-2 ring-white dark:ring-white' : 'hover:scale-105'
                    }`}
                    style={{ backgroundColor: preset.hex }}
                  >
                    {isSelected && <i className="fa-solid fa-check text-white text-xs drop-shadow" />}
                  </button>
                );
              })}

              {/* Custom Color Input */}
              <div className="flex items-center gap-2 bg-black/5 dark:bg-white/5 px-2.5 py-1 rounded-2xl">
                <input
                  type="color"
                  value={customSeedColor}
                  onChange={e => setCustomSeedColor(e.target.value)}
                  className="w-6 h-6 rounded-full cursor-pointer bg-transparent border-0 outline-none"
                  title={t.customSeedColor}
                />
                <input
                  type="text"
                  value={customSeedColor}
                  onChange={e => setCustomSeedColor(e.target.value)}
                  className="w-20 bg-transparent text-xs font-bold outline-none"
                  placeholder="#39C5BB"
                />
              </div>
            </div>
          </div>



          {/* Lyrics alignment */}
          <div className="flex items-center justify-between text-xs pt-2 border-t border-black/5 dark:border-white/5">
            <div>
              <div className="font-semibold">{t.lyricAlign}</div>
              <div className="text-gray-500 text-[11px]">{t.lyricAlignSub}</div>
            </div>
            <div className={`${isDarkMode ? 'bg-white/5' : 'bg-black/5'} p-1 rounded-2xl flex items-center space-x-1`}>
              {(['right', 'center', 'left'] as LyricsAlign[]).map(align => (
                <button
                  key={align}
                  onClick={() => setLyricsAlign(align)}
                  className={`px-3 py-1.5 rounded-xl text-xs font-semibold transition ${lyricsAlign === align ? primaryBg : 'opacity-60'}`}
                >
                  {align === 'right' ? t.alignRight : align === 'center' ? t.alignCenter : t.alignLeft}
                </button>
              ))}
            </div>
          </div>

          {/* Lyrics Font Size (Range: 14px to 64px) */}
          <div className="flex items-center justify-between text-xs pt-2 border-t border-black/5 dark:border-white/5">
            <div>
              <div className="font-semibold">{t.lyricsFontSize}</div>
              <div className="text-gray-500 text-[11px]">{t.lyricsFontSizeSub} (14px ~ 64px)</div>
            </div>
            <div className="flex items-center space-x-3">
              <input
                type="range"
                min="14"
                max="64"
                step="1"
                value={lyricsFontSize}
                onChange={e => setLyricsFontSize(parseInt(e.target.value, 10))}
                className="w-32 accent-md-primary cursor-pointer"
              />
              <M3NumberInput
                value={lyricsFontSize}
                min={14}
                max={64}
                step={1}
                precision={0}
                unit="px"
                onChange={setLyricsFontSize}
              />
            </div>
          </div>


          {/* Translation */}
          <div
            onClick={() => setShowTrans(!showTrans)}
            className="flex items-center justify-between text-xs pt-2 border-t border-black/5 dark:border-white/5 cursor-pointer select-none py-1 hover:opacity-90 transition"
          >
            <div>
              <div className="font-semibold">{t.showTrans}</div>
              <div className="text-gray-500 text-[11px]">{t.transSub}</div>
            </div>
            <Toggle value={showTrans} onChange={setShowTrans} />
          </div>

          {/* Auto collapse sidebar on Now Playing */}
          <div
            onClick={() => setAutoCollapseRailOnNowPlaying(!autoCollapseRailOnNowPlaying)}
            className="flex items-center justify-between text-xs pt-2 border-t border-black/5 dark:border-white/5 cursor-pointer select-none py-1 hover:opacity-90 transition"
          >
            <div>
              <div className="font-semibold">{t.autoCollapseRail}</div>
              <div className="text-gray-500 text-[11px]">{t.autoCollapseRailSub}</div>
            </div>
            <Toggle value={autoCollapseRailOnNowPlaying} onChange={setAutoCollapseRailOnNowPlaying} />
          </div>

          {/* Language */}
          <div className="flex items-center justify-between text-xs pt-2 border-t border-black/5 dark:border-white/5">
            <div>
              <div className="font-semibold">{t.language}</div>
              <div className="text-gray-500 text-[11px]">{t.languageSub}</div>
            </div>
            <M3Dropdown
              value={lang}
              onChange={v => setLang(v as LangKey)}
              options={langOptions}
            />
          </div>

          {/* Theme Mode (Dark / Light) */}
          <div className="flex items-center justify-between text-xs pt-2 border-t border-black/5 dark:border-white/5">
            <div>
              <div className="font-semibold">{t.themeMode}</div>
            </div>
            <div className={`${isDarkMode ? 'bg-white/5' : 'bg-black/5'} p-1 rounded-2xl flex items-center space-x-1`}>
              <button
                onClick={() => setThemeMode('dark')}
                className={`px-3.5 py-1.5 rounded-xl text-xs font-semibold transition cursor-pointer flex items-center gap-1.5 ${isDarkMode ? primaryBg : 'opacity-60 hover:opacity-100'}`}
              >
                <i className="fa-solid fa-moon text-[11px]" />
                <span>{t.dark}</span>
              </button>
              <button
                onClick={() => setThemeMode('light')}
                className={`px-3.5 py-1.5 rounded-xl text-xs font-semibold transition cursor-pointer flex items-center gap-1.5 ${!isDarkMode ? primaryBg : 'opacity-60 hover:opacity-100'}`}
              >
                <i className="fa-solid fa-sun text-[11px]" />
                <span>{t.light}</span>
              </button>
            </div>
          </div>
        </div>


        {/* 5. System */}
        <div
          onClick={() => setAudioSettings({ ...audioSettings, systemTray: !audioSettings.systemTray })}
          className={`${card} p-5 rounded-3xl flex items-center justify-between text-xs cursor-pointer select-none hover:opacity-95 transition`}
        >
          <div>
            <div className="font-semibold">{t.systemTray}</div>
            <div className="text-gray-500 text-[11px]">{t.systemTraySub}</div>
          </div>
          <Toggle
            value={audioSettings.systemTray}
            onChange={v => setAudioSettings({ ...audioSettings, systemTray: v })}
          />
        </div>

        {/* 6. About 0rhxPlayer */}
        <div className={`${card} p-6 rounded-3xl space-y-5 text-xs shadow-sm`}>
          <div className="flex items-center space-x-4">
            <div className="w-14 h-14 rounded-2xl bg-md-primary-container text-md-on-primary-container flex items-center justify-center shrink-0 shadow-inner">
              <i className="fa-solid fa-compact-disc text-3xl animate-spin-slow" />
            </div>
            <div className="min-w-0 flex-1">
              <div className="flex items-center space-x-2">
                <h3 className="font-bold text-base tracking-tight">{t.aboutTitle}</h3>
                <span className="px-2.5 py-0.5 rounded-full text-[11px] font-bold bg-md-primary-container text-md-on-primary-container">
                  v1.0.1
                </span>
              </div>
              <p className="text-gray-500 dark:text-gray-400 text-[11px] mt-0.5 truncate">
                {t.aboutDesc}
              </p>
            </div>
          </div>

          <div className="space-y-3 pt-3 border-t border-black/5 dark:border-white/5">
            {/* Developer */}
            <div className="flex items-center justify-between">
              <span className="text-gray-500 dark:text-gray-400">{t.developer}</span>
              <span className="font-semibold">RinCynar</span>
            </div>

            {/* Official Website */}
            <div className="flex items-center justify-between">
              <span className="text-gray-500 dark:text-gray-400">{t.officialWebsite}</span>
              <button
                onClick={async () => {
                  try {
                    const { openUrl } = await import('@tauri-apps/plugin-opener');
                    await openUrl('https://0rhxPlayer.rincynar.top');
                  } catch {
                    window.open('https://0rhxPlayer.rincynar.top', '_blank');
                  }
                }}
                className={`font-semibold ${primaryText} hover:underline flex items-center gap-1.5`}
              >
                <span>0rhxPlayer.rincynar.top</span>
                <i className="fa-solid fa-arrow-up-right-from-square text-[10px]" />
              </button>
            </div>

            {/* GitHub Repo */}
            <div className="flex items-center justify-between">
              <span className="text-gray-500 dark:text-gray-400">{t.sourceCode}</span>
              <button
                onClick={async () => {
                  try {
                    const { openUrl } = await import('@tauri-apps/plugin-opener');
                    await openUrl('https://github.com/RinCynar/0rhxPlayer-Desktop');
                  } catch {
                    window.open('https://github.com/RinCynar/0rhxPlayer-Desktop', '_blank');
                  }
                }}
                className={`font-semibold ${primaryText} hover:underline flex items-center gap-1.5`}
              >
                <span>RinCynar/0rhxPlayer-Desktop</span>
                <i className="fa-brands fa-github text-xs" />
              </button>
            </div>

            {/* License */}
            <div className="flex items-center justify-between">
              <span className="text-gray-500 dark:text-gray-400">{t.license}</span>
              <span className="text-gray-400 font-medium">GPL-3.0 License</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};