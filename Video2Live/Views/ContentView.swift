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
    @State private var isPreviewing = false
    @State private var lastCoverSeekTime: TimeInterval = 0

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
                    .overlay {
                        ZStack(alignment: .topTrailing) {
                            Color.clear
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { _ in
                                            startLivePreview()
                                        }
                                        .onEnded { _ in
                                            stopLivePreview()
                                        }
                                )

                            Image(systemName: isPreviewing ? "livephoto" : "photo.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(.black.opacity(0.55), in: Circle())
                                .padding(10)
                                .allowsHitTesting(false)
                                .accessibilityLabel(isPreviewing ? "Live preview playing" : "Selected cover")
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                if project.state == .ready {
                    Label("Press and hold the preview to play", systemImage: "livephoto")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .accessibilityLabel("Press and hold the video preview to play the Live Photo")
                }
            }

            if let asset = project.asset {
                TimelineScrubberView(
                    duration: project.duration,
                    sourceStartTime: project.sourceTimeRange.start,
                    asset: asset,
                    rangeStart: Binding(
                        get: { project.rangeStart },
                        set: { project.setRangeStart($0) }
                    ),
                    rangeDuration: project.rangeDuration,
                    coverTime: Binding(
                        get: { project.coverTime },
                        set: { project.setCoverTime($0) }
                    ),
                    onCoverScrub: { previewCover(at: $0) },
                    onCoverScrubEnded: { showCover() }
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
                project.configureClip(for: result.duration)

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
        updatePlayerLoop()
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
        showCover()
    }

    private func startLivePreview() {
        guard !isPreviewing, project.state == .ready, let player else { return }

        isPreviewing = true
        player.seek(to: project.selectedTimeRange.start, toleranceBefore: .zero, toleranceAfter: .zero)
        player.play()
    }

    private func stopLivePreview() {
        guard isPreviewing else { return }

        isPreviewing = false
        showCover()
    }

    private func showCover() {
        guard !isPreviewing, let player else { return }

        player.pause()
        player.seek(to: project.keyFrameTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func previewCover(at localTime: Double) {
        guard !isPreviewing, let player else { return }

        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastCoverSeekTime >= 1.0 / 30.0 else { return }
        lastCoverSeekTime = now

        let time = CMTimeAdd(
            project.sourceTimeRange.start,
            CMTime(seconds: localTime, preferredTimescale: 600)
        )
        let tolerance = CMTime(seconds: 1.0 / 15.0, preferredTimescale: 600)
        player.pause()
        player.seek(to: time, toleranceBefore: tolerance, toleranceAfter: tolerance)
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
        isPreviewing = false
        lastCoverSeekTime = 0
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
