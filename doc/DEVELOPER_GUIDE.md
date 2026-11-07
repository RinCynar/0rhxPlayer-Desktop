# 0rhxPlayer Plugin Developer Specification Manual (v1.0)

---

# English Specification

## 1. Architectural Model

0rhxPlayer (**0P**) is built with C++20 and Qt 6 (QML). The plugin system enforces the following constraints:

1. **Host-Rendered UI**: Plugins cannot embed Chromium, CEF, Electron, or any WebView engine. Plugins provide structured data and declarative UI schemas (`views/*.json`). 0P renders views natively via Qt Quick Material 3 controls.
2. **Sidebar Slot Limit**: A plugin may register at most one (1) sidebar entry. Sidebar entries are managed by 0P's native `NavigationRail` and `NavCustomDialog`.
3. **Global Hooks**: Plugins can register headless background hooks (search, metadata, lyrics) without creating UI entries.
4. **Audio Stream Dispatch**: Plugins pass audio URLs or stream descriptors to 0P's internal audio engine for playback.

---

## 2. Package Identity & Lifecycle

Every plugin must declare a unique reverse-DNS identifier (`id`).

### 2.1 Identifier Syntax

* Pattern: `^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$`
* Reserved Prefix: `top.rincynar.*` is strictly reserved for official system components. Community plugins must use their own domain or prefix.

### 2.2 Versioning & Arbitration

1. **Semantic Versioning (`semver`)**:
   * `New > Current`: In-place upgrade. State data in `PathManager::pluginDataDir(id)` is preserved.
   * `New == Current`: Requires user overwrite confirmation.
   * `New < Current`: Rejected unless downgrade is explicitly forced.
2. **Author Matching**: Upgrades must originate from the matching `author` field.
3. **Display Name Collision**: If duplicate display names exist, the host renders `Name (author)` in the interface.

---

## 3. Package File Layout (`.0px`)

A `.0px` file is a standard ZIP archive. `plugin.json` must exist at the archive root.

```
<plugin-id>.0px
├── plugin.json
├── assets/
│   └── icon.svg
├── views/
│   └── main.json
├── scripts/
│   └── main.js
└── locales/
    ├── en.json
    ├── ja.json
    └── zh-CN.json
```

---

## 4. Manifest Specification (`plugin.json`)

```json
{
  "$schema": "https://raw.githubusercontent.com/RinCynar/0rhxPlayer-Plugins/main/schema/v1/plugin.schema.json",
  "id": "org.example.extension",
  "name": "Extension Template",
  "version": "1.0.0",
  "author": "Author",
  "description": "Standard extension definition template.",
  "category": "Tools",
  "homepage": "https://example.com",
  "minAppVersion": "1.2.0",
  "permissions": [
    "audio:control",
    "audio:state",
    "library:read",
    "library:write",
    "lyrics:read",
    "lyrics:write",
    "ui:slot:menu",
    "ui:slot:sidebar",
    "ui:slot:bottombar"
  ],
  "entries": {
    "sidebar": {
      "enabled": true,
      "title": "Extension",
      "icon": "assets/icon.svg",
      "schema": "views/main.json"
    },
    "contextMenu": {
      "track": {
        "enabled": true,
        "id": "track_action",
        "title": "Track Action",
        "icon": "assets/icon.svg"
      },
      "album": {
        "enabled": false,
        "id": "album_action",
        "title": "Album Action",
        "icon": "assets/icon.svg"
      },
      "playlist": {
        "enabled": false,
        "id": "playlist_action",
        "title": "Playlist Action",
        "icon": "assets/icon.svg"
      }
    },
    "playbackControl": {
      "enabled": false,
      "id": "player_action",
      "title": "Player Bar Action",
      "icon": "assets/icon.svg"
    }
  },
  "hooks": {
    "search": false,
    "mediaSource": false,
    "lyricsProvider": false
  }
}
```

### Manifest Field Definitions

| Field Path | Type | Required | Description |
| --- | --- | --- | --- |
| `id` | `string` | Yes | Reverse-DNS package identifier (max 64 chars). |
| `name` | `string` | Yes | Display name in marketplace and UI (max 32 chars). |
| `version` | `string` | Yes | Semver version string (`X.Y.Z`). |
| `author` | `string` | Yes | Author or organization string. |
| `description` | `string` | Yes | Functional description. |
| `category` | `string` | Yes | Marketplace category tag. |
| `homepage` | `string` | No | Project website URL. |
| `minAppVersion` | `string` | Yes | Minimum compatible 0P version. |
| `permissions` | `string[]` | Yes | Explicit permission declaration list. |
| `entries.sidebar` | `object` | No | Sidebar navigation slot (limit: 1 per package). |
| `entries.sidebar.title` | `string` | No | Text displayed in NavigationRail. |
| `entries.sidebar.icon` | `string` | No | Path to vector icon. |
| `entries.sidebar.schema` | `string` | No | Path to native view schema. |
| `entries.contextMenu.track` | `object` | No | Single track context menu injection. |
| `entries.contextMenu.album` | `object` | No | Album item context menu injection. |
| `entries.contextMenu.playlist` | `object` | No | Playlist item context menu injection. |
| `entries.playbackControl` | `object` | No | Action button injection in bottom player bar. |
| `hooks.search` | `boolean` | No | Query hook for global search bar. |
| `hooks.mediaSource` | `boolean` | No | Cloud and remote audio stream resolver. |
| `hooks.lyricsProvider` | `boolean` | No | Lyrics fetching provider hook. |

---

## 5. Host Hook Interfaces & Action Payloads

When an injected entry is triggered by the user, the host dispatches `pluginActionTriggered(pluginId, actionId, slotType, payload)`:

### 5.1 Context Menu Payloads

* **Track Target (`track`)**:
```json
{
  "type": "track",
  "data": {
    "filePath": "string",
    "title": "string",
    "artist": "string",
    "album": "string",
    "duration": 0,
    "sampleRate": 0,
    "channels": 0,
    "bitrate": 0,
    "format": "string"
  }
}
```

* **Album Target (`album`)**:
```json
{
  "type": "album",
  "data": {
    "albumName": "string",
    "artist": "string",
    "trackCount": 0,
    "tracks": ["filePath1", "filePath2"]
  }
}
```

* **Playlist Target (`playlist`)**:
```json
{
  "type": "playlist",
  "data": {
    "playlistId": "string",
    "title": "string",
    "trackCount": 0
  }
}
```

### 5.2 Bottom Player Bar Payload (`playbackControl`)

```json
{
  "type": "playbackControl",
  "data": {
    "currentTrack": "filePath",
    "isPlaying": true,
    "positionMs": 45000
  }
}
```

---

## 6. Host API Reference (C++ & QML Invokables)

The host exposes full engine operations through the singleton `PluginManager` (`rhx.plugin 1.0`).

### 6.1 Audio Playback & Transport Control

| Method | Parameters | Return Type | Description |
| --- | --- | --- | --- |
| `play` | `filePath: string` (optional) | `void` | Plays the specified file path or URL. If empty, resumes current playback. |
| `pause` | none | `void` | Pauses audio playback. |
| `resume` | none | `void` | Resumes paused audio playback. |
| `stop` | none | `void` | Stops playback and resets stream position to 0. |
| `seek` | `positionMs: int64` | `void` | Seeks stream to target position in milliseconds. |
| `setVolume` | `volume: float` | `void` | Sets master volume level (clamped to `0.0` - `1.0`). |
| `getVolume` | none | `float` | Returns current master volume level (`0.0` - `1.0`). |
| `getPlaybackState` | none | `int` | Returns current state: `0` = Stopped, `1` = Playing, `2` = Paused. |
| `getPositionMs` | none | `int64` | Returns current playback position in milliseconds. |
| `getDurationMs` | none | `int64` | Returns active audio track duration in milliseconds. |
| `getCurrentTrack` | none | `string` | Returns active track file path or URL. |
| `getCurrentMetadata` | none | `object` | Returns current track metadata map (title, artist, album, bitrate, format, etc.). |
| `getPlayMode` | none | `int` | Returns mode: `0` = RepeatAll, `1` = RepeatOne, `2` = Shuffle, `3` = Sequential. |
| `setPlayMode` | `mode: int` | `void` | Sets playback mode (`0` - `3`). |
| `playNext` | none | `void` | Skips to next track in queue. |
| `playPrevious` | none | `void` | Skips to previous track in queue. |

