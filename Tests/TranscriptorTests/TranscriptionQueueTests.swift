import Testing
import Foundation
@testable import Transcriptor

actor StubTranscribing: Transcribing {
    typealias Handler = @Sendable (
        TranscriptionJob,
        @escaping @Sendable (TranscriptionJobState) -> Void,
        @escaping @Sendable (TranscriptionProgress) -> Void,
        @escaping @Sendable (TranscriptionSegment) -> Void
    ) async throws -> TranscriptionSummary

    private var handler: Handler?
    private var callCount = 0
    private var activeCount = 0
    private var maxActive = 0

    var invocationCount: Int {
        callCount
    }

    var peakConcurrency: Int {
        maxActive
    }

    func setHandler(_ handler: @escaping Handler) {
        self.handler = handler
    }

    func transcribe(
        job: TranscriptionJob,
        onState: @escaping @Sendable (TranscriptionJobState) -> Void,
        onProgress: @escaping @Sendable (TranscriptionProgress) -> Void,
        onSegment: @escaping @Sendable (TranscriptionSegment) -> Void
    ) async throws -> TranscriptionSummary {
        activeCount += 1
        maxActive = max(maxActive, activeCount)
        defer { activeCount -= 1 }
        callCount += 1

        guard let handler else {
            return TranscriptionSummary(segmentCount: 0, finalEndTime: nil)
        }
        return try await handler(job, onState, onProgress, onSegment)
    }
}

private final class UUIDList: @unchecked Sendable {
    private let lock = NSLock()
    private var boxed: [UUID] = []

    var values: [UUID] {
        lock.withLock { boxed }
    }

    func append(_ uuid: UUID) {
        lock.withLock { boxed.append(uuid) }
    }
}

private final class IndexBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func next() -> Int {
        lock.withLock {
            defer { value += 1 }
            return value
        }
    }
}

@Suite("TranscriptionQueue")
struct TranscriptionQueueTests {
    private final class Recorder: @unchecked Sendable {
        private let lock = NSLock()
        private var boxed: [TranscriptionQueue.Snapshot] = []

        var snapshots: [TranscriptionQueue.Snapshot] {
            lock.withLock { boxed }
        }

        func add(_ snapshot: TranscriptionQueue.Snapshot) {
            lock.withLock { boxed.append(snapshot) }
        }
    }

    private func makeJobs(_ count: Int) -> [TranscriptionJob] {
        (0..<count).map { index in
            TranscriptionJob(
                sourceURL: URL(fileURLWithPath: "/tmp/fixture-\(index).m4a"),
                locale: Locale(identifier: "es_ES"),
                includeTimestamps: false
            )
        }
    }

    private func tempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("queue-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func isTerminal(_ state: TranscriptionJobState) -> Bool {
        state == .completed || state == .cancelled || state == .failed
    }

