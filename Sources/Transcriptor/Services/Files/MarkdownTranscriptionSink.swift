import Foundation

/// Agrega segmentos en párrafos y los escribe de forma incremental en Markdown.
///
/// El ciclo de vida es por trabajo: `open()` antes de transcribir, `append(_:)`
/// por cada segmento, y bien `finish()` (éxito) o `abort()` (cancelación/fallo).
/// Todas las llamadas se producen de forma secuencial dentro de un mismo trabajo,
/// por lo que no necesita sincronización interna.
final class MarkdownTranscriptionSink: @unchecked Sendable {
    private let writer: MarkdownWriter
    private var aggregator = ParagraphAggregator()
    private(set) var paragraphCount = 0

    init(outputURL: URL, includeTimestamps: Bool, title: String? = nil) {
        self.writer = MarkdownWriter(
            outputURL: outputURL,
            includeTimestamps: includeTimestamps,
            title: title
        )
    }

    func open() throws {
        try writer.open()
    }

    func append(_ segment: TranscriptionSegment) throws {
        if let paragraph = aggregator.append(segment) {
            try writer.write(paragraph)
            paragraphCount += 1
        }
    }

    /// Cierra el párrafo pendiente y el archivo.
    @discardableResult
    func finish() throws -> Int {
        if let paragraph = aggregator.finish() {
            try writer.write(paragraph)
            paragraphCount += 1
        }
        try writer.close()
        return paragraphCount
    }

    /// Elimina el archivo parcial. Política de cancelación/fallo.
    func abort() {
        writer.abort()
    }
}