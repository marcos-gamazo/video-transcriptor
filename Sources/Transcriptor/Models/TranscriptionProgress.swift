import Foundation

struct TranscriptionProgress: Equatable, Sendable {
    let overall: Double
    let download: Double
    let transcription: Double
}