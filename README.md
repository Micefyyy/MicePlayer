# AnimePlayer — Native iOS HLS Streaming App

A native iOS anime streaming app using **AVPlayer with HLS** (no web views, no full-file downloads). Streams video in small chunks so storage stays under 100MB.

## Architecture

- **Player**: AVPlayer (AVKit) with `.m3u8` manifest URLs
- **ABR**: Adaptive Bitrate handled automatically by AVPlayer
- **DRM**: FairPlay Streaming (AES-128 encrypted chunks)
- **Backend**: FastAPI + FFmpeg transcoder

## How to Build (you don't need a Mac)

1. Push this repo to GitHub
2. Go to **Actions** tab → **Build IPA** workflow
3. Click **Run workflow** (or it runs automatically on push to `main`)
4. After build finishes, download `AnimePlayer.ipa` from the Artifacts section
5. Sideload the `.ipa` using AltStore, SideStore, TrollStore, or Sideloadly

## Backend Setup

The backend transcodes raw video into HLS chunks:

```bash
cd backend
pip install -r requirements.txt

# Transcode a video into HLS
python -c "
from transcoder import transcode_to_hls
transcode_to_hls('input.mp4', './output', hls_time=6)
"

# Start the API server
python server.py
```

For quick transcoding with FFmpeg directly:
```bash
chmod +x ffmpeg_commands.sh
./ffmpeg_commands.sh input.mp4 ./output
```

## Project Structure

```
Sources/AnimePlayer/
├── App.swift              — @main entry point
├── ContentView.swift      — Tab bar (5 tabs)
├── Player/
│   ├── HLSPlayer.swift    — AVPlayer wrapper + ObservableObject
│   └── PlayerView.swift   — SwiftUI wrapper for AVPlayerViewController
├── Models/
│   ├── Anime.swift        — Anime/Episode/StreamingData types
│   └── Source.swift       — StreamQuality enum
├── Services/
│   ├── AnimeService.swift  — API client (AniList proxy)
│   ├── FairPlayManager.swift — AVAssetResourceLoaderDelegate for DRM
│   └── Preferences.swift   — UserDefaults wrapper
└── Views/
    ├── HomeView.swift
    ├── DiscoverView.swift
    ├── LibraryView.swift
    ├── DownloadsView.swift
    ├── SettingsView.swift
    ├── AnimeDetailView.swift
    └── PlaybackView.swift

backend/
├── server.py              — FastAPI server
├── transcoder.py          — FFmpeg HLS transcoder
├── ffmpeg_commands.sh     — Shell reference
└── requirements.txt
```