### 6.2 Equalizer & DSP Control

| Method | Parameters | Return Type | Description |
| --- | --- | --- | --- |
| `setEqEnabled` | `enabled: bool` | `void` | Enables or disables the 10-band equalizer. |
| `isEqEnabled` | none | `bool` | Returns whether the equalizer is currently active. |
| `setEqPreamp` | `preampDb: float` | `void` | Sets equalizer preamp gain in decibels. |
| `getEqPreamp` | none | `float` | Returns current equalizer preamp gain in decibels. |
| `setEqBand` | `index: int`, `gainDb: float` | `void` | Sets gain in decibels for specified EQ band index (`0` - `9`). |
| `getEqBands` | none | `float[]` | Returns list of 10 band gain values in decibels. |
| `applyEqPreset` | `presetName: string` | `void` | Applies pre-defined EQ preset (e.g. `Flat`, `Rock`, `Classical`). |
| `resetEq` | none | `void` | Resets all EQ bands and preamp gain to `0.0 dB`. |
| `getEqPreset` | none | `string` | Returns active equalizer preset name. |
| `getEqPresetNames` | none | `string[]` | Returns list of available equalizer preset names. |

### 6.3 Playback Queue

| Method | Parameters | Return Type | Description |
| --- | --- | --- | --- |
| `getQueue` | none | `object[]` | Returns array of track detail maps in current queue. |
| `getQueueCount` | none | `int` | Returns number of tracks in current queue. |
| `getCurrentQueueIndex` | none | `int` | Returns zero-based index of current active track in queue. |
| `playQueueIndex` | `index: int` | `void` | Jumps playback to specified queue index. |
| `setQueue` | `trackPaths: string[]`, `startIndex: int` | `void` | Replaces current queue with list and begins playback at startIndex. |
| `addToQueue` | `filePath: string` | `void` | Appends a single track to the end of the queue. |
| `insertTracksNext` | `trackPaths: string[]` | `void` | Inserts tracks directly after current playing track. |
| `clearQueue` | `keepCurrent: bool` | `void` | Clears playback queue. If keepCurrent is true, current track remains. |
| `removeFromQueue` | `index: int` | `void` | Removes track at specified index from queue. |
| `moveQueueItem` | `from: int`, `to: int` | `void` | Reorders track position within queue. |
| `shuffleQueue` | none | `void` | Shuffles order of all queued tracks. |

### 6.4 Media Library & Search

| Method | Parameters | Return Type | Description |
| --- | --- | --- | --- |
| `getLibraryTrackCount` | none | `int` | Returns total number of indexed tracks in library. |
| `getAllTrackPaths` | none | `string[]` | Returns list of all indexed track file paths. |
| `getAllTracks` | `limit: int`, `offset: int` | `object[]` | Returns paginated array of track detail maps. |
| `getTrackDetails` | `filePath: string` | `object` | Returns complete metadata map for specified track. |
| `getAllAlbums` | none | `object[]` | Returns list of all indexed album items. |
| `getAllArtists` | none | `object[]` | Returns list of all indexed artist items. |
| `getAlbumTracks` | `albumName: string`, `artist: string` | `object[]` | Returns list of tracks belonging to specific album. |
| `getArtistTracks` | `artistName: string` | `object[]` | Returns list of tracks performed by specific artist. |
| `searchLibrary` | `keyword: string` | `object` | Performs search across title, artist, and album fields. |
| `rescanLibrary` | none | `void` | Triggers background library rescan of configured folders. |
| `isScanningLibrary` | none | `bool` | Returns whether library scanner is actively running. |

### 6.5 Playlists & User Favorites

| Method | Parameters | Return Type | Description |
| --- | --- | --- | --- |
| `isFavorite` | `trackPath: string` | `bool` | Returns whether track path is marked as favorite. |
| `toggleFavorite` | `trackPath: string` | `void` | Toggles favorite status of specified track path. |
| `setFavorite` | `trackPath: string`, `favorite: bool` | `void` | Explicitly sets favorite status for specified track path. |
| `getFavoriteCount` | none | `int` | Returns total number of tracks marked as favorite. |
| `getFavoriteTracks` | none | `string[]` | Returns list of all favorite track paths. |
| `getAllPlaylists` | none | `object[]` | Returns array of playlist objects (id, name, trackCount, coverUrl). |
| `getPlaylistTracks` | `playlistId: string` | `object[]` | Returns track detail items contained in playlist. |
| `createPlaylist` | `name: string`, `trackPaths: string[]` | `string` | Creates playlist and returns generated unique playlist identifier. |
| `deletePlaylist` | `playlistId: string` | `bool` | Deletes playlist by identifier. |
| `renamePlaylist` | `playlistId: string`, `newName: string` | `bool` | Renames playlist by identifier. |
| `addTracksToPlaylist` | `playlistId: string`, `trackPaths: string[]` | `bool` | Appends tracks to specified playlist. |
| `removeTracksFromPlaylist` | `playlistId: string`, `trackPaths: string[]` | `bool` | Removes tracks from specified playlist. |
| `playPlaylist` | `playlistId: string`, `shuffle: bool` | `void` | Loads playlist into queue and starts playback. |

### 6.6 Synchronized Lyrics

| Method | Parameters | Return Type | Description |
| --- | --- | --- | --- |
| `hasLyrics` | none | `bool` | Returns whether active track has loaded lyrics. |
| `hasLyricTranslation` | none | `bool` | Returns whether loaded lyrics include translation lines. |
| `getLyricCount` | none | `int` | Returns number of synchronized lyric lines. |
| `getCurrentLyricIndex` | none | `int` | Returns zero-based index of active highlighted lyric line. |
| `getAllLyrics` | none | `object[]` | Returns array of lyric objects (timeMs, text, translation). |
| `getLyricLine` | `index: int` | `object` | Returns single lyric line object at index. |
| `loadLrcContent` | `lrcContent: string` | `bool` | Injects raw LRC text string into synchronized lyric model. |
| `clearLyrics` | none | `void` | Clears all currently loaded lyrics. |

### 6.7 Application Environment & State

| Method | Parameters | Return Type | Description |
| --- | --- | --- | --- |
| `getAppVersion` | none | `string` | Returns host application version string (e.g. `1.2.0`). |
| `getAppLanguage` | none | `string` | Returns current active language code (`en`, `ja`, `zh_CN`). |
| `getThemeMode` | none | `string` | Returns current theme mode (`light`, `dark`, `system`). |
| `getSeedColor` | none | `string` | Returns current Material 3 hex primary seed color. |
| `getPluginDataDir` | `pluginId: string` | `string` | Returns absolute directory path reserved for plugin data storage. |
| `isWindowActive` | none | `bool` | Returns whether application window currently has system focus. |

### 6.8 View Slot Injections & Actions

| Method | Parameters | Return Type | Description |
| --- | --- | --- | --- |
| `getInjectedMenuItems` | `slotType: string`, `contextData: object` | `object[]` | Returns injected menu items for target slot (`track`, `album`, `playlist`). |
| `getInjectedPlaybackControls` | none | `object[]` | Returns injected action buttons for bottom player bar. |
| `triggerPluginAction` | `pluginId: string`, `actionId: string`, `slotType: string`, `payload: object` | `void` | Dispatches action execution to target plugin. |
| `executePluginHook` | `hookType: string`, `params: object` | `object` | Executes registered plugin hook (e.g. `search`). |

