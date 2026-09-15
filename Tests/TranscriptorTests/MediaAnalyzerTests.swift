import Testing
import Foundation
import AVFoundation
@testable import Transcriptor

@Suite("MediaAnalyzer")
struct MediaAnalyzerTests {
    @Test("Analiza un m4a y obtiene su duración")
    func analyzesAudioFile() async throws {
        let url = try TestsFixtures.meetingAudioURL()
        let info = try await MediaAnalyzer().analyze(url: url)
        #expect(info.url == url)
        let seconds = Double(info.duration.components.seconds)
            + Double(info.duration.components.attoseconds) / 1e18
        #expect(seconds > 55 && seconds < 65, "Duración observada: \(seconds) s")
    }

    @Test("Un archivo que no es multimedia devuelve un error de media")
    func rejectsPlainTextFile() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("not-media-\(UUID().uuidString).txt")
        try Data("hola".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        await #expect(throws: MediaError.self) {
            _ = try await MediaAnalyzer().analyze(url: url)
        }
    }

    @Test("Un archivo inexistente devuelve un error de media")
    func rejectsMissingFile() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString).m4a")

        await #expect(throws: MediaError.self) {
            _ = try await MediaAnalyzer().analyze(url: url)
        }
    }

    @Test("Un vídeo sin pista de audio devuelve missingAudioTrack")
    func rejectsVideoWithoutAudio() async throws {
        let url = try TestVideoFactory.writeVideoWithoutAudioTrack()
        defer { try? FileManager.default.removeItem(at: url) }

        do {
            _ = try await MediaAnalyzer().analyze(url: url)
            Issue.record("Se esperaba missingAudioTrack.")
        } catch let error as MediaError {
            #expect(error == .missingAudioTrack)
        } catch {
            Issue.record("Error inesperado: \(error)")
        }
    }
}