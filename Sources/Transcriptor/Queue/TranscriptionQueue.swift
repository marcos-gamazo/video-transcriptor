import Foundation

actor TranscriptionQueue {
    struct Entry: Identifiable, Equatable, Sendable {
        let id: UUID
        var job: TranscriptionJob
        var state: TranscriptionJobState
        var progress: TranscriptionProgress
        var outputURL: URL?
        var failureMessage: String?

        init(job: TranscriptionJob) {
            self.id = job.id
            self.job = job
            self.state = .pending
            self.progress = TranscriptionProgress(overall: 0, download: 0, transcription: 0)
            self.outputURL = nil
            self.failureMessage = nil
        }
    }

    struct Snapshot: Equatable, Sendable {
        var entries: [Entry]
        var isRunning: Bool
    }

    private let service: any Transcribing
    private var destinationDirectory: URL
    private var entries: [Entry] = []
    private var worker: Task<Void, Never>?
    private var currentWork: (id: UUID, task: Task<Void, Never>)?
    private var observer: (@Sendable (Snapshot) -> Void)?
    private var lastEmitTime: Date?
    private var pendingSnapshot: Snapshot?

    init(
        service: any Transcribing = TranscriptionService(),
        destinationDirectory: URL = FileManager.default
            .urls(for: .moviesDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
    ) {
        self.service = service
        self.destinationDirectory = destinationDirectory
    }

    var snapshot: Snapshot {
        Snapshot(entries: entries, isRunning: currentWork != nil)
    }

    func setObserver(_ block: @escaping @Sendable (Snapshot) -> Void) {
        observer = block
        block(snapshot)
    }

    func setDestinationDirectory(_ url: URL) {
        destinationDirectory = url
    }

    func enqueue(jobs: [TranscriptionJob]) async {
        for job in jobs where !entries.contains(where: { $0.id == job.id }) {
            entries.append(Entry(job: job))
        }
        emit()
    }

    /// Inicia el procesamiento de los trabajos pendientes.
    ///
    /// Si ya existe un worker activo, la llamada no hace nada y el trabajo
    /// activo continúa absorbiendo los pendientes que se añadan después.
    func start() async {
        await ensureWorker()
    }

    /// Actualiza el idioma y los timestamps de los trabajos todavía pendientes.
    ///
    /// Devuelve el número de trabajos actualizados. No afecta al trabajo activo.
    @discardableResult
    func applyPendingSettings(locale: Locale?, includeTimestamps: Bool?) -> Int {
        var updated = 0
        for index in entries.indices where entries[index].state == .pending {
            var job = entries[index].job
            if let locale {
                job = TranscriptionJob(
                    id: job.id,
                    sourceURL: job.sourceURL,
                    locale: locale,
                    includeTimestamps: job.includeTimestamps
                )
            }
            if let includeTimestamps {
                job = TranscriptionJob(
                    id: job.id,
                    sourceURL: job.sourceURL,
                    locale: job.locale,
                    includeTimestamps: includeTimestamps
                )
            }
            entries[index].job = job
            updated += 1
        }
        if updated > 0 { emit() }
        return updated
    }

    /// Indica si queda algún trabajo sin procesar (pendiente o en curso).
    var hasPendingWork: Bool {
        entries.contains { $0.state == .pending || Self.isActiveProcessing($0.state) }
    }

    private static func isActiveProcessing(_ state: TranscriptionJobState) -> Bool {
        state == .preparing || state == .downloading || state == .transcribing
    }

    func cancel(id: UUID) async {
        if let index = entryIndex(id), entries[index].state == .pending {
            entries[index].state = .cancelled
            emit()
            return
        }
        if let current = currentWork, current.id == id, let index = entryIndex(id) {
            entries[index].state = .cancelled
            emit()
            current.task.cancel()
        }
    }

    func cancelAll() async {
        if let current = currentWork, let index = entryIndex(current.id) {
            entries[index].state = .cancelled
        }
        for index in entries.indices where entries[index].state == .pending {
            entries[index].state = .cancelled
        }
        currentWork?.task.cancel()
        emit()
    }

    @discardableResult
    func removePending(id: UUID) async -> Bool {
        guard let index = entryIndex(id), entries[index].state == .pending else {
            return false
        }
        entries.remove(at: index)
        emit()
        return true
    }

    // MARK: - Procesado

    private func ensureWorker() async {
        guard worker == nil, nextPendingID() != nil else { return }
        let task = Task { [weak self] in
            guard let self else { return }
            await self.drain()
        }
        worker = task
    }

    private func drain() async {
        defer {
            flushPending()
            currentWork?.task.cancel()
            currentWork = nil
            worker = nil
            emit(immediate: true)
        }
        while !Task.isCancelled {
            guard let id = nextPendingID() else { return }
            await process(id: id)
        }
    }

    private func process(id: UUID) async {
        guard let index = entryIndex(id), entries[index].state == .pending else {
            return
        }

        let job = entries[index].job
        let outputURL = FileDestinationService.uniqueOutputURL(for: job.sourceURL, in: destinationDirectory)
        entries[index].outputURL = outputURL
        entries[index].state = .preparing
        emit(immediate: true)

        let sink = MarkdownTranscriptionSink(
            outputURL: outputURL,
            includeTimestamps: job.includeTimestamps,
            title: job.sourceURL.deletingPathExtension().lastPathComponent
        )
        do {
            try sink.open()
        } catch {
            finalizeFailure(index: index, sink: sink, error: error)
            return
        }

        let writeErrors = LockedError()
        let summaryBox = ResultBox<TranscriptionSummary>()

        let workTask = Task { [weak self] in
            guard let self else { return }
            do {
                let summary = try await self.runTranscription(
                    job: job,
                    id: id,
                    sink: sink,
                    writeErrors: writeErrors
                )
                summaryBox.set(.success(summary))
            } catch {
                summaryBox.set(.failure(error))
            }
        }

        currentWork = (id: id, task: workTask)
        await workTask.value
        currentWork = nil

        guard let finalIndex = entryIndex(id) else { return }

        if let writeError = writeErrors.error {
            finalizeFailure(index: finalIndex, sink: sink, error: writeError)
            return
        }

        switch summaryBox.result {
        case .success:
            do {
                try sink.finish()
                finalizeSuccess(index: finalIndex, sink: sink, outputURL: outputURL)
            } catch {
                finalizeFailure(index: finalIndex, sink: sink, error: error)
            }
        case .failure(let error):
            if Self.isCancellation(error) || workTask.isCancelled {
                finalizeCancelled(index: finalIndex, sink: sink)
            } else {
                finalizeFailure(index: finalIndex, sink: sink, error: error)
            }
        case nil:
            finalizeFailure(index: finalIndex, sink: sink, error: TranscriptionError.cancelled)
        }
    }

    private func runTranscription(
        job: TranscriptionJob,
        id: UUID,
        sink: MarkdownTranscriptionSink,
        writeErrors: LockedError
    ) async throws -> TranscriptionSummary {
        try await service.transcribe(
            job: job,
            onState: { [weak self] state in
                Task { [weak self] in
                    await self?.applyState(id: id, state: state)
                }
            },
            onProgress: { [weak self] progress in
                Task { [weak self] in
                    await self?.applyProgress(id: id, progress: progress)
                }
            },
            onSegment: { segment in
                do {
                    try sink.append(segment)
                } catch {
                    writeErrors.set(error)
                }
            }
        )
    }

    private func applyState(id: UUID, state: TranscriptionJobState) {
        guard let index = entryIndex(id) else { return }
        entries[index].state = state
        switch state {
        case .completed:
            entries[index].progress = TranscriptionProgress(overall: 1, download: 0, transcription: 1)
        default:
            break
        }
        emit(immediate: true)
    }

    private func applyProgress(id: UUID, progress: TranscriptionProgress) {
        guard let index = entryIndex(id) else { return }
        entries[index].progress = progress
        emit()
    }

    private func finalizeSuccess(index: Int, sink: MarkdownTranscriptionSink, outputURL: URL) {
        entries[index].state = .completed
        entries[index].progress = TranscriptionProgress(overall: 1, download: 0, transcription: 1)
        entries[index].outputURL = outputURL
        AppLogger.queue.info("Trabajo completado: \(outputURL.lastPathComponent), \(sink.paragraphCount) párrafos")
        emit()
    }

    private func finalizeFailure(index: Int, sink: MarkdownTranscriptionSink, error: Error) {
        sink.abort()
        entries[index].state = .failed
        entries[index].failureMessage = UserErrorMessage.message(for: error)
        AppLogger.queue.error("Trabajo fallido: \(error)")
        emit()
    }

    private func finalizeCancelled(index: Int, sink: MarkdownTranscriptionSink) {
        sink.abort()
        entries[index].state = .cancelled
        AppLogger.queue.info("Trabajo cancelado")
        emit()
    }

    // MARK: - Helpers

    private func nextPendingID() -> UUID? {
        entries.first(where: { $0.state == .pending })?.id
    }

    private func entryIndex(_ id: UUID) -> Int? {
        entries.firstIndex(where: { $0.id == id })
    }

    /// Throttled emit: terminal state changes and explicit flushes go out immediately;
    /// progress-only updates are coalesced to at most 5 Hz.
    private func emit(immediate: Bool = false) {
        let now = Date()
        let hasTerminal = entries.contains { $0.state == .completed || $0.state == .failed || $0.state == .cancelled }

        if immediate || hasTerminal || lastEmitTime == nil {
            let current = snapshot
            if let pending = pendingSnapshot, pending != current {
                observer?(pending)
            }
            observer?(current)
            lastEmitTime = now
            pendingSnapshot = nil
            return
        }

        if let last = lastEmitTime, now.timeIntervalSince(last) >= 0.2 {
            observer?(snapshot)
            lastEmitTime = now
            pendingSnapshot = nil
        } else {
            pendingSnapshot = snapshot
        }
    }

    /// Flush any pending snapshot — called at drain exit to guarantee the final state is delivered.
    private func flushPending() {
        if let pending = pendingSnapshot {
            observer?(pending)
            lastEmitTime = nil
            pendingSnapshot = nil
        }
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let error = error as? TranscriptionError, error == .cancelled { return true }
        return false
    }
}

private final class LockedError: @unchecked Sendable {
    private let lock = NSLock()
    private var boxed: Error?

    var error: Error? {
        lock.withLock { boxed }
    }

    func set(_ error: Error) {
        lock.withLock { boxed = error }
    }
}

private final class ResultBox<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var boxed: Result<Value, Error>?

    var result: Result<Value, Error>? {
        lock.withLock { boxed }
    }

    func set(_ result: Result<Value, Error>) {
        lock.withLock { boxed = result }
    }
}