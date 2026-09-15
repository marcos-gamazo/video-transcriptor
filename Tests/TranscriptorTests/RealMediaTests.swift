import Testing
import Foundation
import AVFoundation
@testable import Transcriptor

// MARK: - 12.2 Language selection and resolution

@Suite("LanguageSelection")
struct LanguageSelectionTests {
    @Test("VoskModelManager.supportedLocales contiene al menos es_ES")
    func supportedLocalesContainsSpanish() {
        let locales = VoskModelManager.supportedLocales
        let identifiers = locales.map(\.identifier)
        #expect(identifiers.contains("es_ES"), "Se esperaba es_ES en la lista de idiomas soportados.")
    }

    @Test("VoskModelManager.supportedLocales contiene en_US")
    func supportedLocalesContainsEnglish() {
        let locales = VoskModelManager.supportedLocales
        let identifiers = locales.map(\.identifier)
        #expect(identifiers.contains("en_US"), "Se esperaba en_US en la lista de idiomas soportados.")
    }

    @Test("VoskModelManager.supportedLocales tiene más de un idioma")
    func supportedLocalesHasMultipleLanguages() {
        let locales = VoskModelManager.supportedLocales
        let distinctCodes = Set(locales.map { $0.identifier.split(separator: "_").first.map(String.init) ?? "" })
        #expect(distinctCodes.count > 1, "Se esperaba más de un idioma distinto.")
    }

    @Test("Preflight resuelve es a es_ES")
    func preflightResolvesEsToEsES() async throws {
        let manager = VoskModelManager()
        let result = try await manager.preflight(locale: Locale(identifier: "es"))
        #expect(result.resolvedLocale.identifier == "es_ES")
    }

    @Test("Preflight para un idioma no soportado lanza unsupportedLocale")
    func preflightRejectsUnsupportedLocale() async {
        let manager = VoskModelManager()
        do {
            _ = try await manager.preflight(locale: Locale(identifier: "zu_ZA"))
            Issue.record("Se esperaba unsupportedLocale para zu_ZA.")
        } catch let error as VoskError {
            #expect(error == .unsupportedLocale)
        } catch {
            Issue.record("Error inesperado: \(error)")
        }
    }

    @Test("El idioma por defecto del ViewModel es español")
    @MainActor
    func defaultLanguageIsSpanish() {
        let vm = TranscriptionViewModel()
        #expect(vm.selectedLanguageID == "es")
    }
}

// MARK: - 12.15 Model installation

@Suite("ModelInstallation")
struct ModelInstallationTests {
    @Test(
        "Install es un no-op cuando el modelo ya está instalado",
        .disabled("Requiere la descarga de modelos Vosk (Fase 4)."))
    func installNoOpWhenAlreadyInstalled() async throws {
        let manager = VoskModelManager()
        let preflight = try await manager.preflight(locale: Locale(identifier: "es_ES"))
        #expect(preflight.installed)

        let result = try await manager.install(locale: preflight.resolvedLocale)
        #expect(result.identifier == "es_ES")
    }

    @Test("Preflight de un locale no soportado falla antes de intentar install")
    func unsupportedLocaleFailsPreflight() async {
        let manager = VoskModelManager()
        do {
            let preflight = try await manager.preflight(locale: Locale(identifier: "xx_XX"))
            Issue.record("Se esperaba un error, se obtuvo: \(preflight)")
        } catch let error as VoskError {
            #expect(error == .unsupportedLocale)
        } catch {
            Issue.record("Error inesperado: \(error)")
        }
    }
}

// MARK: - 12.21 MP3 real media

@Suite("RealMediaMP3")
struct RealMediaMP3Tests {
    private static func createMinimalMP3(at url: URL) throws {
        var data = Data()
        let frameCount = 38
        let frameSize = 417
        for _ in 0..<frameCount {
            data.append(contentsOf: [0xFF, 0xFB, 0x90, 0x00])
            data.append(Data(count: frameSize - 4))
        }
        try data.write(to: url)
    }

