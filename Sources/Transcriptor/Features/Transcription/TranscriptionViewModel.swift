import AppKit
import Foundation
import Observation
import Speech

@MainActor
@Observable
final class TranscriptionViewModel {
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

    var languageOptions: [LanguageOption] = []
    var selectedLanguageID = "es"
    var includeTimestamps = false
    var areLanguagesLoading = true
    var isImportingFiles = false
    var destinationDirectory: URL = TranscriptionViewModel.defaultDestination
    var entries: [TranscriptionQueue.Entry] = []
    var rejectedFiles: [RejectedFile] = []

    private let queue: TranscriptionQueue
    private let validator = FileValidator()

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
        await queue.start()
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
        let supported = await SpeechTranscriber.supportedLocales
        var byLanguage: [String: String] = [:]
        for locale in supported {
            guard let code = locale.language.languageCode?.identifier else { continue }
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
}