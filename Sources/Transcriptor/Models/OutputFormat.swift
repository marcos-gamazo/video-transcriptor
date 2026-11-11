import Foundation

/// Formato del archivo de transcripción generado.
///
/// El motor de transcripción no conoce el formato: solo el writer decide
/// cómo se representan el título, los párrafos y los timestamps.
enum OutputFormat: String, CaseIterable, Identifiable, Sendable {
    case markdown
    case plainText

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .markdown: return "md"
        case .plainText: return "txt"
        }
    }

    var displayName: String {
        switch self {
        case .markdown: return "Markdown (.md)"
        case .plainText: return "Texto (.txt)"
        }
    }
}
