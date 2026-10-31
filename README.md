# Phornix Factory 🚀
### Modern, Universal Media Converter & Format Factory Clone for All Platforms

**Phornix Factory** is a cross-platform multimedia conversion suite inspired by the iconic **Format Factory**. Built with Flutter, it delivers high-performance conversions for video, audio, images, and documents across **Linux, Windows, macOS, Android, iOS, and Web**.

---

## 🌟 Key Features

### 🎬 Video Converter & Tools
- **Containers**: MP4, MKV, WebM, AVI, MOV, FLV, GIF, 3GP.
- **Audio Ripper**: Extract audio track directly to MP3 or AAC with 1-click.
- **Video to Animated GIF**: Convert video clips to high-quality animated GIFs with lanczos scaling.
- **Precision Trimming**: Sub-second start/end time clipping.
- **Encoders**: H.264 (AVC), H.265 (HEVC), VP9, and direct stream copy (passthrough).
- **Control**: Resolution scaling (4K, 1440p, 1080p, 720p, 480p), custom bitrates, FPS (60, 30, 24), and aspect ratios (16:9, 4:3, 9:16, 1:1).

### 🎵 Audio Converter
- **Formats**: MP3, WAV (Studio PCM), AAC, FLAC (Lossless), OGG (Vorbis), M4A, OPUS.
- **Audio Options**: Bitrates up to 320 kbps, sample rates (48kHz, 44.1kHz), Stereo/Mono channel downmixing, and volume boosting (up to 200%).

### 🖼️ Picture Suite (Pure Dart Engine - 100% Cross-Platform)
- **Formats**: PNG (Transparency), JPG / JPEG, WebP, BMP, ICO (Icon file), GIF.
- **Batch Processing**: Resize with aspect ratio retention, rotation (90°, 180°, 270°).
- **Color Filters**: Grayscale / B&W, Sepia vintage, Negative/Invert.
- **Quality Slider**: Custom compression levels from 10% to 100%.

### 📄 Document Converter
- **Images -> PDF**: Compile single or multiple images into a multi-page PDF document.
- **Text -> PDF**: Convert source code, logs, and plain text into structured PDF documents.
- **Layouts**: Standard A4 and US Letter presets with automatic margins.

### 📱 Device & Social Presets
- **Apple iPhone / iPad**: H.264 High Profile 4.1 + AAC MP4.
- **Android Phone**: Universally compatible MP4 profile.
- **Discord Video**: Automatic CRF compression targeting <25MB file limits.
- **YouTube 1080p**: Optimized bitrates recommended for streaming uploads.
- **TikTok / Reels / Shorts**: 9:16 vertical crop and 1080x1920 scaling.

### 🔍 Media Inspector
- Inspect any file on your computer without running a conversion.
- View container metadata, total duration, overall bitrate, and per-stream codec details (video resolution, frame rate, audio sample rate, channels).

### 🎨 Themes
- **Dark Studio**: Sleek obsidian canvas with electric indigo & amber accents.
- **Format Factory Classic**: Nostalgic classic azure blue and titanium theme paying homage to the original.
- **Cyber Neon**: Midnight background with cyan and magenta accents.
- **Clean Light**: Crisp modern light theme for daytime productivity.

---

## ⚡ Dual-Engine Architecture

Phoenix Factory employs an adaptive hybrid conversion architecture:
1. **FFmpeg Hardware-Accelerated Engine (Desktop / Mobile)**:
   - Utilizes static or system FFmpeg 7.0 for hardware video decoding/encoding, multi-threaded audio transcoding, and real-time progress parsing (`fps`, `speed`, `progress`).
2. **Pure Dart Processing Engine (Zero-Dependency Fallback & Web)**:
   - Uses `package:image` and `package:pdf` to guarantee 100% of image and document conversion operations execute natively in pure Dart across **every platform** (including Web browsers) with zero native dependencies.

---

## 🚀 Running & Building

### Prerequisites
- Flutter SDK 3.13+ (tested on Flutter 3.47.7 stable)
- (Optional for Desktop Video Transcoding): FFmpeg 7.0 (automatically detected in `~/.local/bin`, `/usr/bin`, or system `PATH`)

### Run Locally (Desktop)
```bash
flutter run -d linux
# Or Windows
flutter run -d windows
# Or macOS
flutter run -d macos
```

### Run Locally (Web)
```bash
flutter run -d chrome
```

### Build Releases
```bash
# Linux Desktop Bundle
flutter build linux --release

# Web App
flutter build web --release

# Android APK
flutter build apk --release

# Windows Executable
flutter build windows --release
```

---

## 🧪 Testing

Run automated widget and end-to-end media conversion tests:
```bash
flutter test
```
