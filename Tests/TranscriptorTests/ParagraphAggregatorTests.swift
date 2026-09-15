import Testing
import Foundation
@testable import Transcriptor

@Suite("ParagraphAggregator")
struct ParagraphAggregatorTests {
    private static func segment(_ text: String, start: Double, end: Double) -> TranscriptionSegment {
        TranscriptionSegment(start: start, end: end, text: text)
    }

    private static func aggregate(
        _ segments: [TranscriptionSegment],
        aggregator: ParagraphAggregator = ParagraphAggregator()
    ) -> [TranscriptionParagraph] {
        var aggregator = aggregator
        var paragraphs: [TranscriptionParagraph] = []
        for segment in segments {
            if let paragraph = aggregator.append(segment) {
                paragraphs.append(paragraph)
            }
        }
        if let last = aggregator.finish() {
            paragraphs.append(last)
        }
        return paragraphs
    }

    @Test("Un flujo continuo sin pausas forma un único párrafo")
    func continuousStreamFormsSingleParagraph() {
        let segments = (0..<60).map { i in
            Self.segment("palabra\(i)", start: Double(i), end: Double(i + 1))
        }
        let paragraphs = Self.aggregate(segments)

        #expect(paragraphs.count == 1)
        #expect(paragraphs[0].start == 0.0)
        #expect(paragraphs[0].text == segments.map(\.text).joined(separator: " "))
    }

