import Foundation

struct TranscriptionJob: Identifiable, Equatable, Sendable {
    let id: UUID
    let sourceURL: URL
    let locale: Locale
    let includeTimestamps: Bool

    init(
        id: UUID = UUID(),
        sourceURL: URL,
        locale: Locale,
        includeTimestamps: Bool
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.locale = locale
        self.includeTimestamps = includeTimestamps
    }
}

enum TranscriptionJobState: Equatable, Sendable {
    case pending
    case preparing
    case downloading
    case transcribing
    case completed
    case cancelled
    case failed
}