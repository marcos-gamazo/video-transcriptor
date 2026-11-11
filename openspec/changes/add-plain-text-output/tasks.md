# Tasks

* [x] 1.1 Añadir `OutputFormat` (`markdown`, `plainText`) con extensión y nombre visible.
* [x] 1.2 Añadir `outputFormat` a `TranscriptionJob` (por defecto `.markdown`).
* [x] 1.3 Renombrar `MarkdownWriter` → `TranscriptWriter` y soportar texto plano.
* [x] 1.4 Renombrar `MarkdownTranscriptionSink` → `TranscriptionFileSink` y propagar el formato.
* [x] 1.5 `FileDestinationService` genera nombres con la extensión del formato.
* [x] 1.6 `applyPendingSettings` aplica también el formato a los trabajos pendientes.
* [x] 1.7 Selector "Formato" en la fila "Guardar en".
* [x] 1.8 Tests: writer en texto (con/sin timestamps), nombres `.txt`, sufijos únicos, cola genera `.txt`, ajustes pendientes.
* [ ] 1.9 Validación manual en la app: transcribir un archivo real en `.txt` y abrirlo en TextEdit.
* [x] 1.10 Subir versión de la app a 1.1 (build 2) y publicar la release `v1.1.0` con el DMG.
* [x] 1.11 CI: sustituir `swift-actions/setup-swift` (Node.js 20, obsoleto) por la instalación del paquete oficial de swift.org.
* [x] 1.12 Documentar formatos de salida, proceso de release y entorno de desarrollo (README, AGENTS.md).
