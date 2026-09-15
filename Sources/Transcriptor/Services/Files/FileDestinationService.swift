import Foundation

struct FileDestinationService {
    static func markdownFileName(for sourceURL: URL) -> String {
        let base = sourceURL.deletingPathExtension().lastPathComponent
        let stem = base.isEmpty ? "transcripcion" : base
        return stem + ".md"
    }

    static func uniqueOutputURL(for sourceURL: URL, in directory: URL) -> URL {
        let name = markdownFileName(for: sourceURL)
        let stem = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension

        var candidate = directory.appendingPathComponent(name)
        var index = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(stem)-\(index).\(ext)")
            index += 1
        }
        return candidate
    }
}