    @Test("Un párrafo de 10 minutos sin pausas sigue siendo un párrafo")
    func noFixedCadence() {
        let segments = (0..<100).map { i in
            Self.segment("fragmento\(i)", start: Double(i * 10), end: Double(i * 10 + 9))
        }
        let paragraphs = Self.aggregate(segments)

        #expect(paragraphs.count == 1,
                "Una regla de cadencia fija partiría este flujo; el agregador no debe usarla.")
        #expect(paragraphs[0].start == 0.0)
    }

    @Test("Un silencio mayor que el umbral separa párrafos con su timestamp correcto")
    func longPauseBreaksParagraph() {
        let segments = [
            Self.segment("primera", start: 0, end: 1),
            Self.segment("segunda", start: 1, end: 2),
            Self.segment("tercera", start: 5, end: 6),
            Self.segment("cuarta", start: 6, end: 7),
        ]
        let paragraphs = Self.aggregate(segments)

        #expect(paragraphs.count == 2)
        #expect(paragraphs[0].start == 0.0)
        #expect(paragraphs[0].text == "primera segunda")
        #expect(paragraphs[1].start == 5.0)
        #expect(paragraphs[1].text == "tercera cuarta")
    }

    @Test("Un silencio inferior al umbral no separa")
    func shortPauseDoesNotBreak() {
        let segments = [
            Self.segment("hola", start: 0, end: 1),
            Self.segment("mundo", start: 1.5, end: 2.5),
        ]
        let paragraphs = Self.aggregate(segments)
        #expect(paragraphs.count == 1)
        #expect(paragraphs[0].text == "hola mundo")
    }

    @Test("Un silencio exactamente igual al umbral sí separa")
    func pauseEqualToThresholdBreaks() {
        let segments = [
            Self.segment("inicio", start: 0, end: 2),
            Self.segment("final", start: 4, end: 6),
        ]
        let paragraphs = Self.aggregate(segments, aggregator: ParagraphAggregator(pauseThreshold: 2.0))
        #expect(paragraphs.count == 2)
        #expect(paragraphs[1].start == 4.0)
    }

    @Test("Puntuación de fin de frase con pausa breve separa")
    func sentencePunctuationWithShortGapBreaks() {
        let aggregator = ParagraphAggregator(pauseThreshold: 2.0, shortGapThreshold: (750)/1000.0)
        let segments = [
            Self.segment("Buenos días.", start: 0, end: 1),
            Self.segment("Bienvenidos", start: 2, end: 3),
        ]
        let paragraphs = Self.aggregate(segments, aggregator: aggregator)

        #expect(paragraphs.count == 2)
        #expect(paragraphs[0].text == "Buenos días.")
        #expect(paragraphs[1].text == "Bienvenidos")
        #expect(paragraphs[1].start == 2.0)
    }

    @Test("Puntuación sin pausa suficiente no separa")
    func sentencePunctuationWithTinyGapDoesNotBreak() {
        let aggregator = ParagraphAggregator(pauseThreshold: 2.0, shortGapThreshold: (750)/1000.0)
        let segments = [
            Self.segment("Sí.", start: 0, end: 1),
            Self.segment("Adelante", start: 1.3, end: 2.3),
        ]
        let paragraphs = Self.aggregate(segments, aggregator: aggregator)
        #expect(paragraphs.count == 1)
        #expect(paragraphs[0].text == "Sí. Adelante")
    }

    @Test("Segmentos solapados no generan un corte")
    func overlappingSegmentsDoNotBreak() {
        let segments = [
            Self.segment("a", start: 0, end: 2),
            Self.segment("b", start: 1, end: 3),
            Self.segment("c", start: 1.5, end: 3.5),
        ]
        let paragraphs = Self.aggregate(segments)
        #expect(paragraphs.count == 1)
        #expect(paragraphs[0].text == "a b c")
    }

    @Test("Los segmentos vacíos se ignoran")
    func emptySegmentsIgnored() {
        let segments = [
            Self.segment("", start: 0, end: 1),
            Self.segment("   ", start: 1, end: 2),
            Self.segment("real", start: 2, end: 3),
            Self.segment("", start: 3, end: 4),
        ]
        let paragraphs = Self.aggregate(segments)
        #expect(paragraphs.count == 1)
        #expect(paragraphs[0].text == "real")
    }

    @Test("Finish devuelve el párrafo pendiente y reinicia el estado")
    func finishReturnsPendingParagraph() {
        var aggregator = ParagraphAggregator()
        _ = aggregator.append(Self.segment("solo", start: 0, end: 1))

        let paragraph = aggregator.finish()
        #expect(paragraph?.text == "solo")
        #expect(paragraph?.start == 0.0)
        #expect(aggregator.currentText.isEmpty)
        #expect(aggregator.currentStart == nil)
    }

    @Test("Conversación larga: sin pérdida, sin duplicados, y memoria no acumulada")
    func longConversation() {
        let wordsPerGroup = 5
        let groupCount = 60
        var segments: [TranscriptionSegment] = []
        var expected = Array(repeating: "", count: groupCount)
        var expectedStarts = Array(repeating: 0.0, count: groupCount)

        for group in 0..<groupCount {
            let base = Double(group) * (3.0 + Double(wordsPerGroup))
            expectedStarts[group] = base
            var words: [String] = []
            for word in 0..<wordsPerGroup {
                let start = base + Double(word)
                let text = "w\(group)-\(word)"
                words.append(text)
                segments.append(Self.segment(text, start: start, end: start + 1))
            }
            expected[group] = words.joined(separator: " ")
        }

        var aggregator = ParagraphAggregator()
        var maxCurrentTextLength = 0
        var paragraphs: [TranscriptionParagraph] = []
        for current in segments {
            if let paragraph = aggregator.append(current) {
                paragraphs.append(paragraph)
            }
            maxCurrentTextLength = max(maxCurrentTextLength, aggregator.currentText.count)
        }
        if let last = aggregator.finish() {
            paragraphs.append(last)
        }

        #expect(paragraphs.count == groupCount)
        for (index, paragraph) in paragraphs.enumerated() {
            #expect(paragraph.text == expected[index])
            #expect(paragraph.start == expectedStarts[index])
        }

        let reconstructed = paragraphs.map(\.text).joined(separator: " ")
        let allWords = segments.map(\.text).joined(separator: " ")
        #expect(reconstructed == allWords, "No debería perderse ni duplicarse texto.")

        #expect(maxCurrentTextLength <= 64,
                "El agregador debería conservar solo el párrafo actual; llegó a \(maxCurrentTextLength) caracteres.")
        #expect(aggregator.currentText.isEmpty)
    }
}