import Foundation
import AVFAudio
import CoreMedia

struct MediaInfo: Equatable, Sendable {
    let url: URL
    let duration: Double
}

struct AudioStreamFormat: Equatable, Sendable {
    let sampleRate: Double
    let channelCount: UInt32
    let bitDepth: UInt32
    let isFloat: Bool
    let isInterleaved: Bool
}

/// Un buffer PCM con su tiempo de presentación en el medio de origen.
/// Reemplaza al `AnalyzerInput` del framework Speech (macOS 26).
struct AnalyzerInput: @unchecked Sendable {
    let buffer: AVAudioPCMBuffer
    let bufferStartTime: CMTime?
}