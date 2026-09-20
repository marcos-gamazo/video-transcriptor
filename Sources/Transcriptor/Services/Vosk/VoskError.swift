import Foundation

enum VoskError: Error, Equatable {
    case unsupportedLocale
    case modelNotFound
    case modelCorrupted(String)
    case downloadFailed(String)
    case offlineAssetInstallation
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
        case .downloadFailed:
            return "No se pudo descargar el modelo de idioma."
        case .offlineAssetInstallation:
            return "Se necesita conexión a Internet para instalar el idioma por primera vez."
        }
    }
}