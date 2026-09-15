import Testing
import Foundation
@testable import Transcriptor

@Suite("VoskService")
struct VoskServiceTests {
    @Test("Negocia el formato PCM que requiere Vosk (16 kHz, mono, Int16)")
    func negotiatesFormat() async {
        let service = VoskService(locale: Locale(identifier: "es_ES"))
        let format = await service.negotiatedAudioFormat()
        #expect(format != nil)
        #expect(format?.sampleRate == 16_000)
        #expect(format?.channelCount == 1)
        #expect(format?.bitDepth == 16)
        #expect(format?.isFloat == false)
        #expect(format?.isInterleaved == true)
    }

    @Test("Fase 1: transcribe aún no disponible hasta integrar libvosk")
    func transcribeUnavailableInPhase1() async {
        let url = URL(fileURLWithPath: "/tmp/placeholder.m4a")
        let service = VoskService(locale: Locale(identifier: "es_ES"))
        do {
            _ = try await service.transcribe(url: url) { _ in }
            Issue.record("Se esperaba VoskError.transcriptionNotAvailable en Fase 1.")
        } catch let error as VoskError {
            #expect(error == .transcriptionNotAvailable)
        } catch {
            Issue.record("Error inesperado: \(error)")
        }
    }

    // MARK: - Requieren VoskService integrado (Fase 3)

    @Test(
        "Transcribe el audio de prueba y produce segmentos con texto y tiempos",
        .disabled("Requiere la integración de libvosk (Fase 3)."))
    func transcribesFixture() async throws {
        let url = try TestsFixtures.meetingAudioURL()
        let service = VoskService(locale: Locale(identifier: "es_ES"))

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
        #expect(lastEnd > 45 && lastEnd < 70, "Fin observado: \(lastEnd) s")

        let joined = segments.map(\.text).joined(separator: " ")
        #expect(joined.localizedCaseInsensitiveContains("buenos días"),
                "El texto transcrito debería contener la frase inicial del fixture.")
    }

    @Test(
        "Cancelar se propaga como TranscriptionError.cancelled",
        .disabled("Requiere la integración de libvosk (Fase 3)."))
    func cancellationPropagates() async throws {
        let url = try TestsFixtures.meetingAudioURL()

        let task = Task {
            let service = VoskService(locale: Locale(identifier: "es_ES"))
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