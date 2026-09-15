import Foundation

enum SpeechError: Error, Equatable {
    case unsupportedLocale
    case assetNotInstalled
    case assetInstallationFailed(String)
    case offlineAssetInstallation
    case analysisFailed(String)
}

extension SpeechError {
    var userMessage: String {
        switch self {
        case .unsupportedLocale:
            return "El idioma seleccionado no está soportado."
        case .assetNotInstalled:
            return "El idioma seleccionado todavía no está instalado."
        case .assetInstallationFailed:
            return "No se pudo instalar el recurso de idioma."
        case .offlineAssetInstallation:
            return "Se necesita conexión para instalar el idioma por primera vez."
        case .analysisFailed:
            return "No se pudo completar la transcripción."
        }
    }
}