---

## 7. Event Bus & Lifecycle Signals

Plugins and host views connect to signals on `PluginManager` to observe lifecycle events:

| Signal Signature | Parameters | Description |
| --- | --- | --- |
| `playbackStateChanged` | `state: int` | Emitted when state changes (`0` = Stopped, `1` = Playing, `2` = Paused). |
| `positionChanged` | `positionMs: int64`, `durationMs: int64` | Emitted as audio playback position advances. |
| `trackChanged` | `trackInfo: object` | Emitted when current playing track changes or metadata updates. |
| `volumeChanged` | `volume: float` | Emitted when master volume changes (`0.0` - `1.0`). |
| `playModeChanged` | `mode: int` | Emitted when playback mode changes (`0` - `3`). |
| `eqChanged` | none | Emitted when equalizer state, preamp, bands, or presets change. |
| `queueChanged` | none | Emitted when queue contents or track order changes. |
| `libraryChanged` | none | Emitted when tracks in local library are added, modified, or removed. |
| `favoritesChanged` | `trackPath: string`, `isFavorite: bool` | Emitted when favorite status of a track changes. |
| `playlistsChanged` | none | Emitted when user playlists are created, modified, or deleted. |
| `lyricsChanged` | none | Emitted when lyrics content or active lyric index updates. |
| `windowActiveChanged` | `active: bool` | Emitted when window focus or background state transitions. |
| `pluginActionTriggered` | `pluginId: string`, `actionId: string`, `slotType: string`, `data: object` | Emitted when user clicks an injected plugin menu or bar button. |

---

## 8. View Schema & Native Material 3 Container Structure

Plugins specify UI structure via declarative JSON schemas (`views/*.json`). Views are rendered strictly by host native QML components:

```json
{
  "type": "page",
  "title": "Extension Workbench",
  "sections": [
    {
      "type": "banner",
      "title": "Workbench Header",
      "subtitle": "Declarative native container"
    },
    {
      "type": "card",
      "title": "Status Card",
      "details": "Rendered via Material 3 surfaceContainerHighest"
    },
    {
      "type": "list",
      "title": "Item Feed",
      "items": [
        {
          "title": "Item 1",
          "subtitle": "Subtitle description",
          "action": "onItemClick"
        }
      ]
    }
  ]
}
```

---

## 9. Security & Permission Declarations

Plugins must explicitly request permissions in `plugin.json`:

| Permission String | Description | Guarded Capabilities |
| --- | --- | --- |
| `audio:control` | Transport control permission | `play`, `pause`, `resume`, `stop`, `seek`, `setVolume`, `setPlayMode`, EQ |
| `audio:state` | Audio engine state inspection | `getPlaybackState`, `getPositionMs`, `getDurationMs`, `getCurrentMetadata` |
| `library:read` | Media library read query | `getAllTracks`, `getAllAlbums`, `getAllArtists`, `searchLibrary` |
| `library:write` | Library modification | `createPlaylist`, `deletePlaylist`, `addTracksToPlaylist`, `setFavorite` |
| `lyrics:read` | Synchronized lyrics inspection | `hasLyrics`, `getLyricCount`, `getAllLyrics`, `getLyricLine` |
| `lyrics:write` | Synchronized lyrics injection | `loadLrcContent`, `clearLyrics` |
| `ui:slot:menu` | Context menu action injection | `entries.contextMenu.track`, `entries.contextMenu.album`, `entries.contextMenu.playlist` |
| `ui:slot:sidebar` | Sidebar navigation slot | `entries.sidebar` |
| `ui:slot:bottombar` | Bottom player bar action | `entries.playbackControl` |
| `network:fetch` | External network communication | `QNetworkAccessManager` remote HTTP/HTTPS queries |

---

# 日本語仕様書

## 1. アーキテクチャモデル

0rhxPlayer（**0P**）は C++20 および Qt 6（QML）で実装されています。プラグインシステムには以下の制約が適用されます：

1. **ホスト描画 UI**: プラグインは Chromium、CEF、Electron、または WebView エンジンを組み込むことはできません。プラグインは構造化データおよび宣言型 UI スキーマ（`views/*.json`）を提供し、0P が Qt Quick Material 3 コントロールを通じて描画を行います。
2. **サイドバー登録制限**: プラグインが登録できるサイドバー項目は最大 1 つです。登録項目は 0P ネイティブの `NavigationRail` および `NavCustomDialog` によって管理されます。
3. **グローバルフック**: プラグインは UI 項目を持たずにバックグラウンドフック（検索、メタデータ、歌詞）を登録できます。
4. **オーディオストリーム配信**: プラグインはオーディオ URL またはストリーム記述子を 0P 内部オーディオエンジンに渡し、再生を実行します。

---

## 2. パッケージ識別子とライフサイクル

すべてのプラグインは一意のリバース DNS 識別子（`id`）を宣言する必要があります。

### 2.1 識別子構文

* パターン: `^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$`
* 予約プレフィックス: `top.rincynar.*` は公式システムコンポーネント専用です。コミュニティ製プラグインは独自のドメインまたはプレフィックスを使用する必要があります。

### 2.2 バージョン調停

1. **セマンティックバージョニング (`semver`)**:
   * `新バージョン > 現バージョン`: インプレース更新。`PathManager::pluginDataDir(id)` 内の状態データは保持されます。
   * `新バージョン == 現バージョン`: 上書き確認が必要です。
   * `新バージョン < 現バージョン`: ダウングレードが明示的に指定されない限り拒絶されます。
2. **作成者一致確認**: 更新は一致する `author` フィールドから行われる必要があります。
3. **表示名競合**: 重複する表示名が存在する場合、インターフェースには `名称 (作成者)` と表示されます。

---

## 3. パッケージファイル構造 (`.0px`)

`.0px` ファイルは標準 ZIP アーカイブです。アーカイブ直下に `plugin.json` が存在する必要があります。

```
<plugin-id>.0px
├── plugin.json
├── assets/
│   └── icon.svg
├── views/
│   └── main.json
├── scripts/
│   └── main.js
└── locales/
    ├── en.json
    ├── ja.json
    └── zh-CN.json
```

---

## 4. マニフェスト仕様 (`plugin.json`)

```json
{
  "$schema": "https://raw.githubusercontent.com/RinCynar/0rhxPlayer-Plugins/main/schema/v1/plugin.schema.json",
  "id": "org.example.extension",
  "name": "Extension Template",
  "version": "1.0.0",
  "author": "Author",
  "description": "Standard extension definition template.",
  "category": "Tools",
  "homepage": "https://example.com",
  "minAppVersion": "1.2.0",
  "permissions": [
    "audio:control",
    "audio:state",
    "library:read",
    "library:write",
    "lyrics:read",
    "lyrics:write",
    "ui:slot:menu",
    "ui:slot:sidebar",
    "ui:slot:bottombar"
  ],
  "entries": {
    "sidebar": {
      "enabled": true,
      "title": "Extension",
      "icon": "assets/icon.svg",
      "schema": "views/main.json"
    },
    "contextMenu": {
      "track": {
        "enabled": true,
        "id": "track_action",
        "title": "Track Action",
        "icon": "assets/icon.svg"
      },
      "album": {
        "enabled": false,
        "id": "album_action",
        "title": "Album Action",
        "icon": "assets/icon.svg"
      },
      "playlist": {
        "enabled": false,
        "id": "playlist_action",
        "title": "Playlist Action",
        "icon": "assets/icon.svg"
      }
    },
    "playbackControl": {
      "enabled": false,
      "id": "player_action",
      "title": "Player Bar Action",
      "icon": "assets/icon.svg"
    }
  },
  "hooks": {
    "search": false,
    "mediaSource": false,
    "lyricsProvider": false
  }
}
```

### マニフェストフィールド定義表

