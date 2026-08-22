export type LangKey = 'zh' | 'en' | 'ja';

export interface I18NDict {
  appName: string;
  home: string;
  library: string;
  search: string;
  queue: string;
  playlist: string;
  settings: string;
  eq: string;
  dailyMix: string;
  featuredSection: string;
  titles: string;
  artists: string;
  albums: string;
  folders: string;
  updatedToday: string;
  updatedYesterday: string;
  updatedDaysAgo: string;
  nowPlayingTitle: string;
  played: string;
  nexts: string;
  hintedSearch: string;
  profileSettings: string;
  nickname: string;
  avatarLocal: string;
  selectAvatarFile: string;
  resetAvatar: string;
  lyricAlign: string;
  alignRight: string;
  alignCenter: string;
  alignLeft: string;
  lyricsFontSize: string;
  lyricsFontSizeSub: string;
  showTrans: string;

  language: string;
  languageSub: string;
  themeMode: string;
  themeSystem: string;
  dark: string;
  light: string;
  audioEngine: string;
  audioSpec: string;
  greetingMorning: string;
  greetingAfternoon: string;
  greetingEvening: string;
  greetingNight: string;
  emptyLibrary: string;
  showAll: string;
  openFolder: string;
  importFiles: string;
  noLyrics: string;
  sectionAudioEngine: string;
  resamplerAlgorithm: string;
  bufferSize: string;
  replayGainMode: string;
  cueAutoScan: string;
  sectionLibraryNav: string;
  sectionInterface: string;
  autoCollapseRail: string;
  autoCollapseRailSub: string;
  navRailCustom: string;
  navRailCustomDesc: string;
  artistSeparators: string;
  artistSeparatorsSub: string;
  customSeedColor: string;
  customSeedColorSub: string;
  useArtworkTheme: string;
  useArtworkThemeSub: string;
  globalHotkeys: string;
  systemTray: string;
  enabled: string;
  disabled: string;
  formatLabel: string;
  bitrateLabel: string;
  engineLabel: string;
  featuredPlaylists: string;
  audiophileCol: string;
  searchTrackResults: string;
  audioEngineSub: string;
  resamplerSub: string;
  replayGainSub: string;
  lyricAlignSub: string;
  systemTraySub: string;
  createPlaylist: string;
  myPlaylists: string;
  favoritesPlaylist: string;
  trackCount: string;
  saveNavCustom: string;
  transSub: string;
  cancel: string;
  navRailOrderHint: string;
  moveUp: string;
  moveDown: string;
  expandRail: string;
  collapseRail: string;
  specFormat: string;
  specBitrate: string;
  specDriver: string;
  specReplayGain: string;
  featuredTracksTitle: string;
  featuredAlbumsTitle: string;
  collapseNowPlaying: string;
  refreshRecommendations: string;
  rescanLibrary: string;
  addFolder: string;
  removeFolder: string;
  removeFolderConfirm: string;
  scannedFoldersTitle: string;
  noScannedFolders: string;
  allTracks: string;
  featuredAlbums: string;

  // Playlist Page
  systemPlaylist: string;
  customPlaylist: string;
  backToPlaylists: string;
  playAll: string;
  shufflePlay: string;
  emptyPlaylistHint: string;
  renamePlaylist: string;
  deletePlaylist: string;
  removeFromPlaylist: string;
  save: string;

  // Equalizer
  eqSubtitle: string;
  reset: string;
  eqBypass: string;
  eqEnabled: string;
  soundPresets: string;
  preamp: string;
  preampDesc: string;
  customPreset: string;

  // Library & Search & Batch & Actions
  batchSelect: string;
  finishSelect: string;
  sortTitleAsc: string;
  sortTitleDesc: string;
  sortArtistAsc: string;
  sortArtistDesc: string;
  sortAlbumAsc: string;
  sortAlbumDesc: string;
  sortFolderAsc: string;
  sortFolderDesc: string;
  sortTrackCountDesc: string;
  sortTrackCountAsc: string;
  sortSizeDesc: string;
  sortBitrateDesc: string;
  sortFormatAsc: string;
  sortModifiedDesc: string;
  sortAddedDesc: string;
  sortDurationDesc: string;
  sortDurationAsc: string;
  selectedCount: string;
  selectAll: string;
  deselectAll: string;
  batchPlay: string;
  batchAddToQueue: string;
  batchAddToPlaylist: string;
  batchRemoveFromLibrary: string;
  batchAddTitle: string;
  createAndAdd: string;
  newPlaylistPlaceholder: string;
  create: string;
  confirm: string;
  back: string;
  searchHistory: string;
  clear: string;
  noMatchResults: string;
  noMatchDesc: string;
  libraryTracksHeader: string;
  noPlayedTracks: string;
  noQueueTracks: string;
  removeFromQueue: string;
  playNextAction: string;
  addToQueueAction: string;
  addToPlaylistAction: string;
  newPlaylistAction: string;
  noCustomPlaylists: string;
  added: string;
  moreActions: string;
  favorite: string;
  favorited: string;
  addToFavorites: string;
  removeFromFavorites: string;

