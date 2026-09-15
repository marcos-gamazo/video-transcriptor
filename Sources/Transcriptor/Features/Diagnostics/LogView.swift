import SwiftUI

/// Presenta el registro como sheet desde la ventana principal.
/// Sustituye a la escena `Window(id:)` de macOS 13+.
@MainActor
final class LogPresenter: ObservableObject {
    static let shared = LogPresenter()
    @Published var isPresented = false
}

struct LogView: View {
    @StateObject private var store = LogStore.shared
    @State private var errorsOnly = false

    private var visibleEntries: [LogEntryRecord] {
        errorsOnly ? store.entries.filter { $0.level == .error } : store.entries
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("Registro de la aplicación")
                    .font(.headline)
                Spacer()
                Toggle("Solo errores", isOn: $errorsOnly)
                    .controlSize(.small)
                    .help("Mostrar únicamente los errores registrados")
                Button("Limpiar") { store.clear() }
                    .disabled(store.entries.isEmpty)
                    .help("Borrar todas las entradas del registro")
            }
            .padding(12)

            Divider()

            if visibleEntries.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(visibleEntries.reversed()) { entry in
                    LogEntryRow(entry: entry)
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 600, minHeight: 380)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 30))
                .foregroundColor(.secondary)
            Text(errorsOnly ? "No hay errores registrados" : "Aún no hay entradas de registro")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 30)
    }
}

private struct LogEntryRow: View {
    let entry: LogEntryRecord

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: iconName)
                .foregroundColor(tint)
                .frame(width: 16)
            Text(Self.timeFormatter.string(from: entry.date))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .fixedSize()
            Text(entry.category)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Capsule().fill(tint.opacity(0.15)))
                .foregroundColor(tint)
            Text(entry.message)
                .font(.system(size: 12, design: .monospaced))
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var iconName: String {
        switch entry.level {
        case .debug: "ant"
        case .info: "info.circle"
        case .error: "exclamationmark.triangle"
        }
    }

    private var tint: Color {
        switch entry.level {
        case .debug: .gray
        case .info: .blue
        case .error: .red
        }
    }
}