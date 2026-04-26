import SwiftUI
import AVKit
import AVFoundation

struct ContentView: View {
    @State private var project = VideoProject()
    @State private var generator = LivePhotoGenerator()
    @State private var player: AVPlayer?
    @State private var looper: AVPlayerLooper?
    @State private var droppedURL: URL?

    private let analyzer = VideoAnalyzer()

    var body: some View {
        VStack(spacing: 0) {
            if project.state == .idle {
                DropZoneView(droppedURL: $droppedURL)
            } else {
                videoEditorView
            }
        }
        .frame(minWidth: 600, minHeight: 420)
        .onChange(of: droppedURL) { _, newURL in
            if let url = newURL {
                analyzeVideo(url: url)
            }
        }
    }

    @ViewBuilder
    private var videoEditorView: some View {
        VStack(spacing: 12) {
            // Video preview
            if let player = player {
                VideoPreviewView(player: player)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
            }

            // Timeline scrubber for long videos
            if project.isLongVideo, let asset = project.asset {
                TimelineScrubberView(
                    duration: project.duration,
                    asset: asset,
                    rangeStart: $project.rangeStart,
                    rangeDuration: project.rangeDuration
                )
                .padding(.horizontal, 20)
                .onChange(of: project.rangeStart) { _, _ in
                    updatePlayerLoop()
                }
            }

            Spacer()

            // Bottom bar
            HStack {
                Button("New Video") {
                    resetAll()
                }
                .buttonStyle(.bordered)

                Spacer()

                ConvertButton(
                    state: project.state,
                    progress: generator.progress,
                    action: { startConversion() },
                    resetAction: { resetAll() }
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    private func analyzeVideo(url: URL) {
        project.state = .analyzing
        project.sourceURL = url

        Task {
            do {
                let result = try await analyzer.analyze(url: url)
                project.asset = result.asset
                project.duration = result.duration
                project.naturalSize = result.size

                // Set initial range for long videos
                if project.isLongVideo {
                    project.rangeStart = 0
                    project.rangeDuration = min(3.0, result.duration)
                }

                setupPlayer()
                project.state = .ready
            } catch {
                project.state = .failed(message: error.localizedDescription)
            }
        }
    }

    private func setupPlayer() {
        guard let asset = project.asset else { return }

        let playerItem = AVPlayerItem(asset: asset)
        let queuePlayer = AVQueuePlayer(playerItem: playerItem)
        looper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)
        player = queuePlayer
        queuePlayer.play()

        if project.isLongVideo {
            updatePlayerLoop()
        }
    }

    private func updatePlayerLoop() {
        guard let asset = project.asset else { return }

        let range = project.selectedTimeRange
        let playerItem = AVPlayerItem(asset: asset)
        let queuePlayer = AVQueuePlayer(playerItem: playerItem)
        looper = AVPlayerLooper(
            player: queuePlayer,
            templateItem: playerItem,
            timeRange: range
        )
        player = queuePlayer
        queuePlayer.play()
    }

    private func startConversion() {
        project.state = .converting(progress: 0)
        generator.progress = 0

        Task {
            do {
                try await generator.generate(project: project)
                project.state = .completed
            } catch {
                project.state = .failed(message: error.localizedDescription)
            }
        }
    }

    private func resetAll() {
        player?.pause()
        player = nil
        looper = nil
        droppedURL = nil
        project.reset()
        generator.progress = 0
    }
}
