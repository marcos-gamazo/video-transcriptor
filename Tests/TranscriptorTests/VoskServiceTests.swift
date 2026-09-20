import Testing
import Foundation
@testable import Transcriptor

@Suite("VoskService")
struct VoskServiceTests {
    @Test("Negocia el formato PCM que requiere Vosk (16 kHz, mono, Int16)")
    func negotiatesFormat() async {
        let service = VoskService(locale: Locale(identifier: "es_ES"))
        let format = await service.negotiatedAudioFormat()
        #expect(format.sampleRate == 16_000)
        #expect(format.channelCount == 1)
        #expect(format.bitDepth == 16)
        #expect(format.isFloat == false)
        #expect(format.isInterleaved == true)
    }

    // MARK: - Unit tests de parsing (no requieren modelo ni media)

    @Test("Extrae el texto de un utterance JSON de Vosk")
    func parsesUtteranceText() {
        let json = #"{"result":[{"conf":1.0,"end":0.4,"start":0.0,"word":"hola"}],"text":"hola"}"#
        #expect(VoskService.transcriptionText(from: json) == "hola")
    }

    @Test("Devuelve nil cuando el utterance no tiene texto")
    func ignoresEmptyUtterance() {
        let json = #"{"text":""}"#
        let whitespace = #"{"text":"   "}"#
        #expect(VoskService.transcriptionText(from: json) == nil)
        #expect(VoskService.transcriptionText(from: whitespace) == nil)
        #expect(VoskService.transcriptionText(from: "no-es-json") == nil)
    }

    @Test("El inicio del segmento es el primer timestamp de palabra del utterance")
    func segmentStartUsesFirstWordTime() {
        let json = #"{"result":[{"end":0.4,"start":0.0,"word":"hola"},{"end":1.2,"start":0.45,"word":"mundo"}],"text":"hola mundo"}"#
        #expect(VoskService.segmentStart(json: json, previousEnd: 9) == 0.0)
        #expect(VoskService.segmentStart(json: #"{"text":"sin palabras"}"#, previousEnd: 3.5) == 3.5)
        #expect(VoskService.segmentStart(json: "no-es-json", previousEnd: 1.25) == 1.25)
    }

    @Test("El final del segmento se calcula desde la última palabra o desde el tiempo procesado")
    func segmentEndUsesLastWordTime() {
        let json = #"{"result":[{"end":0.4,"start":0.0,"word":"hola"},{"end":1.2,"start":0.45,"word":"mundo"}],"text":"hola mundo"}"#
        // Si la última palabra termina después del punto de lectura, manda el timestamp de palabra.
        #expect(VoskService.segmentEnd(json: json, elapsed: 0.9) == 1.2)
        // Si el audio ya procesado supera a la última palabra (silencio entre utterances), manda el tiempo procesado.
        #expect(VoskService.segmentEnd(json: json, elapsed: 10) == 10)
        // Sin timestamps de palabra, el final cae al tiempo procesado.
        #expect(VoskService.segmentEnd(json: #"{"text":"hola"}"#, elapsed: 7.5) == 7.5)
    }

    @Test("isValidModelDirectory rechaza directorios sin am/final.mdl")
    func rejectsDirectoryWithoutModelGraph() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("vosk-invalid-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        #expect(!VoskService.isValidModelDirectory(dir))

        let nested = dir.appendingPathComponent("am")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        #expect(!VoskService.isValidModelDirectory(dir), "Falta am/final.mdl, el directorio sigue siendo inválido.")
    }

    // MARK: - Mapeo de errores de descarga de modelo

    @Test("Los errores de conectividad de la descarga se traducen a offlineAssetInstallation")
    func mapsConnectivityErrorsToOffline() {
        #expect(VoskModelManager.mapDownloadError(URLError(.notConnectedToInternet))
                == .offlineAssetInstallation)
        #expect(VoskModelManager.mapDownloadError(URLError(.networkConnectionLost))
                == .offlineAssetInstallation)
        #expect(VoskModelManager.mapDownloadError(URLError(.timedOut))
                == .offlineAssetInstallation)
        #expect(VoskModelManager.mapDownloadError(URLError(.cannotConnectToHost))
                == .offlineAssetInstallation)
    }

    @Test("Los demás errores de red se traducen a downloadFailed")
    func mapsOtherErrorsToDownloadFailed() {
        let server = VoskModelManager.mapDownloadError(URLError(.badServerResponse))
        guard case .downloadFailed = server else {
            Issue.record("Se esperaba downloadFailed, recibido: \(server)")
            return
        }

        let other = VoskModelManager.mapDownloadError(
            NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "boom"])
        )
        guard case .downloadFailed = other else {
            Issue.record("Se esperaba downloadFailed, recibido: \(other)")
            return
        }
    }

    // MARK: - Requieren modelo instalado y media real

    @Test(
        "Transcribe el audio de prueba y produce segmentos con texto y tiempos",
        .enabled(if: voskIntegrationTestsEnabled))
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
        .enabled(if: voskIntegrationTestsEnabled))
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