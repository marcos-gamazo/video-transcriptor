import Foundation
import UniformTypeIdentifiers

struct FileValidator {
    static let supportedExtensions: Set<String> = ["mp3", "m4a", "wav", "mp4", "mov", "m4v"]
    static let supportedContentTypes: [UTType] = [.audio, .movie, .mpeg4Movie, .quickTimeMovie]

    func validate(_ url: URL) -> Result<URL, FileValidationError> {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            return .failure(.notAFile)
        }
        let ext = url.pathExtension.lowercased()
        guard Self.supportedExtensions.contains(ext) else {
            return .failure(.unsupportedFormat(url.lastPathComponent))
        }
        return .success(url)
    }
}

enum FileValidationError: Error, Equatable {
    case notAFile
    case unsupportedFormat(String)

    var userMessage: String {
        switch self {
        case .notAFile:
            return "No se puede añadir este elemento porque no es un archivo."
        case .unsupportedFormat(let name):
            return "«\(name)» no es un formato de audio o vídeo compatible."
        }
    }
}