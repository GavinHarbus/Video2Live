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
    @State private var completedOutput: LivePhotoOutput?

    private let analyzer = VideoAnalyzer()

    var body: some View {
        VStack(spacing: 0) {
            if project.state == .idle {
                DropZoneView(
                    droppedURL: $droppedURL,
                    chooseFile: { chooseVideoFile() }
                )
            } else if project.state == .analyzing {
                analyzingView
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
        .focusedSceneValue(\.openVideoAction, { chooseVideoFile() })
        .focusedSceneValue(\.cancelVideoOperationAction, cancelVideoOperationAction)
    }

    private var analyzingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Analyzing video…")
                .font(.headline)
            Text(droppedURL?.lastPathComponent ?? "")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Button("Cancel") {
                resetAll()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
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

                            Button(action: toggleLivePreview) {
                                Image(systemName: isPreviewing ? "stop.fill" : "livephoto")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(8)
                                    .background(.black.opacity(0.55), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .padding(10)
                            .disabled(!canPreview)
                            .help(isPreviewing ? "Stop Live Photo preview" : "Play Live Photo preview")
                            .accessibilityLabel(
                                isPreviewing ? "Stop Live Photo preview" : "Play Live Photo preview"
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                if canPreview {
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
                        set: {
                            project.setRangeStart($0)
                            markProjectDirty()
                        }
                    ),
                    rangeDuration: project.rangeDuration,
                    coverTime: Binding(
                        get: { project.coverTime },
                        set: {
                            project.setCoverTime($0)
                            markProjectDirty()
                        }
                    ),
                    onCoverScrub: { previewCover(at: $0) },
                    onCoverScrubEnded: { showCover() }
                )
                .padding(.horizontal, 20)
                .onChange(of: project.rangeStart) { _, _ in
                    updatePlayerLoop()
                }
                .disabled(project.state == .converting)
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
                    stage: generator.stage,
                    action: { startConversion() },
                    retryAction: { startConversion() },
                    cancelAction: { cancelConversion() },
                    canRetry: project.asset != nil,
                    exportAction: { chooseExportFolder() },
                    completionMessage: completionMessage,
                    completionActionLabel: completionActionLabel,
                    completionActionIcon: completionActionIcon,
                    completionAction: { openCompletedOutput() },
                    openSettingsAction: { openPhotosSettings() },
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
                project.state = .failed(
                    kind: .analysis,
                    message: error.localizedDescription
                )
            }
        }
    }

    private func chooseVideoFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK {
            droppedURL = panel.url
        }
    }

    private var cancelVideoOperationAction: (() -> Void)? {
        switch project.state {
        case .analyzing:
            return { resetAll() }
        case .converting:
            return { cancelConversion() }
        case .idle, .ready, .completed, .failed:
            return nil
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
        guard !isPreviewing, canPreview, let player else { return }

        isPreviewing = true
        player.seek(to: project.selectedTimeRange.start, toleranceBefore: .zero, toleranceAfter: .zero)
        player.play()
    }

    private func toggleLivePreview() {
        if isPreviewing {
            stopLivePreview()
        } else {
            startLivePreview()
        }
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

    private func startConversion(destination: LivePhotoDestination = .photos) {
        guard let sourceURL = project.sourceURL else { return }

        conversionTask?.cancel()
        let operationID = UUID()
        conversionID = operationID
        project.state = .converting
        generator.progress = 0
        generator.stage = .preparing
        completedOutput = nil

        conversionTask = Task {
            do {
                let output = try await generator.generate(
                    project: project,
                    destination: destination
                )
                try Task.checkCancellation()
                guard conversionID == operationID, project.sourceURL == sourceURL else { return }
                completedOutput = output
                project.state = .completed
            } catch is CancellationError {
                return
            } catch {
                guard conversionID == operationID, project.sourceURL == sourceURL else { return }
                project.state = .failed(
                    kind: failureKind(for: error),
                    message: error.localizedDescription
                )
            }
        }
    }

    private var canPreview: Bool {
        switch project.state {
        case .ready, .completed, .failed:
            return true
        case .idle, .analyzing, .converting:
            return false
        }
    }

    private func failureKind(for error: Error) -> ConversionFailureKind {
        guard let error = error as? V2LError else { return .conversion }
        if case .photosAuthorizationDenied = error {
            return .photosPermission
        }
        return .conversion
    }

    private func markProjectDirty() {
        switch project.state {
        case .completed, .failed:
            completedOutput = nil
            project.state = .ready
        case .idle, .analyzing, .ready, .converting:
            break
        }
    }

    private func chooseExportFolder() {
        let panel = NSOpenPanel()
        panel.title = "Export Live Photo Pair"
        panel.message = "Choose a folder for the matching HEIC and MOV files."
        panel.prompt = "Export"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let directoryURL = panel.url {
            startConversion(destination: .folder(directoryURL))
        }
    }

    private var completionMessage: String {
        switch completedOutput {
        case .photos:
            return "Live Photo saved to Photos!"
        case .files:
            return "Live Photo pair exported!"
        case nil:
            return "Live Photo created!"
        }
    }

    private var completionActionLabel: String? {
        switch completedOutput {
        case .photos:
            return "Open Photos"
        case .files:
            return "Show in Finder"
        case nil:
            return nil
        }
    }

    private var completionActionIcon: String {
        switch completedOutput {
        case .photos:
            return "photo.on.rectangle"
        case .files, nil:
            return "folder"
        }
    }

    private func openCompletedOutput() {
        switch completedOutput {
        case .photos:
            guard let photosURL = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: "com.apple.Photos"
            ) else { return }
            NSWorkspace.shared.openApplication(
                at: photosURL,
                configuration: NSWorkspace.OpenConfiguration()
            )
        case .files(let files):
            NSWorkspace.shared.activateFileViewerSelecting([files.heicURL, files.movURL])
        case nil:
            break
        }
    }

    private func openPhotosSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    private func cancelConversion() {
        conversionID = nil
        conversionTask?.cancel()
        conversionTask = nil
        generator.progress = 0
        isPreviewing = false
        completedOutput = nil
        project.state = project.asset == nil ? .idle : .ready
        showCover()
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
        completedOutput = nil
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
