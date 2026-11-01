# 0rhxPlayer Plugin Developer Specification Guide

<p align="center">
  <b>Official Developer Guide for 0rhxPlayer Native Extension Ecosystem</b><br>
  Language Navigation: <a href="#english-specification">English</a> | <a href="#日本語仕様概要">日本語</a> | <a href="#简体中文规范概要">简体中文</a>
</p>

---

<a name="english-specification"></a>
# English Specification

## 1. Core Architecture & Design Philosophy

0rhxPlayer (**0P**) is a lightweight, minimalist, audiophile-grade desktop audio player engineered in native C++20 and Qt 6 (QML). To maintain microsecond-level low latency, minimal memory footprint (~100 MB steady-state), and smooth 60/120 FPS hardware-accelerated rendering, the plugin system adheres to strict architectural red-lines:

> [!IMPORTANT]
> **Strict Red-Line: 100% Native Material 3 UI — Strictly NO WebView / Browser Engines**
> 0rhxPlayer permanently and strictly forbids any Chromium, CEF, Electron, or WebView embeddings. 
> Plugins provide **data feeds and declarative UI schemas (JSON)**. The host application handles all view rendering using native Qt Quick Material 3 primitives.

### Key Pillars:
1. **Schema-Driven Presentation**: Plugins define view structures via declarative JSON schemas (`views/*.json`). 0P renders them using native Material You container cards, lists, and controls.
2. **Strict Sidebar Limits**: A plugin may register **at most one (1)** sidebar item. Sidebar entries integrate seamlessly into 0P's native `NavigationRail` and user-controlled reordering dialog (`NavCustomDialog`).
3. **Global Hook System**: Headless / background plugins (e.g. NetEase Cloud Music, synced lyrics fetchers) operate without a sidebar tab, hooking directly into global search and media library queries.
4. **Direct Stream Passthrough**: Audio streams discovered by plugins are passed directly to 0P's high-fidelity BASS audio engine, preserving WASAPI Exclusive mode, 64-bit SoX resampling, and bit-perfect DAC output.

---

## 2. Plugin Package Structure (`.0px`)

0rhxPlayer plugins are distributed as `.0px` bundles (standard ZIP archives). When installed, the package is extracted to `PathManager::pluginsDir() / <plugin_id>`.

```
<plugin-id>.0px (ZIP Archive)
├── plugin.json                 # Mandatory plugin manifest
├── assets/
│   └── icon.svg                # Vector SVG icon (1:1 aspect ratio)
├── views/
│   └── main.json               # Native Material 3 view schema
├── mock_data/                  # Static or cached feeds
│   └── search_results.json
└── README.md                   # Plugin documentation
```

---

## 3. Manifest Definition (`plugin.json`)

The `plugin.json` file resides in the root of the `.0px` bundle. All field definitions and types are detailed below:

```json
{
  "$schema": "https://raw.githubusercontent.com/RinCynar/0rhxPlayer-Plugins/main/schema/v1/plugin.schema.json",
  "id": "com.rincynar.netease",
  "name": "Netease Cloud Music",
  "version": "1.0.0",
  "author": "RinCynar",
  "description": "Cloud streaming, library sync, and search hook for Netease Music.",
  "category": "NetService",
  "homepage": "https://github.com/RinCynar/0rhxPlayer-Plugins",
  "enabled": true,
  "sidebar": {
    "title": "Cloud Music",
    "icon": "assets/icon.svg",
    "route": "cloud_music",
    "schema": "views/main.json"
  },
  "hooks": {
    "search": true,
    "library": true,
    "lyrics": false
  }
}
```

### Field Definitions:

