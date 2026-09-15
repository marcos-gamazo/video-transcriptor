import Foundation

struct TranscriptionSegment: Equatable, Sendable {
    let start: Double
    let end: Double
    let text: String
}