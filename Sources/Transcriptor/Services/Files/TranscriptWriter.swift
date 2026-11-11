import Foundation

/// Escribe la transcripción de forma incremental en Markdown o texto plano.
final class TranscriptWriter {
    private let outputURL: URL
    private let format: OutputFormat
    private let includeTimestamps: Bool
    private let title: String?
    private var handle: FileHandle?
    private(set) var isOpen = false
    private var isClosed = false

    init(
        outputURL: URL,
        format: OutputFormat = .markdown,
        includeTimestamps: Bool,
        title: String? = nil
    ) {
        self.outputURL = outputURL
        self.format = format
        self.includeTimestamps = includeTimestamps
        self.title = title
    }

    func open() throws {
        guard !isClosed else {
            throw OutputError.writerClosed
        }
        guard !isOpen else { return }

        let parent = outputURL.deletingLastPathComponent()
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: parent.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            AppLogger.export.error("Carpeta de destino no disponible: \(parent.path)")
            throw OutputError.directoryUnavailable(parent.path)
        }
        guard FileManager.default.createFile(atPath: outputURL.path, contents: nil) else {
            AppLogger.export.error("No se pudo crear el archivo de salida: \(outputURL.path)")
            throw OutputError.fileCreationFailed(outputURL.path)
        }

        do {
            handle = try FileHandle(forWritingTo: outputURL)
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            AppLogger.export.error("No se pudo abrir el archivo de salida: \(outputURL.path): \(error)")
            throw OutputError.fileCreationFailed("\(outputURL.path): \(error)")
        }
        isOpen = true

        if let title, !title.isEmpty {
            try write(string: Self.titleBlock(title, format: format))
        }
    }

    func write(_ paragraph: TranscriptionParagraph) throws {
        try open()
        try write(string: Self.paragraphBlock(paragraph, format: format, includeTimestamps: includeTimestamps))
    }

    func close() throws {
        defer { isClosed = true }
        guard let handle else {
            isOpen = false
            return
        }
        do {
            try handle.synchronize()
            try handle.close()
        } catch {
            self.handle = nil
            isOpen = false
            AppLogger.export.error("No se pudo cerrar el archivo de salida: \(outputURL.path): \(error)")
            throw OutputError.closeFailed("\(outputURL.path): \(error)")
        }
        self.handle = nil
        isOpen = false
    }

    /// Elimina el archivo parcial. Política de cancelación/fallo:
    /// no se dejan transcripciones incompletas en disco.
    func abort() {
        handle = nil
        isOpen = false
        isClosed = true
        do {
            try FileManager.default.removeItem(at: outputURL)
        } catch {
            AppLogger.export.info("No había archivo parcial que eliminar en \(outputURL.lastPathComponent)")
        }
    }

    private func write(string: String) throws {
        guard let handle else {
            throw OutputError.writerClosed
        }
        do {
            try handle.write(contentsOf: Data(string.utf8))
        } catch {
            AppLogger.export.error("No se pudo escribir en \(outputURL.path): \(error)")
            throw OutputError.writeFailed("\(outputURL.path): \(error)")
        }
    }

    static func titleBlock(_ title: String, format: OutputFormat) -> String {
        switch format {
        case .markdown: return "# \(title)\n\n"
        case .plainText: return "\(title)\n\n"
        }
    }

    static func paragraphBlock(
        _ paragraph: TranscriptionParagraph,
        format: OutputFormat,
        includeTimestamps: Bool
    ) -> String {
        guard includeTimestamps else {
            return "\(paragraph.text)\n\n"
        }
        let timestamp = timestampString(from: paragraph.start)
        switch format {
        case .markdown: return "### [\(timestamp)]\n\n\(paragraph.text)\n\n"
        case .plainText: return "[\(timestamp)] \(paragraph.text)\n\n"
        }
    }

    static func timestampString(from duration: Duration) -> String {
        let total = max(0, Int(duration.components.seconds))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}