| Field | Type | Required | Description & Constraints |
| :--- | :--- | :--- | :--- |
| `id` | `string` | **Yes** | Unique reverse-DNS identifier (e.g., `com.author.plugin`). Lowercase alphanumeric, hyphen, dot only. |
| `name` | `string` | **Yes** | Human-readable plugin display name. |
| `version` | `string` | **Yes** | Semantic versioning (`major.minor.patch`, e.g., `1.0.0`). |
| `author` | `string` | **Yes** | Author or organization name. |
| `description` | `string` | **Yes** | Concise summary of plugin functionality. |
| `category` | `string` | **Yes** | Extension category: `"NetService"`, `"Lyrics"`, `"Metadata"`, `"Test"`, `"Utility"`, or `"Other"`. |
| `homepage` | `string` | No | Project website or GitHub repository URL. |
| `icon` | `string` | No | Path to plugin icon relative to root (or system `qrc:/` icon). |
| `enabled` | `boolean` | No | Default activation status upon installation (default: `true`). |
| `sidebar` | `object` | No | Sidebar entry specification. **Maximum 1 per plugin**. |
| `sidebar.title` | `string` | Yes* | Label displayed in NavigationRail and tooltip. |
| `sidebar.icon` | `string` | No | Relative path to SVG icon or system QRC path. |
| `sidebar.route` | `string` | Yes* | Unique route identifier for view routing. |
| `sidebar.schema` | `string` | No | Relative path to declarative native view schema JSON. |
| `hooks` | `object` | No | Global feature hooks enabled by the plugin. |
| `hooks.search` | `boolean` | No | Whether the plugin intercepts global search queries. |
| `hooks.library` | `boolean` | No | Whether the plugin injects external library categories. |
| `hooks.lyrics` | `boolean` | No | Whether the plugin supplies online synced lyrics. |

---

## 4. Sidebar Integration Rules

1. **Strict 1-Item Limit**: Any plugin declaring multiple navigation items will be rejected or truncated to the primary item.
2. **Native Ordering System**: Sidebar items are injected into `ConfigManager.allNavItems` as `plugin:<plugin_id>`. Users can drag, reorder, or toggle item visibility inside `NavCustomDialog`.
3. **Lifecycle Synchronization**: When a plugin is disabled or uninstalled, its sidebar item is immediately unmounted from `visibleNavItems`. When re-enabled, it restores to its saved order position.

---

## 5. Declarative Native UI Schema (`views/*.json`)

When a user selects a plugin's sidebar tab, 0rhxPlayer reads the schema file declared in `sidebar.schema` and renders it with native Material 3 widgets:

```json
{
  "type": "page",
  "title": "Netease Cloud Music Discovery",
  "sections": [
    {
      "type": "banner",
      "title": "Daily Recommendations",
      "subtitle": "Updated daily based on your listening preferences"
    },
    {
      "type": "card",
      "title": "Top Playlist",
      "details": "High-resolution lossless tracks curated by editors"
    },
    {
      "type": "track_list",
      "title": "Hot Tracks",
      "items": [
        {
          "id": "195821038",
          "title": "Shelter",
          "artist": "Porter Robinson & Madeon",
          "album": "Shelter - Single",
          "duration": 219,
          "streamUrl": "https://music.163.com/song/media/outer/url?id=195821038.mp3",
          "cover": "https://p1.music.126.net/..."
        }
      ]
    }
  ]
}
```

- Double-clicking or activating a track item invokes `AudioEngine.play(item.streamUrl)` natively.
- No HTML/DOM/CSS is parsed; all visual rendering uses GPU-accelerated QML items (`Theme.surfaceContainerLow`, `Theme.primary`).

---

## 6. Global Search Hook Protocol

When `hooks.search` is set to `true`, 0rhxPlayer queries the plugin during search input. Plugins provide track records adhering to this specification:

```json
[
  {
    "title": "Track Name",
    "artist": "Artist Name",
    "album": "Album Name",
    "durationMs": 240000,
    "format": "MP3",
    "bitrateKbps": 320,
    "streamUrl": "https://...",
    "coverUrl": "https://..."
  }
]
```

