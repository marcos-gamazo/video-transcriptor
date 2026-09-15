import Testing
import Foundation
@testable import Transcriptor

@Suite("AudioStreamProvider")
struct AudioStreamProviderTests {
    private let format = AudioStreamProvider.fallbackFormat

    @Test("Lee todos los frames de un m4a de forma incremental")
    func readsAllFramesIncrementally() async throws {
        let url = try TestsFixtures.meetingAudioURL()
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

    @Test("La cancelación detiene la lectura de inmediato")
    func cancellationStopsReadingEarly() async throws {
        let url = try TestsFixtures.meetingAudioURL()

        final class Probe: @unchecked Sendable {
            var stop = false
        }
        let probe = Probe()
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

    @Test("Un archivo sin pista de audio produce un error de media")
    func rejectsNonAudioMedia() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("stream-not-media-\(UUID().uuidString).txt")
        try Data("hola".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let stream = AudioStreamProvider.makeStream(url: url, format: format)
        await #expect(throws: MediaError.self) {
            var iterator = stream.makeAsyncIterator()
            _ = try await iterator.next()
        }
    }
}