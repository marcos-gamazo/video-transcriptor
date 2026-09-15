import Testing
import Foundation
@testable import Transcriptor

@Suite("UserErrorMessage")
struct UserErrorMessageTests {
    @Test("Mapea errores de media a mensajes comprensibles")
    func mapsMediaErrors() {
        #expect(UserErrorMessage.message(for: MediaError.unsupportedMedia)
                == "El archivo seleccionado no es un archivo de audio o vídeo compatible.")
        #expect(UserErrorMessage.message(for: MediaError.missingAudioTrack)
                == "El archivo no contiene ninguna pista de audio.")
    }

    @Test("Mapea errores de Vosk y modelos")
    func mapsVoskErrors() {
        #expect(UserErrorMessage.message(for: VoskError.unsupportedLocale)
                == "El idioma seleccionado no está soportado.")
        #expect(UserErrorMessage.message(for: VoskError.offlineAssetInstallation)
                == "Se necesita conexión para instalar el idioma por primera vez.")
        #expect(UserErrorMessage.message(for: VoskError.modelNotFound)
                == "El modelo de idioma necesario no está instalado.")
        #expect(UserErrorMessage.message(for: VoskError.transcriptionNotAvailable)
                == "El motor de transcripción local todavía no está disponible.")
    }

    @Test("Mapea errores de escritura")
    func mapsOutputErrors() {
        #expect(UserErrorMessage.message(for: OutputError.directoryUnavailable("/x"))
                == "La carpeta de destino no está disponible.")
        #expect(UserErrorMessage.message(for: OutputError.writeFailed("/x"))
                == "No se pudo escribir la transcripción.")
    }

    @Test("Mapea errores de validación de archivos")
    func mapsValidationErrors() {
        #expect(UserErrorMessage.message(for: FileValidationError.notAFile)
                == "No se puede añadir este elemento porque no es un archivo.")
    }

    @Test("Mapea errores de dominio y desconocidos")
    func mapsDomainAndUnknownErrors() {
        #expect(UserErrorMessage.message(for: TranscriptionError.cancelled)
                == "La transcripción fue cancelada.")
        #expect(UserErrorMessage.message(for: NSError(domain: "x", code: 1))
                == "No se pudo completar la transcripción.")
    }
}

@MainActor
@Suite("LogStore")
struct LogStoreTests {
    @Test("Mantiene como máximo `capacity` entradas y conserva las más recientes")
    func boundsCapacity() {
        let store = LogStore()
        let capacity = store.capacity
        for index in 0..<(capacity + 50) {
            store.append(LogEntryRecord(level: .info, category: "app", message: "\(index)"))
        }
        #expect(store.entries.count == capacity)
        #expect(store.entries.first?.message == "\(50)")
        #expect(store.entries.last?.message == "\(capacity + 49)")
    }

    @Test("clear vacía el registro")
    func clearsEntries() {
        let store = LogStore()
        store.append(LogEntryRecord(level: .error, category: "queue", message: "fallo"))
        store.clear()
        #expect(store.entries.isEmpty)
    }
}