| フィールドパス | 型 | 必須 | 説明 |
| --- | --- | --- | --- |
| `id` | `string` | 是 | リバース DNS パッケージ識別子（最長 64 文字）。 |
| `name` | `string` | 是 | マーケットおよび UI での表示名（最長 32 文字）。 |
| `version` | `string` | 是 | セマンティックバージョン文字列（`X.Y.Z`）。 |
| `author` | `string` | 是 | 作成者または組織名。 |
| `description` | `string` | 是 | 機能説明文。 |
| `category` | `string` | 是 | マーケット分類タグ。 |
| `homepage` | `string` | 否 | プロジェクトウェブサイト URL。 |
| `minAppVersion` | `string` | 是 | 最低対応 0P バージョン。 |
| `permissions` | `string[]` | 是 | 必要な権限宣言リスト。 |
| `entries.sidebar` | `object` | 否 | サイドバー登録スロット（1 プラグインにつき最大 1 つ）。 |
| `entries.sidebar.title` | `string` | 否 | NavigationRail に表示されるテキスト。 |
| `entries.sidebar.icon` | `string` | 否 | ベクターアイコンのパス。 |
| `entries.sidebar.schema` | `string` | 否 | ネイティブビュースキーマのパス。 |
| `entries.contextMenu.track` | `object` | 否 | 単曲コンテキストメニュー登録。 |
| `entries.contextMenu.album` | `object` | 否 | アルバムコンテキストメニュー登録。 |
| `entries.contextMenu.playlist` | `object` | 否 | プレイリストコンテキストメニュー登録。 |
| `entries.playbackControl` | `object` | 否 | 下部プレイヤーバーアクションボタン登録。 |
| `hooks.search` | `boolean` | 否 | グローバル検索バー照会フック。 |
| `hooks.mediaSource` | `boolean` | 否 | クラウドおよびリモート音源リゾルバー。 |
| `hooks.lyricsProvider` | `boolean` | 否 | オンライン歌詞プロバイダーフック。 |

---

## 5. ホストフックインターフェースとペイロード

ユーザーが注入項目を実行した際、ホストは `pluginActionTriggered(pluginId, actionId, slotType, payload)` を送出します：

### 5.1 コンテキストメニューペイロード

* **単曲対象 (`track`)**:
```json
{
  "type": "track",
  "data": {
    "filePath": "string",
    "title": "string",
    "artist": "string",
    "album": "string",
    "duration": 0,
    "sampleRate": 0,
    "channels": 0,
    "bitrate": 0,
    "format": "string"
  }
}
```

* **アルバム対象 (`album`)**:
```json
{
  "type": "album",
  "data": {
    "albumName": "string",
    "artist": "string",
    "trackCount": 0,
    "tracks": ["filePath1", "filePath2"]
  }
}
```

* **プレイリスト対象 (`playlist`)**:
```json
{
  "type": "playlist",
  "data": {
    "playlistId": "string",
    "title": "string",
    "trackCount": 0
  }
}
```

### 5.2 下部プレイヤーバーペイロード (`playbackControl`)

```json
{
  "type": "playbackControl",
  "data": {
    "currentTrack": "filePath",
    "isPlaying": true,
    "positionMs": 45000
  }
}
```

---

## 6. ホスト API リファレンス (C++ & QML 呼び出し可能関数)

ホストはシングルトン `PluginManager`（`rhx.plugin 1.0`）を通じてエンジン機能を提供します。

### 6.1 オーディオ再生とトランスポート制御

| メソッド | 引数 | 戻り値の型 | 説明 |
| --- | --- | --- | --- |
| `play` | `filePath: string` (省略可能) | `void` | 指定されたファイルパスまたは URL を再生します。空の場合は再生を再開します。 |
| `pause` | なし | `void` | 再生を一時停止します。 |
| `resume` | なし | `void` | 一時停止中の再生を再開します。 |
| `stop` | なし | `void` | 再生を停止し位置を 0 にリセットします。 |
| `seek` | `positionMs: int64` | `void` | 指定ミリ秒位置へシークします。 |
| `setVolume` | `volume: float` | `void` | マスター音量を設定します（`0.0` - `1.0` に制限）。 |
| `getVolume` | なし | `float` | 現在のマスター音量を返します（`0.0` - `1.0`）。 |
| `getPlaybackState` | なし | `int` | 現在の状態を返します: `0` = 停止, `1` = 再生中, `2` = 一時停止。 |
| `getPositionMs` | なし | `int64` | 現在の再生位置（ミリ秒）を返します。 |
| `getDurationMs` | なし | `int64` | 現在の楽曲の総再生時間（ミリ秒）を返します。 |
| `getCurrentTrack` | なし | `string` | 現在の楽曲ファイルパスまたは URL を返します。 |
| `getCurrentMetadata` | なし | `object` | 現在のメタデータマップ（タイトル、アーティスト、アルバム等）を返します。 |
| `getPlayMode` | なし | `int` | 再生モードを返します: `0` = 全曲リピート, `1` = 1曲リピート, `2` = シャッフル, `3` = 順次再生。 |
| `setPlayMode` | `mode: int` | `void` | 再生モードを設定します（`0` - `3`）。 |
| `playNext` | なし | `void` | キュー内の次の楽曲を再生します。 |
| `playPrevious` | なし | `void` | キュー内の前の楽曲を再生します。 |

### 6.2 イコライザーと DSP 制御

| メソッド | 引数 | 戻り値の型 | 説明 |
| --- | --- | --- | --- |
| `setEqEnabled` | `enabled: bool` | `void` | 10 バンドイコライザーの有効/無効を切り替えます。 |
| `isEqEnabled` | なし | `bool` | イコライザーが有効かどうかを返します。 |
| `setEqPreamp` | `preampDb: float` | `void` | プリアンプゲイン（dB）を設定します。 |
| `getEqPreamp` | なし | `float` | 現在のプリアンプゲイン（dB）を返します。 |
| `setEqBand` | `index: int`, `gainDb: float` | `void` | 指定バンド（`0` - `9`）のゲイン（dB）を設定します。 |
| `getEqBands` | なし | `float[]` | 10 バンドのゲインリスト（dB）を返します。 |
| `applyEqPreset` | `presetName: string` | `void` | プリセット（`Flat`, `Rock`, `Classical` 等）を適用します。 |
| `resetEq` | なし | `void` | すべてのバンドおよびプリアンプゲインを `0.0 dB` にリセットします。 |
| `getEqPreset` | なし | `string` | 現在適用されているプリセット名を返します。 |
| `getEqPresetNames` | なし | `string[]` | 利用可能なプリセット名リストを返します。 |

### 6.3 再生キュー

| メソッド | 引数 | 戻り値の型 | 説明 |
| --- | --- | --- | --- |
| `getQueue` | なし | `object[]` | 現在の再生キュー内の楽曲情報リストを返します。 |
| `getQueueCount` | なし | `int` | 再生キュー内の楽曲数を返します。 |
| `getCurrentQueueIndex` | なし | `int` | 再生中の楽曲のキューインデックスを返します。 |
| `playQueueIndex` | `index: int` | `void` | 指定インデックスの楽曲を再生します。 |
| `setQueue` | `trackPaths: string[]`, `startIndex: int` | `void` | キューを置き換え指定位置から再生を開始します。 |
| `addToQueue` | `filePath: string` | `void` | 楽曲をキューの末尾に追加します。 |
| `insertTracksNext` | `trackPaths: string[]` | `void` | 現在再生中の楽曲の直後に楽曲を挿入します。 |
| `clearQueue` | `keepCurrent: bool` | `void` | キューを消去します。keepCurrent が真の場合、現在の曲は保持されます。 |
| `removeFromQueue` | `index: int` | `void` | 指定インデックスの楽曲をキューから削除します。 |
| `moveQueueItem` | `from: int`, `to: int` | `void` | キュー内の楽曲順序を並べ替えます。 |
| `shuffleQueue` | なし | `void` | キュー内の楽曲をシャッフルします。 |

