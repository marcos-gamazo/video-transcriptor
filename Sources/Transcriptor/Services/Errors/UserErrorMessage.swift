import Foundation

/// Convierte errores técnicos en mensajes comprensibles para el usuario final.
enum UserErrorMessage {
    static func message(for error: any Error) -> String {
        switch error {
        case let transcription as TranscriptionError:
            return transcription.userMessage
        case let media as MediaError:
            return media.userMessage
        case let speech as SpeechError:
            return speech.userMessage
        case let output as OutputError:
            return output.userMessage
        case let validation as FileValidationError:
            return validation.userMessage
        default:
            return "No se pudo completar la transcripción."
        }
    }
}