import SwiftUI

@main
struct TranscriptorApp: App {
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
                    LogPresenter.shared.isPresented = true
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            }
        }
    }
}