import Foundation
import AVFoundation
import CoreMedia

struct MediaAnalyzer: Sendable {
    func analyze(url: URL) async throws -> MediaInfo {
        let asset = AVURLAsset(url: url)

        let isPlayable: Bool
        let tracks: [AVAssetTrack]
        let duration: CMTime
        do {
            (isPlayable, tracks, duration) = try await asset.load(.isPlayable, .tracks, .duration)
        } catch {
            AppLogger.audio.error("No se pudieron cargar los metadatos de \(url.path): \(error)")
            throw MediaError.loadFailed("AVAsset load falló: \(error)")
        }

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

        return MediaInfo(url: url, duration: Duration.seconds(seconds))
    }
}