    @Test("MediaAnalyzer acepta un MP3 mínimo generado")
    func mediaAnalyzerAcceptsMP3() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mp3-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let mp3URL = dir.appendingPathComponent("silence.mp3")
        try Self.createMinimalMP3(at: mp3URL)

        let info = try await MediaAnalyzer().analyze(url: mp3URL)
        #expect(info.duration > 0, "El MP3 debería tener duración positiva.")
    }

    @Test("AudioStreamProvider lee buffers de un MP3 mínimo")
    func audioStreamReadsMP3() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mp3-stream-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let mp3URL = dir.appendingPathComponent("silence.mp3")
        try Self.createMinimalMP3(at: mp3URL)

        let format = AudioStreamProvider.fallbackFormat
        let stream = AudioStreamProvider.makeStream(url: mp3URL, format: format)
        var iterator = stream.makeAsyncIterator()
        var buffers = 0
        while let input = try await iterator.next() {
            buffers += 1
            #expect(input.buffer.frameLength > 0)
        }
        #expect(buffers > 0, "Se esperaba al menos un buffer del MP3.")
    }
}

// MARK: - 12.22 WAV real media

@Suite("RealMediaWAV")
struct RealMediaWAVTests {
    /// Convierte un M4A a un WAV PCM float32 mono de 22050 Hz.
    ///
    /// No se usa AVAudioFile(forWriting:settings:) porque en este SDK
    /// `read(into:)` lanza `nilError` al llegar al final del archivo y
    /// `write(from:)` exige un formato idéntico al del archivo destino.
    /// Se escribe la cabecera WAV manualmente y se copian las muestras.
    private static func createWAVFixture(in directory: URL) throws -> URL {
        let url = directory.appendingPathComponent("meeting-\(UUID().uuidString).wav")
        let m4a = try TestsFixtures.meetingAudioURL()
        let input = try AVAudioFile(forReading: m4a)
        let sampleRate = input.processingFormat.sampleRate
        let totalFrames = input.length

        var header = Data(count: 44)
        try header.write(to: url)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()

        let chunkFrames: AVAudioFrameCount = 4096
        guard let buffer = AVAudioPCMBuffer(pcmFormat: input.processingFormat, frameCapacity: chunkFrames) else {
            throw TestsFixtures.FixtureError.missing
        }
        var readFrames: Int64 = 0
        while readFrames < totalFrames {
            let remaining = totalFrames - readFrames
            let frames = AVAudioFrameCount(min(Int64(chunkFrames), remaining))
            try input.read(into: buffer, frameCount: frames)
            let got = Int64(buffer.frameLength)
            if got == 0 { break }
            readFrames += got
            if let mData = buffer.mutableAudioBufferList.pointee.mBuffers.mData {
                let count = Int(buffer.frameLength) * 4
                try handle.write(contentsOf: Data(bytes: mData, count: count))
            }
            buffer.frameLength = 0
        }
        try handle.close()

        let dataLength = Int(readFrames) * 4
        var fmt = Data()
        fmt.append(contentsOf: Array("RIFF".utf8))
        var riffSize = UInt32(36 + dataLength).littleEndian
        withUnsafeBytes(of: &riffSize) { fmt.append(contentsOf: $0) }
        fmt.append(contentsOf: Array("WAVE".utf8))
        fmt.append(contentsOf: Array("fmt ".utf8))
        var fmtSize = UInt32(16).littleEndian
        withUnsafeBytes(of: &fmtSize) { fmt.append(contentsOf: $0) }
        var audioFormat = UInt16(3).littleEndian
        withUnsafeBytes(of: &audioFormat) { fmt.append(contentsOf: $0) }
        var channels = UInt16(1).littleEndian
        withUnsafeBytes(of: &channels) { fmt.append(contentsOf: $0) }
        var sampleRate32 = UInt32(sampleRate).littleEndian
        withUnsafeBytes(of: &sampleRate32) { fmt.append(contentsOf: $0) }
        var byteRate = UInt32(sampleRate * 4).littleEndian
        withUnsafeBytes(of: &byteRate) { fmt.append(contentsOf: $0) }
        var blockAlign = UInt16(4).littleEndian
        withUnsafeBytes(of: &blockAlign) { fmt.append(contentsOf: $0) }
        var bitsPerSample = UInt16(32).littleEndian
        withUnsafeBytes(of: &bitsPerSample) { fmt.append(contentsOf: $0) }
        fmt.append(contentsOf: Array("data".utf8))
        var dataSize = UInt32(dataLength).littleEndian
        withUnsafeBytes(of: &dataSize) { fmt.append(contentsOf: $0) }

        let headerHandle = try FileHandle(forWritingTo: url)
        try headerHandle.seek(toOffset: 0)
        try headerHandle.write(contentsOf: fmt)
        try headerHandle.close()
        return url
    }