### 6.4 メディアライブラリと検索

| メソッド | 引数 | 戻り値の型 | 説明 |
| --- | --- | --- | --- |
| `getLibraryTrackCount` | なし | `int` | インデックス登録された楽曲総数を返します。 |
| `getAllTrackPaths` | なし | `string[]` | すべての登録楽曲のファイルパス一覧を返します。 |
| `getAllTracks` | `limit: int`, `offset: int` | `object[]` | ページ分割された楽曲詳細リストを返します。 |
| `getTrackDetails` | `filePath: string` | `object` | 指定ファイルパスの完全なメタデータを返します。 |
| `getAllAlbums` | なし | `object[]` | すべてのアルバム一覧を返します。 |
| `getAllArtists` | なし | `object[]` | すべてのアーティスト一覧を返します。 |
| `getAlbumTracks` | `albumName: string`, `artist: string` | `object[]` | 特定アルバムに属する楽曲リストを返します。 |
| `getArtistTracks` | `artistName: string` | `object[]` | 特定アーティストの楽曲リストを返します。 |
| `searchLibrary` | `keyword: string` | `object` | タイトル、アーティスト、アルバムを検索します。 |
| `rescanLibrary` | なし | `void` | 設定フォルダーのバックグラウンド再スキャンを実行します。 |
| `isScanningLibrary` | なし | `bool` | スキャナーが実行中かどうかを返します。 |

### 6.5 プレイリストとお気に入り

| メソッド | 引数 | 戻り値の型 | 説明 |
| --- | --- | --- | --- |
| `isFavorite` | `trackPath: string` | `bool` | 楽曲がお気に入りに登録されているかを返します。 |
| `toggleFavorite` | `trackPath: string` | `void` | 楽曲のお気に入り状態を切り替えます。 |
| `setFavorite` | `trackPath: string`, `favorite: bool` | `void` | 楽曲のお気に入り状態を明示的に設定します。 |
| `getFavoriteCount` | なし | `int` | お気に入り楽曲の総数を返します。 |
| `getFavoriteTracks` | なし | `string[]` | お気に入り楽曲のファイルパス一覧を返します。 |
| `getAllPlaylists` | なし | `object[]` | プレイリスト一覧（id、name、trackCount、coverUrl）を返します。 |
| `getPlaylistTracks` | `playlistId: string` | `object[]` | プレイリストに含まれる楽曲一覧を返します。 |
| `createPlaylist` | `name: string`, `trackPaths: string[]` | `string` | プレイリストを作成し一意の ID を返します。 |
| `deletePlaylist` | `playlistId: string` | `bool` | ID でプレイリストを削除します。 |
| `renamePlaylist` | `playlistId: string`, `newName: string` | `bool` | ID でプレイリスト名を変更します。 |
| `addTracksToPlaylist` | `playlistId: string`, `trackPaths: string[]` | `bool` | プレイリストに楽曲を追加します。 |
| `removeTracksFromPlaylist` | `playlistId: string`, `trackPaths: string[]` | `bool` | プレイリストから楽曲を削除します。 |
| `playPlaylist` | `playlistId: string`, `shuffle: bool` | `void` | プレイリストをキューに読み込み再生を開始します。 |

### 6.6 同期歌詞

| メソッド | 引数 | 戻り値の型 | 説明 |
| --- | --- | --- | --- |
| `hasLyrics` | なし | `bool` | 楽曲に歌詞が読み込まれているかを返します。 |
| `hasLyricTranslation` | なし | `bool` | 読み込まれた歌詞に翻訳行が含まれているかを返します。 |
| `getLyricCount` | なし | `int` | 同期歌詞の総行数を返します。 |
| `getCurrentLyricIndex` | なし | `int` | 現在ハイライトされている歌詞行のインデックスを返します。 |
| `getAllLyrics` | なし | `object[]` | 歌詞オブジェクト一覧（timeMs, text, translation）を返します。 |
| `getLyricLine` | `index: int` | `object` | 指定インデックスの歌詞行を返します。 |
| `loadLrcContent` | `lrcContent: string` | `bool` | 生の LRC 文字列を歌詞モデルに注入します。 |
| `clearLyrics` | なし | `void` | 読み込まれている歌詞を消去します。 |

### 6.7 アプリケーション環境と状態

| メソッド | 引数 | 戻り値の型 | 説明 |
| --- | --- | --- | --- |
| `getAppVersion` | なし | `string` | ホストアプリケーションのバージョン（例: `1.2.0`）を返します。 |
| `getAppLanguage` | なし | `string` | 現在有効な言語コード（`en`, `ja`, `zh_CN`）を返します。 |
| `getThemeMode` | なし | `string` | 現在のテーマモード（`light`, `dark`, `system`）を返します。 |
| `getSeedColor` | なし | `string` | 現在の Material 3 シードカラー（16進文字列）を返します。 |
| `getPluginDataDir` | `pluginId: string` | `string` | プラグイン専用のデータ保存先ディレクトリ絶対パスを返します。 |
| `isWindowActive` | なし | `bool` | アプリケーションウィンドウがアクティブかを返します。 |

### 6.8 ビュースロット注入とアクション

| メソッド | 引数 | 戻り値の型 | 説明 |
| --- | --- | --- | --- |
| `getInjectedMenuItems` | `slotType: string`, `contextData: object` | `object[]` | 対象スロット（`track`, `album`, `playlist`）の注入メニュー項目を返します。 |
| `getInjectedPlaybackControls` | なし | `object[]` | 下部プレイヤーバーの注入アクションボタンを返します。 |
| `triggerPluginAction` | `pluginId: string`, `actionId: string`, `slotType: string`, `payload: object` | `void` | 対象プラグインへアクション実行をディスパッチします。 |
| `executePluginHook` | `hookType: string`, `params: object` | `object` | 登録されたフック（`search` 等）を実行します。 |

---

## 7. イベントバスとライフサイクルシグナル

プラグインや画面は `PluginManager` のシグナルを購読して状態を監視できます：

| シグナル定義 | 引数 | 説明 |
| --- | --- | --- |
| `playbackStateChanged` | `state: int` | 再生状態変化時に送出（`0` = 停止, `1` = 再生中, `2` = 一時停止）。 |
| `positionChanged` | `positionMs: int64`, `durationMs: int64` | 再生位置進行時に送出。 |
| `trackChanged` | `trackInfo: object` | 再生楽曲切り替えまたはメタデータ更新時に送出。 |
| `volumeChanged` | `volume: float` | マスター音量変更時に送出（`0.0` - `1.0`）。 |
| `playModeChanged` | `mode: int` | 再生モード変更時に送出（`0` - `3`）。 |
| `eqChanged` | なし | イコライザー設定変更時に送出。 |
| `queueChanged` | なし | キューの内容または順序変更時に送出。 |
| `libraryChanged` | なし | ローカルライブラリの楽曲追加・変更・削除時に送出。 |
| `favoritesChanged` | `trackPath: string`, `isFavorite: bool` | 楽曲のお気に入り状態変化時に送出。 |
| `playlistsChanged` | なし | プレイリスト作成・更新・削除時に送出。 |
| `lyricsChanged` | なし | 歌詞データ更新時に送出。 |
| `windowActiveChanged` | `active: bool` | ウィンドウのフォーカス状態変化時に送出。 |
| `pluginActionTriggered` | `pluginId: string`, `actionId: string`, `slotType: string`, `data: object` | ユーザーが注入メニューまたはボタンをクリックした際に送出。 |

---

## 8. ビュースキーマとネイティブコンテナ構造

プラグインは宣言型 JSON スキーマ（`views/*.json`）で UI を定義します。描画はすべてホストのネイティブ QML コンポーネントが担当します：

