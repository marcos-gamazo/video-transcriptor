import Foundation
@testable import Transcriptor

/// En CI los runners headless bloquean AVFoundation (dlopen/deadlock),
/// así que las suites de media se deshabilitan por defecto en ese entorno.
/// Localmente no hay que definir nada: corren siempre.
let mediaTestsEnabled =
    ProcessInfo.processInfo.environment["TRANSCRIPTOR_SKIP_MEDIA_TESTS"] == nil

/// Los tests de transcripción end-to-end con Vosk requieren, además de AVFoundation,
/// que el modelo del idioma esté instalado en la ruta de modelos de la aplicación
/// (`~/Library/Application Support/Transcriptor/models/vosk-model-small-es-0.42`).
/// Con el modelo ausente se omiten; no se descargan modelos en CI.
let voskIntegrationTestsEnabled: Bool = {
    guard mediaTestsEnabled else { return false }
    let url = VoskModelManager.modelsDirectory
        .appendingPathComponent("vosk-model-small-es-0.42", isDirectory: true)
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
          isDirectory.boolValue else {
        return false
    }
    return true
}()