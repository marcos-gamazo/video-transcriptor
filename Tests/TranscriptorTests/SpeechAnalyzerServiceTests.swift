import Testing
import Foundation
@testable import Transcriptor

@Suite("SpeechAnalyzerService")
struct SpeechAnalyzerServiceTests {
    @Test("Negocia un formato de audio compatible")
    func negotiatesFormat() async {
        let service = SpeechAnalyzerService(locale: Locale(identifier: "es_ES"))
        let format = await service.negotiatedAudioFormat()
        #expect(format != nil)
        #expect(format?.sampleRate ?? 0 > 0)
        #expect(format?.channelCount ?? 0 > 0)
    }

    @Test("Transcribe el audio de prueba y produce segmentos con texto y tiempos")
    func transcribesFixture() async throws {
        let url = try TestsFixtures.meetingAudioURL()
        let service = SpeechAnalyzerService(locale: Locale(identifier: "es_ES"))

        final class Collector: @unchecked Sendable {
            var segments: [TranscriptionSegment] = []
        }
        let collector = Collector()
        let summary = try await service.transcribe(url: url) { segment in
            collector.segments.append(segment)
        }
        let segments = collector.segments

        #expect(summary.segmentCount > 0)
        #expect(segments.count == summary.segmentCount)
        #expect(segments.allSatisfy { !$0.text.isEmpty })
        #expect(segments.allSatisfy { $0.start <= $0.end })

        guard let lastEnd = summary.finalEndTime else {
            Issue.record("Se esperaba un final de transcripción.")
            return
        }
        let lastEndSeconds = Double(lastEnd.components.seconds)
            + Double(lastEnd.components.attoseconds) / 1e18
        #expect(lastEndSeconds > 45 && lastEndSeconds < 70, "Fin observado: \(lastEndSeconds) s")

        let joined = segments.map(\.text).joined(separator: " ")
        #expect(joined.localizedCaseInsensitiveContains("buenos días"),
                "El texto transcrito debería contener la frase inicial del fixture.")
    }

    @Test("Cancelar se propaga como TranscriptionError.cancelled")
    func cancellationPropagates() async throws {
        let url = try TestsFixtures.meetingAudioURL()

        let task = Task {
            let service = SpeechAnalyzerService(locale: Locale(identifier: "es_ES"))
            _ = try await service.transcribe(url: url) { _ in }
        }
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Se esperaba que la cancelación produjera un error.")
        } catch let error as TranscriptionError {
            #expect(error == .cancelled)
        } catch {
            Issue.record("Error inesperado: \(error)")
        }
    }
}