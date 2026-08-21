# 0rhxPlayer Desktop - 系统架构设计与协议契约规范 (Architecture & IPC Contract)

## 1. 架构总览 (Architecture Overview)

0rhxPlayer Desktop 采用 **Tauri 2.x** 架构，将高性能原生 Rust 后端与现代响应式 Webview 前端（React 19 + TypeScript + Tailwind CSS + Material 3 Tokens）深度解耦结合：

```
+-----------------------------------------------------------------------+
|                         Frontend (Webview2)                           |
|  +---------------------+  +----------------------------------------+  |
|  |  Navigation Rail    |  |  Main Content Workspace                |  |
|  |  - Home / Library   |  |  - Daily Mix / Featured / Playlists    |  |
|  |  - Search / Queue   |  |  - Filter Chips / Track Grid & Lists   |  |
|  +---------------------+  +----------------------------------------+  |
|  +-----------------------------------------------------------------+  |
|  |  Material You Color Engine (@material/material-color-utilities) |  |
|  +-----------------------------------------------------------------+  |
|  |  Global Bottom Player Bar (Progress Seek, Transport, Volume)   |  |
|  +-----------------------------------------------------------------+  |
+-----------------------------------^-----------------------------------+
                                    | Tauri IPC (Commands & Events)
+-----------------------------------v-----------------------------------+
|                        Rust Core (src-tauri)                          |
|  +------------------------+ +------------------+ +------------------+ |
|  | Audio Engine           | | Metadata Parser  | | Local Database   | |
|  | - cpal (Audio Stream)  | | - lofty          | | - SQLite (WAL)   | |
|  | - symphonia (Decoders) | | - Cover Artwork  | | - Fast Indexer   | |
|  | - Lockless RingBuffer  | | - Tag Extraction | | - Playlist Mgmt  | |
|  +------------------------+ +------------------+ +------------------+ |
+-----------------------------------------------------------------------+
```

---

## 2. 前端设计与 UI 布局分层 (UI Layout & Material 3)

基于 `/Design` 目录下的 5 组设计稿（Home, Library, Playlist, Search, Settings），前端划分为以下视觉与交互层次：

### 2.1 整体容器与窗口材质
- **窗口基底**：Windows 11 Mica / Acrylic 亚克力半透明材质与无边框原生控制（关闭、最小化、最大化）。
- **主题与调色板**：Material You 动态调色系统。封面图加载后通过 `@material/material-color-utilities` 实时提取 Key Color，动态映射为 `--md-sys-color-primary`, `--md-sys-color-surface-container`, `--md-sys-color-on-surface` 等 CSS 变量。支持浅色（Light）与深色（Dark）模式无缝切换。

### 2.2 导航侧边栏 (Navigation Rail)
- **顶部操作区**：Menu 汉堡按钮 + Material 3 圆角 FAB 浮动动作按钮（快速导入/新建播放列表）。
- **导航项集合**：
  - **Home (主页)**：`Daily Mix` 水平滚动推荐圈、`Section title` 宽卡片（内嵌右下角快捷播放按钮）。
  - **Library (曲库)**：分类 Filter Chips（`Titles` / `Artists` / `Albums` / `Folders`）+ 网格化专辑/曲目卡片。
  - **Search (搜索)**：顶部圆角搜索药丸栏 + 推荐与分类探索 + 结果列表。
  - **Playlist (播放列表与正在播放)**：顶部巨幅 Header Banner（当前播放曲目沉浸渐变背景）、`Played / Nexts` 分段器（Segmented Switch）、带星级/红心的曲目列表。
  - **Settings (设置)**：音频设备切换、解码选项、曲库扫描路径管理、主题模式等。

### 2.3 底部全局播放控制栏 (Global Bottom Player Bar)
- **顶部贴边进度条 (Seek Line)**：细长线性进度条，悬停高亮，支持平滑拖拽寻道（Seeking）。
- **左侧曲目信息**：缩略封面图、曲目标题、艺术家名称。
- **右侧控制按键**：随机播放（Shuffle）、上一曲（Previous）、播放/暂停（Play/Pause）、下一曲（Next）、音量调节与静音。

---

## 3. Rust 原生核心模块划分 (Rust Core Architecture)

