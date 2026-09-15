# AGENTS.md

## Project

This repository contains a native macOS transcription application called Transcriptor.

The application transcribes audio recordings and videos into Markdown using Apple's on-device Speech framework.

## Before Making Changes

Before implementing a change:

1. Read this file.
2. Read `openspec/project.md`.
3. Read the relevant OpenSpec change under `openspec/changes/`.
4. Check existing implementation before introducing new abstractions.
5. Prefer Apple's native APIs over third-party dependencies.

If a change contradicts an existing OpenSpec requirement, stop and reassess the design instead of silently changing the requirement.

## Platform Requirements

The application targets:

* macOS
* Apple Silicon
* `arm64`

Do not add Intel/x86_64 support.

Do not create universal binaries.

## Technology Rules

Prefer:

* Swift
* SwiftUI
* Speech
* AVFoundation
* Foundation
* UniformTypeIdentifiers
* Swift Concurrency
* Apple's logging APIs

Avoid third-party dependencies unless they solve a concrete problem that Apple's frameworks cannot reasonably solve.

Do not introduce a dependency merely for convenience.

## Speech Requirements

Use Apple's:

* `SpeechAnalyzer`
* `SpeechTranscriber`

for transcription.

Use Apple's supported asset-management APIs for speech models.

Do not:

* implement a custom speech model;
* bundle speech models in the application;
* use cloud transcription;
* send media to external APIs.

The transcription pipeline must remain local.

## Offline Requirement

After the required speech model/asset has been installed, transcription must work without Internet access.

Internet access may be required for Apple's asset installation.

Do not introduce any other network dependency.

## Language Behaviour

The language is explicitly selected by the user.

Spanish is the default.

Do not implement automatic language detection unless explicitly requested.

Do not implement translation.

The selected language is the language that SpeechTranscriber should transcribe.

## Media Processing

Use AVFoundation for media handling.

For videos, process the audio track directly through a streaming pipeline.

Do not create a complete temporary audio file unless a concrete technical limitation requires it.

If a temporary file becomes necessary, document why and ensure it is cleaned up.

## Memory Rules

Memory efficiency is a first-class requirement.

Never implement a pipeline that:

* reads an entire media file into memory;
* reads an entire audio track into memory;
* accumulates the complete transcription for a long recording;
* unnecessarily duplicates large audio buffers;
* runs multiple transcription jobs concurrently.

Prefer streaming and incremental processing.

The intended pipeline is:

```text
Media
  ↓
AVFoundation
  ↓
small audio buffers
  ↓
SpeechAnalyzer
  ↓
transcription results
  ↓
paragraph aggregation
  ↓
MarkdownWriter
  ↓
disk
```

## Concurrency

Use Swift Concurrency.

Keep the main/UI actor responsive.

Long-running work must not block the UI.

Cancellation must propagate through the complete processing pipeline.

Resources must be released when a job is:

* completed;
* cancelled;
* failed.

## Transcription Data

Preserve timing information internally.

Do not reduce the processing pipeline to a single large `String`.

Use a streaming representation of transcription results.

A conceptual segment is:

```swift
struct TranscriptionSegment {
    let start: Duration
    let end: Duration
    let text: String
}
```

Do not automatically store all segments for the entire file.

## Paragraphs and Timestamps

Timestamps are optional at export time.

When timestamps are enabled:

* timestamps belong to paragraphs/blocks;
* they should represent the beginning of the paragraph;
* do not emit a timestamp for every low-level SpeechTranscriber result.

When timestamps are disabled:

* output clean readable paragraphs;
* do not include timestamp metadata.

The exporter should decide whether timestamps are visible.

The transcription engine should not care whether the user wants timestamps in the final Markdown.

## Output

Initial output format is Markdown.

Do not add additional export formats unless explicitly requested.

The Markdown writer should support incremental writing.

Avoid constructing the complete Markdown document in memory before writing it.

## Architecture

Prefer a lightweight architecture:

```text
Views
  ↓
ViewModels
  ↓
Services
  ↓
Apple Frameworks
```

Keep responsibilities separated.

Examples:

