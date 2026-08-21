<div align="center">

# 🎵 0rhxPlayer Desktop

### 无损本地音乐播放器
**Lossless Music Player for Desktop**

[![Release](https://img.shields.io/github/v/release/RinCynar/0rhxPlayer-Desktop?style=flat-square&color=39C5BB)](https://github.com/RinCynar/0rhxPlayer-Desktop/releases/latest)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux-006A6B?style=flat-square)](https://0rhxPlayer.rincynar.top)
[![Tauri](https://img.shields.io/badge/Tauri-v2-FFC131?style=flat-square&logo=tauri&logoColor=white)](https://tauri.app/)
[![Rust](https://img.shields.io/badge/Rust-1.75%2B-DEA584?style=flat-square&logo=rust&logoColor=white)](https://www.rust-lang.org/)
[![React](https://img.shields.io/badge/React-19-61DAFB?style=flat-square&logo=react&logoColor=black)](https://react.dev/)
[![Material 3](https://img.shields.io/badge/Design-Material%20You%203.0-39C5BB?style=flat-square)](https://m3.material.io/)
[![License](https://img.shields.io/github/license/RinCynar/0rhxPlayer-Desktop?style=flat-square&color=blue)](LICENSE)

[🌐 官方主页与在线文档 (Official Website)](https://0rhxPlayer.rincynar.top) • [📦 立即下载 (Releases)](https://github.com/RinCynar/0rhxPlayer-Desktop/releases/latest) • [🧩 VSCode 插件版](https://github.com/RinCynar/0rhxPlayer)

</div>

---

## 📖 项目简介 (Introduction)

**0rhxPlayer Desktop** 是一款现代化桌面本地音乐播放器。基于 **Tauri 2 + Rust + React 19** 构建，以 **Bit-Perfect 硬件直通**、**无锁低延迟音频调度** 与 **Google Material Design 3** 为核心设计原则，在提供极致原声音质的同时，带来毫秒级响应的流畅交互体验。

---

## 📸 界面预览 (Screenshots)

<div align="center">

### 1. 现代化曲库与主页推荐 (Modern Home & Adaptive Library)
> 集成个性化问候、智能采样推荐单曲与专辑、自适应分类侧栏及沉浸式底部播放控制台。

![0rhxPlayer Home Page](info-pic/Screenshot%202026-08-21%20120003.png)

<br/>

### 2. 沉浸式 NowPlaying 播放器与双语动态歌词 (Immersive NowPlaying & Bilingual Lyrics)
> 全视口弹性自适应专辑画质、全套发烧级音频流参数卡片（WASAPI 独占驱动、实时比特率、ReplayGain 增益）及平滑滚动的双语对齐歌词。

![0rhxPlayer NowPlaying View](info-pic/Screenshot%202026-08-21%20120150.png)

</div>

---

## ✨ 核心特性 (Key Features)

### 🔊 1. 发烧级音频引擎管线 (Audiophile Audio Pipeline)
- **WASAPI 独占硬件直通**：绕过 Windows 系统的音效混音层（Software Mixer），直通声卡实现 Bit-Perfect 逐比特还原。
- **64-bit 浮点重采样**：集成高质量音频重采样引擎，消除采样率转换中的相位失真与量化噪声。
- **无锁抢占式起播调度器 (Playback Scheduler)**：
  - 前端 0ms 乐观 UI 响应与防抖取消机制。
  - Rust 后端基于 Atomic Generation ID 实现无锁流式抢占，疯狂连点切歌零卡顿、零死锁。
- **ReplayGain 音量平衡**：自动感知音轨/专辑峰值增益，保持不同曲目间舒适一致的听感响度。

### 🎼 2. 全格式无损解码支持 (Universal Lossless Codecs)
- 原生支持 **FLAC、WAV、APE、Apple Lossless (ALAC)、DSD (DSF/DFF)、AIFF** 等高规格无损母带。
- 完整兼容 **MP3、AAC、OGG Vorbis、Opus、WMA** 等主流有损音频。
- 支持 CUE 分轨解析与嵌入式专辑大图解析。

### 🎛️ 3. 10-Band 专业参数化均衡器 (DSP Equalizer)
- 采用 Biquad 二阶 IIR 滤波器架构，提供 10 个标准频段独立增益调节（±12dB）。
- 硬件级前级增益（Preamp）调节，有效防止信号过载削波（Clipping）。
- 内置 Flat、Rock、Pop、Jazz、Classical、Electronic、Vocal Boost 等多种精调预设。

### 📜 4. 极致歌词与元数据系统 (Lyrics & Metadata)
- 支持外部 `.lrc` 文件与音频文件内嵌 ID3 / Vorbis Comments 歌词。
- 智能双语翻译对齐显示（支持中/英/日多语种对照）。
- 歌词行支持居左、居中、居右对齐调节与字体缩放。
- 精准毫秒级高亮与自然平滑居中滚动，用户临时滑动后自动恢复追踪。

### 🎨 5. Material You 3.0 设计与动效系统 (M3 Motion & Theming)
- 以 **初音绿 (`#39C5BB`)** 为基调的 Material 3 调色板体系。
- 严格遵循 Google M3 Motion Tokens，全应用落地 `cubic-bezier(0.05, 0.7, 0.1, 1.0)` 强调缓动曲线与流畅 Fade Through 穿透过渡。
- 虚拟化网格与长列表（`@tanstack/react-virtual`），即使管理数万首歌曲仍稳定在 60fps。
- 图片异步解码 (`decoding="async"`) 与原生懒加载 (`loading="lazy"`)，杜绝重排掉帧。

### 🌐 6. 国际化与双端生态协同 (Ecosystem)
- 界面 100% 完整覆盖 **简体中文**、**English**、**日本語** 三语无缝切换。
- 提供与 [VSCode 插件版](https://github.com/RinCynar/0rhxPlayer) 相同的操作习惯与快捷键规范，打造沉浸式极客听音闭环。

---

## 📥 下载与安装 (Download & Installation)

前往 **[0rhxPlayer 官网](https://0rhxPlayer.rincynar.top)** 或 **[GitHub Releases](https://github.com/RinCynar/0rhxPlayer-Desktop/releases/latest)** 获取最新发行版本：

| 平台 (Platform) | 架构 (Arch) | 安装包类型 (Package Type) | 说明 |
| :--- | :--- | :--- | :--- |
| **Windows** | x64 (AMD64) | `.exe` (NSIS Installer)  | 推荐 Windows 10/11 用户使用 |
| **Windows** | ARM64 | `.exe` (NSIS Installer) | 适用于 Surface Pro 等 ARM 架构设备 |
| **Linux** | x64 (AMD64) | `.AppImage` / `.tar.gz` | 开箱即用，免安装便携运行 |

---

## 🛠️ 本地开发与构建 (Development & Build)

### 1. 环境准备 (Prerequisites)
- [Node.js](https://nodejs.org/) (>= 18)
- [pnpm](https://pnpm.io/) (>= 9)
- [Rust](https://www.rust-lang.org/) (>= 1.75) 与 Cargo
- [Tauri CLI](https://tauri.app/v2/guides/getting-started/prerequisites/)

### 2. 克隆仓库 (Clone Repository)
```bash
git clone https://github.com/RinCynar/0rhxPlayer-Desktop.git
cd 0rhxPlayer-Desktop
```

### 3. 安装前端依赖 (Install Dependencies)
```bash
pnpm install
```

### 4. 启动开发模式 (Run Development Mode)
```bash
pnpm tauri dev
```

### 5. 构建生产发布包 (Build Release Bundle)
```bash
pnpm tauri build
```
构建生成的安装包与二进制文件将输出至 `src-tauri/target/release/bundle/`。

---

## 🔗 相关生态 (Ecosystem & Links)

- **桌面端官网**: [https://0rhxPlayer.rincynar.top](https://0rhxPlayer.rincynar.top)
- **桌面端仓库**: [https://github.com/RinCynar/0rhxPlayer-Desktop](https://github.com/RinCynar/0rhxPlayer-Desktop)
- **VSCode 插件版仓库**: [https://github.com/RinCynar/0rhxPlayer](https://github.com/RinCynar/0rhxPlayer)
- **VSCode 插件市场主页**: [Visual Studio Marketplace - 0rhxPlayer](https://marketplace.visualstudio.com/items?itemName=RinCynar.0rhxplayer)

---

## 📄 开源许可证 (License)

本项目基于 **[GPL-3.0 License](LICENSE)** 开源发布。

Copyright © 2026 [RinCynar](https://github.com/RinCynar).
