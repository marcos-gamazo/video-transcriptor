import AppKit
import Foundation
import Combine

@MainActor
final class TranscriptionViewModel: ObservableObject {
    struct LanguageOption: Identifiable {
        let id: String
        let displayName: String

        var locale: Locale { Locale(identifier: id) }
    }

    struct RejectedFile: Identifiable {
        let id = UUID()
        let name: String
        let message: String
    }

    struct ModelDownloadNotice {
        let displayName: String
        let modelName: String
        let sizeHint: String
    }

    @Published var languageOptions: [LanguageOption] = []
    @Published var selectedLanguageID = "es"
    @Published var includeTimestamps = false
    @Published var areLanguagesLoading = true
    @Published var isImportingFiles = false
    @Published var destinationDirectory: URL = TranscriptionViewModel.defaultDestination
    @Published var entries: [TranscriptionQueue.Entry] = []
    @Published var rejectedFiles: [RejectedFile] = []
    @Published var modelDownloadNotice: ModelDownloadNotice?
    @Published var isConfirmingModelDownload = false

    private let queue: TranscriptionQueue
    private let validator = FileValidator()
    private let modelManager = VoskModelManager()

    var selectedLanguage: Locale { Locale(identifier: selectedLanguageID) }

    var isProcessing: Bool {
        entries.contains {
            $0.state == .preparing || $0.state == .downloading || $0.state == .transcribing
        }
    }

    var hasPending: Bool {
        entries.contains { $0.state == .pending }
    }

    var canStart: Bool {
        hasPending && !isProcessing
    }

    static var defaultDestination: URL {
        FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
    }

    init(queue: TranscriptionQueue = TranscriptionQueue()) {
        self.queue = queue
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.configureQueueObserving()
            await self.loadLanguages()
        }
    }

    private func configureQueueObserving() async {
        await queue.setDestinationDirectory(destinationDirectory)
        await queue.setObserver { [weak self] snapshot in
            Task { @MainActor [weak self] in
                self?.apply(snapshot)
            }
        }
    }

    private func apply(_ snapshot: TranscriptionQueue.Snapshot) {
        entries = snapshot.entries
    }

    func addFiles(_ urls: [URL]) async {
        var valid: [URL] = []
        let existing = rejectedFiles.map { ($0.name, $0.message) }
        for url in urls {
            switch validator.validate(url) {
            case .success(let ok):
                valid.append(ok)
            case .failure(let error):
                let name = url.lastPathComponent
                guard !existing.contains(where: { $0.0 == name && $0.1 == error.userMessage }) else { continue }
                rejectedFiles.append(RejectedFile(name: name, message: error.userMessage))
            }
        }
        guard !valid.isEmpty else { return }
        let jobs = valid.map {
            TranscriptionJob(sourceURL: $0, locale: selectedLanguage, includeTimestamps: includeTimestamps)
        }
        await queue.enqueue(jobs: jobs)
    }

    func dismissRejected(id: UUID) {
        rejectedFiles.removeAll { $0.id == id }
    }

    func dismissAllRejected() {
        rejectedFiles.removeAll()
    }

    func start() async {
        await queue.applyPendingSettings(locale: selectedLanguage, includeTimestamps: includeTimestamps)
        guard hasPending else { return }

        // La primera transcripción de un idioma requiere descargar su modelo:
        // se avisa antes de iniciar la descarga en lugar de empezar sin más.
        do {
            let preflight = try await modelManager.preflight(locale: selectedLanguage)
            guard preflight.installed else {
                modelDownloadNotice = ModelDownloadNotice(
                    displayName: displayName(for: preflight.resolvedLocale),
                    modelName: preflight.modelName,
                    sizeHint: VoskModelManager.zipSizeHint(for: preflight.modelName)
                )
                isConfirmingModelDownload = true
                return
            }
        } catch {
            // Si el idioma no está soportado, se continúa y la cola lo reporta.
        }
        await queue.start()
    }

    func confirmModelDownload() async {
        isConfirmingModelDownload = false
        modelDownloadNotice = nil
        await queue.start()
    }

    func dismissModelDownload() {
        isConfirmingModelDownload = false
        modelDownloadNotice = nil
    }

    func cancelAll() async {
        await queue.cancelAll()
    }

    func cancel(id: UUID) async {
        await queue.cancel(id: id)
    }

    func removePending(id: UUID) async {
        _ = await queue.removePending(id: id)
    }

    func presentFileImport() {
        isImportingFiles = true
    }

    func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Selecciona la carpeta donde se guardarán las transcripciones"
        panel.prompt = "Guardar en"
        panel.directoryURL = destinationDirectory
        guard panel.runModal() == .OK, let url = panel.url else { return }
        destinationDirectory = url
        Task { await queue.setDestinationDirectory(url) }
    }

    func revealInFinder(_ outputURL: URL?) {
        guard let outputURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([outputURL])
    }

    private func loadLanguages() async {
        let supported = VoskModelManager.supportedLocales
        var byLanguage: [String: String] = [:]
        for locale in supported {
            let code = languageCode(of: locale)
            guard !code.isEmpty else { continue }
            guard byLanguage[code] == nil else { continue }
            byLanguage[code] = Locale.current.localizedString(forLanguageCode: code) ?? code
        }
        let options = byLanguage
            .map { LanguageOption(id: $0.key, displayName: $0.value) }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        languageOptions = options
        if let spanish = options.first(where: { $0.id == "es" }) {
            selectedLanguageID = spanish.id
        } else if let first = options.first {
            selectedLanguageID = first.id
        }
        areLanguagesLoading = false
    }

    private func languageCode(of locale: Locale) -> String {
        let id = locale.identifier
        let separatorIndex = id.firstIndex { $0 == "_" || $0 == "-" }
        guard let separatorIndex else { return id }
        return String(id[..<separatorIndex])
    }

    private func displayName(for locale: Locale) -> String {
        let code = languageCode(of: locale)
        return languageOptions.first(where: { $0.id == code })?.displayName
            ?? Locale.current.localizedString(forLanguageCode: code)
            ?? code
    }
}