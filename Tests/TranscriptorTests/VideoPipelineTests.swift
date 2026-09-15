import Testing
import Foundation
import AVFoundation
@testable import Transcriptor

@Suite("VideoPipeline", .serialized)
struct VideoPipelineTests {
    private static let isCancelled: @Sendable () -> Bool = { false }

    private static func fileType(forExtension ext: String) -> AVFileType {
        switch ext {
        case "mp4": return .mp4
        case "m4v": return .m4v
        default: return .mov
        }
    }

    private static func videoURL(fileExtension: String) async throws -> URL {
        try await TestVideoFactory.writeVideoWithAudioTrack(
            audioSource: TestsFixtures.meetingAudioURL(),
            fileExtension: fileExtension,
            fileType: fileType(forExtension: fileExtension)
        )
    }

    @Test("MediaAnalyzer acepta vídeo con audio", arguments: ["mov", "mp4", "m4v"])
    func analyzesVideoWithAudio(fileExtension: String) async throws {
        let url = try await Self.videoURL(fileExtension: fileExtension)
        defer { try? FileManager.default.removeItem(at: url) }

        let info = try await MediaAnalyzer().analyze(url: url)
        #expect(info.url == url)
        let seconds = Double(info.duration.components.seconds)
            + Double(info.duration.components.attoseconds) / 1e18
        #expect(seconds > 55 && seconds < 65, "Duración observada: \(seconds) s")
    }

    @Test("El stream lee todo el audio del vídeo", arguments: ["mov", "mp4", "m4v"])
    func streamsAllVideoFrames(fileExtension: String) async throws {
        let url = try await Self.videoURL(fileExtension: fileExtension)
        defer { try? FileManager.default.removeItem(at: url) }

        let format = AudioStreamProvider.fallbackFormat
        let stream = AudioStreamProvider.makeStream(url: url, format: format)

        var iterator = stream.makeAsyncIterator()
        var buffers = 0
        var frames: Int64 = 0
        while let input = try await iterator.next() {
            buffers += 1
            frames += Int64(input.buffer.frameLength)
            #expect(input.buffer.format.sampleRate == format.sampleRate)
            #expect(input.buffer.format.channelCount == format.channelCount)
        }

        #expect(buffers > 50, "Se esperaban decenas de buffers, se leyeron \(buffers)")
        #expect(frames > 900_000 && frames < 1_000_000, "Frames totales: \(frames)") // 950 841 en el Spike
    }

    @Test("Transcribe el audio de un vídeo", arguments: ["mov", "mp4", "m4v"])
    func transcribesVideoAudio(fileExtension: String) async throws {
        let url = try await Self.videoURL(fileExtension: fileExtension)
        defer { try? FileManager.default.removeItem(at: url) }

        let service = SpeechAnalyzerService(locale: Locale(identifier: "es_ES"))
        let collector = SegmentCollector()
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

    @Test("El stream de un vídeo sin audio devuelve missingAudioTrack")
    func rejectsVideoWithoutAudioTrack() async throws {
        let url = try TestVideoFactory.writeVideoWithoutAudioTrack()
        defer { try? FileManager.default.removeItem(at: url) }

        let stream = AudioStreamProvider.makeStream(url: url, format: AudioStreamProvider.fallbackFormat)
        do {
            var iterator = stream.makeAsyncIterator()
            _ = try await iterator.next()
            Issue.record("Se esperaba missingAudioTrack.")
        } catch let error as MediaError {
            #expect(error == .missingAudioTrack)
        } catch {
            Issue.record("Error inesperado: \(error)")
        }
    }

    @Test("La cancelación detiene la lectura del vídeo de inmediato")
    func cancellationStopsVideoReadingEarly() async throws {
        let url = try await Self.videoURL(fileExtension: "mov")
        defer { try? FileManager.default.removeItem(at: url) }

        final class Probe: @unchecked Sendable {
            var stop = false
        }
        let probe = Probe()
        let format = AudioStreamProvider.fallbackFormat
        let stream = AudioStreamProvider.makeStream(url: url, format: format, isCancelled: { probe.stop })

        var iterator = stream.makeAsyncIterator()
        var buffers = 0
        while let _ = try await iterator.next() {
            buffers += 1
            if buffers == 3 {
                probe.stop = true
            }
        }

        #expect(buffers == 3,
                "La cancelación debería detener la lectura de inmediato, pero se leyeron \(buffers) buffers")
    }

    @Test("La lectura de un vídeo no crea archivos temporales de audio")
    func noTemporaryAudioFileDuringVideoRead() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("video-no-temp-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let url = try await TestVideoFactory.writeVideoWithAudioTrack(
            audioSource: TestsFixtures.meetingAudioURL(),
            fileExtension: "mov",
            fileType: .mov,
            in: dir
        )
        let before = try FileManager.default.contentsOfDirectory(atPath: dir.path).sorted()

        let stream = AudioStreamProvider.makeStream(url: url, format: AudioStreamProvider.fallbackFormat)
        var iterator = stream.makeAsyncIterator()
        var buffers = 0
        while let _ = try await iterator.next() {
            buffers += 1
        }
        #expect(buffers > 50)

        let after = try FileManager.default.contentsOfDirectory(atPath: dir.path).sorted()
        #expect(after == before, "La lectura no debería crear archivos temporales.")
    }
}

private final class SegmentCollector: @unchecked Sendable {
    var segments: [TranscriptionSegment] = []
}