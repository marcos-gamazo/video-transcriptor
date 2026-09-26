# Implementation Tasks

## 1. Project Setup (Legacy)

* [x] 1.1 Crear la rama `legacy-intel` partiendo de la versión Apple Silicon. (hecho: rama creada y publicada en GitHub)
* [x] 1.2 Configurar el target para Intel (`x86_64`). (job `build-x86_64` de `legacy-intel.yml` con `swift build --triple x86_64-apple-macosx11.0` + verificación `file`/`vtool`; la compilación nativa en un Mac Intel real sigue pendiente — ver 1.6 y 10.x)
* [x] 1.2b Estrategia de tests en CI. (el runner headless bloquea AVFoundation → deadlock en suites de media; se resuelve con `TRANSCRIPTOR_SKIP_MEDIA_TESTS=1` que deshabilita las suites AVFoundation vía `.enabled(if: mediaTestsEnabled)`; ver `Tests/TranscriptorTests/TestSupport/MediaTestGate.swift`. Las suites puras corren en CI, las de media/memoria se ejecutan localmente)
* [x] 1.3 Configurar `macOS 11.0` como deployment target mínimo. (se mantiene Swift 6 si el toolchain lo permite para ese target; el binario corre en macOS 11 y superiores; `Package.swift` → `.macOS(.v11)`, `AppEnvironment.deploymentTarget` → `"macOS 11.0"`)
* [x] 1.4 Mantener Swift Concurrency y SwiftUI como base de la UI.
* [x] 1.5 Eliminar las dependencias de las APIs de Speech de Apple (`SpeechAnalyzer`, `SpeechTranscriber`, `Speech.AssetInventory`) del código compilado. (eliminado `Sources/Transcriptor/Services/Speech/`; creado `Services/Vosk/` con `VoskService`, `VoskModelManager`, `VoskError` como stubs Fase 1)
* [ ] 1.6 Verificar que el proyecto compila para `x86_64` con deployment target macOS 11 sin usar APIs posteriores. (PENDIENTE: el cross-build está configurado en CI, pero en este host arm64 `swift build --triple x86_64-apple-macosx11.0` falla por falta de stdlib Swift x86_64 en el toolchain; el build nativo en un Mac Intel real lo resolvería — ver Open Question 6 de design.md)
* [x] 1.7 Portar las APIs incompatibles con macOS 11 del código compartido:
  * [x] 1.7.1 `@Observable`/`@Bindable` → `ObservableObject` + `@Published` (`TranscriptionViewModel`, `LogStore`, vistas).
  * [x] 1.7.2 `Duration` → `Double` (segundos) en el dominio (modelos, `ParagraphAggregator`, `MarkdownWriter`, `TranscriptionService`).
  * [x] 1.7.3 `ContinuousClock` → throttle por `Date` en `TranscriptionQueue`.
  * [x] 1.7.4 `AnalyzerInput` propio (hoy importado desde Speech) y `.foregroundStyle`/`.textSelection`/`.formatted`/`.monospacedDigit`/`.listRowSeparator`/`Window(id:)`/`openWindow`/`asset.load` async → equivalentes macOS 11. (prefacio: el `swift test`/build arm64 con deployment 11 pasa; los tests usan `-target arm64-apple-macosx26.0` porque el Swift Testing del toolchain 6.3 lo exige)

---

## 2. Spike — Vosk en macOS Intel

> Las tareas marcadas `[x]` indican validación experimental. No significan que la funcionalidad esté implementada en producción.

