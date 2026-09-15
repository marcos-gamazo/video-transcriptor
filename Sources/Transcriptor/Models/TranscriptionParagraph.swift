import Foundation

struct TranscriptionParagraph: Equatable, Sendable {
    let start: Duration
    let text: String
}