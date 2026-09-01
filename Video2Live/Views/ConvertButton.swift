import SwiftUI

struct ConvertButton: View {
    let state: ConversionState
    let progress: Double
    let stage: ConversionStage
    let action: () -> Void
    let retryAction: () -> Void
    let cancelAction: () -> Void
    let canRetry: Bool
    let exportAction: () -> Void
    let completionMessage: String
    let completionActionLabel: String?
    let completionActionIcon: String
    let completionAction: () -> Void
    let openSettingsAction: () -> Void
    let resetAction: () -> Void

    @ViewBuilder
    var body: some View {
        Group {
            switch state {
            case .idle, .analyzing:
                EmptyView()

            case .ready:
                HStack(spacing: 12) {
                Button(action: action) {
                    Label("Convert to Live Photo", systemImage: "livephoto")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                exportMenu
                }

            case .converting:
                HStack(spacing: 10) {
                Text(stage.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ProgressView(value: progress)
                    .frame(width: 140)
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Button("Cancel", role: .cancel, action: cancelAction)
                    .buttonStyle(.bordered)
                }

            case .completed:
                HStack(spacing: 12) {
                Label(completionMessage, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                if let completionActionLabel {
                    Button(action: completionAction) {
                        Label(completionActionLabel, systemImage: completionActionIcon)
                    }
                    .buttonStyle(.borderedProminent)
                }
                }

            case .failed(let kind, let message):
                VStack(alignment: .trailing, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Label(failureTitle(for: kind), systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: 320, alignment: .leading)
                        .help(message)
                }
                HStack(spacing: 8) {
                    switch kind {
                    case .analysis:
                        Button("Choose Another Video", action: resetAction)
                            .buttonStyle(.borderedProminent)
                    case .photosPermission:
                        Button(action: openSettingsAction) {
                            Label("Open Settings", systemImage: "gearshape")
                        }
                        .buttonStyle(.bordered)
                        Button(action: exportAction) {
                            Label("Export Instead", systemImage: "folder.badge.plus")
                        }
                        .buttonStyle(.borderedProminent)
                    case .conversion:
                        Button("Try Again", action: retryAction)
                            .buttonStyle(.bordered)
                            .disabled(!canRetry)
                        Button(action: exportAction) {
                            Label("Export Instead", systemImage: "folder.badge.plus")
                        }
                        .buttonStyle(.bordered)
                        .disabled(!canRetry)
                    }
                }
                }
            }
        }
        .animation(.default, value: state)
    }

    private func failureTitle(for kind: ConversionFailureKind) -> String {
        switch kind {
        case .analysis:
            return "Couldn’t open video"
        case .photosPermission:
            return "Photos permission required"
        case .conversion:
            return "Conversion failed"
        }
    }

    private var exportMenu: some View {
        Menu {
            Button(action: exportAction) {
                Label("Export Pair to Folder…", systemImage: "folder.badge.plus")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("More export options")
        .accessibilityLabel("More export options")
    }
}