```json
{
  "type": "page",
  "title": "Extension Workbench",
  "sections": [
    {
      "type": "banner",
      "title": "Workbench Header",
      "subtitle": "Declarative native container"
    },
    {
      "type": "card",
      "title": "Status Card",
      "details": "Rendered via Material 3 surfaceContainerHighest"
    },
    {
      "type": "list",
      "title": "Item Feed",
      "items": [
        {
          "title": "Item 1",
          "subtitle": "Subtitle description",
          "action": "onItemClick"
        }
      ]
    }
  ]
}
```

---

## 9. セキュリティと権限宣言

プラグインは `plugin.json` で必要な権限を明示的に要求する必要があります：

| 権限識別子 | 説明 | ガード対象機能 |
| --- | --- | --- |
| `audio:control` | トランスポート制御権限 | `play`, `pause`, `resume`, `stop`, `seek`, `setVolume`, `setPlayMode`, EQ |
| `audio:state` | オーディオエンジン状態照会 | `getPlaybackState`, `getPositionMs`, `getDurationMs`, `getCurrentMetadata` |
| `library:read` | メディアライブラリ読み取り照会 | `getAllTracks`, `getAllAlbums`, `getAllArtists`, `searchLibrary` |
| `library:write` | ライブラリ変更権限 | `createPlaylist`, `deletePlaylist`, `addTracksToPlaylist`, `setFavorite` |
| `lyrics:read` | 同期歌詞読み取り | `hasLyrics`, `getLyricCount`, `getAllLyrics`, `getLyricLine` |
| `lyrics:write` | 同期歌詞注入 | `loadLrcContent`, `clearLyrics` |
| `ui:slot:menu` | コンテキストメニュー注入 | `entries.contextMenu.track`, `entries.contextMenu.album`, `entries.contextMenu.playlist` |
| `ui:slot:sidebar` | サイドバー登録スロット | `entries.sidebar` |
| `ui:slot:bottombar` | 下部プレイヤーバーアクション | `entries.playbackControl` |
| `network:fetch` | 外部ネットワーク通信 | `QNetworkAccessManager` による HTTP/HTTPS 通信 |

---

# 简体中文规范手册

## 1. 架构模型

0rhxPlayer（**0P**）基于 C++20 与 Qt 6（QML）构建。插件系统遵循以下约束：

1. **宿主原生渲染**：插件严禁嵌入 Chromium、CEF、Electron 或任何 WebView 引擎。插件向宿主提供结构化数据与声明式 UI Schema（`views/*.json`），所有的视图均由 0P 原生 Qt Quick Material 3 控件负责呈现。
2. **侧边栏槽位限额**：每个插件最多只允许注册 1 个侧边栏入口。侧边栏入口直接接入 0P 原生的 `NavigationRail` 与 `NavCustomDialog` 统一调度管理。
3. **全局钩子**：无界面的后台型插件可注册全局搜索、元数据刮削、歌词解析等后台钩子，无需创建任何 UI 入口。
4. **音频流直通**：插件解析到的音频流或 URL 直接交由 0P 内部音频引擎播放。

---

## 2. 包标识与生命周期

每个插件必须声明全局唯一的反向域名标识符（`id`）。

### 2.1 标识符语法规则

* 正则规则：`^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$`
* 保留前缀：`top.rincynar.*` 严格作为官方保留命名空间，第三方社区插件必须使用自身的反向域名或独立前缀。

### 2.2 版本仲裁

1. **语义化版本 (`semver`)**：
   * `新版本 > 当前版本`：就地覆盖升级，`PathManager::pluginDataDir(id)` 目录下的独立数据予以保留。
   * `新版本 == 当前版本`：提示用户确认是否覆盖安装。
   * `新版本 < 当前版本`：默认拒绝，除非显式指定降级参数。
2. **作者签名校验**：同 ID 插件的升级必须来自相同的 `author`。
3. **同名冲突处理**：当不同插件显示名称重名时，界面呈现为 `名称 (作者)`。

---

## 3. 插件包物理结构 (`.0px`)

`.0px` 包为标准 ZIP 归档。根目录下必须包含 `plugin.json`。

```
<plugin-id>.0px
├── plugin.json
├── assets/
│   └── icon.svg
├── views/
│   └── main.json
├── scripts/
│   └── main.js
└── locales/
    ├── en.json
    ├── ja.json
    └── zh-CN.json
```

---

## 4. 清单规范 (`plugin.json`)

```json
{
  "$schema": "https://raw.githubusercontent.com/RinCynar/0rhxPlayer-Plugins/main/schema/v1/plugin.schema.json",
  "id": "org.example.extension",
  "name": "Extension Template",
  "version": "1.0.0",
  "author": "Author",
  "description": "Standard extension definition template.",
  "category": "Tools",
  "homepage": "https://example.com",
  "minAppVersion": "1.2.0",
  "permissions": [
    "audio:control",
    "audio:state",
    "library:read",
    "library:write",
    "lyrics:read",
    "lyrics:write",
    "ui:slot:menu",
    "ui:slot:sidebar",
    "ui:slot:bottombar"
  ],
  "entries": {
    "sidebar": {
      "enabled": true,
      "title": "Extension",
      "icon": "assets/icon.svg",
      "schema": "views/main.json"
    },
    "contextMenu": {
      "track": {
        "enabled": true,
        "id": "track_action",
        "title": "Track Action",
        "icon": "assets/icon.svg"
      },
      "album": {
        "enabled": false,
        "id": "album_action",
        "title": "Album Action",
        "icon": "assets/icon.svg"
      },
      "playlist": {
        "enabled": false,
        "id": "playlist_action",
        "title": "Playlist Action",
        "icon": "assets/icon.svg"
      }
    },
    "playbackControl": {
      "enabled": false,
      "id": "player_action",
      "title": "Player Bar Action",
      "icon": "assets/icon.svg"
    }
  },
  "hooks": {
    "search": false,
    "mediaSource": false,
    "lyricsProvider": false
  }
}
```

### 清单字段定义表

| 字段路径 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `id` | `string` | 是 | 反向域名包名（最长 64 字符）。 |
| `name` | `string` | 是 | 界面与市场中的显示名称（最长 32 字符）。 |
| `version` | `string` | 是 | 语义化版本号（`X.Y.Z`）。 |
| `author` | `string` | 是 | 作者或组织名称。 |
| `description` | `string` | 是 | 功能描述文本。 |
| `category` | `string` | 是 | 市场分类标签。 |
| `homepage` | `string` | 否 | 项目主页网址。 |
| `minAppVersion` | `string` | 是 | 最低兼容 0P 版本号。 |
| `permissions` | `string[]` | 是 | 执行所需的权限声明列表。 |
| `entries.sidebar` | `object` | 否 | 侧边栏槽位定义（单个插件上限 1 个）。 |
| `entries.sidebar.title` | `string` | 否 | 在 NavigationRail 中展示的文本。 |
| `entries.sidebar.icon` | `string` | 否 | 矢量图标文件路径。 |
| `entries.sidebar.schema` | `string` | 否 | 原生视图结构文件路径。 |
| `entries.contextMenu.track` | `object` | 否 | 单曲右键菜单注入定义。 |
| `entries.contextMenu.album` | `object` | 否 | 专辑右键菜单注入定义。 |
| `entries.contextMenu.playlist` | `object` | 否 | 歌单右键菜单注入定义。 |
| `entries.playbackControl` | `object` | 否 | 底部播放控制栏按钮注入定义。 |
| `hooks.search` | `boolean` | 否 | 全局搜索栏拦截钩子。 |
| `hooks.mediaSource` | `boolean` | 否 | 远端流媒体解析钩子。 |
| `hooks.lyricsProvider` | `boolean` | 否 | 在线歌词抓取钩子。 |

---

## 5. 宿主钩子调用接口与动作载荷

当用户在界面触发对应入口时，宿主分发 `pluginActionTriggered(pluginId, actionId, slotType, payload)`：