    private func waitUntil(
        _ condition: @escaping () async -> Bool,
        timeout: Duration = .seconds(5)
    ) async -> Bool {
        let clock = ContinuousClock()
        let start = clock.now
        while clock.now - start < timeout {
            if await condition() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return await condition()
    }

    @Test("Procesa los trabajos en orden FIFO y solo uno a la vez")
    func processesFIFOWithSingleConcurrency() async throws {
        let stub = StubTranscribing()
        let seen = UUIDList()
        await stub.setHandler { job, _, _, _ in
            seen.append(job.id)
            try? await Task.sleep(for: .milliseconds(20))
            return TranscriptionSummary(segmentCount: 1, finalEndTime: .seconds(1))
        }

        let queue = TranscriptionQueue(service: stub, destinationDirectory: try tempDirectory())
        let jobs = makeJobs(3)
        await queue.enqueue(jobs: jobs)
        await queue.start()

        let done = await waitUntil { [queue] in
            let snapshot = await queue.snapshot
            return snapshot.entries.count == 3 && snapshot.entries.allSatisfy { self.isTerminal($0.state) }
        }
        #expect(done)

        let finalSnapshot = await queue.snapshot
        #expect(finalSnapshot.entries.allSatisfy { $0.state == .completed })
        #expect(seen.values == jobs.map(\.id))
        #expect(await stub.peakConcurrency == 1)
        #expect(await stub.invocationCount == 3)
    }

    @Test("Un fallo de un trabajo no detiene los siguientes")
    func failedJobDoesNotStopTheQueue() async throws {
        let stub = StubTranscribing()
        let box = IndexBox()
        await stub.setHandler { _, _, _, _ in
            let current = box.next()
            if current == 0 {
                throw MediaError.unsupportedMedia
            }
            return TranscriptionSummary(segmentCount: 1, finalEndTime: nil)
        }

        let queue = TranscriptionQueue(service: stub, destinationDirectory: try tempDirectory())
        let jobs = makeJobs(2)
        await queue.enqueue(jobs: jobs)
        await queue.start()

        let done = await waitUntil { [queue] in
            await queue.snapshot.entries.allSatisfy { self.isTerminal($0.state) }
        }
        #expect(done)

        let snapshot = await queue.snapshot
        #expect(snapshot.entries[0].state == .failed)
        #expect(snapshot.entries[1].state == .completed)
    }

    @Test("Un trabajo cancelado no bloquea la cola")
    func cancelledJobDoesNotBlockTheQueue() async throws {
        let stub = StubTranscribing()
        let jobs = makeJobs(2)
        let firstID = jobs[0].id
        await stub.setHandler { job, _, _, _ in
            if job.id == firstID {
                try await Task.sleep(for: .seconds(5))
            }
            return TranscriptionSummary(segmentCount: 1, finalEndTime: nil)
        }

        let queue = TranscriptionQueue(service: stub, destinationDirectory: try tempDirectory())
        await queue.enqueue(jobs: jobs)
        await queue.start()

        let started = await waitUntil { [queue] in
            let snapshot = await queue.snapshot
            return snapshot.entries.contains { $0.state == .preparing || $0.state == .transcribing }
        }
        #expect(started)

        await queue.cancel(id: firstID)

        let done = await waitUntil { [queue] in
            await queue.snapshot.entries.allSatisfy { self.isTerminal($0.state) }
        }
        #expect(done)

        let snapshot = await queue.snapshot
        #expect(snapshot.entries[0].state == .cancelled)
        #expect(snapshot.entries[1].state == .completed)
    }

    @Test("Cancelar todo deja los trabajos pendientes cancelados")
    func cancelAllCancelsPendingJobs() async throws {
        let stub = StubTranscribing()
        await stub.setHandler { _, _, _, _ in
            try await Task.sleep(for: .seconds(5))
            return TranscriptionSummary(segmentCount: 0, finalEndTime: nil)
        }

        let queue = TranscriptionQueue(service: stub, destinationDirectory: try tempDirectory())
        let jobs = makeJobs(3)
        await queue.enqueue(jobs: jobs)
        await queue.start()

        let started = await waitUntil { [queue] in
            await queue.snapshot.entries.contains { $0.state == .preparing || $0.state == .transcribing }
        }
        #expect(started)

        await queue.cancelAll()

        let done = await waitUntil { [queue] in
            await queue.snapshot.entries.allSatisfy { self.isTerminal($0.state) }
        }
        #expect(done)

        let snapshot = await queue.snapshot
        #expect(snapshot.entries.allSatisfy { $0.state == .cancelled })
    }

    @Test("Eliminar un trabajo pendiente lo quita sin bloquear la cola")
    func removePendingRemovesItFromTheQueue() async throws {
        let stub = StubTranscribing()
        let box = IndexBox()
        await stub.setHandler { _, _, _, _ in
            let current = box.next()
            if current == 0 {
                try? await Task.sleep(for: .milliseconds(200))
            }
            return TranscriptionSummary(segmentCount: 1, finalEndTime: nil)
        }

        let queue = TranscriptionQueue(service: stub, destinationDirectory: try tempDirectory())
        let jobs = makeJobs(3)
        await queue.enqueue(jobs: jobs)
        await queue.start()

        let removed = await queue.removePending(id: jobs[1].id)
        #expect(removed)

        let done = await waitUntil { [queue] in
            let snapshot = await queue.snapshot
            return snapshot.entries.count == 2 && snapshot.entries.allSatisfy { $0.state == .completed }
        }
        #expect(done)

        let snapshot = await queue.snapshot
        #expect(snapshot.entries.map(\.id) == [jobs[0].id, jobs[2].id])
        #expect(snapshot.entries.allSatisfy { $0.state == .completed })
    }

    @Test("Los trabajos pendientes no disparan transcripción hasta que les toca")
    func pendingJobsStayAsMetadataUntilActive() async throws {
        let stub = StubTranscribing()
        let box = IndexBox()
        await stub.setHandler { _, _, _, _ in
            let current = box.next()
            if current == 0 {
                try? await Task.sleep(for: .milliseconds(300))
            }
            return TranscriptionSummary(segmentCount: 1, finalEndTime: nil)
        }

        let queue = TranscriptionQueue(service: stub, destinationDirectory: try tempDirectory())
        let jobs = makeJobs(4)
        await queue.enqueue(jobs: jobs)
        await queue.start()

        let observed = await waitUntil { [queue] in
            let snapshot = await queue.snapshot
            return snapshot.entries[0].state == .preparing || snapshot.entries[0].state == .transcribing
        }
        #expect(observed)

        let midSnapshot = await queue.snapshot
        #expect(midSnapshot.entries.count == 4)
        #expect(midSnapshot.entries[1...].allSatisfy { $0.state == .pending })
        #expect(await stub.invocationCount == 1,
                "Solo debería haberse iniciado el primer trabajo.")

        let done = await waitUntil { [queue] in
            await queue.snapshot.entries.allSatisfy { $0.state == .completed }
        }
        #expect(done)
        #expect(await stub.invocationCount == 4)
    }