    @Test("MediaAnalyzer acepta un WAV convertido desde M4A")
    func mediaAnalyzerAcceptsWAV() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wav-analyzer-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let wav = try Self.createWAVFixture(in: dir)

        let info = try await MediaAnalyzer().analyze(url: wav)
        #expect(info.duration > 55 && info.duration < 65, "Duración WAV observada: \(info.duration) s")
    }

    @Test(
        "Transcribe un WAV real y produce segmentos con texto",
        .disabled("Requiere la integración de libvosk (Fase 3)."))
    func transcribesWAVEndToEnd() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wav-transcribe-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let wav = try Self.createWAVFixture(in: dir)

        let job = TranscriptionJob(
            sourceURL: wav,
            locale: Locale(identifier: "es_ES"),
            includeTimestamps: false
        )
        let service = TranscriptionService()
        let summary = try await service.transcribe(job: job) { _ in }
        #expect(summary.segmentCount > 0, "El WAV debería producir al menos un segmento de transcripción.")
    }
}

// MARK: - 12.27 Real files of different durations

@Suite("RealMediaDurations")
struct RealMediaDurationsTests {
    @Test(
        "La transcripción de un m4a de ~60s completa sin error",
        .disabled("Requiere la integración de libvosk (Fase 3)."))
    func transcribesShortAudio() async throws {
        let url = try TestsFixtures.meetingAudioURL()
        let job = TranscriptionJob(
            sourceURL: url,
            locale: Locale(identifier: "es_ES"),
            includeTimestamps: false
        )
        let service = TranscriptionService()
        let summary = try await service.transcribe(job: job) { _ in }
        #expect(summary.segmentCount > 0)
        #expect(summary.finalEndTime != nil)
    }
}

// MARK: - 15 Final Product Validation (end-to-end through the real queue)

@Suite("EndToEndValidation", .serialized)
struct EndToEndValidationTests {
    private func tempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("e2e-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func isTerminal(_ state: TranscriptionJobState) -> Bool {
        state == .completed || state == .cancelled || state == .failed
    }

    private func waitUntil(
        _ condition: @escaping () async -> Bool,
        timeout: TimeInterval = 30
    ) async -> Bool {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if await condition() { return true }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
        return await condition()
    }

