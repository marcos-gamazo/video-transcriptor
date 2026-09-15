import Foundation

struct TranscriptionSegment: Equatable, Sendable {
    let start: Duration
    let end: Duration
    let text: String
}