---

## 7. Marketplace Indexing (`index.md`)

Official and third-party plugin repositories publish their catalog via an `index.md` file. 0rhxPlayer parses YAML frontmatter or fenced JSON blocks:

```markdown
---
plugins:
  - id: "com.rincynar.netease"
    name: "Netease Cloud Music"
    version: "1.0.0"
    author: "RinCynar"
    description: "Cloud streaming and search hook"
    category: "NetService"
    packageUrl: "https://github.com/RinCynar/0rhxPlayer-Plugins/releases/download/v1.0.0/netease.0px"
    icon: "globe.svg"
  - id: "com.rincynar.krclyrics"
    name: "KRC Synced Lyrics"
    version: "1.1.0"
    author: "0P Contributors"
    description: "Karaoke syllable-level synced lyrics"
    category: "Lyrics"
    packageUrl: "https://github.com/RinCynar/0rhxPlayer-Plugins/releases/download/v1.1.0/krclyrics.0px"
    icon: "music.svg"
---

# 0rhxPlayer Official Plugin Repository
Welcome to the plugin marketplace.
```

---

<a name="日本語仕様概要"></a>
# 日本語仕様概要

## 1. 0rhxPlayer プラグイン設計思想
0rhxPlayer（0P）は、軽量性・ミニマリズム・高音質再生（WASAPI 排他モード、SoX 64-bit リサンプリング）を追求したネイティブオーディオプレーヤーです。

> [!IMPORTANT]
> **重要原則: 完全ネイティブ Material 3 UI — WebView / ブラウザエンジンの使用は厳格に禁止**
> 0P では Chromium や WebView などの埋め込みブラウザを一切採用しません。プラグインはデータと宣言的 UI スキーマ（JSON）のみを提供し、すべての画面描画は 0P のネイティブ QML コントロールが担当します。

## 2. 制限事項と機能要件
- **サイドバー上限**: 1 プラグインにつき登録可能なサイドバーアイコンは **最大 1 つ** です。
- **サイドバー統合**: 0P ネイティブのナビゲーションレール編集ダイアログ（`NavCustomDialog`）と自動連動し、ユーザーが並び替えや非表示を管理できます。
- **グローバルフック**: サイドバーを持たないプラグイン（歌詞プロバイダーや検索フック）もサポートされています。
- **配布形式**: `.0px`（標準 ZIP 形式）パッケージ。

---

<a name="简体中文规范概要"></a>
# 简体中文规范概要

## 1. 核心设计哲学与铁律
0rhxPlayer（0P）作为专注于无损高保真与极速轻量的原生音频播放器，对插件架构设立了坚决的工程底线：

> [!IMPORTANT]
> **绝对红线：100% 原生 Material 3 UI — 坚决杜绝任何 WebView / 浏览器引擎**
> 0P 永久严禁引入 Chromium、CEF、Electron 或任何形式的内嵌 WebView。
> 插件仅负责逻辑处理并向宿主提供结构化数据与声明式视图 Schema（JSON），所有的界面绘制与动画 100% 由 0P 原生 QML 控件负责，确保 120 FPS 的丝滑与整体视觉的一致性。

## 2. 核心规则总结
1. **侧边栏配额限制**：每个插件**最多只能申请 1 个**侧边栏入口。申请后直接进入 0P 原生侧边栏管理系统，支持用户拖拽排序和显隐切换。
2. **全局 Hook 支持**：支持无侧边栏的后台型插件（如网易云音乐、歌词刮削），直接 Hook 全局搜索与曲库，异步向原生各页面注入云端流媒体数据。
3. **打包分发标准**：`.0px` 后缀的通用 ZIP 归档包，根目录必须包含符合规范的 `plugin.json`。
4. **插件市场换源**：官方市场默认拉取 GitHub 仓库的 `index.md`，支持在设置中自定义更换为第三方镜像或自定义源。