    @Test("Propaga el progreso y el estado del trabajo activo")
    func propagatesProgressAndState() async throws {
        let stub = StubTranscribing()
        await stub.setHandler { _, onState, onProgress, _ in
            onState(.transcribing)
            onProgress(TranscriptionProgress(overall: 0.25, download: 0, transcription: 0.5))
            // Los pasos superan la ventana de throttling (200 ms) para que
            // los valores intermedios lleguen al observador.
            for fraction in stride(from: 0.0, through: 1.0, by: 0.25) {
                onProgress(TranscriptionProgress(
                    overall: 0.25 + 0.75 * fraction,
                    download: 0,
                    transcription: fraction
                ))
                try? await Task.sleep(for: .milliseconds(260))
            }
            onState(.completed)
            return TranscriptionSummary(segmentCount: 2, finalEndTime: nil)
        }

        let recorder = Recorder()
        let queue = TranscriptionQueue(service: stub, destinationDirectory: try tempDirectory())
        await queue.setObserver { recorder.add($0) }
        let jobs = makeJobs(1)
        await queue.enqueue(jobs: jobs)
        await queue.start()

        let done = await waitUntil { [queue] in
            await queue.snapshot.entries.allSatisfy { $0.state == .completed }
        }
        #expect(done)

        let finalEntry = recorder.snapshots.last?.entries.first
        #expect(finalEntry?.state == .completed)
        #expect(finalEntry?.progress.overall == 1)

        let observedStates = recorder.snapshots.compactMap(\.entries.first?.state)
        #expect(observedStates.contains(.preparing))
        #expect(observedStates.contains(.transcribing))

        let observedOveralls = recorder.snapshots.compactMap(\.entries.first?.progress.overall)
        let hasIntermediate = observedOveralls.contains { $0 > 0 && $0 < 1 }
        #expect(hasIntermediate)
    }

    @Test("Encolar no procesa hasta que se llama a start")
    func enqueueDoesNotStartUntilExplicitlyStarted() async throws {
        let stub = StubTranscribing()
        await stub.setHandler { _, _, _, _ in
            return TranscriptionSummary(segmentCount: 1, finalEndTime: nil)
        }

        let queue = TranscriptionQueue(service: stub, destinationDirectory: try tempDirectory())
        await queue.enqueue(jobs: makeJobs(2))

        try? await Task.sleep(for: .milliseconds(200))
        #expect(await stub.invocationCount == 0,
                "Encolar no debería iniciar la transcripción por sí mismo.")

