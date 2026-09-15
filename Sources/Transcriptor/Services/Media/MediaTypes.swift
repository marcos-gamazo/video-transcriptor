import Foundation

struct MediaInfo: Equatable, Sendable {
    let url: URL
    let duration: Duration
}

struct AudioStreamFormat: Equatable, Sendable {
    let sampleRate: Double
    let channelCount: UInt32
    let bitDepth: UInt32
    let isFloat: Bool
    let isInterleaved: Bool
}