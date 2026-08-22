<div align="center">

# 🎵 0rhxPlayer Desktop

### A Lightweight & Modern Material 3 Local Music Player for Desktop
**一个轻量、现代化、遵循 Material 3 设计的本地音乐播放器**

[![Release](https://img.shields.io/github/v/release/RinCynar/0rhxPlayer-Desktop?style=flat-square&color=39C5BB)](https://github.com/RinCynar/0rhxPlayer-Desktop/releases/latest)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux-006A6B?style=flat-square)](https://0rhxplayer.rincynar.top)
[![Tauri](https://img.shields.io/badge/Tauri-v2-FFC131?style=flat-square&logo=tauri&logoColor=white)](https://tauri.app/)
[![Rust](https://img.shields.io/badge/Rust-1.75%2B-DEA584?style=flat-square&logo=rust&logoColor=white)](https://www.rust-lang.org/)
[![React](https://img.shields.io/badge/React-19-61DAFB?style=flat-square&logo=react&logoColor=black)](https://react.dev/)
[![Material 3](https://img.shields.io/badge/Design-Material%20You%203.0-39C5BB?style=flat-square)](https://m3.material.io/)
[![License](https://img.shields.io/github/license/RinCynar/0rhxPlayer-Desktop?style=flat-square&color=blue)](LICENSE)

[🌐 Official Website](https://0rhxplayer.rincynar.top) • [📦 Releases](https://github.com/RinCynar/0rhxPlayer-Desktop/releases/latest) • [🧩 VSCode Extension](https://github.com/RinCynar/0rhxPlayer)

**English** | [简体中文](README_zh.md)

</div>

---

## 📌 About

**0rhxPlayer Desktop** is a modern local music player built with the **Tauri 2 + Rust + React 19** stack.

Designed from the ground up to offer a clean aesthetic, fluid interactions, low memory footprint, and dedicated local audio playback. It adheres to **Google Material Design 3** guidelines with Miku Teal (`#39C5BB`) as its signature accent color, supporting bit-perfect decoding for popular lossless/lossy formats, synchronized dynamic lyrics, and a built-in 10-band equalizer.

> [!NOTE]
> The current version is `v1.0.2` and is actively maintained. Feedback, bug reports, and suggestions are welcome via [GitHub Issues](https://github.com/RinCynar/0rhxPlayer-Desktop/issues)!

---

## 📸 Screenshots

<div align="center">

### 🌙 Dark Mode

#### 1. Home & Recommendations
> Personalized greetings, randomized album/track recommendations, dynamic color theming, and bottom player bar.

![0rhxPlayer Dark Home](info-pic/Dark-HomePage.png)

<br/>

#### 2. NowPlaying & Dual-line Lyrics
> High-res album artwork, real-time audio metadata (sample rate, format, driver mode), and line-by-line synchronized bilingual lyrics.

![0rhxPlayer Dark NowPlaying](info-pic/Dark-NowPlaying.png)

<br/>

---

### ☀️ Light Mode

#### 1. Home & Recommendations
![0rhxPlayer Light Home](info-pic/Light-HomePage.png)

<br/>

#### 2. NowPlaying & Dual-line Lyrics
![0rhxPlayer Light NowPlaying](info-pic/Light-NowPlaying.png)

</div>

---

## 🛠️ Features

- **🎧 Local Audio Playback**:
  - High-performance Rust backend powered by `cpal` and `symphonia` with low-latency Windows WASAPI / DirectSound and Linux ALSA output.
  - Lossless format decoding (FLAC, WAV, APE, ALAC) & lossy codecs (MP3, AAC, OGG, Opus).
  - CUE sheet auto-parsing and ReplayGain volume normalization.
- **🎛️ 10-Band Equalizer (EQ)**:
  - 10 frequency band gain adjustments (±12 dB) with pre-amp gain control.
  - Built-in acoustic presets (Flat, Pop, Rock, Vocal Boost, Classical, etc.).
- **📜 Lyrics & Metadata**:
  - Automatically loads embedded tags and external `.lrc` files.
  - Line-by-line synchronized bilingual translation scrolling with customizable font size and alignments.
- **🎨 Material 3 Visuals & Motion**:
  - Dynamic color palettes derived from seed colors with automatic System / Dark / Light theme switching.
  - Seamless M3 cubic-bezier transitions and smooth shared-element layout animations.
  - Virtualized list rendering (`@tanstack/react-virtual`) for buttery-smooth library scrolling with tens of thousands of tracks.
- **🌐 Internationalization (i18n)**:
  - Out-of-the-box multilingual support: **English**, **简体中文**, and **日本語**.

---

## 📥 Downloads & Installation

Get pre-built standalone binaries from the **[GitHub Releases](https://github.com/RinCynar/0rhxPlayer-Desktop/releases/latest)** or the **[Official Website](https://0rhxplayer.rincynar.top)**:

| Platform | Package Format | Description |
| :--- | :--- | :--- |
| **Windows (x64)** | `.exe` (Installer) / `.zip` (Portable) | Windows 10/11 64-bit |
| **Windows (ARM64)** | `.exe` (Installer) / `.zip` (Portable) | Windows on ARM (e.g., Surface Pro X / Snapdragon X Elite) |
| **Linux (x64)** | `.AppImage` / `.tar.gz` (Portable) | Major x64 Linux distributions |

---

## 💻 Build from Source

### Prerequisites
- [Node.js](https://nodejs.org/) (>= 18) and [pnpm](https://pnpm.io/)
- [Rust](https://www.rust-lang.org/) (>= 1.75) and Cargo
- [Tauri 2 Prerequisites](https://tauri.app/v2/guides/getting-started/prerequisites/)

### Steps
```bash
# 1. Clone repository
git clone https://github.com/RinCynar/0rhxPlayer-Desktop.git
cd 0rhxPlayer-Desktop

# 2. Install dependencies
pnpm install

# 3. Development mode with hot-reload
pnpm tauri dev

# 4. Production build
pnpm tauri build
```

---

## 🔗 Related Projects

- **VSCode Extension**: [0rhxPlayer for VSCode](https://github.com/RinCynar/0rhxPlayer) (Available on the Visual Studio Marketplace)
- **Official Website**: [https://0rhxplayer.rincynar.top](https://0rhxplayer.rincynar.top)

---

## 📄 License

This project is licensed under the **[GNU General Public License v3.0 (GPL-3.0)](LICENSE)**.

Copyright © 2026 [RinCynar](https://github.com/RinCynar).
