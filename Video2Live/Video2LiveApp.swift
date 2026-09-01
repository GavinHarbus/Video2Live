import SwiftUI

private struct OpenVideoActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

private struct CancelVideoOperationActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var openVideoAction: (() -> Void)? {
        get { self[OpenVideoActionKey.self] }
        set { self[OpenVideoActionKey.self] = newValue }
    }

    var cancelVideoOperationAction: (() -> Void)? {
        get { self[CancelVideoOperationActionKey.self] }
        set { self[CancelVideoOperationActionKey.self] = newValue }
    }
}

private struct VideoCommands: Commands {
    @FocusedValue(\.openVideoAction) private var openVideoAction
    @FocusedValue(\.cancelVideoOperationAction) private var cancelVideoOperationAction

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Open Video…") {
                openVideoAction?()
            }
            .keyboardShortcut("o", modifiers: .command)
            .disabled(openVideoAction == nil)

            Button("Cancel Current Operation") {
                cancelVideoOperationAction?()
            }
            .keyboardShortcut(.cancelAction)
            .disabled(cancelVideoOperationAction == nil)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@MainActor
final class AuxiliaryWindowPresenter {
    static let shared = AuxiliaryWindowPresenter()

    private var aboutWindowController: NSWindowController?

    private init() {}

    func showAbout() {
        if aboutWindowController == nil {
            aboutWindowController = makeWindow(
                title: "About Video2LivePhoto",
                id: "about",
                content: AboutView()
            )
        }
        present(aboutWindowController)
    }

    private func makeWindow<Content: View>(
        title: String,
        id: String,
        content: Content
    ) -> NSWindowController {
        let hostingController = NSHostingController(rootView: content)
        let window = NSWindow(contentViewController: hostingController)
        window.title = title
        window.identifier = NSUserInterfaceItemIdentifier(id)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.setContentSize(hostingController.view.fittingSize)
        window.center()
        return NSWindowController(window: window)
    }

    private func present(_ controller: NSWindowController?) {
        controller?.showWindow(nil)
        controller?.window?.makeKeyAndOrderFront(nil)
    }
}

@main
struct Video2LiveApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup("Video2LivePhoto", id: "main") {
            ContentView()
        }
        .defaultSize(width: 720, height: 520)
        .commands {
            VideoCommands()

            CommandGroup(replacing: .appInfo) {
                Button("About Video2LivePhoto") {
                    AuxiliaryWindowPresenter.shared.showAbout()
                }
            }

            CommandGroup(before: .windowList) {
                Button("Video2LivePhoto") {
                    openWindow(id: "main")
                }
                .keyboardShortcut("0", modifiers: .command)

                Divider()
            }
        }
    }
}
