import Foundation
import AVFAudio
import CVosk

/// Resultado de un utterance de Vosk con timestamps por palabra.
private struct VoskWord: Decodable {
    let start: Double
    let end: Double
    let word: String
}

private struct VoskUtterance: Decodable {
    let text: String
    let result: [VoskWord]?
}

/// Servicio de transcripción local con Vosk (Kaldi).
///
/// Fase 3: integración real con `libvosk.dylib` mediante el módulo C `CVosk`.
/// Requiere que el modelo del idioma esté instalado (ver `VoskModelManager`).
actor VoskService {
    private let locale: Locale

    init(locale: Locale) {
        self.locale = locale
    }

    /// Vosk requiere PCM mono 16 kHz, 16 bits, entero, interleaved.
    func negotiatedAudioFormat() -> AudioStreamFormat {
        AudioStreamFormat(
            sampleRate: 16_000,
            channelCount: 1,
            bitDepth: 16,
            isFloat: false,
            isInterleaved: true
        )
    }

    private var modelURL: URL? {
        guard let modelName = VoskModelManager.modelName(for: locale) else { return nil }
        return VoskModelManager.modelsDirectory.appendingPathComponent(modelName, isDirectory: true)
    }

    func transcribe(
        url: URL,
        onSegment: @escaping @Sendable (TranscriptionSegment) -> Void = { _ in }
    ) async throws -> TranscriptionSummary {
        guard let modelURL = modelURL, Self.isValidModelDirectory(modelURL) else {
            throw VoskError.modelNotFound
        }

        let stream = AudioStreamProvider.makeStream(url: url, format: negotiatedAudioFormat())

        vosk_set_log_level(0)

        let model = modelURL.path.withCString { vosk_model_new($0) }
        guard let model else {
            throw VoskError.modelCorrupted("El modelo no se pudo cargar")
        }
        defer { vosk_model_free(model) }

        guard let recognizer = vosk_recognizer_new(model, 16_000) else {
            throw VoskError.modelCorrupted("No se pudo crear el recognition engine")
        }
        defer { vosk_recognizer_free(recognizer) }

        vosk_recognizer_set_words(recognizer, 1)

        var segmentCount = 0
        var lastEnd: Double?
        var framesFed: Int64 = 0

        do {
            var iterator = stream.makeAsyncIterator()
            while let input = try await iterator.next() {
                guard !Task.isCancelled else { break }
                try Task.checkCancellation()

                let frames = Int64(input.buffer.frameLength)
                let accepted = Self.acceptWaveform(recognizer: recognizer, buffer: input.buffer)
                framesFed += frames

                if accepted == 1, let json = vosk_recognizer_result(recognizer) {
                    let string = String(cString: json)
                    if let text = Self.transcriptionText(from: string) {
                        let end = Self.segmentEnd(json: string, elapsed: Self.elapsedSeconds(frames: framesFed))
                        let start = Self.segmentStart(json: string, previousEnd: lastEnd)
                        guard end >= start else { continue }
                        lastEnd = end
                        segmentCount += 1
                        onSegment(TranscriptionSegment(start: start, end: end, text: text))
                    }
                }
            }

            guard !Task.isCancelled else { throw TranscriptionError.cancelled }
            try Task.checkCancellation()

            if let finalJSON = vosk_recognizer_final_result(recognizer) {
                let string = String(cString: finalJSON)
                if let text = Self.transcriptionText(from: string) {
                    let end = Self.segmentEnd(json: string, elapsed: Self.elapsedSeconds(frames: framesFed))
                    let start = Self.segmentStart(json: string, previousEnd: lastEnd)
                    lastEnd = end
                    segmentCount += 1
                    onSegment(TranscriptionSegment(start: start, end: end, text: text))
                }
            }
        } catch let error as TranscriptionError {
            throw error
        } catch let error as MediaError {
            throw error
        } catch is CancellationError {
            throw TranscriptionError.cancelled
        }

        return TranscriptionSummary(segmentCount: segmentCount, finalEndTime: lastEnd)
    }

    // MARK: - Parsing

    private static func elapsedSeconds(frames: Int64) -> Double {
        Double(frames) / 16_000.0
    }

    static func transcriptionText(from json: String) -> String? {
        guard let data = json.data(using: .utf8),
              let utterance = try? JSONDecoder().decode(VoskUtterance.self, from: data) else {
            return nil
        }
        let text = utterance.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    static func segmentStart(json: String, previousEnd: Double?) -> Double {
        guard let data = json.data(using: .utf8),
              let utterance = try? JSONDecoder().decode(VoskUtterance.self, from: data),
              let words = utterance.result, let first = words.first else {
            return previousEnd ?? 0
        }
        return first.start
    }

    static func segmentEnd(json: String, elapsed: Double) -> Double {
        guard let data = json.data(using: .utf8),
              let utterance = try? JSONDecoder().decode(VoskUtterance.self, from: data),
              let words = utterance.result, let last = words.last else {
            return elapsed
        }
        return max(last.end, elapsed)
    }

    // MARK: - Puente C

    private static func acceptWaveform(
        recognizer: OpaquePointer,
        buffer: AVAudioPCMBuffer
    ) -> Int32 {
        let list = UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList)
        guard let audioBuffer = list.first,
              let data = audioBuffer.mData,
              audioBuffer.mDataByteSize > 0 else {
            return 0
        }
        return vosk_recognizer_accept_waveform(
            recognizer,
            data.assumingMemoryBound(to: CChar.self),
            Int32(audioBuffer.mDataByteSize)
        )
    }

    static func isValidModelDirectory(_ url: URL) -> Bool {
        let am = url.appendingPathComponent("am/final.mdl")
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: am.path, isDirectory: &isDirectory)
            && !isDirectory.boolValue
    }
}