import SwiftUI

struct TranscriptionView: View {
    @State private var viewModel = TranscriptionViewModel()

    var body: some View {
        @Bindable var viewModel = viewModel

        VStack(spacing: 14) {
            DropZoneView(
                hasFiles: !viewModel.entries.isEmpty,
                onFilesDropped: { urls in
                    Task { await viewModel.addFiles(urls) }
                },
                onSelectFiles: { viewModel.presentFileImport() }
            )

            HStack(spacing: 14) {
                Picker("Idioma", selection: $viewModel.selectedLanguageID) {
                    if viewModel.areLanguagesLoading {
                        Text("Cargando idiomas…").tag("")
                    }
                    ForEach(viewModel.languageOptions) { option in
                        Text(option.displayName).tag(option.id)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 240)
                .disabled(viewModel.areLanguagesLoading || viewModel.isProcessing)
                .help("El idioma en el que se transcribirá el audio")

                Toggle("Incluir timestamps", isOn: $viewModel.includeTimestamps)
                    .disabled(viewModel.isProcessing)
                    .help("Añade la hora de inicio de cada párrafo al documento")

                Spacer()

                Button {
                    Task { await viewModel.start() }
                } label: {
                    Label("Transcribir", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!viewModel.canStart)
                .keyboardShortcut("t", modifiers: [.command, .shift])
                .help("Empieza a transcribir todos los trabajos pendientes (⇧⌘T)")

                Button(role: .destructive) {
                    Task { await viewModel.cancelAll() }
                } label: {
                    Label("Cancelar", systemImage: "xmark")
                }
                .controlSize(.large)
                .disabled(!viewModel.isProcessing && !viewModel.hasPending)
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .help("Cancela la transcripción activa (⇧⌘C)")
            }
            .padding(.horizontal, 20)

            HStack(spacing: 10) {
                Label("Guardar en", systemImage: "folder")
                    .foregroundStyle(.secondary)
                Text(viewModel.destinationDirectory.path)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 12)
                Button("Cambiar…") { viewModel.chooseDestination() }
                    .disabled(viewModel.isProcessing)
            }
            .padding(.horizontal, 20)

            Divider()

            List {
                if viewModel.entries.isEmpty && viewModel.rejectedFiles.isEmpty {
                    emptyState
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(viewModel.entries) { entry in
                        JobRow(
                            entry: entry,
                            onCancel: { Task { await viewModel.cancel(id: entry.id) } },
                            onRemove: { Task { await viewModel.removePending(id: entry.id) } },
                            onReveal: { viewModel.revealInFinder(entry.outputURL) }
                        )
                    }

                    ForEach(viewModel.rejectedFiles) { rejected in
                        RejectedFileRow(item: rejected) {
                            viewModel.dismissRejected(id: rejected.id)
                        }
                    }
                }
            }
            .listStyle(.inset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            footer
        }
        .frame(minWidth: 700, minHeight: 540)
        .fileImporter(
            isPresented: $viewModel.isImportingFiles,
            allowedContentTypes: FileValidator.supportedContentTypes,
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                Task { await viewModel.addFiles(urls) }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.plaintext")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Aún no hay trabajos")
                .font(.headline)
            Text("Añade archivos para empezar a transcribirlos")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Aún no hay trabajos. Añade archivos para empezar a transcribirlos.")
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Procesamiento local", systemImage: "lock.shield")
                .accessibilityLabel("Procesamiento local. Este punto no es interactivo.")
            Text("Los archivos y las transcripciones se procesan en tu Mac y nunca se envían a servidores externos.")
            Text("La primera transcripción de un idioma puede requerir descargar ese idioma directamente de Apple.")
                .foregroundStyle(.secondary)
        }
        .font(.callout)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Procesamiento local. Los archivos y las transcripciones se procesan en tu Mac y nunca se envían a servidores externos. La primera transcripción de un idioma puede requerir descargar ese idioma directamente de Apple.")
    }
}