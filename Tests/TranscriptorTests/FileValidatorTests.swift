import Testing
import Foundation
@testable import Transcriptor

@Suite("FileValidator")
struct FileValidatorTests {
    private let validator = FileValidator()

    private func tempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("validator-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeFile(named name: String, in dir: URL) -> URL {
        let url = dir.appendingPathComponent(name)
        FileManager.default.createFile(atPath: url.path, contents: Data("x".utf8))
        return url
    }

    @Test("Acepta los formatos soportados")
    func acceptsSupportedFormats() throws {
        let dir = try tempDirectory()
        for ext in ["mp3", "m4a", "wav", "mp4", "mov", "m4v"] {
            let url = makeFile(named: "clip.\(ext)", in: dir)
            #expect(try validator.validate(url).get() == url)
        }
    }

    @Test("Ignora la diferencia de mayúsculas en la extensión")
    func acceptsUppercaseExtension() throws {
        let dir = try tempDirectory()
        let url = makeFile(named: "Clip.MP3", in: dir)
        #expect(try validator.validate(url).get() == url)
    }

    @Test("Rechaza extensiones no soportadas")
    func rejectsUnsupportedExtension() throws {
        let dir = try tempDirectory()
        let url = makeFile(named: "notas.txt", in: dir)
        #expect(validator.validate(url) == .failure(.unsupportedFormat("notas.txt")))
    }

    @Test("Rechaza directorios")
    func rejectsDirectories() throws {
        let dir = try tempDirectory()
        #expect(validator.validate(dir) == .failure(.notAFile))
    }

    @Test("Rechaza rutas inexistentes")
    func rejectsMissingFiles() {
        let url = URL(fileURLWithPath: "/no/existe/fichero.mp3")
        #expect(validator.validate(url) == .failure(.notAFile))
    }
}