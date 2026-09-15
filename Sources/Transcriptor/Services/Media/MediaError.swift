import Foundation

enum MediaError: Error, Equatable {
    case loadFailed(String)
    case unsupportedMedia
    case missingAudioTrack
    case cannotAddOutput
    case assetReadFailed(String)
}

extension MediaError {
    var userMessage: String {
        switch self {
        case .loadFailed:
            return "No se pudo leer el archivo."
        case .unsupportedMedia:
            return "El archivo seleccionado no es un archivo de audio o vídeo compatible."
        case .missingAudioTrack:
            return "El archivo no contiene ninguna pista de audio."
        case .cannotAddOutput:
            return "No se pudo preparar la lectura del audio."
        case .assetReadFailed:
            return "No se pudo leer el audio."
        }
    }
}