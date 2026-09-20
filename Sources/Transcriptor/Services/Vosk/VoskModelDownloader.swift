import Foundation

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}

/// Descarga un modelo Vosk desde la fuente oficial con reporte de progreso.
///
/// Usa `URLSessionDownloadTask` (macOS 11) para volcar el zip directamente a
/// disco sin cargarlo completo en memoria. La cancelación de la tarea Swift
/// que `await`e a `download(from:onProgress:)` cancela la descarga subyacente.
final class VoskModelDownloader: NSObject, URLSessionDownloadDelegate {
    private final class State: @unchecked Sendable {
        let lock = NSLock()
        var task: URLSessionDownloadTask?
        var continuation: CheckedContinuation<URL, Error>?
        var progressHandler: (@Sendable (Double) -> Void)?
    }

    private let state = State()

    func download(
        from url: URL,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        let session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)
        let task = session.downloadTask(with: url)

        state.lock.withLock {
            state.task = task
            state.progressHandler = onProgress
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                state.lock.withLock {
                    state.continuation = continuation
                }
                task.resume()
            }
        } onCancel: {
            task.cancel()
        }
    }

    private func finish(resumingWith result: Result<URL, Error>) {
        let continuation: CheckedContinuation<URL, Error>? = state.lock.withLock {
            defer {
                state.continuation = nil
                state.progressHandler = nil
            }
            return state.continuation
        }
        guard let continuation else { return }
        switch result {
        case .success(let url):
            continuation.resume(returning: url)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}

extension VoskModelDownloader {
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let fraction = min(1, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
        state.lock.lock()
        let handler = state.progressHandler
        state.lock.unlock()
        handler?(fraction)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // El fichero temporal solo existe durante la llamada del delegado:
        // se mueve a una ruta estable antes de resolver la continuación.
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("vosk-download-\(UUID().uuidString).zip")
        do {
            try FileManager.default.moveItem(at: location, to: destination)
            finish(resumingWith: .success(destination))
        } catch {
            finish(resumingWith: .failure(VoskError.downloadFailed(
                "No se pudo guardar el modelo descargado: \(error.localizedDescription)"
            )))
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionDownloadTask,
        didCompleteWithError error: Error?
    ) {
        guard let error else { return }
        finish(resumingWith: .failure(error))
    }
}