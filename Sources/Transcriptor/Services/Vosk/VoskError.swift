import Foundation

enum VoskError: Error, Equatable {
    case unsupportedLocale
    case modelNotFound
    case modelCorrupted(String)
    case audioNotConvertible
    case modelTooLarge
    case downloadFailed(String)
    case offlineAssetInstallation
    case transcriptionNotAvailable
    case installNotAvailable
    case analysisFailed(String)
}

extension VoskError {
    var userMessage: String {
        switch self {
        case .unsupportedLocale:
            return "El idioma seleccionado no está soportado."
        case .modelNotFound:
            return "El modelo de idioma necesario no está instalado."
        case .modelCorrupted:
            return "El modelo de idioma está dañado o es incompatible."
        case .audioNotConvertible:
            return "Este archivo no se puede convertir al formato de audio necesario."
        case .modelTooLarge:
            return "El modelo de idioma requiere más memoria de la disponible en este equipo."
        case .downloadFailed:
            return "No se pudo descargar el modelo de idioma."
        case .offlineAssetInstallation:
            return "Se necesita conexión para instalar el idioma por primera vez."
        case .transcriptionNotAvailable:
            return "El motor de transcripción local todavía no está disponible."
        case .installNotAvailable:
            return "La descarga automática del idioma todavía no está disponible."
        case .analysisFailed:
            return "No se pudo completar la transcripción."
        }
    }
}