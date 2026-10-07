<div align="center">

# 🎵 0rhxPlayer Desktop

### A Lightweight & Modern Material 3 Local Music Player for Desktop (Native Qt 6)

**English** | [简体中文](README_zh.md)

</div>

---

> [!IMPORTANT]
> ### ⚡ Project Status: Native Qt 6 Rebuild
>
> This repository hosts the **native Qt 6 (C++20 / Qt Quick)** implementation of 0rhxPlayer.
> It replaces the previous Tauri-based version in pursuit of a fully native audio pipeline
> (Un4seen BASS with WASAPI Exclusive output on a dedicated high-priority thread) and lower
> system overhead. Development is in progress.

## Features

- **🎧 Local Audio Playback**: Un4seen BASS engine with WASAPI exclusive output, FLAC / WAV / APE / MP3 / AAC / OGG / Opus decoding.
- **🎛️ 10-Band Equalizer**: ±12 dB Biquad EQ with presets and pre-amp gain.
- **📜 Lyrics & Metadata**: Embedded tags and external `.lrc` support, line-by-line synchronized bilingual lyrics.
- **🎨 Material 3 UI**: Flat M3 design, dynamic seed-color theming, system / dark / light modes.
- **🌐 i18n**: English, 简体中文, 日本語.

## Build (Windows)

Requirements: Qt 6.11 (MinGW 64-bit), CMake ≥ 3.20, Ninja.

```bash
cmake -B build -G Ninja
cmake --build build
```

The BASS runtime libraries are bundled under `libs/bass/` and deployed automatically by the build.

## License

Distributed under the [MIT License](LICENSE).
