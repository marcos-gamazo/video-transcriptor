import Foundation

struct ParagraphAggregator {
    var pauseThreshold: Double
    var shortGapThreshold: Double

    private(set) var currentStart: Double?
    private(set) var currentEnd: Double?
    private(set) var currentText: String = ""

    init(
        pauseThreshold: Double = 2,
        shortGapThreshold: Double = 0.75
    ) {
        self.pauseThreshold = pauseThreshold
        self.shortGapThreshold = shortGapThreshold
    }

    /// Acumula un segmento y devuelve el párrafo completado cuando el segmento
    /// actual inicia un bloque nuevo, o `nil` mientras el párrafo sigue abierto.
    mutating func append(_ segment: TranscriptionSegment) -> TranscriptionParagraph? {
        let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        guard let paragraphStart = currentStart else {
            currentStart = segment.start
            currentEnd = segment.end
            currentText = text
            return nil
        }

        let pause = max(0, (segment.start - (currentEnd ?? paragraphStart)))
        let currentEndsSentence = Self.endsSentence(currentText)

        if pause >= pauseThreshold || (currentEndsSentence && pause >= shortGapThreshold) {
            let completed = flush()
            currentStart = segment.start
            currentEnd = segment.end
            currentText = text
            return completed
        }

        currentEnd = segment.end
        currentText = currentText + " " + text
        return nil
    }

    /// Devuelve el párrafo pendiente, si existe, y reinicia el estado.
    mutating func finish() -> TranscriptionParagraph? {
        flush()
    }

    private mutating func flush() -> TranscriptionParagraph? {
        guard let start = currentStart, !currentText.isEmpty else { return nil }
        currentStart = nil
        currentEnd = nil
        let text = currentText
        currentText = ""
        return TranscriptionParagraph(start: start, text: text)
    }

    private static func endsSentence(_ text: String) -> Bool {
        guard let last = text.trimmingCharacters(in: .whitespacesAndNewlines).last else {
            return false
        }
        return last == "." || last == "!" || last == "?" || last == "…"
    }
}