  // Play Modes
  repeatOne: string;
  shuffle: string;
  sequential: string;
  repeatAll: string;

  // About Module
  aboutTitle: string;
  aboutDesc: string;
  version: string;
  developer: string;
  officialWebsite: string;
  sourceCode: string;
  license: string;
}








export const I18N: Record<LangKey, I18NDict> = {
  "zh": {
    "appName": "0rhxPlayer",
    "home": "首页",
    "library": "曲库",
    "search": "搜索",
    "queue": "播放队列",
    "playlist": "歌单",
    "settings": "设置",
    "eq": "均衡器",
    "dailyMix": "每日推荐",
    "featuredSection": "特色专题",
    "titles": "单曲",
    "artists": "歌手",
    "albums": "专辑",
    "folders": "文件夹",
    "updatedToday": "今天更新",
    "updatedYesterday": "昨天更新",
    "updatedDaysAgo": "2 天前更新",
    "nowPlayingTitle": "播放队列",
    "played": "已播放",
    "nexts": "即将播放",
    "hintedSearch": "搜索歌曲、歌手或专辑...",
    "profileSettings": "个人资料设置",
    "nickname": "用户昵称",
    "avatarLocal": "本地头像图片",
    "selectAvatarFile": "选择本地文件...",
    "resetAvatar": "恢复默认头像",
    "lyricAlign": "歌词对齐方式",
    "alignRight": "居右",
    "alignCenter": "居中",
    "alignLeft": "居左",
    "lyricsFontSize": "歌词字号大小",
    "lyricsFontSizeSub": "调节沉浸式播放页面的歌词文字大小",
    "showTrans": "显示歌词翻译",
    "language": "界面语言",
    "languageSub": "设置应用界面显示语言",
    "themeMode": "主题模式",
    "themeSystem": "跟随系统",
    "dark": "深色模式",
    "light": "浅色模式",
    "audioEngine": "音频输出驱动引擎",
    "audioSpec": "输出规格",
    "greetingMorning": "早上好",
    "greetingAfternoon": "下午好",
    "greetingEvening": "晚上好",
    "greetingNight": "夜深了，注意休息",
    "emptyLibrary": "暂无本地音乐，点击侧栏浮动按钮导入文件夹",
    "showAll": "查看全部",
    "openFolder": "扫描文件夹",
    "importFiles": "导入文件",
    "noLyrics": "暂无歌词",
    "sectionAudioEngine": "音频驱动与 DSP 引擎",
    "resamplerAlgorithm": "重采样算法",
    "bufferSize": "缓冲区大小",
    "replayGainMode": "声级平准 (ReplayGain)",
    "cueAutoScan": "CUE 关联分轨解析",
    "sectionLibraryNav": "曲库与标签检索管线",
    "sectionInterface": "界面与视觉定制",
    "autoCollapseRail": "展开播放详情时自动折叠侧栏",
    "autoCollapseRailSub": "展开全屏播放界面时自动收起导航栏以获得更大沉浸视野",
    "navRailCustom": "自定义",
    "navRailCustomDesc": "开启或勾选要在侧边栏中显示的导航项目",
    "artistSeparators": "歌手字段分隔符",
    "artistSeparatorsSub": "按指定符号拆分包含多个歌手的字段 (如 / 或 ,)",
    "customSeedColor": "主题基色 (Seed Color)",
    "customSeedColorSub": "自定义应用界面的核心 Material 3 调色板基色",
    "useArtworkTheme": "随专辑封面动态提取主题色",
    "useArtworkThemeSub": "根据当前播放曲目的封面主色生成沉浸式配色方案",
    "globalHotkeys": "全局热键与媒体按键",
    "systemTray": "关闭时最小化到系统托盘",
    "enabled": "已启用",
    "disabled": "已禁用",
    "formatLabel": "音频格式",
    "bitrateLabel": "比特率",
    "engineLabel": "输出引擎",
    "featuredPlaylists": "精选专题歌单",
    "audiophileCol": "发烧级无损典藏系列",
    "searchTrackResults": "精选单曲搜索结果",
    "audioEngineSub": "独占/共享模式与低延迟驱动",
    "resamplerSub": "高精度重采样算法",
    "replayGainSub": "防止跨曲目音量突变与过载",
    "lyricAlignSub": "滚动歌词的版面排列习惯",
    "systemTraySub": "关闭主窗口时挂起至系统托盘",
    "createPlaylist": "新建歌单",
    "myPlaylists": "我的歌单收藏",
    "favoritesPlaylist": "我最喜爱的音乐",
    "trackCount": "首曲目",
    "saveNavCustom": "保存更改",
    "transSub": "切换主歌词下方的多语言翻译行",
    "cancel": "取消",
    "navRailOrderHint": "上下调整顺序 / 勾选显示",
    "moveUp": "上移",
    "moveDown": "下移",
    "expandRail": "展开导航栏",
    "collapseRail": "折叠导航栏",
    "specFormat": "格式 & 采样率",
    "specBitrate": "比特率 & 声道",
    "specDriver": "驱动引擎 & 延迟",
    "specReplayGain": "增益平准",
    "featuredTracksTitle": "精选单曲推荐",
    "featuredAlbumsTitle": "精选专辑推荐",
    "collapseNowPlaying": "收起",
    "refreshRecommendations": "重新推荐",
    "rescanLibrary": "重新扫描",
    "addFolder": "添加扫描文件夹",
    "removeFolder": "移除文件夹",
    "removeFolderConfirm": "确定要从扫描目录中移除该文件夹吗？(不会删除本地文件)",
    "scannedFoldersTitle": "已添加的扫描目录",
    "noScannedFolders": "暂无已添加的扫描目录，点击上方按钮添加",
    "allTracks": "全部单曲",
    "featuredAlbums": "所属专辑",

    // Playlist
    "systemPlaylist": "系统歌单",
    "customPlaylist": "自定义歌单",
    "backToPlaylists": "返回歌单列表",
    "playAll": "播放全部",
    "shufflePlay": "随机播放",
    "emptyPlaylistHint": "歌单中暂无歌曲，请前往曲库添加",
    "renamePlaylist": "重命名歌单",
    "deletePlaylist": "删除歌单",
    "removeFromPlaylist": "移出歌单",
    "save": "保存",

    // Equalizer
    "eqSubtitle": "基于双二阶滤波器的 10 段专业级图示均衡器与动态增益调节",
    "reset": "重置",
    "eqBypass": "已旁通",
    "eqEnabled": "已开启",
    "soundPresets": "声音风格预设",
    "preamp": "前级增益",
    "preampDesc": "提升或衰减总输入信号强度，防止频段增益叠加产生削波失真 (双击滑块归零)",
    "customPreset": "自定义",

    // Library & Search & Batch & Actions
    "batchSelect": "批量选择",
    "finishSelect": "完成选择",
    "sortTitleAsc": "A-Z (曲名升序)",
    "sortTitleDesc": "Z-A (曲名降序)",
    "sortArtistAsc": "A-Z (歌手升序)",
    "sortArtistDesc": "Z-A (歌手降序)",
    "sortAlbumAsc": "A-Z (专辑升序)",
    "sortAlbumDesc": "Z-A (专辑降序)",
    "sortFolderAsc": "A-Z (目录升序)",
    "sortFolderDesc": "Z-A (目录降序)",
    "sortTrackCountDesc": "曲目数量 (最多)",
    "sortTrackCountAsc": "曲目数量 (最少)",
    "sortSizeDesc": "文件体积 (最大)",
    "sortBitrateDesc": "比特率 (最高)",
    "sortFormatAsc": "编码格式 (FLAC/MP3等)",
    "sortModifiedDesc": "修改时间 (最新)",
    "sortAddedDesc": "添加时间 (最新)",
    "sortDurationDesc": "时长 (最长)",
    "sortDurationAsc": "时长 (最短)",
    "selectedCount": "已选择",

    "selectAll": "全选",
    "deselectAll": "取消全选",
    "batchPlay": "播放",
    "batchAddToQueue": "加入队列",
    "batchAddToPlaylist": "加入歌单",
    "batchRemoveFromLibrary": "从曲库移除",
    "batchAddTitle": "添加到歌单",
    "createAndAdd": "新建歌单并添加",
    "newPlaylistPlaceholder": "新歌单名称...",
    "create": "创建",
    "confirm": "确定",
    "back": "返回",
    "searchHistory": "搜索历史",
    "clear": "清空",
    "noMatchResults": "无匹配结果",
    "noMatchDesc": "未找到相关音乐",
    "libraryTracksHeader": "曲库单曲",
    "noPlayedTracks": "暂无已播放曲目",
    "noQueueTracks": "队列中暂无曲目",
    "removeFromQueue": "从队列移除",
    "playNextAction": "下一首播放",
    "addToQueueAction": "添加到播放队列",
    "addToPlaylistAction": "添加到歌单",
    "newPlaylistAction": "新建歌单",
    "noCustomPlaylists": "暂无自定义歌单",
    "added": "已添加",
    "moreActions": "更多操作",
    "favorite": "收藏",
    "favorited": "已收藏",
    "addToFavorites": "添加到我喜爱",
    "removeFromFavorites": "从我喜爱移除",

    // Play Modes
    "repeatOne": "单曲循环",
    "shuffle": "随机播放",
    "sequential": "顺序播放",
    "repeatAll": "列表循环",

    // About Module
    "aboutTitle": "关于 0rhxPlayer",
    "aboutDesc": "基于 Tauri 2 + React 的跨平台全格式无损音频播放器",
    "version": "版本",
    "developer": "开发者",
    "officialWebsite": "官方主页",
    "sourceCode": "开源代码仓库",
    "license": "开源协议"
  },
  "en": {
    "appName": "0rhxPlayer",
    "home": "Home",
    "library": "Library",
    "search": "Search",
    "queue": "Queue",
    "playlist": "Playlists",
    "settings": "Settings",
    "eq": "Equalizer",
    "dailyMix": "Daily Mix",
    "featuredSection": "Featured Section",
    "titles": "Titles",
    "artists": "Artists",
    "albums": "Albums",
    "folders": "Folders",
    "updatedToday": "Updated today",
    "updatedYesterday": "Updated yesterday",
    "updatedDaysAgo": "Updated 2 days ago",
    "nowPlayingTitle": "Playback Queue",
    "played": "Played",
    "nexts": "Nexts",
    "hintedSearch": "Search tracks, artists or albums...",
    "profileSettings": "Profile Settings",
    "nickname": "Nickname",
    "avatarLocal": "Local Avatar File",
    "selectAvatarFile": "Choose File...",
    "resetAvatar": "Reset Default Avatar",
    "lyricAlign": "Lyrics Alignment",
    "alignRight": "Right",
    "alignCenter": "Center",
    "alignLeft": "Left",
    "lyricsFontSize": "Lyrics Font Size",
    "lyricsFontSizeSub": "Adjust the font size of lyrics in NowPlaying view",
    "showTrans": "Show Lyrics Translation",
    "language": "App Language",
    "languageSub": "Select application display language",
    "themeMode": "Theme Mode",
    "themeSystem": "System",
    "dark": "Dark",
    "light": "Light",
    "audioEngine": "Audio Driver Engine",
    "audioSpec": "Output Specs",
    "greetingMorning": "Good morning",
    "greetingAfternoon": "Good afternoon",
    "greetingEvening": "Good evening",
    "greetingNight": "Late night, remember to rest",
    "emptyLibrary": "No local audio found. Click the FAB button to import.",
    "showAll": "Show all",
    "openFolder": "Scan Folder",
    "importFiles": "Import Files",
    "noLyrics": "No lyrics available",
    "sectionAudioEngine": "Audio Engine & DSP Pipeline",
    "resamplerAlgorithm": "Resampler Algorithm",
    "bufferSize": "Buffer Size",
    "replayGainMode": "ReplayGain Loudness",
    "cueAutoScan": "CUE Sheet Auto-indexing",
    "sectionLibraryNav": "Library & Metadata Pipeline",
    "sectionInterface": "Interface & Customization",
    "autoCollapseRail": "Auto Collapse Sidebar on Now Playing",
    "autoCollapseRailSub": "Collapse navigation rail when opening Now Playing for immersive view",
    "navRailCustom": "Customize",
    "navRailCustomDesc": "Select visible navigation items on the side rail",
    "artistSeparators": "Artist Separators",
    "artistSeparatorsSub": "Split multiple artists by symbols (e.g. / or ,)",
    "customSeedColor": "Theme Seed Color",
    "customSeedColorSub": "Customize the primary Material 3 palette seed color",
    "useArtworkTheme": "Dynamic Theme from Album Art",
    "useArtworkThemeSub": "Generate dynamic color scheme from current track's artwork",
    "globalHotkeys": "Global Hotkeys & Media Keys",
    "systemTray": "Minimize to system tray on close",
    "enabled": "Enabled",
    "disabled": "Disabled",
    "formatLabel": "Format",
    "bitrateLabel": "Bitrate",
    "engineLabel": "Audio Driver",
    "featuredPlaylists": "Featured Playlists",
    "audiophileCol": "Lossless Audiophile Collection",
    "searchTrackResults": "Featured Track Results",
    "audioEngineSub": "Exclusive/Shared low latency output",
    "resamplerSub": "High precision audio resampling",
    "replayGainSub": "Prevent sudden loudness jumps across tracks",
    "lyricAlignSub": "Layout pattern for synchronized lyrics",
    "systemTraySub": "Keep playing in tray when closed",
    "createPlaylist": "Create Playlist",
    "myPlaylists": "My Playlists",
    "favoritesPlaylist": "My Favorite Tracks",
    "trackCount": "tracks",
    "saveNavCustom": "Save Changes",
    "transSub": "Toggle translated lyric lines below main text",
    "cancel": "Cancel",
    "navRailOrderHint": "Reorder / Toggle visibility",
    "moveUp": "Move Up",
    "moveDown": "Move Down",
    "expandRail": "Expand Rail",
    "collapseRail": "Collapse Rail",
    "specFormat": "Format & Rate",
    "specBitrate": "Bitrate & Channels",
    "specDriver": "Driver & Latency",
    "specReplayGain": "ReplayGain",
    "featuredTracksTitle": "Featured Tracks",
    "featuredAlbumsTitle": "Featured Albums",
    "collapseNowPlaying": "Collapse",
    "refreshRecommendations": "Refresh",
    "rescanLibrary": "Rescan Library",
    "addFolder": "Add Folder",
    "removeFolder": "Remove Folder",
    "removeFolderConfirm": "Are you sure you want to remove this folder from scan paths? (Local files will not be deleted)",
    "scannedFoldersTitle": "Monitored Folders",
    "noScannedFolders": "No monitored folders. Click above to add one.",
    "allTracks": "All Tracks",
    "featuredAlbums": "Albums",

    // Playlist
    "systemPlaylist": "System Playlist",
    "customPlaylist": "Custom Playlist",
    "backToPlaylists": "Back to Playlists",
    "playAll": "Play All",
    "shufflePlay": "Shuffle",
    "emptyPlaylistHint": "No tracks in playlist. Add songs from your library.",
    "renamePlaylist": "Rename Playlist",
    "deletePlaylist": "Delete Playlist",
    "removeFromPlaylist": "Remove from Playlist",
    "save": "Save",

    // Equalizer
    "eqSubtitle": "10-Band Pro Graphic Equalizer with Biquad Filters & Gain Control",
    "reset": "Reset",
    "eqBypass": "Bypass",
    "eqEnabled": "Enabled",
    "soundPresets": "Sound Presets",
    "preamp": "Preamp",
    "preampDesc": "Boost or attenuate master input to prevent clipping (Double-click to reset)",
    "customPreset": "Custom",

    // Library & Search & Batch & Actions
    "batchSelect": "Select",
    "finishSelect": "Done",
    "sortTitleAsc": "Title (A-Z)",
    "sortTitleDesc": "Title (Z-A)",
    "sortArtistAsc": "Artist (A-Z)",
    "sortArtistDesc": "Artist (Z-A)",
    "sortAlbumAsc": "Album (A-Z)",
    "sortAlbumDesc": "Album (Z-A)",
    "sortFolderAsc": "Folder (A-Z)",
    "sortFolderDesc": "Folder (Z-A)",
    "sortTrackCountDesc": "Track Count (Most)",
    "sortTrackCountAsc": "Track Count (Least)",
    "sortSizeDesc": "File Size (Largest)",
    "sortBitrateDesc": "Bitrate (Highest)",
    "sortFormatAsc": "Codec / Format",
    "sortModifiedDesc": "Modified Time (Newest)",
    "sortAddedDesc": "Date Added (Newest)",
    "sortDurationDesc": "Duration (Longest)",
    "sortDurationAsc": "Duration (Shortest)",
    "selectedCount": "Selected",
    "selectAll": "Select All",
    "deselectAll": "Deselect All",
    "batchPlay": "Play",
    "batchAddToQueue": "Add to Queue",
    "batchAddToPlaylist": "Add to Playlist",
    "batchRemoveFromLibrary": "Remove from Library",
    "batchAddTitle": "Add to Playlist",
    "createAndAdd": "New Playlist & Add",
    "newPlaylistPlaceholder": "New playlist name...",
    "create": "Create",
    "confirm": "Confirm",
    "back": "Back",
    "searchHistory": "Search History",
    "clear": "Clear",
    "noMatchResults": "No Results",
    "noMatchDesc": "No matching music found",
    "libraryTracksHeader": "Library Tracks",
    "noPlayedTracks": "No played tracks",
    "noQueueTracks": "Queue is empty",
    "removeFromQueue": "Remove from Queue",
    "playNextAction": "Play Next",
    "addToQueueAction": "Add to Queue",
    "addToPlaylistAction": "Add to Playlist",
    "newPlaylistAction": "New Playlist",
    "noCustomPlaylists": "No custom playlists",
    "added": "Added",
    "moreActions": "More Actions",
    "favorite": "Favorite",
    "favorited": "Favorited",
    "addToFavorites": "Add to Favorites",
    "removeFromFavorites": "Remove from Favorites",

    // Play Modes
    "repeatOne": "Repeat One",
    "shuffle": "Shuffle",
    "sequential": "Sequential",
    "repeatAll": "Repeat All",

    // About Module
    "aboutTitle": "About 0rhxPlayer",
    "aboutDesc": "Cross-platform Next-Gen Audiophile Local Music Player powered by Tauri 2 + React",
    "version": "Version",
    "developer": "Developer",
    "officialWebsite": "Official Website",
    "sourceCode": "Source Repository",
    "license": "License"
  },
  "ja": {
    "appName": "0rhxPlayer",
    "home": "ホーム",
    "library": "ライブラリ",
    "search": "検索",
    "queue": "再生キュー",
    "playlist": "プレイリスト",
    "settings": "設定",
    "eq": "イコライザー",
    "dailyMix": "デイリーミックス",
    "featuredSection": "特集セクション",
    "titles": "曲名",
    "artists": "アーティスト",
    "albums": "アルバム",
    "folders": "フォルダ",
    "updatedToday": "本日更新",
    "updatedYesterday": "昨日更新",
    "updatedDaysAgo": "2日前に更新",
    "nowPlayingTitle": "再生キュー",
    "played": "再生済み",
    "nexts": "次再生",
    "hintedSearch": "曲、歌手、アルバムを検索...",
    "profileSettings": "プロフィール設定",
    "nickname": "ユーザー名",
    "avatarLocal": "ローカルアバター画像",
    "selectAvatarFile": "ローカルファイル選択...",
    "resetAvatar": "デフォルトに戻す",
    "lyricAlign": "歌詞の配置",
    "alignRight": "右揃え",
    "alignCenter": "中央揃え",
    "alignLeft": "左揃え",
    "lyricsFontSize": "歌詞の文字サイズ",
    "lyricsFontSizeSub": "再生画面の歌詞テキストサイズを調整",
    "showTrans": "歌詞の翻訳表示",
    "language": "表示言語",
    "languageSub": "アプリの表示言語を選択",
    "themeMode": "テーマモード",
    "themeSystem": "システム連動",
    "dark": "ダーク",
    "light": "ライト",
    "audioEngine": "オーディオドライバー",
    "audioSpec": "出力スペック",
    "greetingMorning": "おはようございます",
    "greetingAfternoon": "こんにちは",
    "greetingEvening": "こんばんは",
    "greetingNight": "夜深です，おやすみなさい",
    "emptyLibrary": "ローカル曲がありません。ボタンからフォルダを追加してください。",
    "showAll": "すべて表示",
    "openFolder": "フォルダをスキャン",
    "importFiles": "ファイルを追加",
    "noLyrics": "歌詞がありません",
    "sectionAudioEngine": "オーディオエンジン & DSP",
    "resamplerAlgorithm": "リサンプラーアルゴリズム",
    "bufferSize": "バッファサイズ",
    "replayGainMode": "ReplayGain 音量平准化",
    "cueAutoScan": "CUE シート自動読み込み",
    "sectionLibraryNav": "ライブラリとタグ検索",
    "sectionInterface": "UI & テーマのカスタム",
    "autoCollapseRail": "再生詳細を開く時にサイドバーを自動折りたたみ",
    "autoCollapseRailSub": "再生詳細画面を開いた際にサイドバーを折りたたんで歌詞の表示領域を広げます",
    "navRailCustom": "カスタム",
    "navRailCustomDesc": "表示項目をカスタマイズできます",
    "artistSeparators": "歌手の区切り文字",
    "artistSeparatorsSub": "複数の歌手を记号で分割（例：/ や ,）",
    "customSeedColor": "テーマシードカラー",
    "customSeedColorSub": "Material 3 パレットのベースカラーをカスタマイズ",
    "useArtworkTheme": "アルバムアートから自動配色",
    "useArtworkThemeSub": "再生中のアルバムアートから配色を動的生成",
    "globalHotkeys": "グローバルショートカット",
    "systemTray": "終了時にトレイに最小化",
    "enabled": "有効",
    "disabled": "無効",
    "formatLabel": "フォーマット",
    "bitrateLabel": "ビットレート",
    "engineLabel": "出力エンジン",
    "featuredPlaylists": "注目のプレイリスト",
    "audiophileCol": "ハイレゾ高音质コレクション",
    "searchTrackResults": "検索結果（トラック）",
    "audioEngineSub": "排他/共有モードと低遅延出力",
    "resamplerSub": "高精度リサンプリングアルゴリズム",
    "replayGainSub": "トラック間の音量急变を防止",
    "lyricAlignSub": "同期歌詞のテキスト配置",
    "systemTraySub": "終了時にバックグラウンドで継続",
    "createPlaylist": "新規プレイリスト",
    "myPlaylists": "マイプレイリスト",
    "favoritesPlaylist": "お気に入り曲集",
    "trackCount": "曲",
    "saveNavCustom": "変更を保存",
    "transSub": "メイン歌詞下の多言語翻訳表示を切り替え",
    "cancel": "キャンセル",
    "navRailOrderHint": "順序変更 / 表示切替",
    "moveUp": "上へ移動",
    "moveDown": "下へ移動",
    "expandRail": "展開",
    "collapseRail": "折りたたむ",
    "specFormat": "フォーマット & レート",
    "specBitrate": "ビットレート & チャンネル",
    "specDriver": "ドライバー & レイテンシ",
    "specReplayGain": "ゲイン平準化",
    "featuredTracksTitle": "おすすめの曲",
    "featuredAlbumsTitle": "おすすめアルバム",
    "collapseNowPlaying": "折りたたむ",
    "refreshRecommendations": "おすすめ再読み込み",
    "rescanLibrary": "ライブラリ再スキャン",
    "addFolder": "フォルダを追加",
    "removeFolder": "フォルダを削除",
    "removeFolderConfirm": "このフォルダをスキャン対象から削除しますか？(ローカルファイルは削除されません)",
    "scannedFoldersTitle": "登録済みフォルダ",
    "noScannedFolders": "登録されたフォルダはありません。上のボタンから追加してください。",
    "allTracks": "すべての曲",
    "featuredAlbums": "アルバム",

    // Playlist
    "systemPlaylist": "システムプレイリスト",
    "customPlaylist": "カスタムプレイリスト",
    "backToPlaylists": "プレイリスト一覧に戻る",
    "playAll": "すべて再生",
    "shufflePlay": "シャッフル再生",
    "emptyPlaylistHint": "曲がありません。ライブラリから追加してください。",
    "renamePlaylist": "プレイリスト名を変更",
    "deletePlaylist": "プレイリストを削除",
    "removeFromPlaylist": "プレイリストから削除",
    "save": "保存",

    // Equalizer
    "eqSubtitle": "Biquadフィルター搭載10バンド・グラフィックイコライザー",
    "reset": "リセット",
    "eqBypass": "バイパス",
    "eqEnabled": "有効",
    "soundPresets": "サウンドプリセット",
    "preamp": "プリアンプ",
    "preampDesc": "入力ゲインを調整して音割れを防止（ダブルクリックでリセット）",
    "customPreset": "カスタム",

    // Library & Search & Batch & Actions
    "batchSelect": "一括選択",
    "finishSelect": "完了",
    "sortTitleAsc": "曲名 (昇順)",
    "sortTitleDesc": "曲名 (降順)",
    "sortArtistAsc": "アーティスト (昇順)",
    "sortArtistDesc": "アーティスト (降順)",
    "sortAlbumAsc": "アルバム (昇順)",
    "sortAlbumDesc": "アルバム (降順)",
    "sortFolderAsc": "フォルダ (昇順)",
    "sortFolderDesc": "フォルダ (降順)",
    "sortTrackCountDesc": "曲数 (多い順)",
    "sortTrackCountAsc": "曲数 (少ない順)",
    "sortSizeDesc": "ファイルサイズ (大きい順)",
    "sortBitrateDesc": "ビットレート (高い順)",
    "sortFormatAsc": "フォーマット (FLAC/MP3等)",
    "sortModifiedDesc": "更新日時 (新しい順)",
    "sortAddedDesc": "追加日時 (新しい順)",
    "sortDurationDesc": "時間 (長い順)",
    "sortDurationAsc": "時間 (短い順)",
    "selectedCount": "選択中",
    "selectAll": "すべて選択",
    "deselectAll": "選択解除",
    "batchPlay": "再生",
    "batchAddToQueue": "キューに追加",
    "batchAddToPlaylist": "プレイリストに追加",
    "batchRemoveFromLibrary": "ライブラリから削除",
    "batchAddTitle": "プレイリストに追加",
    "createAndAdd": "新規作成して追加",
    "newPlaylistPlaceholder": "新規プレイリスト名...",
    "create": "作成",
    "confirm": "確定",
    "back": "戻る",
    "searchHistory": "検索履歴",
    "clear": "クリア",
    "noMatchResults": "検索結果なし",
    "noMatchDesc": "該当する曲が見つかりませんでした",
    "libraryTracksHeader": "ライブラリの曲",
    "noPlayedTracks": "再生履歴はありません",
    "noQueueTracks": "キューは空です",
    "removeFromQueue": "キューから削除",
    "playNextAction": "次に再生",
    "addToQueueAction": "キューに追加",
    "addToPlaylistAction": "プレイリストに追加",
    "newPlaylistAction": "新規プレイリスト",
    "noCustomPlaylists": "プレイリストはありません",
    "added": "追加済み",
    "moreActions": "その他の操作",
    "favorite": "お気に入り",
    "favorited": "お気に入り済み",
    "addToFavorites": "お気に入りに追加",
    "removeFromFavorites": "お気に入りから削除",

    // Play Modes
    "repeatOne": "1曲リピート",
    "shuffle": "シャッフル",
    "sequential": "順次再生",
    "repeatAll": "全曲リピート",

    // About Module
    "aboutTitle": "0rhxPlayer について",
    "aboutDesc": "Tauri 2 + React による次世代ハイレゾ対応ローカル音楽プレイヤー",
    "version": "バージョン",
    "developer": "開発者",
    "officialWebsite": "公式サイト",
    "sourceCode": "ソースコード",
    "license": "ライセンス"
  }
};

export function formatCount(count: number, unit: 'track' | 'album' | 'folder' | 'artist', lang: LangKey): string {
  switch (lang) {
    case 'en':
      if (unit === 'track') return `${count} track${count === 1 ? '' : 's'}`;
      if (unit === 'album') return `${count} album${count === 1 ? '' : 's'}`;
      if (unit === 'folder') return `${count} folder${count === 1 ? '' : 's'}`;
      if (unit === 'artist') return `${count} artist${count === 1 ? '' : 's'}`;
      return `${count}`;
    case 'ja':
      if (unit === 'track') return `${count} 曲`;
      if (unit === 'album') return `${count} アルバム`;
      if (unit === 'folder') return `${count} フォルダ`;
      if (unit === 'artist') return `${count} アーティスト`;
      return `${count}`;
    case 'zh':
    default:
      if (unit === 'track') return `${count} 首曲目`;
      if (unit === 'album') return `${count} 张专辑`;
      if (unit === 'folder') return `${count} 个文件夹`;
      if (unit === 'artist') return `${count} 位歌手`;
      return `${count}`;
  }
}