    @Test(
        "15.1/15.13 Cola real transcribe un m4a y escribe un .md correcto en disco",
        .disabled("Requiere la integración de libvosk (Fase 3)."))
    func queueTranscribesAudioAndWritesMarkdown() async throws {
        let url = try TestsFixtures.meetingAudioURL()
        let destination = try tempDirectory()
        defer { try? FileManager.default.removeItem(at: destination) }

        let job = TranscriptionJob(
            sourceURL: url,
            locale: Locale(identifier: "es_ES"),
            includeTimestamps: true
        )
        let queue = TranscriptionQueue(
            service: TranscriptionService(),
            destinationDirectory: destination
        )
        await queue.enqueue(jobs: [job])
        await queue.start()

        let done = await waitUntil { [queue] in
            let snapshot = await queue.snapshot
            return snapshot.entries.allSatisfy { self.isTerminal($0.state) }
        }
        #expect(done, "La cola debería completar el trabajo.")

        let snapshot = await queue.snapshot
        guard let entry = snapshot.entries.first else {
            Issue.record("Se esperaba un trabajo procesado.")
            return
        }
        #expect(entry.state == .completed)
        #expect(entry.outputURL?.pathExtension == "md")
        #expect(FileManager.default.fileExists(atPath: entry.outputURL?.path ?? ""))

        let content = try String(contentsOf: entry.outputURL!, encoding: .utf8)
        #expect(!content.isEmpty)
        #expect(content.hasPrefix("# meeting"), "El Markdown debería empezar con un encabezado con el nombre del archivo.")
        #expect(content.contains("### ["), "Con timestamps activados, debería haber bloques con timestamp.")
        let paragraphStarts = content.components(separatedBy: "\n").filter { $0.hasPrefix("### [") }
        #expect(paragraphStarts.count > 0, "Debería haber al menos un párrafo con timestamp.")
    }

    @Test(
        "15.3 La transcripción sin timestamps escribe Markdown limpio",
        .disabled("Requiere la integración de libvosk (Fase 3)."))
    func queueWritesCleanMarkdownWithoutTimestamps() async throws {
        let url = try TestsFixtures.meetingAudioURL()
        let destination = try tempDirectory()
        defer { try? FileManager.default.removeItem(at: destination) }

        let job = TranscriptionJob(
            sourceURL: url,
            locale: Locale(identifier: "es_ES"),
            includeTimestamps: false
        )
        let queue = TranscriptionQueue(
            service: TranscriptionService(),
            destinationDirectory: destination
        )
        await queue.enqueue(jobs: [job])
        await queue.start()

        let done = await waitUntil { [queue] in
            let snapshot = await queue.snapshot
            return snapshot.entries.allSatisfy { self.isTerminal($0.state) }
        }
        #expect(done)

        let snapshot = await queue.snapshot
        guard let entry = snapshot.entries.first, entry.state == .completed,
              let output = entry.outputURL else {
            Issue.record("La transcripción sin timestamps debería completar.")
            return
        }
        let content = try String(contentsOf: output, encoding: .utf8)
        #expect(!content.contains("### ["), "Sin timestamps no debería haber bloques marcados.")
        #expect(!content.contains("["), "Sin timestamps no debería aparecer metadatos de tiempo.")
        #expect(content.contains("."), "Debería contener texto transcrito.")
    }

    @Test(
        "15.5 La cola real procesa varios archivos secuencialmente en orden",
        .disabled("Requiere la integración de libvosk (Fase 3)."))
    func queueProcessesMultipleFilesSequentially() async throws {
        let url = try TestsFixtures.meetingAudioURL()
        let destination = try tempDirectory()
        defer { try? FileManager.default.removeItem(at: destination) }

        let jobs = [url, url].map { source in
            TranscriptionJob(
                sourceURL: source,
                locale: Locale(identifier: "es_ES"),
                includeTimestamps: false
            )
        }
        let queue = TranscriptionQueue(
            service: TranscriptionService(),
            destinationDirectory: destination
        )
        await queue.enqueue(jobs: jobs)
        await queue.start()

        let done = await waitUntil(
            { [queue] in
                let snapshot = await queue.snapshot
                return snapshot.entries.allSatisfy { self.isTerminal($0.state) }
            },
            timeout: 60
        )
        #expect(done, "Ambos trabajos deberían completarse.")
        #expect(done, "La cola debería completar ambos trabajos.")

        let snapshot = await queue.snapshot
        #expect(snapshot.entries.count == 2)
        #expect(snapshot.entries.allSatisfy { $0.state == .completed })
        let outputs = snapshot.entries.compactMap(\.outputURL)
        #expect(outputs.count == 2)
        #expect(outputs[0].lastPathComponent == "meeting.md")
        #expect(outputs[1].lastPathComponent == "meeting-2.md",
                "El segundo archivo debería usar un nombre único sin sobrescribir.")
    }
}