* `SpeechAnalyzerService` → Speech analysis.
* `SpeechAssetManager` → speech asset/model availability.
* `MediaAnalyzer` → media inspection.
* `AudioStreamProvider` → audio streaming.
* `TranscriptionQueue` → job scheduling.
* `ParagraphAggregator` → grouping transcription segments.
* `MarkdownWriter` → Markdown output.
* `AppLogger` → diagnostics.

Do not create abstractions without a concrete reason.

## UI

The UI is intended for non-technical users.

Prefer clear labels such as:

* "Seleccionar archivos…"
* "Idioma"
* "Incluir timestamps"
* "Guardar en"
* "Transcribir"
* "Cancelar"

Avoid technical terminology in normal user-facing UI.

Detailed technical information belongs in logs/debugging facilities.

## Errors

Never expose raw framework errors directly to normal users.

Convert technical failures into useful user-facing messages.

Keep the underlying error available for diagnostics.

Always distinguish:

* unsupported media;
* missing audio;
* unsupported language;
* missing speech asset;
* offline asset installation;
* transcription failure;
* cancellation;
* output/write failure.

## Logging

Use structured logging.

Do not log:

* passwords;
* secrets;
* unnecessary personal information;
* complete audio contents;
* complete transcription contents unless explicitly required for debugging.

## Testing

Every meaningful feature should have appropriate tests.

Prioritize testing:

* media validation;
* language selection;
* model availability;
* cancellation;
* queue state transitions;
* paragraph aggregation;
* Markdown formatting;
* timestamp formatting;
* output naming;
* error mapping.

For the media and Speech pipeline, include integration tests or manual test procedures where unit testing is not practical.

### Test environment (no Xcode)

This machine has no Xcode, only CommandLineTools. `swift test` against the system `swift` does NOT work (the CommandLineTools test runner finds zero tests).

Use the official Swift toolchain installed via Homebrew:

```sh
TOOL=/opt/homebrew/opt/swift/Swift-6.3.xctoolchain/usr/bin
"$TOOL/swift" test
```

This provides a fully working Swift Testing integration (discovery, execution, failure exit codes). Run tests with this toolchain, never with the system `swift`.

## Performance Validation

Do not assume the streaming architecture is memory efficient; measure it.

Test with long recordings and videos.

Verify:

* memory remains reasonably stable;
* UI remains responsive;
* cancellation releases resources;
* temporary files are not unnecessarily created;
* processing one job does not leave large buffers from previous jobs.

## OpenSpec Workflow

OpenSpec is the source of truth for planned functionality.

Before implementing a significant feature:

1. Inspect the relevant specification.
2. Inspect the design.
3. Inspect the implementation tasks.
4. Implement the smallest coherent change.
5. Run tests/build validation.
6. Update the relevant task status.
7. Do not mark work complete if it has not actually been validated.

Do not skip OpenSpec requirements simply because an alternative implementation is easier.

If the existing specification becomes technically incorrect because of an Apple API limitation or a discovered architectural issue, explain the issue and update the OpenSpec design/specification before making a contradictory implementation.

## Code Quality

Prefer:

* small types;
* explicit responsibilities;
* meaningful names;
* structured concurrency;
* immutable data where practical;
* dependency injection where it genuinely improves testing;
* clear error types;
* testable services.

Avoid:

* global mutable state;
* massive ViewModels;
* massive service classes;
* unnecessary singletons;
* force unwraps where avoidable;
* hidden background work;
* unnecessary third-party frameworks.

## Security and Privacy

Treat all media files as potentially sensitive.

Do not upload them.

Do not expose them through logs.

Do not add analytics that transmit media metadata without explicit future approval.

## Distribution

The final target is an Apple Silicon macOS application distributed as a signed and notarized DMG.

Do not spend significant implementation effort on packaging until the core transcription pipeline has been validated.

## Important Priority Order

When making engineering trade-offs, prioritize in this order:

1. Correct transcription behaviour.
2. Privacy/local processing.
3. Memory efficiency.
4. Reliability and cancellation.
5. Simple user experience.
6. Maintainable architecture.
7. Performance optimizations.
8. Packaging/distribution polish.

Do not sacrifice correctness or privacy for superficial performance improvements.
