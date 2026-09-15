import Foundation
import AVFoundation

/// Genera medios sintéticos largos para la validación de memoria y rendimiento.
enum SyntheticLongMedia {
    /// Escribe un WAV PCM mono con silencio de la duración indicada.
    static func writeSilenceWav(
        durationSeconds: Int,
        sampleRate: Double = 16_000,
        in directory: URL
    ) throws -> URL {
        let url = directory.appendingPathComponent("silence-\(durationSeconds)s-\(UUID().uuidString).wav")
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: true
        ) else {
            throw CreationError.formatFailure
        }
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]
        let file = try AVAudioFile(forWriting: url, settings: settings)

        let chunkFrames = AVAudioFrameCount(sampleRate) * 5
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunkFrames) else {
            throw CreationError.formatFailure
        }
        buffer.frameLength = chunkFrames
        var totalWritten: Int64 = 0
        let totalFrames = Int64(durationSeconds) * Int64(sampleRate)
        while totalWritten < totalFrames {
            let remaining = totalFrames - totalWritten
            let frames = AVAudioFrameCount(min(Int64(chunkFrames), remaining))
            buffer.frameLength = frames
            if let channel = buffer.floatChannelData?[0] {
                channel.update(repeating: 0, count: Int(frames))
            }
            try file.write(from: buffer)
            totalWritten += Int64(frames)
        }
        return url
    }

    /// Duración real en segundos de un archivo de audio WAV.
    static func wavDuration(url: URL) throws -> Double {
        let file = try AVAudioFile(forReading: url)
        return Double(file.length) / file.processingFormat.sampleRate
    }

    /// Escribe un vídeo (pista de vídeo corta + pista de audio larga) a partir
    /// de un WAV de silencio, usando la composición passthrough ya probada.
    static func writeLongSilentVideo(
        durationSeconds: Int,
        fileExtension: String,
        fileType: AVFileType,
        in directory: URL
    ) async throws -> URL {
        let audioURL = try writeSilenceWav(durationSeconds: durationSeconds, in: directory)
        defer { try? FileManager.default.removeItem(at: audioURL) }
        return try await TestVideoFactory.writeVideoWithAudioTrack(
            audioSource: audioURL,
            fileExtension: fileExtension,
            fileType: fileType,
            in: directory
        )
    }

    enum CreationError: Error, CustomStringConvertible {
        case formatFailure

        var description: String {
            "No se pudo crear un formato o buffer de audio."
        }
    }
}