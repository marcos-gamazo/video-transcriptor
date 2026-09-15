import Foundation
import CoreMedia
import AVFAudio
import CoreAudio
import Speech
import Synchronization

actor SpeechAnalyzerService {
    private let transcriber: SpeechTranscriber
    private let analyzer: SpeechAnalyzer
    private let cancelFlag: CancellationFlag

    init(locale: Locale) {
        self.transcriber = SpeechTranscriber(locale: locale, preset: .timeIndexedTranscriptionWithAlternatives)
        self.analyzer = SpeechAnalyzer(
            modules: [transcriber],
            options: SpeechAnalyzer.Options(priority: .utility, modelRetention: .whileInUse)
        )
        self.cancelFlag = CancellationFlag()
    }

    func negotiatedAudioFormat() async -> AudioStreamFormat? {
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            return nil
        }
        return Self.audioStreamFormat(from: format)
    }

    func transcribe(
        url: URL,
        onSegment: @escaping @Sendable (TranscriptionSegment) -> Void
    ) async throws -> TranscriptionSummary {
        let flag = cancelFlag
        return try await withTaskCancellationHandler {
            do {
                let negotiated = await self.negotiatedAudioFormat() ?? AudioStreamProvider.fallbackFormat
                let format = negotiated.interleavedPCM()
                let stream = AudioStreamProvider.makeStream(url: url, format: format) {
                    flag.isSet
                }
                return try await self.performTranscription(stream: stream, format: format, onSegment: onSegment)
            } catch {
                if flag.isSet || Task.isCancelled {
                    throw TranscriptionError.cancelled
                }
                throw error
            }
        } onCancel: {
            flag.set()
        }
    }

    private func performTranscription(
        stream: some AsyncSequence<AnalyzerInput, any Error> & Sendable,
        format: AudioStreamFormat,
        onSegment: @escaping @Sendable (TranscriptionSegment) -> Void
    ) async throws -> TranscriptionSummary {
        let flag = cancelFlag

        do {
            try await analyzer.prepareToAnalyze(in: format.makeAVAudioFormat())

            let resultsTask = Task {
                try await Self.consumeResults(transcriber, cancelFlag: flag, onSegment: onSegment)
            }

            do {
                let lastSampleTime = try await analyzer.analyzeSequence(stream)
                guard !flag.isSet, !Task.isCancelled else {
                    resultsTask.cancel()
                    await analyzer.cancelAndFinishNow()
                    throw TranscriptionError.cancelled
                }

                if let lastSampleTime {
                    try await analyzer.finalizeAndFinish(through: lastSampleTime)
                } else {
                    await analyzer.cancelAndFinishNow()
                }

                let segmentCount = try await resultsTask.value
                let finalEndTime = await analyzer.volatileRange?.end

                guard !flag.isSet, !Task.isCancelled else {
                    throw TranscriptionError.cancelled
                }

                AppLogger.speech.info("Transcripción completada: \(segmentCount) segmentos, fin en \(Self.timeString(finalEndTime))")
                return TranscriptionSummary(segmentCount: segmentCount, finalEndTime: Self.duration(from: finalEndTime))
            } catch {
                resultsTask.cancel()
                await analyzer.cancelAndFinishNow()
                if flag.isSet || Task.isCancelled {
                    throw TranscriptionError.cancelled
                }
                AppLogger.speech.error("La transcripción falló: \(error)")
                throw error
            }
        } catch {
            if flag.isSet || Task.isCancelled {
                throw TranscriptionError.cancelled
            }
            throw error
        }
    }

    private static func consumeResults(
        _ transcriber: SpeechTranscriber,
        cancelFlag: CancellationFlag,
        onSegment: @escaping @Sendable (TranscriptionSegment) -> Void
    ) async throws -> Int {
        var count = 0
        for try await result in transcriber.results {
            if cancelFlag.isSet || Task.isCancelled {
                break
            }
            for segment in segments(of: result) {
                onSegment(segment)
                count += 1
            }
        }
        return count
    }

    private static func audioStreamFormat(from format: AVAudioFormat) -> AudioStreamFormat {
        let asbd = format.streamDescription.pointee
        return AudioStreamFormat(
            sampleRate: asbd.mSampleRate,
            channelCount: asbd.mChannelsPerFrame,
            bitDepth: asbd.mBitsPerChannel,
            isFloat: (asbd.mFormatFlags & kLinearPCMFormatFlagIsFloat) != 0,
            isInterleaved: (asbd.mFormatFlags & kLinearPCMFormatFlagIsNonInterleaved) == 0
        )
    }

    private static func segments(of result: SpeechTranscriber.Result) -> [TranscriptionSegment] {
        var hasRuns = false
        var output: [TranscriptionSegment] = []
        for run in result.text.runs {
            if let timeRange = run.attributes[AttributeScopes.SpeechAttributes.TimeRangeAttribute.self] {
                hasRuns = true
                let text = String(result.text[run.range].characters)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }
                output.append(TranscriptionSegment(
                    start: duration(from: timeRange.start),
                    end: duration(from: timeRange.end),
                    text: text
                ))
            }
        }
        guard output.isEmpty else { return output }
        if hasRuns { return [] }
        let text = String(result.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }
        return [TranscriptionSegment(
            start: duration(from: result.range.start),
            end: duration(from: result.range.end),
            text: text
        )]
    }

    private static func duration(from time: CMTime) -> Duration {
        let seconds = CMTimeGetSeconds(time)
        guard seconds.isFinite, !seconds.isNaN, seconds >= 0 else { return .zero }
        return Duration.seconds(seconds)
    }

    private static func duration(from time: CMTime?) -> Duration? {
        guard let time else { return nil }
        let seconds = CMTimeGetSeconds(time)
        guard seconds.isFinite, !seconds.isNaN, seconds >= 0 else { return nil }
        return Duration.seconds(seconds)
    }

    private static func timeString(_ time: CMTime?) -> String {
        guard let time else { return "desconocido" }
        let seconds = CMTimeGetSeconds(time)
        guard seconds.isFinite, !seconds.isNaN, seconds >= 0 else { return "desconocido" }
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }
}

private final class CancellationFlag: Sendable {
    private let state = Mutex(false)

    var isSet: Bool {
        state.withLock { $0 }
    }

    func set() {
        state.withLock { $0 = true }
    }
}