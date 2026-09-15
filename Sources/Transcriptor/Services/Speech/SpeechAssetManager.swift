import Foundation
import Speech

actor SpeechAssetManager {
    struct LocalePreflight: Equatable, Sendable {
        let resolvedLocale: Locale
        let installed: Bool
    }

    func preflight(locale requested: Locale) async throws -> LocalePreflight {
        guard let resolved = await SpeechTranscriber.supportedLocale(equivalentTo: requested) else {
            AppLogger.speech.error("Idioma no soportado: \(requested.identifier)")
            throw SpeechError.unsupportedLocale
        }
        let installed = await isInstalled(resolved)
        return LocalePreflight(resolvedLocale: resolved, installed: installed)
    }

    func isInstalled(_ locale: Locale) async -> Bool {
        let installed = await SpeechTranscriber.installedLocales
        return installed.contains(locale)
    }

    func install(
        locale: Locale,
        onProgress: @escaping @Sendable (Double) -> Void = { _ in }
    ) async throws -> Locale {
        guard await !isInstalled(locale) else {
            return locale
        }
        try Task.checkCancellation()

        let transcriber = SpeechTranscriber(locale: locale, preset: .timeIndexedTranscriptionWithAlternatives)

        let alreadyReserved = await AssetInventory.reservedLocales.contains(locale)
        let didReserve: Bool
        if alreadyReserved {
            didReserve = true
        } else {
            didReserve = try await AssetInventory.reserve(locale: locale)
        }
        guard didReserve else {
            AppLogger.speech.error("No se pudo reservar el idioma para la instalación: \(locale.identifier)")
            throw SpeechError.assetInstallationFailed("No se pudo reservar el idioma para la instalación.")
        }
        let reservedBySelf = !alreadyReserved && didReserve

        do {
            guard let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) else {
                throw SpeechError.assetInstallationFailed("No se pudo crear la solicitud de instalación.")
            }
            try Task.checkCancellation()

            let progress = request.progress
            let token = progress.observe(
                \.fractionCompleted,
                options: [.initial, .new]
            ) { observed, _ in
                onProgress(Double(observed.fractionCompleted))
            }
            defer { token.invalidate() }

            do {
                try await request.downloadAndInstall()
            } catch {
                throw Self.mapInstallError(error)
            }

            onProgress(1)
            return locale
        } catch let error as SpeechError {
            if error == .offlineAssetInstallation {
                AppLogger.speech.error("Instalación offline del idioma \(locale.identifier)")
            } else {
                AppLogger.speech.error("Fallo de instalación del idioma \(locale.identifier): \(error)")
            }
            if reservedBySelf {
                _ = await AssetInventory.release(reservedLocale: locale)
            }
            throw error
        } catch {
            AppLogger.speech.error("Fallo desconocido al instalar el idioma \(locale.identifier): \(error)")
            if reservedBySelf {
                _ = await AssetInventory.release(reservedLocale: locale)
            }
            throw error
        }
    }

    private static func mapInstallError(_ error: Error) -> SpeechError {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            let offlineCodes: Set<Int> = [
                NSURLErrorNotConnectedToInternet,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorTimedOut,
                NSURLErrorCannotFindHost,
                NSURLErrorCannotConnectToHost,
            ]
            if offlineCodes.contains(nsError.code) {
                return .offlineAssetInstallation
            }
        }
        return .assetInstallationFailed(nsError.localizedDescription)
    }
}