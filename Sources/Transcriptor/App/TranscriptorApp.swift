import SwiftUI

@main
struct TranscriptorApp: App {
    @Environment(\.openWindow) private var openWindow

    init() {
        AppLogger.app.log(level: .info, "Inicio de Transcriptor (\(AppEnvironment.bundleIdentifier))")
    }

    var body: some Scene {
        WindowGroup {
            TranscriptionView()
        }
        .commands {
            CommandMenu("Registro") {
                Button("Ver registro…") {
                    openWindow(id: "log")
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            }
        }

        Window("Registro", id: "log") {
            LogView()
        }
        .defaultSize(width: 720, height: 460)
    }
}