import SwiftUI

@main
@MainActor
struct JisticleApp: App {
    @Environment(\.openWindow) private var openWindow

    init() {
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            RootView()
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Window") {
                    openWindow(id: "main")
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Button("New Gist...") {
                    NotificationCenter.default.post(name: .createNewGist, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandGroup(replacing: .appInfo) {
                Button("About Jisticle") {
                    let aboutWindow = NSWindow(
                        contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                        styleMask: [.titled, .closable],
                        backing: .buffered,
                        defer: false
                    )
                    aboutWindow.title = "About Jisticle"
                    aboutWindow.contentView = NSHostingView(rootView: AboutView())
                    aboutWindow.center()
                    aboutWindow.makeKeyAndOrderFront(nil)
                }
            }

            CommandGroup(replacing: .help) {
                Button("Jisticle Help") {
                    if let url = URL(string: "https://github.com/adamghill/jisticle") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
}

extension Notification.Name {
    static let createNewGist = Notification.Name("createNewGist")
}
