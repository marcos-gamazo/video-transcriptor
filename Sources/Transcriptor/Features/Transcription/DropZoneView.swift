import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    let hasFiles: Bool
    let onFilesDropped: ([URL]) -> Void
    let onSelectFiles: () -> Void

    @State private var isTargeted = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 2, dash: isTargeted ? [0] : [6])
                )
                .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary.opacity(0.6))
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accentColor.opacity(isTargeted ? 0.08 : 0.03))
                )

            VStack(spacing: 10) {
                Image(systemName: isTargeted ? "arrow.down.doc.fill" : "square.and.arrow.down")
                    .font(.system(size: 34))
                    .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary)
                    .accessibilityHidden(true)
                Text(hasFiles ? "Añade más archivos de audio o vídeo" : "Arrastra aquí tus archivos de audio o vídeo")
                    .font(.headline)
                    .foregroundStyle(isTargeted ? Color.accentColor : Color.primary)
                Text("También puedes seleccionarlos manualmente")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button("Seleccionar archivos…", action: onSelectFiles)
                    .controlSize(.large)
                    .help("Abre el selector de archivos del sistema")
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(hasFiles ? "Zona de archivos. Arrastra archivos de audio o vídeo, o pulsa el botón para seleccionarlos." : "Arrastra aquí tus archivos de audio o vídeo, o pulsa el botón para seleccionarlos manualmente.")
        .onDrop(of: [UTType.fileURL], isTargeted: $isTargeted, perform: handleDrop)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let collector = URLCollector()
        var progressTokens: [Progress] = []
        let group = DispatchGroup()
        for provider in providers {
            group.enter()
            let progress = provider.loadObject(ofClass: URL.self) { object, _ in
                if let url = object as? URL {
                    collector.append(url)
                }
                group.leave()
            }
            progressTokens.append(progress)
        }
        group.notify(queue: .main) {
            _ = progressTokens
            onFilesDropped(collector.values)
        }
        return true
    }
}

private final class URLCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [URL] = []

    func append(_ url: URL) {
        lock.withLock { storage.append(url) }
    }

    var values: [URL] {
        lock.withLock { storage }
    }
}