### 5.1 右键菜单上下文载荷

* **单曲项 (`track`)**:
```json
{
  "type": "track",
  "data": {
    "filePath": "string",
    "title": "string",
    "artist": "string",
    "album": "string",
    "duration": 0,
    "sampleRate": 0,
    "channels": 0,
    "bitrate": 0,
    "format": "string"
  }
}
```

* **专辑项 (`album`)**:
```json
{
  "type": "album",
  "data": {
    "albumName": "string",
    "artist": "string",
    "trackCount": 0,
    "tracks": ["filePath1", "filePath2"]
  }
}
```

* **歌单项 (`playlist`)**:
```json
{
  "type": "playlist",
  "data": {
    "playlistId": "string",
    "title": "string",
    "trackCount": 0
  }
}
```

### 5.2 底部控制栏动作载荷 (`playbackControl`)

```json
{
  "type": "playbackControl",
  "data": {
    "currentTrack": "filePath",
    "isPlaying": true,
    "positionMs": 45000
  }
}
```

---

## 6. 宿主 API 参考清单 (C++ 与 QML 可调用函数)

宿主通过单例 `PluginManager`（`rhx.plugin 1.0`）暴露播放器核心操作。

### 6.1 音频控制与播放状态

| 方法名 | 参数 | 返回值类型 | 功能说明 |
| --- | --- | --- | --- |
| `play` | `filePath: string` (可选) | `void` | 播放指定的本地音频文件或远端流。若为空则恢复当前播放。 |
| `pause` | 无 | `void` | 暂停当前播放。 |
| `resume` | 无 | `void` | 恢复暂停中的播放。 |
| `stop` | 无 | `void` | 停止播放并重置进度为 0。 |
| `seek` | `positionMs: int64` | `void` | 跨度跳转至指定的毫秒进度位置。 |
| `setVolume` | `volume: float` | `void` | 设置主音量（限制在 `0.0` 至 `1.0` 之间）。 |
| `getVolume` | 无 | `float` | 获取当前主音量（`0.0` 至 `1.0`）。 |
| `getPlaybackState` | 无 | `int` | 获取当前播放状态：`0` = 停止, `1` = 播放中, `2` = 已暂停。 |
| `getPositionMs` | 无 | `int64` | 获取当前音频已播放的毫秒数。 |
| `getDurationMs` | 无 | `int64` | 获取当前音频的总长度毫秒数。 |
| `getCurrentTrack` | 无 | `string` | 获取当前播放曲目的本地路径或 URL。 |
| `getCurrentMetadata` | 无 | `object` | 获取当前曲目完整的元数据映射表（标题、艺术家、专辑、比特率等）。 |
| `getPlayMode` | 无 | `int` | 获取当前播放模式：`0` = 全部循环, `1` = 单曲循环, `2` = 随机, `3` = 顺序播放。 |
| `setPlayMode` | `mode: int` | `void` | 设定播放模式（`0` 至 `3`）。 |
| `playNext` | 无 | `void` | 跳至队列中的下一首。 |
| `playPrevious` | 无 | `void` | 跳至队列中的上一首。 |

### 6.2 均衡器与 DSP 控制

| 方法名 | 参数 | 返回值类型 | 功能说明 |
| --- | --- | --- | --- |
| `setEqEnabled` | `enabled: bool` | `void` | 开启或关闭 10 段硬件级均衡器。 |
| `isEqEnabled` | 无 | `bool` | 查询均衡器当前是否处于开启状态。 |
| `setEqPreamp` | `preampDb: float` | `void` | 设定均衡器前置放大增益（分贝 dB）。 |
| `getEqPreamp` | 无 | `float` | 获取当前均衡器前置放大增益（分贝 dB）。 |
| `setEqBand` | `index: int`, `gainDb: float` | `void` | 调节指定频段（`0` 至 `9`）的增益（分贝 dB）。 |
| `getEqBands` | 无 | `float[]` | 获取 10 个频段当前的增益分贝列表。 |
| `applyEqPreset` | `presetName: string` | `void` | 应用指定名称的预设（如 `Flat`, `Rock`, `Classical`）。 |
| `resetEq` | 无 | `void` | 重置所有频段与前置放大增益为 `0.0 dB`。 |
| `getEqPreset` | 无 | `string` | 获取当前所激活的预设名称。 |
| `getEqPresetNames` | 无 | `string[]` | 获取所有内置预设名称列表。 |

### 6.3 播放队列管理

| 方法名 | 参数 | 返回值类型 | 功能说明 |
| --- | --- | --- | --- |
| `getQueue` | 无 | `object[]` | 获取当前播放队列的曲目详情映射数组。 |
| `getQueueCount` | 无 | `int` | 获取当前队列中的曲目总数。 |
| `getCurrentQueueIndex` | 无 | `int` | 获取当前正在播放曲目的队列索引（从 0 开始）。 |
| `playQueueIndex` | `index: int` | `void` | 直接跳转播放指定队列索引位置的曲目。 |
| `setQueue` | `trackPaths: string[]`, `startIndex: int` | `void` | 用新曲目列表全量覆盖当前队列，并从 startIndex 开始播放。 |
| `addToQueue` | `filePath: string` | `void` | 将单首曲目追加至队列末尾。 |
| `insertTracksNext` | `trackPaths: string[]` | `void` | 将曲目列表插入至当前正在播放的曲目之后（下一首播放）。 |
| `clearQueue` | `keepCurrent: bool` | `void` | 清空播放队列。若 keepCurrent 为真，则保留当前曲目。 |
| `removeFromQueue` | `index: int` | `void` | 从队列中移除指定索引位置的曲目。 |
| `moveQueueItem` | `from: int`, `to: int` | `void` | 调整队列内特定曲目的顺序位置。 |
| `shuffleQueue` | 无 | `void` | 随机打乱当前队列中的所有曲目。 |

### 6.4 曲库检索与扫描

| 方法名 | 参数 | 返回值类型 | 功能说明 |
| --- | --- | --- | --- |
| `getLibraryTrackCount` | 无 | `int` | 获取本地曲库已收录的曲目总数。 |
| `getAllTrackPaths` | 无 | `string[]` | 获取本地曲库所有曲目的文件绝对路径列表。 |
| `getAllTracks` | `limit: int`, `offset: int` | `object[]` | 分页获取曲库内的曲目元数据数组。 |
| `getTrackDetails` | `filePath: string` | `object` | 获取指定曲目路径的详细属性映射表。 |
| `getAllAlbums` | 无 | `object[]` | 获取所有已分类专辑列表。 |
| `getAllArtists` | 无 | `object[]` | 获取所有已分类歌手列表。 |
| `getAlbumTracks` | `albumName: string`, `artist: string` | `object[]` | 检索指定专辑内的所有曲目列表。 |
| `getArtistTracks` | `artistName: string` | `object[]` | 检索指定歌手演唱的所有曲目列表。 |
| `searchLibrary` | `keyword: string` | `object` | 跨标题、艺术家与专辑字段执行本地曲库全文检索。 |
| `rescanLibrary` | 无 | `void` | 触发后台扫描线程对全部已配置目录进行增量扫描。 |
| `isScanningLibrary` | 无 | `bool` | 查询曲库扫描引擎是否正在运行。 |

### 6.5 歌单与用户收藏

