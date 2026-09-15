import Foundation

/// Gestión de modelos Vosk locales.
///
/// A diferencia de los activos de Speech de Apple, los modelos Vosk son
/// directorios locales (`~/Library/Application Support/Transcriptor/models/`).
///
/// Fase 1: resolución de modelo y comprobación de instalación ya son
/// funcionales. La descarga/instalación se implementa en Fase 4
/// (task 4.x); por ahora `install` lanza `VoskError.installNotAvailable`.
actor VoskModelManager {
    struct LocalePreflight: Equatable, Sendable {
        let resolvedLocale: Locale
        let modelName: String
        let installed: Bool
    }

    /// Idiomas disponibles en la instalación Vosk. Convención de idioma
    /// explícita elegida por el usuario (sin detección automática).
    static let supportedLocales: [Locale] = [
        Locale(identifier: "es_ES"),
        Locale(identifier: "en_US")
    ]

    static func modelName(for locale: Locale) -> String? {
        switch languageCode(of: locale) {
        case "es": return "vosk-model-small-es"
        case "en": return "vosk-model-small-en"
        default: return nil
        }
    }

    static var modelsDirectory: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support
            .appendingPathComponent(AppEnvironment.bundleIdentifier, isDirectory: true)
            .appendingPathComponent("models", isDirectory: true)
    }

    func preflight(locale requested: Locale) async throws -> LocalePreflight {
        guard let modelName = Self.modelName(for: requested) else {
            throw VoskError.unsupportedLocale
        }
        let resolved = Self.resolve(locale: requested)
        let installed = await isInstalled(modelName: modelName)
        return LocalePreflight(resolvedLocale: resolved, modelName: modelName, installed: installed)
    }

    func isInstalled(modelName: String) async -> Bool {
        let modelURL = Self.modelsDirectory.appendingPathComponent(modelName, isDirectory: true)
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: modelURL.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }

    func install(
        locale: Locale,
        onProgress: @escaping @Sendable (Double) -> Void = { _ in }
    ) async throws -> Locale {
        throw VoskError.installNotAvailable
    }

    private static func languageCode(of locale: Locale) -> String {
        let id = locale.identifier
        let separatorIndex = id.firstIndex { $0 == "_" || $0 == "-" }
        guard let separatorIndex else { return id }
        return String(id[..<separatorIndex])
    }

    private static func resolve(locale: Locale) -> Locale {
        guard languageCode(of: locale) == "en" else { return Locale(identifier: "es_ES") }
        return Locale(identifier: "en_US")
    }
}