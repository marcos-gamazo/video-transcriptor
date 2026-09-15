import Foundation
import AVFoundation
import AVFAudio
import CoreMedia
import CoreAudio

enum AudioStreamProvider {
    static let fallbackFormat = AudioStreamFormat(
        sampleRate: 16_000,
        channelCount: 1,
        bitDepth: 32,
        isFloat: true,
        isInterleaved: true
    )

    static func makeStream(
        url: URL,
        format: AudioStreamFormat,
        isCancelled: @escaping @Sendable () -> Bool = { Task.isCancelled }
    ) -> AudioBuffersStream {
        AudioBuffersStream(url: url, format: format, isCancelled: isCancelled)
    }
}

extension AudioStreamFormat {
    func makeAVAudioFormat() throws -> AVAudioFormat {
        let common: AVAudioCommonFormat
        switch (isFloat, bitDepth) {
        case (true, 64):
            common = .pcmFormatFloat64
        case (true, _):
            common = .pcmFormatFloat32
        case (false, 16):
            common = .pcmFormatInt16
        case (false, _):
            common = .pcmFormatInt32
        }
        guard let format = AVAudioFormat(
            commonFormat: common,
            sampleRate: sampleRate,
            channels: channelCount,
            interleaved: isInterleaved
        ) else {
            throw MediaError.assetReadFailed("No se pudo representar un formato de audio de \(sampleRate) Hz, \(channelCount) canales.")
        }
        return format
    }

    func interleavedPCM() -> AudioStreamFormat {
        AudioStreamFormat(
            sampleRate: sampleRate,
            channelCount: channelCount,
            bitDepth: bitDepth,
            isFloat: isFloat,
            isInterleaved: true
        )
    }
}

struct AudioBuffersStream: AsyncSequence, Sendable {
    typealias Element = AnalyzerInput

    private let url: URL
    private let format: AudioStreamFormat
    private let isCancelled: @Sendable () -> Bool

    init(url: URL, format: AudioStreamFormat, isCancelled: @escaping @Sendable () -> Bool) {
        self.url = url
        self.format = format
        self.isCancelled = isCancelled
    }

    func makeAsyncIterator() -> Iterator {
        Iterator(url: url, format: format, isCancelled: isCancelled)
    }

    struct Iterator: AsyncIteratorProtocol {
        typealias Element = AnalyzerInput

        private let url: URL
        private let format: AudioStreamFormat
        private let isCancelled: @Sendable () -> Bool

        private var asset: AVURLAsset?
        private var reader: AVAssetReader?
        private var audioOutput: AVAssetReaderAudioMixOutput?
        private var didOpen = false
        private var didStartReading = false

        init(url: URL, format: AudioStreamFormat, isCancelled: @escaping @Sendable () -> Bool) {
            self.url = url
            self.format = format
            self.isCancelled = isCancelled
        }

        mutating func next() async throws -> AnalyzerInput? {
            try await openIfNeeded()
            guard let reader, let audioOutput else { return nil }

            if isCancelled() {
                return nil
            }

            if !didStartReading {
                guard reader.startReading() else {
                    throw MediaError.assetReadFailed(
                        reader.error?.localizedDescription ?? "AVAssetReader status \(reader.status.rawValue)"
                    )
                }
                didStartReading = true
            }

            guard let sample = audioOutput.copyNextSampleBuffer() else {
                if reader.status == .failed {
                    throw MediaError.assetReadFailed(
                        reader.error?.localizedDescription ?? "AVAssetReader status \(reader.status.rawValue)"
                    )
                }
                return nil
            }

            guard let pcm = Self.makePCMBuffer(from: sample) else {
                throw MediaError.assetReadFailed("No se pudo convertir el sample buffer en AVAudioPCMBuffer.")
            }

            let presentationTime = CMSampleBufferGetPresentationTimeStamp(sample)
            let bufferStartTime: CMTime? = CMTimeGetSeconds(presentationTime).isNaN ? nil : presentationTime
            return AnalyzerInput(buffer: pcm, bufferStartTime: bufferStartTime)
        }

