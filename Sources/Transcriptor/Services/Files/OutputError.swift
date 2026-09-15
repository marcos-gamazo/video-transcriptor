import Foundation

enum OutputError: Error, Equatable {
    case directoryUnavailable(String)
    case fileCreationFailed(String)
    case writeFailed(String)
    case closeFailed(String)
    case writerClosed
}

extension OutputError {
    var userMessage: String {
        switch self {
        case .directoryUnavailable:
            return "La carpeta de destino no está disponible."
        case .fileCreationFailed:
            return "No se pudo crear el archivo de transcripción."
        case .writeFailed:
            return "No se pudo escribir la transcripción."
        case .closeFailed:
            return "No se pudo cerrar el archivo de transcripción."
        case .writerClosed:
            return "La transcripción ya está cerrada."
        }
    }
}