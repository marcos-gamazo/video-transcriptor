import Foundation
import Observation

enum LogLevel: String, Sendable {
    case debug
    case info
    case error
}

struct LogEntryRecord: Identifiable, Equatable, Sendable {
    let id: UUID
    let date: Date
    let level: LogLevel
    let category: String
    let message: String

    init(
        id: UUID = UUID(),
        date: Date = .now,
        level: LogLevel,
        category: String,
        message: String
    ) {
        self.id = id
        self.date = date
        self.level = level
        self.category = category
        self.message = message
    }
}

/// Retiene en memoria las últimas entradas de registro para poder
/// consultarlas desde la UI. El buffer es acotado para no crecer sin límite.
@MainActor
@Observable
final class LogStore {
    static let shared = LogStore()

    private(set) var entries: [LogEntryRecord] = []
    let capacity = 1000

    func append(_ entry: LogEntryRecord) {
        entries.append(entry)
        if entries.count > capacity {
            entries.removeFirst(entries.count - capacity)
        }
    }

    func clear() {
        entries.removeAll()
    }
}