| 方法名 | 参数 | 返回值类型 | 功能说明 |
| --- | --- | --- | --- |
| `isFavorite` | `trackPath: string` | `bool` | 查询指定曲目是否处于收藏状态。 |
| `toggleFavorite` | `trackPath: string` | `void` | 切换指定曲目的收藏状态。 |
| `setFavorite` | `trackPath: string`, `favorite: bool` | `void` | 显式设定指定曲目的收藏状态。 |
| `getFavoriteCount` | 无 | `int` | 获取所有已收藏曲目的总数。 |
| `getFavoriteTracks` | 无 | `string[]` | 获取全部收藏曲目的路径列表。 |
| `getAllPlaylists` | 无 | `object[]` | 获取全部歌单对象数组（id, name, trackCount, coverUrl）。 |
| `getPlaylistTracks` | `playlistId: string` | `object[]` | 获取指定歌单内的所有曲目详情数组。 |
| `createPlaylist` | `name: string`, `trackPaths: string[]` | `string` | 创建新歌单并返回生成的唯一歌单标识符。 |
| `deletePlaylist` | `playlistId: string` | `bool` | 根据标识符彻底删除歌单。 |
| `renamePlaylist` | `playlistId: string`, `newName: string` | `bool` | 根据标识符重命名歌单。 |
| `addTracksToPlaylist` | `playlistId: string`, `trackPaths: string[]` | `bool` | 向指定歌单批量添加曲目。 |
| `removeTracksFromPlaylist` | `playlistId: string`, `trackPaths: string[]` | `bool` | 从指定歌单批量移除曲目。 |
| `playPlaylist` | `playlistId: string`, `shuffle: bool` | `void` | 将指定歌单载入队列并开始播放。 |

### 6.6 歌词数据与注入

| 方法名 | 参数 | 返回值类型 | 功能说明 |
| --- | --- | --- | --- |
| `hasLyrics` | 无 | `bool` | 查询当前曲目是否已加载歌词。 |
| `hasLyricTranslation` | 无 | `bool` | 查询当前歌词是否包含翻译文本。 |
| `getLyricCount` | 无 | `int` | 获取同步歌词的总行数。 |
| `getCurrentLyricIndex` | 无 | `int` | 获取当前正在高亮唱出的歌词行索引。 |
| `getAllLyrics` | 无 | `object[]` | 获取所有歌词行对象数组（timeMs, text, translation）。 |
| `getLyricLine` | `index: int` | `object` | 获取指定行索引的歌词数据对象。 |
| `loadLrcContent` | `lrcContent: string` | `bool` | 向播放器歌词引擎动态注入原生 LRC 文本内容。 |
| `clearLyrics` | 无 | `void` | 清空当前正在展示的所有歌词内容。 |

### 6.7 应用程序环境与配置

| 方法名 | 参数 | 返回值类型 | 功能说明 |
| --- | --- | --- | --- |
| `getAppVersion` | 无 | `string` | 获取宿主播放器版本号（如 `1.2.0`）。 |
| `getAppLanguage` | 无 | `string` | 获取当前生效的语言代码（`en`, `ja`, `zh_CN`）。 |
| `getThemeMode` | 无 | `string` | 获取当前色彩模式（`light`, `dark`, `system`）。 |
| `getSeedColor` | 无 | `string` | 获取当前 Material 3 主题种子色（十六进制字符串）。 |
| `getPluginDataDir` | `pluginId: string` | `string` | 获取为该插件专门开辟的隔离存储绝对路径。 |
| `isWindowActive` | 无 | `bool` | 查询播放器主窗口是否处于系统焦点激活状态。 |

### 6.8 视图插槽注入与动作分发

| 方法名 | 参数 | 返回值类型 | 功能说明 |
| --- | --- | --- | --- |
| `getInjectedMenuItems` | `slotType: string`, `contextData: object` | `object[]` | 获取指定插槽（`track`, `album`, `playlist`）已注入的所有插件菜单项。 |
| `getInjectedPlaybackControls` | 无 | `object[]` | 获取底部控制栏已注入的全部扩展功能按钮。 |
| `triggerPluginAction` | `pluginId: string`, `actionId: string`, `slotType: string`, `payload: object` | `void` | 向指定插件派发用户动作执行指令。 |
| `executePluginHook` | `hookType: string`, `params: object` | `object` | 执行已注册的宿主钩子（如 `search`）。 |

---

## 7. 全生命周期事件总线信号

插件和前端视图可直接通过监听 `PluginManager` 的 Qt 信号来响应各种生命周期变动：

| 信号定义 | 参数列表 | 触发时机与说明 |
| --- | --- | --- |
| `playbackStateChanged` | `state: int` | 播放状态切换时触发（`0` = 停止, `1` = 播放中, `2` = 暂停）。 |
| `positionChanged` | `positionMs: int64`, `durationMs: int64` | 播放进度推进时触发。 |
| `trackChanged` | `trackInfo: object` | 切歌或当前曲目元数据更新时触发。 |
| `volumeChanged` | `volume: float` | 主音量数值发生改变时触发（`0.0` 至 `1.0`）。 |
| `playModeChanged` | `mode: int` | 循环模式改变时触发（`0` 至 `3`）。 |
| `eqChanged` | 无 | 均衡器频段、开关、前置放大或预设变更时触发。 |
| `queueChanged` | 无 | 播放队列内容或顺序发生变动时触发。 |
| `libraryChanged` | 无 | 本地曲库有歌曲添加、删除或变动时触发。 |
| `favoritesChanged` | `trackPath: string`, `isFavorite: bool` | 曲目收藏状态变动时触发。 |
| `playlistsChanged` | 无 | 用户歌单创建、更名或内容变动时触发。 |
| `lyricsChanged` | 无 | 歌词内容被动态替换或更新时触发。 |
| `windowActiveChanged` | `active: bool` | 播放器窗口焦点激活或移入后台时触发。 |
| `pluginActionTriggered` | `pluginId: string`, `actionId: string`, `slotType: string`, `data: object` | 用户点击了注入的右键菜单或控制栏按钮时触发。 |

---

## 8. 声明式视图 Schema 与原生 Material 3 容器

插件界面的排版采用原生声明式 JSON（`views/*.json`），杜绝任何 DOM 树或外部脚本渲染，100% 由 0P 原生 QML 控件绘制呈现：

```json
{
  "type": "page",
  "title": "Extension Workbench",
  "sections": [
    {
      "type": "banner",
      "title": "Workbench Header",
      "subtitle": "Declarative native container"
    },
    {
      "type": "card",
      "title": "Status Card",
      "details": "Rendered via Material 3 surfaceContainerHighest"
    },
    {
      "type": "list",
      "title": "Item Feed",
      "items": [
        {
          "title": "Item 1",
          "subtitle": "Subtitle description",
          "action": "onItemClick"
        }
      ]
    }
  ]
}
```

---

## 9. 权限声明体系与安全管控

插件在 `plugin.json` 中必须显式声明所需的权限标识符：

| 权限标识符 | 权限描述 | 所管辖的接口与动作 |
| --- | --- | --- |
| `audio:control` | 音频传输控制权限 | `play`, `pause`, `resume`, `stop`, `seek`, `setVolume`, `setPlayMode`, EQ 调节 |
| `audio:state` | 音频状态查询权限 | `getPlaybackState`, `getPositionMs`, `getDurationMs`, `getCurrentMetadata` |
| `library:read` | 曲库元数据检索权限 | `getAllTracks`, `getAllAlbums`, `getAllArtists`, `searchLibrary` |
| `library:write` | 歌单与曲库写入权限 | `createPlaylist`, `deletePlaylist`, `addTracksToPlaylist`, `setFavorite` |
| `lyrics:read` | 歌词数据读取权限 | `hasLyrics`, `getLyricCount`, `getAllLyrics`, `getLyricLine` |
| `lyrics:write` | 歌词数据注入权限 | `loadLrcContent`, `clearLyrics` |
| `ui:slot:menu` | 右键上下文菜单注入权限 | `entries.contextMenu.track`, `entries.contextMenu.album`, `entries.contextMenu.playlist` |
| `ui:slot:sidebar` | 侧边栏独立槽位申请权限 | `entries.sidebar` |
| `ui:slot:bottombar` | 底部播放栏控制按钮注入 | `entries.playbackControl` |
| `network:fetch` | 外部网络请求权限 | `QNetworkAccessManager` 发起 HTTP/HTTPS 网络拉取与解析 |