        let snapshot = await queue.snapshot
        #expect(snapshot.entries.allSatisfy { $0.state == .pending })

        await queue.start()

        let done = await waitUntil { [queue] in
            await queue.snapshot.entries.allSatisfy { self.isTerminal($0.state) }
        }
        #expect(done)
        #expect(await stub.invocationCount == 2)
    }

    @Test("applyPendingSettings actualiza solo los trabajos pendientes")
    func applyPendingSettingsUpdatesPendingJobsOnly() async throws {
        let stub = StubTranscribing()
        let jobs = makeJobs(2)
        let firstID = jobs[0].id
        await stub.setHandler { job, _, _, _ in
            if job.id == firstID {
                try await Task.sleep(for: .seconds(5))
            }
            return TranscriptionSummary(segmentCount: 1, finalEndTime: nil)
        }

        let queue = TranscriptionQueue(service: stub, destinationDirectory: try tempDirectory())
        await queue.enqueue(jobs: jobs)
        await queue.start()

        let started = await waitUntil { [queue] in
            await queue.snapshot.entries.contains { $0.state == .transcribing || $0.state == .preparing }
        }
        #expect(started)

        let newLocale = Locale(identifier: "en_US")
        let updated = await queue.applyPendingSettings(locale: newLocale, includeTimestamps: true)
        #expect(updated == 1)

        let snapshot = await queue.snapshot
        let active = snapshot.entries.first { $0.id == firstID }
        let pending = snapshot.entries.first { $0.id == jobs[1].id }
        #expect(active != nil)
        if let active {
            #expect(active.job.locale != newLocale)
            #expect(active.job.includeTimestamps == false)
        }
        #expect(pending != nil)
        if let pending {
            #expect(pending.job.locale == newLocale)
            #expect(pending.job.includeTimestamps == true)
        }
    }

    @Test("Un fallo guarda un mensaje comprensible para el usuario")
    func failedEntryExposesFriendlyMessage() async throws {
        let stub = StubTranscribing()
        await stub.setHandler { _, _, _, _ in
            throw MediaError.unsupportedMedia
        }

        let queue = TranscriptionQueue(service: stub, destinationDirectory: try tempDirectory())
        await queue.enqueue(jobs: makeJobs(1))
        await queue.start()

        let done = await waitUntil { [queue] in
            await queue.snapshot.entries.allSatisfy { self.isTerminal($0.state) }
        }
        #expect(done)

        let entry = await queue.snapshot.entries.first
        #expect(entry?.state == .failed)
        #expect(entry?.failureMessage == MediaError.unsupportedMedia.userMessage)
    }

    @Test("Una ráfaga de progreso no inunda al observador (throttling)")
    func progressBurstDoesNotFloodObserver() async throws {
        let stub = StubTranscribing()
        await stub.setHandler { _, onState, onProgress, _ in
            onState(.transcribing)
            // Simula un vídeo largo: miles de actualizaciones de progreso inmediatas.
            for fraction in 0...20_000 {
                onProgress(TranscriptionProgress(
                    overall: 0.25 + 0.75 * Double(fraction) / 20_000,
                    download: 0,
                    transcription: Double(fraction) / 20_000
                ))
            }
            onState(.completed)
            return TranscriptionSummary(segmentCount: 20_000, finalEndTime: nil)
        }

        let recorder = Recorder()
        let queue = TranscriptionQueue(service: stub, destinationDirectory: try tempDirectory())
        await queue.setObserver { recorder.add($0) }
        await queue.enqueue(jobs: makeJobs(1))
        await queue.start()

        let done = await waitUntil { [queue] in
            await queue.snapshot.entries.allSatisfy { $0.state == .completed }
        }
        #expect(done)

        #expect(recorder.snapshots.count <= 100,
                "20 000 progresos no deberían generar cientos de snapshots, sino ~\(recorder.snapshots.count).")

        let finalEntry = recorder.snapshots.last?.entries.first
        #expect(finalEntry?.state == .completed)
        #expect(finalEntry?.progress.overall == 1)
    }
}