<div align="center">

# 🎬 Video2Live

### Turn any video into a real Live Photo — on macOS, in one click.

**Native Swift · 100% offline · Fully sandboxed · Open source (MIT)**

[![Download](https://img.shields.io/badge/Download-v1.0.0%20DMG-blue?style=for-the-badge&logo=apple)](https://github.com/GavinHarbus/Video2Live/releases/tag/v1.0.0)
[![macOS](https://img.shields.io/badge/macOS-14.0%2B-black?style=for-the-badge&logo=apple)](https://github.com/GavinHarbus/Video2Live/releases/latest)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)
[![Stars](https://img.shields.io/github/stars/GavinHarbus/Video2Live?style=for-the-badge&logo=github)](https://github.com/GavinHarbus/Video2Live/stargazers)

[**⬇️ Download for macOS**](https://github.com/GavinHarbus/Video2Live/releases/tag/v1.0.0) · [**🌐 Product page**](https://gavinschneestudio.com/products/video2live.html) · [**🐛 Report a bug**](https://github.com/GavinHarbus/Video2Live/issues) · [**⭐ Star the repo**](https://github.com/GavinHarbus/Video2Live)

</div>

---

## 👀 Demo

https://github.com/user-attachments/assets/b5496849-04d7-4657-bd52-f016626d8bed

> Drop a video → pick a 3-second moment → click convert → it's already in your Photos app as a real Live Photo. That's it.

---

## ✨ Why Video2Live?

You found a perfect video clip — a sunset, a pet doing something hilarious, a beautiful drone shot — and you wish it could be your iPhone wallpaper or a Live Photo to share. Apple lets you set Live Photos as wallpapers and share them with the iconic press-to-play effect, but **converting a regular video into a real Live Photo is surprisingly painful**:

- 🚫 Online converters upload your private videos to unknown servers.
- 🚫 Most "Live Photo maker" apps cost money, are buggy, or strip your audio.
- 🚫 Manual workflows require Shortcuts hacks, command-line tools, and a lot of patience.

**Video2Live fixes all of that.** It's a tiny, native macOS app that uses Apple's own frameworks (`AVFoundation`, `Photos`) to produce *real* Live Photos with the proper QuickTime metadata — the same kind iPhones produce — and drops them straight into your Photos library. No upload, no account, no subscription, no telemetry.

---

## 🚀 Features

- 🪄 **One-click conversion** — drag, drop, done.
- 🎚 **Interactive timeline scrubber** — pick the perfect 3-second segment with thumbnail preview.
- ✂️ **Output framing** — keep the original ratio or crop to 9:16, 4:3, and 1:1 with adjustable positioning.
- 🔊 **Audio preserved** — unlike most converters, your original audio stays in the Live Photo.
- 📥 **Direct Photos library import** — no Finder shuffle, no AirDrop dance.
- 📂 **Paired-file export** — save the matching HEIC + MOV files to a folder when you do not want to use Photos.
- ✅ **Output validation** — verifies pairing identifiers, cover timing, duration, and video encoding before saving.
- 🔒 **Fully sandboxed** — runs inside the macOS App Sandbox; only sees the video you pick.
- 🛡 **Photos Add-Only permission** — Video2Live can save photos but *cannot* read your library.
- 📡 **100% offline** — zero network requests, zero analytics, zero tracking.
- 🍎 **Native Swift + SwiftUI** — fast, lightweight, no Electron, no bundled Chromium.
- 🆓 **Free & open source** — MIT licensed; audit, fork, and build it yourself.
- 📁 **Broad format support** — accepts formats that macOS can decode, then writes a Photos-compatible H.264/AAC MOV.

---

## ⬇️ Install

### Recommended: Download the DMG

1. Go to the [latest release](https://github.com/GavinHarbus/Video2Live/releases/tag/v1.0.0).
2. Download `Video2Live.dmg`.
3. Open the DMG and drag **Video2Live.app** into your **Applications** folder.
4. Launch it. On first run, macOS may ask you to confirm — go to **System Settings → Privacy & Security** if needed.

> **Requirements:** macOS 14.0 (Sonoma) or later. Apple Silicon and Intel Macs both supported.

### Or build from source

```bash
git clone https://github.com/GavinHarbus/Video2Live.git
cd Video2Live
open Video2Live.xcodeproj
```

In Xcode, select your development team under **Signing & Capabilities** (required for Photos library access), then press **Cmd + R**.

---

## 🎯 Usage

1. **Load a video** — drag and drop a video onto the app window, or click **Choose File**. Supports formats that macOS can decode.
2. **Frame your Live Photo** — keep the original ratio or choose 9:16 / 4:3 / 1:1, then adjust the crop position.
3. **Pick your moment** *(videos > 5s only)* — drag the timeline scrubber to choose the 3-second segment you want as your Live Photo.
4. **Convert** — click **Convert to Live Photo**. Video2Live will:
   - Extract a key frame from the middle of your selected range
   - Generate a HEIC still image with the proper Apple maker metadata
    - Encode an H.264/AAC MOV clip with the `quicktime.content.identifier` and `still-image-time` tags
    - Validate the generated pair before saving it
   - Import the paired files into your Photos library as a Live Photo
    - Or export the matching HEIC + MOV files from the overflow menu
5. **Enjoy** — open Photos, find your new Live Photo, long-press it (or hover with Force Touch), and watch it animate. Set it as your wallpaper, share it on iMessage, or upload to Instagram.

---

## 💡 Use cases

- 📱 **Wallpapers** — turn cinematic clips into stunning iOS / iPadOS Live Wallpapers.
- 📸 **Social sharing** — Live Photos look way cooler than static images on iMessage and Instagram.
- 🎁 **Memory archives** — convert old `.mp4` family footage into Live Photos for the Photos timeline.
- 🛹 **Sports highlights** — slow, looping moments make great Live Photos.
- 🐶 **Pet content** — your dog's perfect 3 seconds, immortalized.
- 🎨 **Creators** — build wallpaper packs to sell or share.

---

## 🧪 How It Works

| Step | What happens |
|------|--------------|
| **Analyze** | Reads video duration, resolution, and track info via `AVURLAsset` |
| **Compose** | Applies the selected aspect ratio and crop position to preview, cover, and video |
| **Extract Frame** | Uses `AVAssetImageGenerator` to capture a precise frame at the midpoint of your selection |
| **Write HEIC** | Creates a HEIC image with `kCGImagePropertyMakerAppleDictionary` containing the shared content identifier UUID |
| **Write MOV** | Exports the clip with `com.apple.quicktime.content.identifier` and `com.apple.quicktime.still-image-time` metadata so Photos recognizes it as a Live Photo pair |
| **Validate** | Reads both generated files back and verifies their identifiers, timing, duration, and H.264 video track |
| **Import** | Uses `PHAssetCreationRequest` to add the HEIC + MOV pair to your Photos library |

A Live Photo is just a paired HEIC + MOV with matching metadata. Video2Live handles the entire pipeline correctly — frame extraction, metadata embedding, and Photos import — in one click.

---

## 🗂 Project Structure

```
Video2Live/
├── Video2LiveApp.swift             # App entry point
├── Models/
│   ├── ConversionState.swift       # State machine for the conversion flow
│   ├── VideoProject.swift          # Observable model holding video state
│   └── VideoFraming.swift          # Shared crop geometry and output sizing
├── Views/
│   ├── ContentView.swift           # Root view with state-based switching
│   ├── DropZoneView.swift          # Drag-and-drop + file picker
│   ├── VideoPreviewView.swift      # AVPlayerView wrapper
│   ├── TimelineScrubberView.swift  # Thumbnail strip with range selector
│   ├── FramingControlsView.swift   # Aspect ratio and crop position controls
│   └── ConvertButton.swift         # Convert button + progress indicator
├── Services/
│   ├── VideoAnalyzer.swift         # Video metadata analysis
│   ├── HEICWriter.swift            # Key frame extraction + HEIC writing
│   ├── MOVWriter.swift             # Video trimming + QuickTime metadata
│   ├── LivePhotoGenerator.swift    # Conversion pipeline orchestrator
│   ├── LivePhotoExporter.swift     # Collision-safe HEIC + MOV folder export
│   ├── LivePhotoValidator.swift    # Post-generation metadata verification
│   ├── VideoCompositionBuilder.swift # Shared preview and export composition
│   └── PhotosImporter.swift        # Photos library import
└── Utilities/
    ├── MetadataConstants.swift     # Metadata key constants
    └── Errors.swift                # Error types
Video2LiveTests/                    # Unit and media-pipeline integration tests
```

Run the test suite with:

```bash
xcodebuild -project Video2Live.xcodeproj -scheme Video2Live -destination 'platform=macOS' test
```

---

## 🔐 Permissions & Privacy

Video2Live requests the absolute minimum:

- **Photos Library (Add Only)** — to save the generated Live Photo. Cannot read your existing library.
- **User-Selected File Access** — reads the video you pick and writes only to an export folder you explicitly choose.

The app runs inside the macOS App Sandbox and **never makes a network request**. There is no analytics SDK, no telemetry, no crash reporter, nothing. Your videos never leave your Mac.

Read the full privacy policy on the [product page](https://gavinschneestudio.com/products/video2live.html).

---

## 📦 Build a DMG yourself

```bash
./scripts/build-dmg.sh
```

This archives, exports, and creates `build/Video2Live.dmg` with a drag-to-Applications layout — ready to share.

---

## 🛟 Troubleshooting

- **"Photos library access was denied"** → System Settings → Privacy & Security → Photos → enable Video2Live.
- **Conversion succeeded but the Live Photo doesn't animate** → Make sure the source has at least one video track. Pure-audio files or some screen recordings may not work.
- **A format will not open** → The source codec must be decodable by AVFoundation. Try converting the source to H.264 or HEVC first.
- **App is "damaged" / unsigned warning** → Right-click `Video2Live.app` → **Open** → confirm. Or run `xattr -cr /Applications/Video2Live.app`.

Still stuck? [Open an issue](https://github.com/GavinHarbus/Video2Live/issues) — happy to help.

---

## 🙌 Support the project

If Video2Live saved you time, please:

- ⭐ [Star this repo](https://github.com/GavinHarbus/Video2Live) — it really helps others discover it.
- 🐦 Share it on X / 小红书 / Threads — tag with `#Video2Live`.
- 🐛 [File issues](https://github.com/GavinHarbus/Video2Live/issues) and feature requests.
- 🔧 Pull requests welcome — see [Project Structure](#-project-structure) to get oriented.

Want more native, privacy-first tools for creators? Check out the rest of [**Gavin Schnee Studio**](https://gavinschneestudio.com).

---

## 📄 License

[MIT](LICENSE) © Gavin Schnee Studio
