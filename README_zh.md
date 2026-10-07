<div align="center">

# 🎵 0rhxPlayer Desktop

### 轻量、现代、Material 3 设计的桌面本地音乐播放器(原生 Qt 6)

[English](README.md) | **简体中文**

</div>

---

> [!IMPORTANT]
> ### ⚡ 项目状态:原生 Qt 6 重构
>
> 本仓库承载 0rhxPlayer 的**原生 Qt 6(C++20 / Qt Quick)**实现,取代先前的 Tauri 版本,
> 以获得纯原生音频管线(Un4seen BASS 直通 WASAPI Exclusive,独立高优先级线程)与更低的系统开销。开发进行中。

## 功能

- **🎧 本地音频播放**:Un4seen BASS 引擎直通 WASAPI,支持 FLAC / WAV / APE / MP3 / AAC / OGG / Opus 解码。
- **🎛️ 10 段均衡器**:±12 dB Biquad EQ,内置预设与前级增益。
- **📜 歌词与元数据**:支持内嵌标签与外部 `.lrc`,逐行双语歌词同步。
- **🎨 Material 3 界面**:纯色 Flat M3 设计,种子色动态取色,系统 / 深色 / 浅色主题。
- **🌐 多语言**:English、简体中文、日本語。

## 构建(Windows)

环境要求:Qt 6.11(MinGW 64 位)、CMake ≥ 3.20、Ninja。

```bash
cmake -B build -G Ninja
cmake --build build
```

BASS 运行库已随仓库置于 `libs/bass/`,构建时自动部署。

## 许可证

基于 [MIT License](LICENSE) 发布。
