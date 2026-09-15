# Transcriptor — Project Context

## Overview

Transcriptor is a native macOS application for transcribing audio recordings and videos into Markdown text.

The application is intended primarily for non-technical users. The main interaction should therefore be simple, visual, and predictable.

The application uses Apple's on-device Speech framework, specifically `SpeechAnalyzer` and `SpeechTranscriber`, for speech-to-text transcription.

The application must not depend on a custom backend or external transcription service.

## Platform

Target platform:

* macOS
* Apple Silicon only
* Architecture: `arm64`

Intel/x86_64 support is explicitly out of scope.

Do not introduce universal binaries unless explicitly requested in a future change.

## Technology Stack

Use Apple's native technologies wherever practical:

* Swift
* SwiftUI
* Speech
* AVFoundation
* Foundation
* UniformTypeIdentifiers
* Swift Concurrency

Avoid third-party dependencies unless there is a clear technical justification.

The application should remain as lightweight and maintainable as possible.

## Architecture

Use a lightweight architecture based on:

* SwiftUI Views
* ViewModels
* Domain Models
* Services

Do not introduce large architectural frameworks or unnecessary abstraction layers.

Prefer small, focused services with clear responsibilities.

Suggested high-level organization:

```text
App/
Features/
Models/
Services/
Exporters/
Logging/
```

The exact structure may evolve if implementation details or Apple APIs make a different organization more appropriate.

## Speech Engine

The transcription engine must use:

* `SpeechTranscriber`
* `SpeechAnalyzer`

Speech model assets must be managed using Apple's supported asset-management APIs, such as `AssetInventory`.

Do not bundle Apple's speech models inside the application.

Do not download or manage custom speech models.

Do not introduce cloud transcription services.

## Privacy

Transcription must be performed locally on the Mac.

The application must not send:

* audio
* video
* transcriptions
* user files
* transcription metadata

to external servers.

Internet connectivity may be required only when Apple needs to download a speech asset that is not already installed.

Once the required speech asset is installed, transcription must work without an Internet connection.

## Languages

The language used for transcription is explicitly selected by the user.

Spanish is the default language because it is the primary expected use case.

Other languages supported by the installed version of Apple's Speech framework may be offered.

Do not implement automatic language detection in the initial version.

Do not implement translation.

If the user selects English, the application transcribes English. It does not translate English into Spanish.

## Input Media

The application must support audio and video.

Initial formats to prioritize:

* MP3
* M4A
* WAV
* MP4
* MOV
* M4V

Use AVFoundation for media inspection and audio extraction.

For video files, process the audio track as a stream.

Do not routinely create a complete intermediate WAV/AIFF/MP3 file before transcription.

## Memory and Performance

Memory efficiency is a primary architectural requirement.

The application must be designed around streaming.

Do not:

* load entire media files into RAM;
* load entire audio tracks into RAM;
* keep the entire transcription in memory;
* create unnecessarily large temporary files;
* process multiple transcription jobs simultaneously.

Prefer:

```text
Disk
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
Disk
```

The memory footprint should remain reasonably stable as media duration increases.

Long recordings are an explicit use case.

## Transcription Results

Internally, transcription results must retain timing information.

A conceptual result contains:

```swift
struct TranscriptionSegment {
    let start: Duration
    let end: Duration
    let text: String
}
```

However, do not assume that all segments need to be stored in an array for the entire recording.

Results should be consumed incrementally.

The pipeline should be capable of:

```text
SpeechTranscriber
    ↓
TranscriptionSegment
    ↓
ParagraphAggregator
    ↓
MarkdownWriter
```

Once processed data is no longer required, it should be released.

## Timestamps

Timestamps are optional.

The user can choose:

* transcription without timestamps;
* transcription with timestamps.

When enabled, timestamps should be associated with paragraphs rather than every low-level SpeechTranscriber result.

Example:

```markdown
### [00:03:47]

Como sabéis, llevamos dos semanas trabajando
en la nueva arquitectura.
```

The timestamp represents the start of the paragraph/block.

The internal pipeline should retain more precise timing information when available.

## Output

The initial output format is Markdown only.

Do not implement:

* SRT
* VTT
* TXT
* DOCX
* PDF

unless explicitly requested in a future change.

Output should be written incrementally where practical.

A source file such as:

```text
reunion.mp4
```

should normally produce:

```text
reunion.md
```

## Job Processing

Multiple files may be added to the application.

The first version must process jobs sequentially.

Example:

```text
Job 1 → processing → completed
Job 2 → pending
Job 3 → pending
```

Do not parallelize transcription jobs in the initial version.

This is intentional to reduce:

* memory pressure;
* CPU contention;
* thermal load;
* unpredictable performance.

## User Interface

The UI should be designed for non-technical users.

The primary workflow should be:

1. Drag files into the application or select them.
2. Select the transcription language.
3. Enable or disable timestamps.
4. Select the destination folder.
5. Start transcription.
6. Monitor progress.
7. Find the generated Markdown file.

Use standard macOS controls wherever possible.

The UI should avoid exposing implementation details.

## Error Handling

Separate technical errors from user-facing messages.

Users should receive simple explanations.

For example:

```text
No se puede transcribir este archivo porque no contiene
una pista de audio compatible.
```

instead of exposing raw framework errors.

Detailed diagnostic information should be available through application logging.

## Logging

Implement structured application logging using Apple's logging facilities where appropriate.

Logs should help diagnose:

* media loading failures;
* unsupported formats;
* Speech framework failures;
* asset installation problems;
* cancellation;
* output/write failures.

Do not log sensitive audio contents or complete transcription text unnecessarily.

## Testing

The application must be tested with:

* short audio;
* long audio;
* short video;
* long video;
* multiple files;
* missing speech assets;
* offline operation;
* cancellation;
* invalid media;
* video without an audio track;
* timestamps enabled;
* timestamps disabled.

Memory usage must be explicitly tested with long recordings.

## Distribution

The final application is intended to be distributed as a DMG.

Release distribution should eventually include:

* Release build;
* Apple code signing;
* notarization;
* DMG packaging.

Distribution work is secondary to validating the transcription pipeline.

## Development Principle

Prefer the simplest Apple-native solution that satisfies the requirements.

Do not prematurely optimize by adding complexity.

However, streaming and memory efficiency are not optional optimizations: they are core architectural requirements of the application.
