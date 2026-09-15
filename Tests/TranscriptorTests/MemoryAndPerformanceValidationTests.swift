import Testing
import Foundation
import AVFoundation
@testable import Transcriptor

/// Las pruebas largas de memoria solo se ejecutan cuando se solicitan
/// explícitamente, para no ralentizar la ejecución normal de `swift test`.
private let validationRequested =
    ProcessInfo.processInfo.environment["TRANSCRIPTOR_MEMORY_VALIDATION"] != nil

private let audioMinutes = envInt("TRANSCRIPTOR_MEM_SYNTH_MINUTES") ?? 30
private let videoMinutes = envInt("TRANSCRIPTOR_MEM_VIDEO_MINUTES") ?? 15
private let formatMinutes = envInt("TRANSCRIPTOR_MEM_FORMAT_MINUTES") ?? 2
private let cancellationMinutes = envInt("TRANSCRIPTOR_MEM_CANCEL_MINUTES") ?? 10
private let mediaAudioPath = ProcessInfo.processInfo.environment["TRANSCRIPTOR_MEM_MEDIA_AUDIO"]
private let mediaVideoPath = ProcessInfo.processInfo.environment["TRANSCRIPTOR_MEM_MEDIA_VIDEO"]
private let multiHourMinutes = envInt("TRANSCRIPTOR_MEM_MULTIHOUR_MINUTES")
private let multiHourConfigured = mediaAudioPath != nil || multiHourMinutes != nil

private func envInt(_ key: String) -> Int? {
    ProcessInfo.processInfo.environment[key].flatMap(Int.init)
}

@Suite("Validación de memoria y rendimiento",
    .enabled(if: validationRequested),
    .serialized)
struct MemoryAndPerformanceValidationTests {
    private static let scratchDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("mem-validation-\(UUID().uuidString)")

    private static func makeScratchDir() throws {
        if FileManager.default.fileExists(atPath: scratchDir.path) {
            try FileManager.default.removeItem(at: scratchDir)
        }
        try FileManager.default.createDirectory(at: scratchDir, withIntermediateDirectories: true)
    }

    private static func job(url: URL) -> TranscriptionJob {
        TranscriptionJob(sourceURL: url, locale: Locale(identifier: "es_ES"), includeTimestamps: false)
    }

    /// Transcribe con TranscriberService de producción muestreando memoria.
    private static func transcribeSampling(
        _ url: URL,
        sampler: MemorySampler
    ) async throws {
        try await sampler.run(interval: (50)/1000.0) {
            _ = try await TranscriptionService().transcribe(job: job(url: url)) { _ in }
        }
    }

