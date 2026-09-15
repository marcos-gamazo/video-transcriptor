import Foundation

/// En CI los runners headless bloquean AVFoundation (dlopen/deadlock),
/// así que las suites de media se deshabilitan por defecto en ese entorno.
/// Localmente no hay que definir nada: corren siempre.
let mediaTestsEnabled =
    ProcessInfo.processInfo.environment["TRANSCRIPTOR_SKIP_MEDIA_TESTS"] == nil