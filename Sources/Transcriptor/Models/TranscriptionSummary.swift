import Foundation

struct TranscriptionSummary: Equatable, Sendable {
    let segmentCount: Int
    let finalEndTime: Duration?
}