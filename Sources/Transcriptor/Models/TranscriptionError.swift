import Foundation

/// Errores de dominio de la transcripción.
enum TranscriptionError: Error, Equatable {
    case cancelled
}

extension TranscriptionError {
    var userMessage: String {
        switch self {
        case .cancelled:
            return "La transcripción fue cancelada."
        }
    }
}