* [x] 2.1 Obtener una librería Vosk para macOS. (prebuilt oficial `vosk-osx-0.3.42.zip`: `libvosk.dylib` **universal2** x86_64+arm64, min **macOS 11.0**, deps solo sistema: Accelerate/libc++/libSystem; ver `Spike/VoskSpike/README.md`)
* [x] 2.2 Crear un puente mínimo con la cabecera `vosk_api.h`. (import directo del header C como módulo `CVosk` via SPM; sin archivos `.c` intermedios)
* [x] 2.3 Transferir audio de prueba. (WAV PCM 16 kHz mono Int16 generado con `afconvert` desde `Samples/meeting.m4a` y `meeting_long.m4a`; 59.55 s y 357.85 s)
* [~] 2.4 Probar el flujo end-to-end. (✅ validado en este Mac a través del slice **arm64** de `libvosk.dylib`: WAV 16 kHz → `vosk-model-small-es-0.42` → texto con timestamps por palabra. ❌ pendiente: ejecución del slice **x86_64** en un Mac Intel real o vía Rosetta — además, `swift build --triple x86_64-apple-macosx12.0` en este host arm64 falla por falta de stdlib Swift x86_64 en el toolchain; el build nativo en el Mac Intel lo resuelve)
* [x] 2.5 Probar la entrada desde un flujo de buffers pequeños. (chunks de 1600 frames; ✅ 59.55 s → 1.13 s, 3 utterances; ✅ 357.85 s → 3.53 s, 18 utterances)
* [x] 2.6 Probar cancelación a mitad de proceso y liberación de recursos. (`--cancel-after 0.3`: detiene la alimentación, exit 2, `vosk_recognizer_free` libera; sin leaks observados)
* [x] 2.7 Decidir entre puente C directo o CLI embebido. (**Decisión: puente C directo** vía header `vosk_api.h` + dylib; sin proceso externo, sin overhead, API mínima estable del upstream — ver Open Question 1 de design.md)
* [x] 2.8 Medir velocidad real y uso de memoria. (memoria pico 208.6 MB (59.6 s) y 265.2 MB (357.9 s), dominada por modelo+decoder; **factor en vivo 0.01–0.02 en Apple Silicon**; pendiente medir en hardware Intel real — tarea 10.1)
* [x] 2.9 Documentar las limitaciones y decisiones encontradas en el Spike. (ver `Spike/VoskSpike/README.md`)

---

## 3. VoskService

> La fase 3 está implementada y compila (puente C `CVosk` + `libvosk.dylib` enlazado).
> La validación end-to-end queda condicionada a un modelo Vosk instalado en la ruta de
> modelos de la app (ver 9.x y las suites gated por `voskIntegrationTestsEnabled`).

* [x] 3.1 Crear `VoskService` con la transcripción real vía la API C de Vosk. (nota de arquitectura: la integración no hace que `VoskService` adopte el protocolo `Transcribing`; `TranscriptionService` es la fachada `Transcribing` de la cola y delega en `VoskService` — ver design.md §4 actualizado)
* [x] 3.2 Negociar el formato de audio de entrada (PCM mono 16 kHz 16-bit).
* [x] 3.3 Alimentar el modelo Vosk buffer a buffer desde el audio PCM 16 kHz.
* [x] 3.4 Extraer resultados de cada utterance completada y convertirlos en `TranscriptionSegment`.
* [x] 3.5 Calcular progreso por duración procesada / duración total. (en `TranscriptionService`, `segment.end / totalSeconds`)
* [x] 3.6 Sustituir `SpeechAnalyzerService` por `VoskService` en `TranscriptionService`.
* [x] 3.7 Propagación de cancelación: detener la lectura de audio y liberar el recognizer. (`Task.isCancelled` + `vosk_recognizer_free` vía `defer`)
* [x] 3.8 Validar que no se crean archivos temporales de audio completos. (test de stream `noTemporaryAudioFileDuringVideoRead` ✅; e2e completo ✅ localmente con el modelo del Spike — ver nota Fase 9 sobre el fix de `makePCMBuffer`)

---

## 4. VoskModelManager

* [x] 4.1 Crear `VoskModelManager` que resuelva el directorio del modelo a partir del locale. (`modelName(for:)` → nombres oficiales de la fuente Vosk: `vosk-model-small-es-0.42` / `vosk-model-small-en-us-0.15`, así la extracción no requiere renombrar el directorio raíz)
* [x] 4.2 Definir la ruta local de modelos (`~/Library/Application Support/com.transcriptor.app/models/`). (`VoskModelManager.modelsDirectory`)
* [x] 4.3 Comprobar presencia del modelo antes de comenzar la transcripción. (`preflight` → `LocalePreflight.installed`; validación real `am/final.mdl` en `VoskService.isValidModelDirectory`)
* [x] 4.4 Implementar descarga de modelos desde la fuente oficial con progreso. (`VoskModelDownloader` con `URLSessionDownloadDelegate` macOS 11: descarga el zip → discotec a disco sin cargarlo en memoria, progreso `didWriteData`, cancelación via `withTaskCancellationHandler`; `install` idempotente: descomprime con `/usr/bin/ditto`, valida `am/final.mdl`, mueve de forma atómica a `modelsDirectory` y limpia temporales; URLs oficiales verificadas en `alphacephei.com/vosk/models`. La descarga real de red queda pendiente de ejecutar en el test manual Intel — el flujo e2e con modelo preinstalado está ✅ validado)
* [x] 4.5 Manejar el caso offline sin modelo instalado (error comprensible al usuario). (`VoskModelManager.mapDownloadError`: códigos de conectividad → `offlineAssetInstallation`; resto → `downloadFailed`; unit tests añadidos en `VoskServiceTests`)
* [x] 4.6 Implementar el estado `.downloading` en la cola tal como lo consume la UI actual. (el estado `TranscriptionJobState.downloading` existe y `TranscriptionService` transita a él y reporta progreso `overall = 0.5 * fraction`; test `installIsNoopWhenAlreadyInstalled` ✅ con modelo preinstalado)

