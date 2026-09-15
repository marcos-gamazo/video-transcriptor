import Foundation

/// Servicio de transcripción local con Vosk (Kaldi).
///
/// Fase 1: solo define el contrato y la negociación de formato. La integración
/// real con `libvosk` se implementa en Fase 3 (OpenSpec create-legacy-intel,
/// task 3.x). Hasta entonces `transcribe` lanza `VoskError.transcriptionNotAvailable`.
actor VoskService {
    private let locale: Locale

    init(locale: Locale) {
        self.locale = locale
    }

    /// Vosk requiere PCM mono 16 kHz, 16 bits, entero, interleaved.
    func negotiatedAudioFormat() -> AudioStreamFormat? {
        AudioStreamFormat(
            sampleRate: 16_000,
            channelCount: 1,
            bitDepth: 16,
            isFloat: false,
            isInterleaved: true
        )
    }

    func transcribe(
        url: URL,
        onSegment: @escaping @Sendable (TranscriptionSegment) -> Void
    ) async throws -> TranscriptionSummary {
        throw VoskError.transcriptionNotAvailable
    }
}