import Foundation

/// Gestión de modelos Vosk locales.
///
/// A diferencia de los activos de Speech de Apple, los modelos Vosk son
/// directorios locales (`~/Library/Application Support/Transcriptor/models/`).
/// Cada modelo se descarga desde la fuente oficial de Vosk
/// (`alphacephei.com/vosk/models`) y se valida antes de considerarse instalado.
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

    /// Nombre oficial del modelo en la fuente `alphacephei.com/vosk/models`.
    /// El directorio local usa el mismo nombre que el zip oficial para que la
    /// extracción no requiera renombrar el directorio raíz del modelo.
    static func modelName(for locale: Locale) -> String? {
        switch languageCode(of: locale) {
        case "es": return "vosk-model-small-es-0.42"
        case "en": return "vosk-model-small-en-us-0.15"
        default: return nil
        }
    }

    /// URL oficial de descarga del zip del modelo.
    static func downloadURL(for modelName: String) -> URL? {
        URL(string: "https://alphacephei.com/vosk/models/\(modelName).zip")
    }

    /// Tamaño aproximado del zip oficial, para el aviso previo a la descarga.
    static func zipSizeHint(for modelName: String) -> String {
        switch modelName {
        case "vosk-model-small-es-0.42": return "unos 38 MB"
        case "vosk-model-small-en-us-0.15": return "unos 40 MB"
        default: return "unos 40 MB"
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
        return Self.isValidModel(at: modelURL)
    }

    /// Instala el modelo del idioma si no está ya presente.
    ///
    /// Descarga el zip oficial con progreso, lo descomprime en un directorio
    /// temporal, valida el grafo de reconocimiento (`am/final.mdl`) y lo
    /// mueve de forma atómica a `modelsDirectory`. Los recursos parciales se
    /// eliminan si el proceso falla o se cancela.
    func install(
        locale: Locale,
        onProgress: @escaping @Sendable (Double) -> Void = { _ in }
    ) async throws -> Locale {
        guard let modelName = Self.modelName(for: locale) else {
            throw VoskError.unsupportedLocale
        }
        let resolved = Self.resolve(locale: locale)

        // Idempotente: si ya está instalado, no se descarga nada.
        if await isInstalled(modelName: modelName) {
            return resolved
        }
        try Task.checkCancellation()

        guard let downloadURL = Self.downloadURL(for: modelName) else {
            throw VoskError.downloadFailed("La URL de descarga del modelo no es válida.")
        }
        let modelsDir = Self.modelsDirectory
        try FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)

        let downloader = VoskModelDownloader()
        let zipURL: URL
        do {
            zipURL = try await downloader.download(from: downloadURL, onProgress: onProgress)
        } catch {
            try Task.checkCancellation()
            throw Self.mapDownloadError(error)
        }
        defer { try? FileManager.default.removeItem(at: zipURL) }

        try Task.checkCancellation()
        try await Self.installModel(zip: zipURL, modelName: modelName, into: modelsDir)
        return resolved
    }

    // MARK: - Installación

    private static func isValidModel(at url: URL) -> Bool {
        let am = url.appendingPathComponent("am/final.mdl")
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: am.path, isDirectory: &isDirectory)
            && !isDirectory.boolValue
    }

    private static func installModel(zip: URL, modelName: String, into modelsDir: URL) async throws {
        let workDir = modelsDir
            .appendingPathComponent(".install-\(modelName)-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: workDir) }
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)

        try await unzip(zip, into: workDir)
        try Task.checkCancellation()

        let contents = try FileManager.default.contentsOfDirectory(
            at: workDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        // El zip oficial contiene un único directorio raíz con el modelo.
        let root: URL
        if contents.count == 1 {
            root = contents[0]
        } else {
            root = workDir
        }
        guard isValidModel(at: root) else {
            throw VoskError.modelCorrupted("El modelo descargado no contiene un grafo de reconocimiento válido.")
        }

        let target = modelsDir.appendingPathComponent(modelName, isDirectory: true)
        if FileManager.default.fileExists(atPath: target.path) {
            try FileManager.default.removeItem(at: target)
        }
        try FileManager.default.moveItem(at: root, to: target)
        try Task.checkCancellation()
    }

    /// Descomprime el zip con `/usr/bin/ditto` (presente en macOS 11),
    /// evitando dependencias de terceros. Corrige permisos de ejecución.
    private static func unzip(_ zip: URL, into destination: URL) async throws {
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-x", "-k", zip.path, destination.path]
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                throw VoskError.downloadFailed("No se pudo descomprimir el modelo descargado.")
            }
            try Task.checkCancellation()
        }.value
    }

    static func mapDownloadError(_ error: Error) -> VoskError {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost,
                 .timedOut, .cannotFindHost, .cannotConnectToHost,
                 .dnsLookupFailed, .dataNotAllowed, .internationalRoamingOff:
                return .offlineAssetInstallation
            default:
                return .downloadFailed(urlError.localizedDescription)
            }
        }
        return .downloadFailed(error.localizedDescription)
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