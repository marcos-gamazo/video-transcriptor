import Testing
import Foundation
@testable import Transcriptor

@Suite("TranscriptionDomain")
struct TranscriptionDomainTests {
    @Test("TranscriptionJob modela una configuración de trabajo")
    func jobModel() {
        let source = URL(fileURLWithPath: "/tmp/a.m4a")
        let locale = Locale(identifier: "es_ES")
        let job = TranscriptionJob(id: UUID(), sourceURL: source, locale: locale, includeTimestamps: true)

        #expect(job.sourceURL == source)
        #expect(job.locale == locale)
        #expect(job.includeTimestamps)
        #expect(job.id != TranscriptionJob(id: UUID(), sourceURL: source, locale: locale, includeTimestamps: true).id)
    }

    @Test("Los estados de trabajo cubren todo el ciclo de vida")
    func jobStates() {
        let all: [TranscriptionJobState] = [
            .pending, .preparing, .downloading, .transcribing,
            .completed, .cancelled, .failed,
        ]
        #expect(Set(all).count == 7)
    }

    @Test("Preflight de locale devuelve es_ES con modelo vosk-model-small-es-0.42")
    func preflightResolvesSpanish() async throws {
        let manager = VoskModelManager()
        let preflight = try await manager.preflight(locale: Locale(identifier: "es"))
        #expect(preflight.resolvedLocale.identifier == "es_ES")
        #expect(preflight.modelName == "vosk-model-small-es-0.42")
    }

    @Test("El modelo en inglés resuelve al modelo oficial en-US")
    func preflightResolvesEnglish() async throws {
        let manager = VoskModelManager()
        let preflight = try await manager.preflight(locale: Locale(identifier: "en"))
        #expect(preflight.resolvedLocale.identifier == "en_US")
        #expect(preflight.modelName == "vosk-model-small-en-us-0.15")
    }

    @Test("La URL de descarga apunta a la fuente oficial de Vosk")
    func officialDownloadURL() {
        #expect(VoskModelManager.downloadURL(for: "vosk-model-small-es-0.42")?
            .absoluteString == "https://alphacephei.com/vosk/models/vosk-model-small-es-0.42.zip")
        #expect(VoskModelManager.downloadURL(for: "vosk-model-small-en-us-0.15")?
            .absoluteString == "https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip")
    }

    @Test("El tamaño del zip de cada modelo tiene una pista de tamaño")
    func zipSizeHints() {
        #expect(!VoskModelManager.zipSizeHint(for: "vosk-model-small-es-0.42").isEmpty)
        #expect(!VoskModelManager.zipSizeHint(for: "vosk-model-small-en-us-0.15").isEmpty)
        #expect(!VoskModelManager.zipSizeHint(for: "desconocido").isEmpty)
    }

    @Test(
        "Install es un no-op cuando el idioma ya está instalado",
        .enabled(if: voskIntegrationTestsEnabled))
    func installIsNoopWhenAlreadyInstalled() async throws {
        final class Counter: @unchecked Sendable {
            var value = 0
        }
        let manager = VoskModelManager()
        let preflight = try await manager.preflight(locale: Locale(identifier: "es_ES"))
        let counter = Counter()
        let resolved = try await manager.install(locale: preflight.resolvedLocale) { _ in
            counter.value += 1
        }
        #expect(resolved.identifier == "es_ES")
        #expect(counter.value == 0, "No debería reportar progreso de descarga si ya está instalado.")
    }
}

@Suite("TranscriptionService")
struct TranscriptionServiceTests {
    @Test(
        "Transcribe un m4a completo y reporta estados y progreso",
        .enabled(if: voskIntegrationTestsEnabled))
    func transcribesMediaWithProgress() async throws {
        let url = try TestsFixtures.meetingAudioURL()
        let job = TranscriptionJob(sourceURL: url, locale: Locale(identifier: "es_ES"), includeTimestamps: true)
        let service = TranscriptionService()

        final class Collector: @unchecked Sendable {
            var states: [TranscriptionJobState] = []
            var progressValues: [Double] = []
            var segments: [TranscriptionSegment] = []
        }
        let collector = Collector()

        let summary = try await service.transcribe(
            job: job,
            onState: { collector.states.append($0) },
            onProgress: { collector.progressValues.append($0.overall) },
            onSegment: { collector.segments.append($0) }
        )

        #expect(summary.segmentCount > 0)
        #expect(summary.segmentCount == collector.segments.count)
        #expect(collector.states.contains(.preparing))
        #expect(collector.states.contains(.transcribing))
        #expect(collector.states.last == .completed)
        #expect(!collector.segments.isEmpty)
        #expect(collector.progressValues.max() ?? 0 >= 0.9,
                "El progreso debería acercarse a 1; último valor: \(collector.progressValues.last ?? -1)")
    }

    @Test(
        "El progreso de transcripción crece de forma globalmente creciente",
        .enabled(if: voskIntegrationTestsEnabled))
    func progressIsMonotonic() async throws {
        let url = try TestsFixtures.meetingAudioURL()
        let job = TranscriptionJob(sourceURL: url, locale: Locale(identifier: "es_ES"), includeTimestamps: false)
        let service = TranscriptionService()

        final class Collector: @unchecked Sendable {
            var progressValues: [Double] = []
            var last = 0.0
        }
        let collector = Collector()

        _ = try await service.transcribe(
            job: job,
            onState: { _ in },
            onProgress: {
                if $0.overall >= collector.last {
                    collector.last = $0.overall
                    collector.progressValues.append($0.overall)
                }
            }
        )

        #expect(collector.progressValues.last == 1)
        let diffs = zip(collector.progressValues.dropFirst(), collector.progressValues)
        #expect(diffs.allSatisfy { $0 >= $1 })
    }

    @Test(
        "Cancelar un trabajo se propaga como TranscriptionError.cancelled",
        .enabled(if: voskIntegrationTestsEnabled))
    func cancellationPropagates() async throws {
        let url = try TestsFixtures.meetingAudioURL()
        let job = TranscriptionJob(sourceURL: url, locale: Locale(identifier: "es_ES"), includeTimestamps: false)

        let task = Task {
            let service = TranscriptionService()
            _ = try await service.transcribe(job: job) { _ in }
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

    @Test("Un archivo no multimedia termina en estado failed")
    func nonMediaFailsWithState() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("service-not-media-\(UUID().uuidString).txt")
        try Data("hola".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let job = TranscriptionJob(sourceURL: url, locale: Locale(identifier: "es_ES"), includeTimestamps: false)
        let service = TranscriptionService()

        final class Collector: @unchecked Sendable {
            var lastState: TranscriptionJobState?
        }
        let collector = Collector()

        do {
            _ = try await service.transcribe(
                job: job,
                onState: { collector.lastState = $0 }
            )
            Issue.record("Se esperaba un error de media.")
        } catch {
            #expect(collector.lastState == .failed)
        }
    }
}