### 3.1 `audio` 核心音频引擎
- **`cpal` Output Pipeline**：建立低延迟原生音频输出流（Windows WASAPI Shared / Linux ALSA or PulseAudio），采样率支持自适应重采样或原采样率输出。
- **`symphonia` Decoding**：支持 MP3, FLAC, WAV, AAC, M4A, OGG Vorbis 等高规格无损与有损格式。
- **并发与时间同步模型**：
  - 音频解码在专用音频流线程执行，避免阻塞 UI。
  - 使用原子变量（`AtomicU64`, `AtomicBool`, `AtomicU32`）与线程安全的锁结构（`Arc<Mutex<PlaybackState>>`）进行纳秒级精确时间戳同步。
  - 寻道（Seek）时执行毫秒级平滑过渡，防止爆音（Click/Pop reduction）。

### 3.2 `metadata` 元数据与封面解析
- 使用 `lofty` 库提取曲目 ID3v1/v2, FLAC Vorbis Comments, APE 标签。
- 提取并压缩嵌入式封面图片，以高效格式（Base64 或二进制流）传回前端，同时作为 Material You 的动态色源。

### 3.3 `db` 本地曲库与配置持久化
- 使用 SQLite (WAL 模式) 存储本地曲库索引、播放列表、历史记录与用户偏好。

---

## 4. 强类型 IPC 协议契约 (IPC Contract Definition)

前端与 Rust 后端通过 Tauri 2.0 Command 系统进行强类型交互，数据结构与命令签名如下：

### 4.1 数据模型 (Data Transfer Objects)

```typescript
// 播放状态枚举
export type PlaybackStatus = 'stopped' | 'playing' | 'paused' | 'buffering';

// 音频元数据 DTO
export interface TrackMetadata {
  id?: string;
  path: string;
  title: string;
  artist: string;
  album: string;
  durationMs: number;
  trackNumber?: number;
  discNumber?: number;
  year?: number;
  genre?: string;
  sampleRate?: number;
  channels?: number;
  bitrate?: number;
  format?: string;
  coverBase64?: string; // data:image/jpeg;base64,...
}

// 实时播放状态 DTO
export interface PlaybackState {
  status: PlaybackStatus;
  currentTrack: TrackMetadata | null;
  positionMs: number;
  durationMs: number;
  volume: number; // 0.0 ~ 1.0
  isMuted: boolean;
  shuffle: boolean;
  repeatMode: 'off' | 'one' | 'all';
}
```

```rust
// Rust 对应结构体
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum PlaybackStatus {
    #[serde(rename = "stopped")]
    Stopped,
    #[serde(rename = "playing")]
    Playing,
    #[serde(rename = "paused")]
    Paused,
    #[serde(rename = "buffering")]
    Buffering,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TrackMetadata {
    pub id: Option<String>,
    pub path: String,
    pub title: String,
    pub artist: String,
    pub album: String,
    pub duration_ms: u64,
    pub track_number: Option<u32>,
    pub disc_number: Option<u32>,
    pub year: Option<u32>,
    pub genre: Option<String>,
    pub sample_rate: Option<u32>,
    pub channels: Option<u16>,
    pub bitrate: Option<u32>,
    pub format: Option<String>,
    pub cover_base64: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PlaybackState {
    pub status: PlaybackStatus,
    pub current_track: Option<TrackMetadata>,
    pub position_ms: u64,
    pub duration_ms: u64,
    pub volume: f32,
    pub is_muted: bool,
    pub shuffle: bool,
    pub repeat_mode: String,
}
```

### 4.2 IPC Commands 契约

| 命令名称 | 参数类型 | 返回值类型 | 说明 |
| :--- | :--- | :--- | :--- |
| `load_track` | `{ path: string }` | `Promise<TrackMetadata>` | 加载指定路径音频并解析其元数据与音频流 |
| `play` | - | `Promise<void>` | 开始/恢复播放 |
| `pause` | - | `Promise<void>` | 暂停播放 |
| `stop` | - | `Promise<void>` | 停止播放并重置游标 |
| `seek` | `{ positionMs: number }` | `Promise<void>` | 精准跳转至指定毫秒位置 |
| `set_volume` | `{ volume: number }` | `Promise<void>` | 设置音量 (0.0 ~ 1.0) |
| `get_playback_state`| - | `Promise<PlaybackState>`| 获取当前播放器快照状态 |
| `open_file_dialog` | - | `Promise<string \| null>` | 唤起系统原生文件选择对话框（支持 mp3, flac, wav 等） |
| `read_track_metadata`| `{ path: string }`| `Promise<TrackMetadata>` | 解析文件标签元数据与内嵌封面 |

### 4.3 IPC Events 事件流 (Push Notifications)

- `playback-position-update` -> `{ positionMs: number, durationMs: number }` (定时回传实时高精度时间戳)
- `playback-state-changed` -> `PlaybackState` (播放状态突变通知：切换曲目、自然播放结束、暂停等)
