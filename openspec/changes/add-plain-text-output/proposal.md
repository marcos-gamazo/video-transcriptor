# Añadir salida en texto plano (.txt)

## Why

Hoy la transcripción solo se guarda como Markdown (`.md`). Muchos usuarios no técnicos quieren abrir el resultado directamente en cualquier editor o pegarlo en otras herramientas sin sintaxis Markdown (`#`, `###`).

## What Changes

* Nuevo ajuste "Formato" en la interfaz: `Markdown (.md)` (predeterminado) o `Texto (.txt)`.
* El formato se guarda por trabajo (`TranscriptionJob.outputFormat`) y se aplica a los pendientes al pulsar "Transcribir", igual que el idioma y los timestamps.
* `MarkdownWriter` pasa a llamarse `TranscriptWriter` y recibe el formato; `MarkdownTranscriptionSink` pasa a `TranscriptionFileSink`.
* El nombre de salida usa la extensión del formato (`reunion.txt`, `reunion-2.txt`).
* La escritura sigue siendo incremental; el motor de transcripción no conoce el formato.

## Impact

* Spec afectada: `output`.
* Sin nuevas dependencias ni cambios en el pipeline de audio/Speech.