        private mutating func openIfNeeded() async throws {
            guard !didOpen else { return }
            didOpen = true

            let asset = AVURLAsset(url: url)
            // Carga síncrona de pistas (compatible macOS 11; archivo local).
            let tracks = asset.tracks
            let audioTracks = tracks.filter { $0.mediaType == .audio }
            guard !audioTracks.isEmpty else {
                throw MediaError.missingAudioTrack
            }

            let audioFormat = try format.interleavedPCM().makeAVAudioFormat()
            let output = AVAssetReaderAudioMixOutput(
                audioTracks: audioTracks,
                audioSettings: Self.outputSettings(for: audioFormat)
            )
            let reader: AVAssetReader
            do {
                reader = try AVAssetReader(asset: asset)
            } catch {
                let filePath = url.path
                AppLogger.audio.error("No se pudo abrir \(filePath) para lectura: \(error)")
                throw MediaError.loadFailed("AVAssetReader no pudo abrir el archivo.")
            }
            guard reader.canAdd(output) else {
                throw MediaError.cannotAddOutput
            }
            reader.add(output)

            self.asset = asset
            self.reader = reader
            self.audioOutput = output
        }

        static func outputSettings(for format: AVAudioFormat) -> [String: Any] {
            let asbd = format.streamDescription.pointee
            return [
                AVFormatIDKey: Int(asbd.mFormatID),
                AVSampleRateKey: asbd.mSampleRate,
                AVNumberOfChannelsKey: Int(asbd.mChannelsPerFrame),
                AVLinearPCMBitDepthKey: Int(asbd.mBitsPerChannel),
                AVLinearPCMIsFloatKey: (asbd.mFormatFlags & kLinearPCMFormatFlagIsFloat) != 0,
                AVLinearPCMIsBigEndianKey: (asbd.mFormatFlags & kLinearPCMFormatFlagIsBigEndian) != 0,
                AVLinearPCMIsNonInterleaved: (asbd.mFormatFlags & kLinearPCMFormatFlagIsNonInterleaved) != 0
            ]
        }

        static func makePCMBuffer(from sample: CMSampleBuffer) -> AVAudioPCMBuffer? {
            let frameCount = CMSampleBufferGetNumSamples(sample)
            guard frameCount > 0,
                  let formatDescription = CMSampleBufferGetFormatDescription(sample),
                  let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription),
                  let audioFormat = AVAudioFormat(streamDescription: asbd, channelLayout: nil) else {
                return nil
            }

            var sizeNeeded = 0
            let firstStatus = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
                sample,
                bufferListSizeNeededOut: &sizeNeeded,
                bufferListOut: nil,
                bufferListSize: 0,
                blockBufferAllocator: kCFAllocatorDefault,
                blockBufferMemoryAllocator: kCFAllocatorDefault,
                flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
                blockBufferOut: nil
            )
            guard firstStatus == noErr, sizeNeeded >= MemoryLayout<AudioBufferList>.size else {
                return nil
            }

            let raw = UnsafeMutableRawPointer.allocate(
                byteCount: sizeNeeded,
                alignment: MemoryLayout<AudioBufferList>.alignment
            )
            let audioBufferList = raw.assumingMemoryBound(to: AudioBufferList.self)

            var retained: CMBlockBuffer?
            let secondStatus = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
                sample,
                bufferListSizeNeededOut: nil,
                bufferListOut: audioBufferList,
                bufferListSize: sizeNeeded,
                blockBufferAllocator: kCFAllocatorDefault,
                blockBufferMemoryAllocator: kCFAllocatorDefault,
                flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
                blockBufferOut: &retained
            )
            guard secondStatus == noErr, retained != nil,
                  let pcm = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(frameCount)) else {
                raw.deallocate()
                return nil
            }

            // Copia manual de muestras (compatible macOS 11; el init
            // bufferListNoCopy solo existe a partir de macOS 12).
            let sourceList = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let destinationList = UnsafeMutableAudioBufferListPointer(pcm.mutableAudioBufferList)
            let bufferCount = Swift.min(sourceList.count, destinationList.count)
            for index in 0..<bufferCount {
                let source = sourceList[index]
                let destination = destinationList[index]
                let byteSize = Swift.min(source.mDataByteSize, destination.mDataByteSize)
                guard byteSize > 0, let sourceData = source.mData, let destinationData = destination.mData else {
                    continue
                }
                memcpy(destinationData, sourceData, Int(byteSize))
            }
            pcm.frameLength = AVAudioFrameCount(frameCount)
            withExtendedLifetime(retained) {}
            raw.deallocate()
            return pcm
        }
    }
}