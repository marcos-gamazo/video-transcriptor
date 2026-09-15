import Foundation
import AVFoundation
import CoreMedia

struct MediaAnalyzer: Sendable {
    func analyze(url: URL) async throws -> MediaInfo {
        let asset = AVURLAsset(url: url)

        // Carga síncrona de propiedades (compatible macOS 11). Para archivos
        // locales la carga es inmediata; esta call no bloquea el main actor.
        let isPlayable = asset.isPlayable
        let tracks = asset.tracks
        let duration = asset.duration

        guard isPlayable else {
            AppLogger.audio.error("El archivo no es reproducible: \(url.path)")
            throw MediaError.unsupportedMedia
        }

        let hasAudioTrack = tracks.contains { $0.mediaType == .audio }
        guard hasAudioTrack else {
            AppLogger.audio.error("El archivo no contiene pista de audio: \(url.path)")
            throw MediaError.missingAudioTrack
        }

        let seconds = CMTimeGetSeconds(duration)
        guard seconds.isFinite, seconds > 0 else {
            throw MediaError.unsupportedMedia
        }

        return MediaInfo(url: url, duration: seconds)
    }
}