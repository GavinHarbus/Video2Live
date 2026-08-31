import SwiftUI

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
                title: "About Video2Live",
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
        WindowGroup("Video2Live", id: "main") {
            ContentView()
        }
        .defaultSize(width: 720, height: 520)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Video2Live") {
                    AuxiliaryWindowPresenter.shared.showAbout()
                }
            }

            CommandGroup(before: .windowList) {
                Button("Video2Live") {
                    openWindow(id: "main")
                }
                .keyboardShortcut("0", modifiers: .command)

                Divider()
            }
        }
    }
}
