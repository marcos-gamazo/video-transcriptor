import Foundation

actor TranscriptionService: Transcribing {
    private let mediaAnalyzer = MediaAnalyzer()
    private let modelManager = VoskModelManager()

    func transcribe(
        job: TranscriptionJob,
        onState: @escaping @Sendable (TranscriptionJobState) -> Void = { _ in },
        onProgress: @escaping @Sendable (TranscriptionProgress) -> Void = { _ in },
        onSegment: @escaping @Sendable (TranscriptionSegment) -> Void = { _ in }
    ) async throws -> TranscriptionSummary {
        do {
            onState(.preparing)

            let mediaInfo = try await mediaAnalyzer.analyze(url: job.sourceURL)
            let totalSeconds = mediaInfo.duration

            let preflight = try await modelManager.preflight(locale: job.locale)
            if !preflight.installed {
                onState(.downloading)
                _ = try await modelManager.install(locale: preflight.resolvedLocale) { fraction in
                    onProgress(TranscriptionProgress(
                        overall: 0.5 * fraction,
                        download: fraction,
                        transcription: 0
                    ))
                }
            }
            try Task.checkCancellation()

            onState(.transcribing)
            let vosk = VoskService(locale: preflight.resolvedLocale)
            let summary = try await vosk.transcribe(url: job.sourceURL) { segment in
                onSegment(segment)
                guard totalSeconds > 0 else { return }
                let fraction = min(1, segment.end / totalSeconds)
                onProgress(TranscriptionProgress(
                    overall: 0.5 + 0.5 * fraction,
                    download: 0,
                    transcription: fraction
                ))
            }

            onState(.completed)
            onProgress(TranscriptionProgress(overall: 1, download: 0, transcription: 1))
            return summary
        } catch {
            if Task.isCancelled {
                AppLogger.queue.info("Transcripción cancelada por el usuario")
                onState(.cancelled)
                throw TranscriptionError.cancelled
            }
            if error is TranscriptionError {
                onState(.cancelled)
                throw error
            }
            onState(.failed)
            throw error
        }
    }
}