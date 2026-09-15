import Foundation

protocol Transcribing: Sendable {
    func transcribe(
        job: TranscriptionJob,
        onState: @escaping @Sendable (TranscriptionJobState) -> Void,
        onProgress: @escaping @Sendable (TranscriptionProgress) -> Void,
        onSegment: @escaping @Sendable (TranscriptionSegment) -> Void
    ) async throws -> TranscriptionSummary
}