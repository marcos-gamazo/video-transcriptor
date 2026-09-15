import Foundation
import OSLog

/// Registro estructurado de la aplicación.
///
/// Cada categoría escribe a `os_log` para diagnóstico del sistema y, a la
/// vez, copia la entrada en `LogStore` para poder consultarla desde la UI.
struct AppLogger {
    static let app = Category(name: "app")
    static let speech = Category(name: "speech")
    static let audio = Category(name: "audio")
    static let export = Category(name: "export")
    static let queue = Category(name: "queue")

    struct Category: Sendable {
        let name: String
        fileprivate let osLogger: Logger

        fileprivate init(name: String) {
            self.name = name
            self.osLogger = Logger(subsystem: AppEnvironment.bundleIdentifier, category: name)
        }

        func info(_ message: String) {
            write(level: .info, message: message)
        }

        func error(_ message: String) {
            write(level: .error, message: message)
        }

        func log(level: LogLevel, _ message: String) {
            write(level: level, message: message)
        }

        private func write(level: LogLevel, message: String) {
            osLogger.log(level: level.osLevel, "\(message, privacy: .public)")
            let record = LogEntryRecord(level: level, category: name, message: message)
            Task { @MainActor in
                LogStore.shared.append(record)
            }
        }
    }
}

extension LogLevel {
    var osLevel: OSLogType {
        switch self {
        case .debug: .debug
        case .info: .info
        case .error: .error
        }
    }
}