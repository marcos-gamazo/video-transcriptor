import Foundation
import AVFoundation
import CoreVideo
import CoreMedia

enum TestVideoFactory {
    static func writeVideoWithAudioTrack(
        audioSource: URL,
        fileExtension: String,
        fileType: AVFileType,
        in directory: URL = FileManager.default.temporaryDirectory
    ) async throws -> URL {
        let url = directory.appendingPathComponent("video-with-audio-\(UUID().uuidString).\(fileExtension)")

        let videoOnlyURL = try writeVideoWithoutAudioTrack()
        defer { try? FileManager.default.removeItem(at: videoOnlyURL) }

        let videoAsset = AVURLAsset(url: videoOnlyURL)
        let audioAsset = AVURLAsset(url: audioSource)

        let sourceVideoTrack = try await videoAsset.loadTracks(withMediaType: .video).first
        let sourceAudioTrack = try await audioAsset.loadTracks(withMediaType: .audio).first
        guard let sourceVideoTrack, let sourceAudioTrack else {
            throw CreationError.compositionFailed("No se encontraron pistas de vídeo o audio de origen.")
        }

        let composition = AVMutableComposition()
        let videoTrack = try composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )
        let audioTrack = try composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )
        guard let videoTrack, let audioTrack else {
            throw CreationError.compositionFailed("No se pudieron crear pistas de composición.")
        }

        try videoTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: sourceVideoTrack.timeRange.duration),
            of: sourceVideoTrack,
            at: .zero
        )
        try audioTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: sourceAudioTrack.timeRange.duration),
            of: sourceAudioTrack,
            at: .zero
        )

        guard let export = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetPassthrough
        ) else {
            throw CreationError.exportFailed(nil)
        }
        export.outputURL = url
        export.outputFileType = fileType
        export.shouldOptimizeForNetworkUse = false

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            export.exportAsynchronously {
                switch export.status {
                case .completed:
                    continuation.resume()
                case .failed:
                    continuation.resume(throwing: CreationError.exportFailed(export.error))
                default:
                    continuation.resume(throwing: CreationError.exportFailed(nil))
                }
            }
        }
        return url
    }

    static func writeVideoWithoutAudioTrack() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("video-no-audio-\(UUID().uuidString).mov")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)

        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 160,
            AVVideoHeightKey: 120,
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
                kCVPixelBufferWidthKey as String: 160,
                kCVPixelBufferHeightKey as String: 120,
            ]
        )
        writer.add(input)
        guard writer.startWriting() else {
            throw CreationError.startWritingFailed(writer.error)
        }
        writer.startSession(atSourceTime: .zero)

        guard let pool = adaptor.pixelBufferPool else {
            throw CreationError.noPixelBufferPool
        }

        let fps: Int32 = 30
        let frameCount = 30
        for frame in 0..<frameCount {
            while !input.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.001)
            }
            var pixelBuffer: CVPixelBuffer?
            let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
            guard status == kCVReturnSuccess, let pixelBuffer else {
                throw CreationError.pixelBufferFailed(status)
            }
            CVPixelBufferLockBaseAddress(pixelBuffer, [])
            if let base = CVPixelBufferGetBaseAddress(pixelBuffer) {
                memset(base, 0, CVPixelBufferGetDataSize(pixelBuffer))
            }
            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
            let time = CMTime(value: CMTimeValue(frame), timescale: fps)
            guard adaptor.append(pixelBuffer, withPresentationTime: time) else {
                throw CreationError.appendFailed(writer.error)
            }
        }

        input.markAsFinished()

        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting { semaphore.signal() }
        semaphore.wait()

        guard writer.status == .completed else {
            throw CreationError.finishFailed(writer.error)
        }
        return url
    }

    enum CreationError: Error, CustomStringConvertible {
        case startWritingFailed(Error?)
        case noPixelBufferPool
        case pixelBufferFailed(OSStatus)
        case appendFailed(Error?)
        case finishFailed(Error?)
        case compositionFailed(String)
        case exportFailed(Error?)

        var description: String {
            switch self {
            case .startWritingFailed(let error):
                return "AVAssetWriter.startWriting falló: \(String(describing: error))"
            case .noPixelBufferPool:
                return "No hay pool de pixel buffers."
            case .pixelBufferFailed(let status):
                return "CVPixelBufferPoolCreatePixelBuffer devolvió \(status)"
            case .appendFailed(let error):
                return "append falló: \(String(describing: error))"
            case .finishFailed(let error):
                return "finishWriting falló: \(String(describing: error))"
            case .compositionFailed(let reason):
                return "No se pudo crear la composición: \(reason)"
            case .exportFailed(let error):
                return "AVAssetExportSession falló: \(String(describing: error))"
            }
        }
    }
}