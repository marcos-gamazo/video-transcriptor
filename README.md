# Transcriptor

macOS Apple Silicon app that transcribes audio and video files into Markdown. All processing is local using Apple's Speech framework — no data leaves your Mac.

## Requirements

- macOS 26.0+
- Apple Silicon Mac (arm64)
- Swift 6.3+

## Build

```sh
swift build -c release
```

The binary is produced at `.build/release/Transcriptor`.

## Run

```sh
.swift build/release/Transcriptor
```

The app will request the Speech framework asset for your selected language the first time you transcribe. This requires an internet connection; afterwards transcription works fully offline.

## Tests

91 tests across 21 suites covering transcription pipeline, media validation, markdown output, memory safety and accessibility.

```sh
swift test
```

To run the memory validation suite (requires longer media fixtures):

```sh
TRANSCRIPTOR_MEMORY_VALIDATION=1 swift test --filter Valid
```

## Build DMG

To generate a distributable DMG:

```sh
bash Scripts/build-release.sh 1.0.0
```

Output: `build/Transcriptor-1.0.0.dmg`

> **Note:** The app is ad-hoc signed. Gatekeeper will block it on first open. To work around this: right-click → Open in Finder, or run `xattr -cr /Applications/Transcriptor.app`. To use a real Developer ID certificate, see `Scripts/notarize.sh`.

## Usage

1. Open Transcriptor
2. Drag audio/video files onto the drop zone, or click **Seleccionar archivos…**
3. Select the transcription language (Spanish by default)
4. Toggle **Incluir timestamps** to add paragraph timestamps to the output
5. Click **Transcribir** (or press `⇧⌘T`)
6. The generated Markdown file appears in the destination folder (Movies by default)

**Supported formats:** mp3, m4a, wav, mp4, mov, m4v

**Keyboard shortcuts:**
| Shortcut | Action |
|---|---|
| `⇧⌘T` | Start transcription |
| `⇧⌘C` | Cancel all |
| `⇧⌘L` | Open log window |

## Architecture

```
TranscriptionView → TranscriptionViewModel → TranscriptionQueue
                                                      ↓
                                              TranscriptionService
                                                      ↓
                                          MediaAnalyzer ← AudioStreamProvider
                                                      ↓
                                            SpeechAnalyzerService
                                                      ↓
                                           ParagraphAggregator
                                                      ↓
                                              MarkdownWriter → disk
```

All media processing is streaming — no full file or audio track is ever loaded into memory.

## OpenSpec

The full design documentation (proposal, specs, tasks, design decisions) lives in `openspec/`.
