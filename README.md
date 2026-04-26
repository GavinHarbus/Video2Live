# Video2Live

A native macOS app that converts video files into Live Photos and imports them directly into your Photos library.

Live Photos consist of a still HEIC image paired with a short MOV video, linked by a shared content identifier. Video2Live handles the entire pipeline — frame extraction, metadata embedding, and Photos import — in one click.

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later (to build from source)

## Build & Run

1. Clone the repository:
   ```bash
   git clone https://github.com/your-username/Video2Live.git
   cd Video2Live
   ```

2. Open the project in Xcode:
   ```bash
   open Video2Live.xcodeproj
   ```

3. Select your development team under **Signing & Capabilities** (required for Photos library access).

4. Press **Cmd + R** to build and run.

## Usage

1. **Load a video** — Drag and drop a video file onto the app window, or click **Choose File** to browse. Supported formats: MOV, MP4, M4V, AVI.

2. **Select a clip** (long videos only) — For videos longer than 5 seconds, a timeline scrubber appears. Drag to select the 3-second segment you want to use.

3. **Convert** — Click **Convert to Live Photo**. The app will:
   - Extract a key frame from the middle of your selected range
   - Generate a HEIC still image with the Apple maker metadata
   - Export a MOV clip with QuickTime content identifier and still-image-time metadata
   - Import the paired files into your Photos library as a Live Photo

4. **Done** — Open the Photos app, find the newly imported Live Photo, and long-press (or hover with Force Touch) to see it animate.

## How It Works

| Step | Description |
|------|-------------|
| Analyze | Reads video duration, resolution, and track info via `AVURLAsset` |
| Extract Frame | Uses `AVAssetImageGenerator` to capture a precise frame at the midpoint |
| Write HEIC | Creates a HEIC image with `kCGImagePropertyMakerAppleDictionary` containing the shared UUID |
| Write MOV | Exports the clip with `com.apple.quicktime.content.identifier` and `com.apple.quicktime.still-image-time` metadata |
| Import | Uses `PHAssetCreationRequest` to add the HEIC + MOV pair as a Live Photo |

## Project Structure

```
Video2Live/
├── Video2LiveApp.swift           # App entry point
├── Models/
│   ├── ConversionState.swift     # State machine for conversion flow
│   └── VideoProject.swift        # Observable model holding video state
├── Views/
│   ├── ContentView.swift         # Root view with state-based switching
│   ├── DropZoneView.swift        # Drag-and-drop + file picker
│   ├── VideoPreviewView.swift    # AVPlayerView wrapper
│   ├── TimelineScrubberView.swift # Thumbnail strip with range selector
│   └── ConvertButton.swift       # Convert button + progress indicator
├── Services/
│   ├── VideoAnalyzer.swift       # Video metadata analysis
│   ├── HEICWriter.swift          # Key frame extraction + HEIC writing
│   ├── MOVWriter.swift           # Video trimming + QuickTime metadata
│   ├── LivePhotoGenerator.swift  # Conversion pipeline orchestrator
│   └── PhotosImporter.swift      # Photos library import
└── Utilities/
    ├── MetadataConstants.swift   # Metadata key constants
    └── Errors.swift              # Error types
```

## Permissions

The app requests the following permissions:

- **Photos Library (Add Only)** — To save the generated Live Photo. You will be prompted on first conversion.
- **User-Selected File Access (Read Only)** — To read the video file you select.

The app runs in a sandbox and does not access any data beyond what you explicitly provide.

## Build DMG for Distribution

A script is included to package the app into a DMG:

```bash
./scripts/build-dmg.sh
```

This will archive, export, and create `build/Video2Live.dmg` with a drag-to-Applications layout.

## Troubleshooting

- **"Photos library access was denied"** — Go to **System Settings > Privacy & Security > Photos** and grant access to Video2Live.
- **Conversion succeeds but Photos doesn't show the Live Photo effect** — Verify the video source has at least one video track. Some screen recordings or audio-only files may not work.
- **Metadata not preserved** — In rare cases, passthrough export may strip custom metadata. The app automatically falls back to `AVAssetWriter` when this is detected.

## License

MIT
