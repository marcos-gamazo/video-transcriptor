import SwiftUI

struct JobRow: View {
    let entry: TranscriptionQueue.Entry
    let onCancel: () -> Void
    let onRemove: () -> Void
    let onReveal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .foregroundColor(tint)
                    .frame(width: 20)
                    .accessibilityLabel(accessibilityStateDescription)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.job.sourceURL.lastPathComponent)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    statusText
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(entry.job.sourceURL.lastPathComponent). \(accessibilityStateDescription)")

                Spacer(minLength: 12)

                trailingControls
            }

            if showsProgress {
                ProgressView(value: progressValue)
                    .progressViewStyle(.linear)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Progreso")
                    .accessibilityValue(progressAccessibilityValue)
            }

            if entry.state == .failed, let failureMessage = entry.failureMessage {
                Text(failureMessage)
                    .font(.callout)
                    .foregroundColor(.red)
                    .accessibilityLabel("Error. \(failureMessage)")
            }

            if entry.state == .completed, let output = entry.outputURL {
                Text(output.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .accessibilityLabel("Archivo generado: \(output.path)")
            }
        }
        .padding(.vertical, 4)
    }

    private var accessibilityStateDescription: String {
        switch entry.state {
        case .pending:
            return "En cola"
        case .preparing:
            return "Preparando"
        case .downloading:
            return "Descargando idioma"
        case .transcribing:
            return "Transcribiendo"
        case .completed:
            return "Completado"
        case .cancelled:
            return "Cancelado"
        case .failed:
            return "Fallado"
        }
    }

    private var progressAccessibilityValue: String {
        let percent = Int((progressValue * 100).rounded())
        return entry.state == .downloading ? "Descargando, \(percent) por ciento" : "\(percent) por ciento"
    }

    @ViewBuilder
    private var trailingControls: some View {
        switch entry.state {
        case .pending:
            Button(action: onRemove) {
                Label("Eliminar", systemImage: "trash")
            }
            .help("Quitar este archivo de la cola")
        case .preparing, .downloading, .transcribing:
            Button(action: onCancel) {
                Label("Cancelar", systemImage: "xmark.circle")
            }
            .help("Cancelar esta transcripción")
        case .completed:
            Button(action: onReveal) {
                Label("Abrir", systemImage: "folder")
            }
            .help("Mostrar el archivo generado en el Finder")
        case .cancelled, .failed:
            EmptyView()
        }
    }

    private var iconName: String {
        switch entry.state {
        case .pending: "clock"
        case .preparing: "hourglass"
        case .downloading: "arrow.down.circle"
        case .transcribing: "waveform"
        case .completed: "checkmark.circle.fill"
        case .cancelled: "xmark.circle"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    private var tint: Color {
        switch entry.state {
        case .pending: .secondary
        case .preparing, .downloading: .blue
        case .transcribing: .blue
        case .completed: .green
        case .cancelled: .secondary
        case .failed: .red
        }
    }

    @ViewBuilder
    private var statusText: some View {
        switch entry.state {
        case .pending:
            Text("En cola")
        case .preparing:
            Text("Preparando…")
        case .downloading:
            Text("Descargando idioma…")
        case .transcribing:
            Text("Transcribiendo…")
        case .completed:
            Text("Completado")
        case .cancelled:
            Text("Cancelado")
        case .failed:
            Text("No se pudo transcribir")
        }
    }

    private var showsProgress: Bool {
        entry.state == .downloading || entry.state == .transcribing
    }

    private var progressValue: Double {
        switch entry.state {
        case .downloading:
            return entry.progress.download
        case .transcribing:
            return entry.progress.overall
        default:
            return 0
        }
    }
}

struct RejectedFileRow: View {
    let item: TranscriptionViewModel.RejectedFile
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .frame(width: 20)
            Text(item.name)
                .font(.callout.weight(.medium))
                .lineLimit(1)
                .truncationMode(.middle)
            Text(item.message)
                .font(.callout)
                .foregroundColor(.secondary)
            Spacer(minLength: 12)
            Button(action: onDismiss) {
                Label("Quitar", systemImage: "xmark")
            }
            .help("Descartar este aviso")
        }
        .padding(.vertical, 4)
    }
}