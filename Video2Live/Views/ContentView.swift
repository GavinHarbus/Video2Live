import SwiftUI
import AVKit
import AVFoundation

struct ContentView: View {
    @State private var project = VideoProject()
    @State private var generator = LivePhotoGenerator()
    @State private var player: AVPlayer?
    @State private var looper: AVPlayerLooper?
    @State private var droppedURL: URL?
    @State private var analysisTask: Task<Void, Never>?
    @State private var conversionTask: Task<Void, Never>?
    @State private var analysisID: UUID?
    @State private var conversionID: UUID?

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
        .onDisappear {
            cancelCurrentWork()
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
                    sourceStartTime: project.sourceTimeRange.start,
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
        analysisTask?.cancel()
        conversionTask?.cancel()
        let operationID = UUID()
        analysisID = operationID
        conversionID = nil
        project.state = .analyzing
        project.sourceURL = url

        analysisTask = Task {
            do {
                let result = try await analyzer.analyze(url: url)
                try Task.checkCancellation()
                guard analysisID == operationID, project.sourceURL == url else { return }

                project.asset = result.asset
                project.sourceTimeRange = result.timeRange
                project.duration = result.duration
                project.naturalSize = result.size

                // Set initial range for long videos
                if project.isLongVideo {
                    project.rangeStart = 0
                    project.rangeDuration = min(3.0, result.duration)
                }

                setupPlayer()
                project.state = .ready
            } catch is CancellationError {
                return
            } catch {
                guard analysisID == operationID, project.sourceURL == url else { return }
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
        guard let sourceURL = project.sourceURL else { return }

        conversionTask?.cancel()
        let operationID = UUID()
        conversionID = operationID
        project.state = .converting(progress: 0)
        generator.progress = 0

        conversionTask = Task {
            do {
                try await generator.generate(project: project)
                try Task.checkCancellation()
                guard conversionID == operationID, project.sourceURL == sourceURL else { return }
                project.state = .completed
            } catch is CancellationError {
                return
            } catch {
                guard conversionID == operationID, project.sourceURL == sourceURL else { return }
                project.state = .failed(message: error.localizedDescription)
            }
        }
    }

    private func resetAll() {
        cancelCurrentWork()
        player?.pause()
        player = nil
        looper = nil
        droppedURL = nil
        project.reset()
        generator.progress = 0
    }

    private func cancelCurrentWork() {
        analysisTask?.cancel()
        conversionTask?.cancel()
        analysisTask = nil
        conversionTask = nil
        analysisID = nil
        conversionID = nil
    }
}