    @Test("11.8/11.9 La transcripción de 30 min mantiene la memoria acotada")
    func audio30MinutesMemoryBounded() async throws {
        try Self.makeScratchDir()
        defer { try? FileManager.default.removeItem(at: Self.scratchDir) }

        let url: URL
        if let path = mediaAudioPath {
            url = URL(fileURLWithPath: path)
        } else {
            url = try SyntheticLongMedia.writeSilenceWav(
                durationSeconds: audioMinutes * 60,
                in: Self.scratchDir
            )
        }

        let sampler = MemorySampler()
        try await Self.transcribeSampling(url, sampler: sampler)
        let snapshot = sampler.snapshot()

        #expect(!snapshot.samples.isEmpty, "No se muestreó memoria durante la transcripción.")
        assertBoundedGrowth(samples: snapshot.samples)
        #expect(snapshot.peak <= 2_000 * 1024 * 1024,
                "Pico de memoria excesivo: \(snapshot.peak.miB).")
        print("MEM-SUMMARY audio30min duración=\(audioMinutes)min pico=\(snapshot.peak.miB) muestras=\(snapshot.samples.count)")
    }

    @Test("11.6 La transcripción de varias horas mantiene la memoria acotada",
        .enabled(if: multiHourConfigured))
    func multiHourAudioMemoryBounded() async throws {
        try Self.makeScratchDir()
        defer { try? FileManager.default.removeItem(at: Self.scratchDir) }

        let url: URL
        if let path = mediaAudioPath {
            url = URL(fileURLWithPath: path)
        } else {
            let minutes = multiHourMinutes ?? 180
            url = try SyntheticLongMedia.writeSilenceWav(durationSeconds: minutes * 60, in: Self.scratchDir)
        }

        let info = try await MediaAnalyzer().analyze(url: url)
        let duration = info.duration
        #expect(duration >= 150 * 60, "El archivo origen no tiene al menos ~2,5 horas: \(duration) s")

        let sampler = MemorySampler()
        try await Self.transcribeSampling(url, sampler: sampler)
        assertBoundedGrowth(samples: sampler.snapshot().samples)
        #expect(sampler.peak <= 2_000 * 1024 * 1024,
                "Pico de memoria excesivo: \(sampler.peak.miB).")
        print("MEM-SUMMARY multihour duración=\(Int(duration / 60))min pico=\(sampler.peak.miB) muestras=\(sampler.snapshot().samples.count)")
    }

    @Test("11.7 La transcripción de un vídeo largo mantiene la memoria acotada y no crea temporales")
    func longVideoMemoryBounded() async throws {
        try Self.makeScratchDir()
        defer { try? FileManager.default.removeItem(at: Self.scratchDir) }

        let url: URL
        if let path = mediaVideoPath {
            url = URL(fileURLWithPath: path)
        } else {
            url = try await SyntheticLongMedia.writeLongSilentVideo(
                durationSeconds: videoMinutes * 60,
                fileExtension: "mov",
                fileType: .mov,
                in: Self.scratchDir
            )
        }

        let before = try FileManager.default.contentsOfDirectory(atPath: Self.scratchDir.path).sorted()

        let sampler = MemorySampler()
        try await Self.transcribeSampling(url, sampler: sampler)

        let after = try FileManager.default.contentsOfDirectory(atPath: Self.scratchDir.path).sorted()
        #expect(after == before,
                "La transcripción creó archivos temporales innecesarios: \(after).")

        assertBoundedGrowth(samples: sampler.snapshot().samples)
        #expect(sampler.peak <= 2_000 * 1024 * 1024,
                "Pico de memoria excesivo: \(sampler.peak.miB).")
    }

    @Test("11.10 La memoria no crece linealmente con la duración")
    func memoryDoesNotGrowLinearly() async throws {
        try Self.makeScratchDir()
        defer { try? FileManager.default.removeItem(at: Self.scratchDir) }

        let shortMinutes = envInt("TRANSCRIPTOR_MEM_LINEAR_SHORT") ?? 5
        let longMinutes = envInt("TRANSCRIPTOR_MEM_LINEAR_LONG") ?? 10
        let shortURL = try SyntheticLongMedia.writeSilenceWav(durationSeconds: shortMinutes * 60, in: Self.scratchDir)
        let shortSampler = MemorySampler()
        try await Self.transcribeSampling(shortURL, sampler: shortSampler)
        let shortPeak = shortSampler.peak
        try? FileManager.default.removeItem(at: shortURL)

        let longURL = try SyntheticLongMedia.writeSilenceWav(durationSeconds: longMinutes * 60, in: Self.scratchDir)
        let longSampler = MemorySampler()
        try await Self.transcribeSampling(longURL, sampler: longSampler)
        let longPeak = longSampler.peak

        // Un crecimiento real lineal al doblar la duración duplicaría la memoria;
        // se permite margen amplio, pero muy por debajo de una duplicación proporcional.
        #expect(longPeak <= shortPeak * 2 + 256 * 1024 * 1024,
                "Pico (\(longMinutes) min) \(longPeak.miB) muy por encima de (\(shortMinutes) min) \(shortPeak.miB).")
    }

    @Test("11.11/11.12 El streaming de audio largo no pierde muestras ni acumula buffers")
    func audioStreamBackpressureAndLoss() async throws {
        try Self.makeScratchDir()
        defer { try? FileManager.default.removeItem(at: Self.scratchDir) }

        let durationSeconds = formatMinutes * 60
        let url = try SyntheticLongMedia.writeSilenceWav(durationSeconds: durationSeconds, in: Self.scratchDir)

        // Se esperan `16k × duración real del archivo` frames al volverlo a leer.
        let realDuration = try SyntheticLongMedia.wavDuration(url: url)
        let expectedFrames = Int64(realDuration * 16_000)
        let sampler = MemorySampler()
        var buffers = 0
        var frames: Int64 = 0
        try await sampler.run(interval: (20)/1000.0) {
            let stream = AudioStreamProvider.makeStream(url: url, format: AudioStreamProvider.fallbackFormat)
            var iterator = stream.makeAsyncIterator()
            while let input = try await iterator.next() {
                buffers += 1
                frames += Int64(input.buffer.frameLength)
            }
        }

        #expect(frames == expectedFrames,
                "Se perdieron muestras: \(frames) de \(expectedFrames) (\(durationSeconds) s).")
        #expect(buffers > 100, "Se esperaban decenas de buffers, se leyeron \(buffers).")
        assertBoundedGrowth(samples: sampler.snapshot().samples)
    }

    @Test("11.15 La cancelación interrumpe y no acumula memoria")
    func cancellationReleasesResources() async throws {
        try Self.makeScratchDir()
        defer { try? FileManager.default.removeItem(at: Self.scratchDir) }

        let url = try SyntheticLongMedia.writeSilenceWav(
            durationSeconds: cancellationMinutes * 60,
            in: Self.scratchDir
        )

        final class StateProbe: @unchecked Sendable {
            private let lock = NSLock()
            private var _states: [TranscriptionJobState] = []
            func record(_ state: TranscriptionJobState) { lock.withLock { _states.append(state) } }
            var hasTranscribed: Bool { lock.withLock { _states.contains(.transcribing) } }
        }
        let probe = StateProbe()

        let sampler = MemorySampler()
        let job = Self.job(url: url)
        let transcription = Task {
            do {
                try await sampler.run(interval: (50)/1000.0) {
                    _ = try await TranscriptionService().transcribe(job: job, onState: { probe.record($0) }) { _ in }
                }
                return "completed"
            } catch _ as TranscriptionError {
                return "cancelled"
            } catch {
                return "other: \(error)"
            }
        }

        // Se espera a que la transcripción haya empezado y se cancela entonces,
        // garantizando que la lectura del audio sigue en curso.
        var deadline = Date().addingTimeInterval(30)
        while !probe.hasTranscribed, Date() < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        #expect(probe.hasTranscribed, "La transcripción nunca empezó.")
        transcription.cancel()

        let outcome = try await transcription.value
        #expect(outcome == "cancelled", "Se esperaba cancelación, se obtuvo: \(outcome).")

        // Tras cancelar, la memoria no debe seguir creciendo de forma sostenida.
        let peakDuring = sampler.peak
        try await Task.sleep(nanoseconds: 1_000_000_000)
        let after = MemoryTracker.currentBytes()
        #expect(after <= peakDuring + 128 * 1024 * 1024,
                "La memoria siguió creciendo tras cancelar: \(peakDuring.miB) → \(after.miB).")
    }

    @Test("11.16 La memoria permanece acotada en varios formatos")
    func memoryBoundedAcrossFormats() async throws {
        try Self.makeScratchDir()
        defer { try? FileManager.default.removeItem(at: Self.scratchDir) }

        let seconds = max(60, formatMinutes * 60)
        var urls: [(String, URL)] = [
            ("wav", try SyntheticLongMedia.writeSilenceWav(durationSeconds: seconds, in: Self.scratchDir)),
        ]
        // Los formatos de vídeo se construyen con el fixture m4a de prueba
        // (el passthrough PCM→MP4 no es fiable; el AAC sí lo es y ya está probado).
        for (ext, fileType) in [("mov", AVFileType.mov), ("mp4", AVFileType.mp4), ("m4v", AVFileType.m4v)] {
            let videoURL = try await TestVideoFactory.writeVideoWithAudioTrack(
                audioSource: TestsFixtures.meetingAudioURL(),
                fileExtension: ext,
                fileType: fileType,
                in: Self.scratchDir
            )
            urls.append((ext, videoURL))
        }

        for (label, url) in urls {
            let sampler = MemorySampler()
            try await Self.transcribeSampling(url, sampler: sampler)
            #expect(sampler.peak <= 2_000 * 1024 * 1024,
                    "\(label): pico excesivo: \(sampler.peak.miB).")
            assertBoundedGrowth(samples: sampler.snapshot().samples, label: label)
        }
    }

    @Test("11.14 El actor principal mantiene el UI responsivo durante la transcripción")
    func mainActorRemainsResponsive() async throws {
        try Self.makeScratchDir()
        defer { try? FileManager.default.removeItem(at: Self.scratchDir) }

        let url = try SyntheticLongMedia.writeSilenceWav(
            durationSeconds: cancellationMinutes * 60,
            in: Self.scratchDir
        )
        let job = Self.job(url: url)

        let transcription = Task {
            try await TranscriptionService().transcribe(job: job) { _ in }
        }

        final class Pump: @unchecked Sendable {
            var iterations = 0
        }
        let pump = Pump()
        let mainPump = Task { @MainActor in
            for index in 1...10_000 {
                pump.iterations = index
                await Task.yield()
            }
        }
        try await Task.sleep(nanoseconds: 2_000_000_000)
        let iterationsInTwoSeconds = pump.iterations
        mainPump.cancel()
        transcription.cancel()

        #expect(iterationsInTwoSeconds > 100,
                "El actor principal quedó bloqueado: solo \(iterationsInTwoSeconds) iteraciones.")
    }
}

private func assertBoundedGrowth(samples: [UInt64], label: String = "audio", slackMB: UInt64 = 48) {
    guard samples.count >= 20 else { return }
    let quarter = samples.count / 4
    guard quarter > 0 else { return }
    let firstPeak = samples.prefix(quarter).max() ?? 0
    let lastPeak = samples.suffix(quarter).max() ?? 0
    let slack = slackMB * 1024 * 1024
    #expect(lastPeak <= firstPeak + slack,
            "\(label): crecimiento no acotado: primer tramo \(firstPeak.miB) → último tramo \(lastPeak.miB).")
}