---

## 5. Media / Audio

* [x] 5.1 Asegurar que `AudioStreamProvider` puede emitir PCM mono 16 kHz 16-bit. (`AudioStreamFormat` Int16 + `outputSettings` del reader; validado en `VoskService.negotiatedAudioFormat`)
* [x] 5.2 Confirmar que el flujo AVFoundation existente (video → audio) funciona sin cambios. (suites `RealMediaMP3`/`RealMediaWAV`/`VideoPipeline` ✅ localmente)
* [x] 5.3 Validar conversión de muestreo/canales por streaming sin fichero temporal. (WAV 22050 Hz estéreo→mono y vídeo → PCM objetivo por streaming; test `noTemporaryAudioFileDuringVideoRead`)
* [x] 5.4 Verificar `MediaAnalyzer` (formats MP3/M4A/WAV/MP4/MOV/M4V) sin cambios para macOS 11.

---

## 6. Model / Queue Integration

* [x] 6.1 Ajustar `TranscriptionJobState` si hiciera falta para la descarga de modelo. (estado `.downloading` ya existe y se rinde en `hasPendingWork`/`isProcessing`)
* [x] 6.2 Integrar la descarga de modelo en el pipeline de cola (state `.downloading`). (`TranscriptionService` transita a `.downloading`, llama a `install` con progreso y documenta el error offline; completado con 4.4)
* [x] 6.3 Mantener la secuencia de jobs (uno a uno) sin cambios.

---

## 7. UI

* [x] 7.1 Reutilizar `TranscriptionView`, `TranscriptionViewModel`, `DropZoneView` y `JobRow` tal cual.
* [~] 7.2 Ajustar la lista de idiomas disponibles a los modelos Vosk instalados. (`supportedLocales` sigue hardcodeado a es/en; no refleja dinámicamente los modelos presentes en disco — aceptable mientras la descarga 4.4 no exista)
* [x] 7.3 Actualizar el mensaje de privacidad para reflejar el motor local Vosk. (TranscriptionView: "nunca se envían a servidores externos" + nota de descarga de modelo del idioma)
* [x] 7.4 Mantener mensajes de error comprensibles para los casos específicos Vosk. (`VoskError.userMessage` cubre modelo ausente/dañado/descarga/offline)
* [x] 7.5 Mantener logs técnicos para diagnóstico.

---

## 8. Output

* [x] 8.1 Verificar que `MarkdownWriter` y `ParagraphAggregator` se reutilizan sin cambios.
* [~] 8.2 Confirmar timestamps por párrafo (con/sin) funcionan con los segmentos de Vosk. (`VoskService` emite `TranscriptionSegment(start/end/text)` con timestamps de palabra; agregación unitaria ✅ — falta validación e2e con modelo real: 9.4/9.8)

---

## 9. Tests

> La suite e2e de Vosk se activa localmente cuando el modelo `vosk-model-small-es-0.42`
> está instalado en `VoskModelManager.modelsDirectory` (gate `voskIntegrationTestsEnabled`).
> En CI se omite (`TRANSCRIPTOR_SKIP_MEDIA_TESTS=1`). Los unit de parsing del utterance
> y el mapeo de errores de descarga no requieren modelo y corren siempre.

* [x] 9.1 Unit tests: `VoskModelManager` (resolución, presencia, offline). (resolución en `preflightResolvesSpanish`/`preflightResolvesEnglish` + `officialDownloadURL`; presencia en `installIsNoopWhenAlreadyInstalled`; offline via `VoskModelManager.mapDownloadError` en `VoskServiceTests`)
* [~] 9.2 Unit tests: `VoskService` con un stub/mock de la librería C. (no hay mock del C bridge; en su lugar: unit de parsing del utterance JSON, mapeo de errores de descarga y tests e2e gated contra el dylib real — ver `VoskServiceTests`)
* [x] 9.3 Unit tests: conversión de utterance de Vosk a `TranscriptionSegment`. (añadidos: `transcriptionText`, `segmentStart`, `segmentEnd`)
* [x] 9.4 Unit tests: agrupación de párrafos con timestamps de Vosk. (`ParagraphAggregatorTests` con segmentos cronometrados)
* [x] 9.5 Tests de la cola (transiciones de estado) sin cambios. (`TranscriptionQueueTests`)
* [x] 9.6 Test de cancelación del pipeline con Vosk. (`cancellationPropagates` ✅ ejecutado localmente con modelo `vosk-model-small-es-0.42` del Spike)
* [ ] 9.7 Test de memoria con archivos largos en hardware Intel (o CI x86_64).
* [ ] 9.8 Pruebas manuales de integración con audio real (grabación de voz en español).

