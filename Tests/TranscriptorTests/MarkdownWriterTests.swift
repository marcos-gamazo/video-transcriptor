import Testing
import Foundation
@testable import Transcriptor

@Suite("MarkdownWriter")
struct MarkdownWriterTests {
    private static func paragraph(_ text: String, start: Double) -> TranscriptionParagraph {
        TranscriptionParagraph(start: .seconds(start), text: text)
    }

    private static func tempFileURL(named name: String = "out-\(UUID().uuidString).md") -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(name)
    }

    @Test("Escribe cabecera y párrafos con timestamps")
    func writesHeaderAndTimestampedParagraphs() throws {
        let url = Self.tempFileURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let writer = MarkdownWriter(outputURL: url, includeTimestamps: true, title: "Reunión")
        try writer.open()
        try writer.write(Self.paragraph("Hola a todos.", start: 0))
        try writer.write(Self.paragraph("Texto dos.", start: 3 * 3600 + 47 * 60 + 5))
        try writer.close()

        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content == "# Reunión\n\n### [00:00:00]\n\nHola a todos.\n\n### [03:47:05]\n\nTexto dos.\n\n")
    }

    @Test("Escribe párrafos limpios sin timestamps")
    func writesCleanParagraphsWithoutTimestamps() throws {
        let url = Self.tempFileURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let writer = MarkdownWriter(outputURL: url, includeTimestamps: false)
        try writer.write(Self.paragraph("Primer párrafo.", start: 0))
        try writer.write(Self.paragraph("Segundo párrafo.", start: 120))

        try writer.close()
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content == "Primer párrafo.\n\nSegundo párrafo.\n\n")
        #expect(!content.contains("###"))
        #expect(!content.contains("["))
    }

    private static let timestampCases: [(seconds: Double, expected: String)] = [
        (seconds: 0.0, expected: "00:00:00"),
        (seconds: 125.0, expected: "00:02:05"),
        (seconds: 227.0, expected: "00:03:47"),
        (seconds: 3 * 3600 + 47 * 60 + 5.0, expected: "03:47:05"),
        (seconds: 25 * 3600.0, expected: "25:00:00"),
    ]

    @Test("Formatea timestamps como HH:MM:SS", arguments: timestampCases)
    func timestampFormat(seconds: Double, expected: String) {
        let string = MarkdownWriter.timestampString(from: .seconds(seconds))
        #expect(string == expected)
    }

    @Test("Escribe de forma incremental antes de cerrar")
    func writesIncrementally() throws {
        let url = Self.tempFileURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let writer = MarkdownWriter(outputURL: url, includeTimestamps: true, title: "T")
        try writer.open()
        try writer.write(Self.paragraph("Primer bloque.", start: 0))

        let partial = try String(contentsOf: url, encoding: .utf8)
        #expect(partial == "# T\n\n### [00:00:00]\n\nPrimer bloque.\n\n",
                "El primer bloque debería estar ya en disco antes de cerrar.")

        try writer.write(Self.paragraph("Segundo bloque.", start: 10))
        try writer.close()
        let full = try String(contentsOf: url, encoding: .utf8)
        #expect(full.hasSuffix("Primer bloque.\n\n### [00:00:10]\n\nSegundo bloque.\n\n"))
    }

    @Test("Un destino sin carpeta produce un error de dominio")
    func missingDirectoryThrows() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("carpeta-inexistente-\(UUID().uuidString)")
            .appendingPathComponent("salida.md")
        let writer = MarkdownWriter(outputURL: url, includeTimestamps: false)

        do {
            try writer.open()
            Issue.record("Se esperaba un error de destino.")
        } catch let error as OutputError {
            #expect(error == .directoryUnavailable(url.deletingLastPathComponent().path))
        } catch {
            Issue.record("Error inesperado: \(error)")
        }
    }

    @Test("Abort elimina el archivo parcial")
    func abortRemovesPartialFile() throws {
        let url = Self.tempFileURL()
        let writer = MarkdownWriter(outputURL: url, includeTimestamps: false)
        try writer.write(Self.paragraph("Parcial.", start: 0))
        #expect(FileManager.default.fileExists(atPath: url.path))

        writer.abort()
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test("Escribir tras cerrar lanza writerClosed")
    func writingAfterCloseThrows() throws {
        let url = Self.tempFileURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let writer = MarkdownWriter(outputURL: url, includeTimestamps: false)
        try writer.write(Self.paragraph("Primero.", start: 0))
        try writer.close()

        do {
            try writer.write(Self.paragraph("Segundo.", start: 1))
            Issue.record("Se esperaba un error al escribir tras cerrar.")
        } catch let error as OutputError {
            #expect(error == .writerClosed)
        } catch {
            Issue.record("Error inesperado: \(error)")
        }
    }
}

@Suite("FileDestinationService")
struct FileDestinationServiceTests {
    @Test("Genera nombres .md a partir del nombre original")
    func buildsMarkdownNames() {
        #expect(FileDestinationService.markdownFileName(for: URL(fileURLWithPath: "/tmp/a/meeting.m4a")) == "meeting.md")
        #expect(FileDestinationService.markdownFileName(for: URL(fileURLWithPath: "/tmp/factura.MP4")) == "factura.md")
        #expect(FileDestinationService.markdownFileName(for: URL(fileURLWithPath: "/tmp/video.mov")) == "video.md")
    }

    @Test("No sobrescribe archivos existentes y usa sufijos únicos")
    func avoidsDuplicateNames() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dst-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let source = URL(fileURLWithPath: "/tmp/reunion.m4a")
        let first = FileDestinationService.uniqueOutputURL(for: source, in: dir)
        #expect(first.lastPathComponent == "reunion.md")

        try Data("# primero".utf8).write(to: first)
        let second = FileDestinationService.uniqueOutputURL(for: source, in: dir)
        #expect(second.lastPathComponent == "reunion-2.md")

        try Data("# segundo".utf8).write(to: second)
        let third = FileDestinationService.uniqueOutputURL(for: source, in: dir)
        #expect(third.lastPathComponent == "reunion-3.md")
    }
}