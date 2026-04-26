import SwiftUI

@main
struct Video2LiveApp: App {
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 720, height: 520)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Video2Live") {
                    openWindow(id: "about")
                }
            }
        }

        Window("About Video2Live", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }
}