> Nota Fase 3/5: durante la validación e2e local se corrigió un bug real del stream:
> `makePCMBuffer` fijaba `frameLength` después de la copia y `AVAudioPCMBuffer` exponía
> `mDataByteSize == 0`, así que la copia de muestras se saltaba y el decoder emitía
> silencio (ceros). Ahora se calcula el tamaño de bytes por frame y se fija
> `mDataByteSize` antes del `memcpy` (`AudioStreamProvider.swift`). Con ello el e2e
> `transcribesFixture` transcribe 59 s en ~1.3 s.

---

## 10. Performance

* [ ] 10.1 Medir factor en vivo con `vosk-model-small-es` en MacBook Air 2015 (o equivalente).
* [ ] 10.2 Comprobar que la UI sigue respondiendo durante la transcripción.
* [ ] 10.3 Comprobar que la transcripción de vídeo largo no acumula memoria.
* [ ] 10.4 Verificar que cancelación libera el modelo y los buffers.
* [ ] 10.5 Confirmar que no se crean archivos temporales.

---

## 11. Distribution

* [~] 11.1 Construir un DMG x86_64 con el modelo Vosk incluido o descargable por primera ejecución. (`Scripts/build-release.sh` empaqueta el .app con `libvosk.dylib` embebido en `Contents/Frameworks` (install name `@rpath/libvosk.dylib`, ya presente en el dylib prebuilt) + rpath `@executable_path/../Frameworks` añadido en `Package.swift`; modelo descargable por primera ejecución con 4.4. El DMG x86_64 concreto se produce vía el job `build-x86_64` de CI; validación real en hardware Intel pendiente — 11.3. FIX back-deployment: al deployar a macOS < 12.3 el binario enlaza débilmente `@rpath/libswift_Concurrency.dylib` (Swift Concurrency back-deployment); en macOS 11 esa lib no existe en el sistema y si no se embeve el runtime cae en el demangler (SIGSEGV al arrancar). ~~`build-release.sh` embebía `libswift_Concurrency.dylib` del toolchain~~ → la copia del toolchain swift.org 6.x está compilada contra un libswiftCore moderno y referencia símbolos `Durations`/Swift 5.7+ que no existen en el libswiftCore de macOS 11 (fallo `Symbol not found` al arrancar). La copia correcta es el runtime **evergreen** de back-deploy que Apple congela en los toolchains Xcode/CLT 13–15 (`usr/lib/swift-5.5/macosx/libswift_Concurrency.dylib`: minOS 10.9, universal x86_64+arm64, sin refs a plataformas modernas, y exporta toda la API de runtime `swift_task_*`/`swift_continuation_*` que el binario Swift 6 necesita — verificado con `nm`). Se **vende** en `Vendor/swift-backdeploy/libswift_Concurrency.dylib` (mismo patrón que `Vendor/vosk`) y `build-release.sh` la embebe siempre para targets < 12.3, con verificación de arquitectura (`lipo`) y de minOS (`vtool`, must ≤ 11.x), independiente del toolchain presente (en CI Xcode 26 ya no la trae). ✅ DMG `Transcriptor-1.0.0-Intel.dmg` re-publicado el 26-09-2026 con la dylib x86_64 embebida (run 36234124715). Probado en hardware Intel por el usuario: falló al arrancar (`Durations` de la copia swift.org) → corregido con evergreen, re-publicación pendiente. Tarea pendiente — 11.3)
* [x] 11.2 Firma ad-hoc (mismo enfoque que la versión actual). (`codesign --force --deep --options runtime`; `Info.plist` ajustado a variante legacy: `LSMinimumSystemVersion` 11.0 y `LSArchitecturePriority` x86_64)
* [ ] 11.3 Verificación end-to-end en un Mac Intel real: instalación, primer uso (descarga de modelo), transcripción offline.

> NOTA: también falta en tareas 10.x validar factor en vivo/memoria/temporales en el Mac Intel real.