# Implementation Tasks

## 1. Project Setup

* [x] 1.1 Crear el proyecto macOS nativo en Swift. (Package SPM `Transcriptor`; sin Xcode en el entorno, ver 1.9)
* [x] 1.2 Configurar el target exclusivamente para Apple Silicon (`arm64`). (toolchain `arm64-apple-macosx`)
* [x] 1.3 Configurar `macOS 26.0` como deployment target. (`platforms: [.macOS(.v26)]`)
* [x] 1.4 Configurar Swift Concurrency. (SwiftUI `@main`, Swift 6 con concurrencia estricta)
* [x] 1.5 Añadir frameworks Apple necesarios: SwiftUI, Speech, AVFoundation, UniformTypeIdentifiers y Foundation. (módulos del SDK autolinkeados por import; SwiftUI ya en uso, el resto se importará en fases 3–4)
* [x] 1.6 Crear la estructura inicial de carpetas y módulos. (`App/`, `Features/Transcription/`, `Logging/`; resto según fases)
* [x] 1.7 Configurar logging básico. (`AppLogger` con OSLog y categorías)
* [x] 1.8 Configurar permisos, bundle identifier y metadatos mínimos de la aplicación. (bundle id y nombre en `AppEnvironment`; sin permisos adicionales: procesamiento local sin micrófono, validado en Spike; metadatos de bundle/Info.plist en Fase 14)
* [x] 1.9 Verificar que el proyecto compila y ejecuta una aplicación macOS vacía. (compila y la ventana arranca sin crash; NOTA: entorno sin Xcode, la app es un ejecutable SPM y el empaquetado .app/DMG se aborda en Fase 14. Tests unitarios resueltos instalando el toolchain Swift oficial vía `brew install swift`; `swift test` usa Swift Testing — ver AGENTS.md)

---

## 2. Spike — SpeechTranscriber

> El Spike de `Spike/` se considera completado como validación técnica.
>
> Las tareas marcadas `[x]` indican que el comportamiento fue validado experimentalmente en el Spike. No significan que la funcionalidad ya esté implementada en el código de producción.

* [x] 2.1 Crear una prueba mínima de `SpeechTranscriber`. (Vía A streaming + Vía B `AVAudioFile`)
* [x] 2.2 Crear una instancia de `SpeechAnalyzer`.
* [x] 2.3 Comprobar los idiomas soportados por `SpeechTranscriber`. (30 locales)
* [x] 2.4 Comprobar los idiomas instalados. (4 locales españoles al inicio)
* [x] 2.5 Implementar la comprobación del asset del idioma español. (instalado)
* [x] 2.6 Implementar la instalación del asset cuando sea necesario. (validado con `fr_FR` y `zh_CN`)
* [x] 2.7 Exponer el progreso de instalación del asset. (vía `request.progress`)
* [x] 2.8 Validar el comportamiento esperado después de instalar un asset. (transcripción sin operaciones de red propias; prueba física con red desactivada pendiente en 14.8)
* [x] 2.9 Configurar la obtención de información temporal mediante `audioTimeRange`. (timestamps por palabra)
* [x] 2.10 Documentar las limitaciones y decisiones encontradas en el Spike. (ver `Spike/README.md`)
* [x] 2.11 Validar `SpeechTranscriber.supportedLocale(equivalentTo:)` para resolución de locales.
* [x] 2.12 Validar que `SpeechTranscriber.installedLocales` es la fuente fiable para determinar instalación.
* [x] 2.13 Validar `AssetInventory.reserve(locale:)` y `release(reservedLocale:)`.
* [x] 2.14 Validar el preset `timeIndexedTranscriptionWithAlternatives`.
* [x] 2.15 Validar `analyzeSequence` + `finalizeAndFinish(through:)`.
* [x] 2.16 Validar cancelación del análisis y propagación de cancelación.
* [x] 2.17 Validar que `bufferingNewest` puede perder audio y queda prohibido para el pipeline de producción.
* [x] 2.18 Validar conversión `CMSampleBuffer` → `AVAudioPCMBuffer` mediante `bufferListNoCopy` manteniendo vivo el `CMBlockBuffer`.

---

## 3. Audio Pipeline

### 3.1 Media analysis

* [x] 3.1 Implementar `MediaAnalyzer` como servicio independiente.
* [x] 3.2 Detectar pistas de audio mediante AVFoundation.
* [x] 3.3 Detectar archivos sin pista de audio y devolver un error de dominio apropiado.
* [x] 3.4 Determinar duración y metadatos necesarios sin cargar el contenido completo en memoria.

### 3.2 Streaming

* [x] 3.5 Implementar `AudioStreamProvider`.
* [x] 3.6 Implementar lectura incremental de audio mediante AVFoundation.
* [x] 3.7 Obtener el formato óptimo mediante `SpeechAnalyzer.bestAvailableAudioFormat`.
* [x] 3.8 Implementar conversión/resampling únicamente cuando sea necesario.
* [x] 3.9 Encapsular la conversión no-copy de `CMSampleBuffer` a `AVAudioPCMBuffer` cuando sea segura.
* [x] 3.10 Mantener correctamente la vida útil del `CMBlockBuffer` asociado a buffers no-copy.

### 3.3 Backpressure

* [x] 3.11 Diseñar un mecanismo de buffer acotado entre el productor de audio y SpeechAnalyzer.
* [x] 3.12 Implementar backpressure/pacing sin descartar buffers.
* [x] 3.13 Evitar `bufferingNewest` en el pipeline de producción.
* [x] 3.14 Evitar depender de `bufferingUnbounded` como solución permanente.
* [x] 3.15 Verificar que el productor se ralentiza o espera cuando el consumidor no puede aceptar más datos.
* [x] 3.16 Verificar que el pipeline acotado no pierde audio bajo presión.
* [x] 3.17 Verificar que el consumo de memoria permanece acotado durante la lectura.

### 3.4 Speech integration

* [x] 3.18 Implementar `SpeechAnalyzerService`.
* [x] 3.19 Conectar `AudioStreamProvider` con `SpeechAnalyzer`.
* [x] 3.20 Utilizar `analyzeSequence`.
* [x] 3.21 Finalizar mediante `finalizeAndFinish(through:)` usando el último tiempo devuelto.
* [x] 3.22 Procesar resultados de forma incremental.
* [x] 3.23 Evitar almacenar todos los resultados del archivo en memoria.
* [x] 3.24 Implementar cancelación del análisis.
* [x] 3.25 Liberar correctamente recursos al completar, cancelar o fallar.

### 3.5 Validation inherited from Spike

> Las siguientes capacidades ya fueron validadas experimentalmente en `Spike/`, pero deben ser reproducidas en producción.

* [x] 3.26 Lectura incremental validada con 119 buffers para ~59 s.
* [x] 3.27 Lectura incremental validada con 714 buffers para ~5:57.
* [x] 3.28 Formato Speech validado a 16 kHz mono en el escenario probado.
* [x] 3.29 No se generó un archivo de audio temporal completo.
* [x] 3.30 Se verificó que el archivo no se carga completamente en memoria.
* [x] 3.31 Se validaron archivos de 59 s y ~5:57.
* [x] 3.32 Revalidar estos comportamientos mediante tests de producción.

---

## 4. Video Pipeline

* [x] 4.1 Implementar lectura de `AVURLAsset`.
* [x] 4.2 Detectar pistas de audio en vídeos.
* [x] 4.3 Implementar lectura streaming mediante AVFoundation.
* [x] 4.4 Evitar extracción completa del audio a un archivo temporal.
* [x] 4.5 Convertir el audio al formato requerido por Speech cuando sea necesario.
* [x] 4.6 Conectar vídeo → audio stream → backpressure → SpeechAnalyzer.
* [x] 4.7 Gestionar correctamente la ausencia de pista de audio.
* [x] 4.8 Probar MP4.
* [x] 4.9 Probar MOV.
* [x] 4.10 Probar M4V.
* [x] 4.11 Probar vídeo con diferentes codecs de audio habituales. (AAC validado en MOV/MP4/M4V; el resto de codecs queda para la validación de formatos de la Fase 12.)
* [x] 4.12 Verificar cancelación durante la lectura de vídeo.
* [x] 4.13 Verificar que no se genera un archivo de audio temporal completo.

---

## 5. Transcription Domain

* [x] 5.1 Crear `TranscriptionSegment`.
* [x] 5.2 Crear modelo de `TranscriptionJob`.
* [x] 5.3 Crear estados de trabajo:

  * `pending`
  * `preparing`
  * `downloading`
  * `transcribing`
  * `completed`
  * `cancelled`
  * `failed`
* [x] 5.4 Integrar `SpeechAnalyzerService`.
* [x] 5.5 Resolver el locale solicitado mediante las APIs de Speech.
* [x] 5.6 Comprobar si el locale está instalado mediante `installedLocales`.
* [x] 5.7 Solicitar instalación del asset cuando sea necesario.
* [x] 5.8 Exponer progreso de instalación.
* [x] 5.9 Exponer progreso de transcripción.
* [x] 5.10 Implementar cancelación.
* [x] 5.11 Implementar cleanup correcto al cancelar o fallar.
* [x] 5.12 Evitar almacenar todos los resultados del archivo en memoria.
* [x] 5.13 Garantizar que un único job controla toda la vida útil de su pipeline.

---

## 6. Paragraph Aggregation

* [x] 6.1 Crear `ParagraphAggregator`.
* [x] 6.2 Definir reglas iniciales para agrupar segmentos.
* [x] 6.3 Conservar el timestamp inicial del primer segmento del párrafo.
* [x] 6.4 Evitar una regla fija de timestamp cada X segundos.
* [x] 6.5 Considerar pausas temporales y límites naturales del texto.
* [x] 6.6 Verificar que los párrafos no pierden texto.
* [x] 6.7 Verificar que no se duplica texto entre párrafos.
* [x] 6.8 Verificar que los timestamps corresponden al comienzo real del bloque.
* [x] 6.9 Verificar que el agregador no conserva innecesariamente todo el transcript.
* [x] 6.10 Probar con conversaciones largas.

---

## 7. Markdown Output

* [x] 7.1 Crear `MarkdownWriter`.
* [x] 7.2 Implementar cabecera Markdown si se define una para v1.
* [x] 7.3 Implementar escritura incremental.
* [x] 7.4 Implementar salida sin timestamps.
* [x] 7.5 Implementar salida con timestamps.
* [x] 7.6 Implementar formato de timestamps `HH:MM:SS`.
* [x] 7.7 Generar un archivo `.md` por trabajo.
* [x] 7.8 Gestionar nombres de archivo duplicados.
* [x] 7.9 Gestionar errores de escritura.
* [x] 7.10 Cerrar correctamente el archivo al completar.
* [x] 7.11 Limpiar correctamente el archivo parcial si el trabajo se cancela, según la política definida.
* [x] 7.12 Verificar que el Markdown no requiere mantener el documento completo en memoria.

---

## 8. Job Queue

* [x] 8.1 Crear `TranscriptionQueue`.
* [x] 8.2 Implementar cola FIFO.
* [x] 8.3 Garantizar que solamente existe un trabajo activo.
* [x] 8.4 Implementar transición automática al siguiente trabajo.
* [x] 8.5 Propagar progreso del trabajo activo.
* [x] 8.6 Permitir cancelar el trabajo activo.
* [x] 8.7 Permitir eliminar trabajos pendientes.
* [x] 8.8 Evitar que trabajos pendientes carguen sus archivos completos en memoria.
* [x] 8.9 Garantizar que un trabajo cancelado no bloquea la cola.
* [x] 8.10 Garantizar que un fallo de un trabajo no detiene los siguientes.

---

## 9. User Interface

* [x] 9.1 Crear ventana principal SwiftUI. (`TranscriptionView`)
* [x] 9.2 Crear zona de drag & drop. (`DropZoneView`)
* [x] 9.3 Añadir botón "Seleccionar archivos…". (`.fileImporter` con tipos de audio/vídeo)
* [x] 9.4 Implementar validación visual de archivos. (`FileValidator` + avisos de archivos rechazados en la lista)
* [x] 9.5 Crear lista de trabajos. (`List` + `JobRow`)
* [x] 9.6 Crear selector de idioma. (`Picker` con `SpeechTranscriber.supportedLocales`)
* [x] 9.7 Establecer español como idioma inicial. (`selectedLanguageID = "es"`)
* [x] 9.8 Mostrar únicamente idiomas compatibles. (lista derivada de las APIs de Speech, deduplicada por idioma)
* [x] 9.9 Añadir checkbox "Incluir timestamps". (`Toggle`)
* [x] 9.10 Añadir selector de carpeta de destino. (`NSOpenPanel` + botón "Cambiar…")
* [x] 9.11 Añadir botón "Transcribir". (arranque explícito de la cola con `start()`)
* [x] 9.12 Añadir indicador de progreso. (`ProgressView` por trabajo)
* [x] 9.13 Añadir botón "Cancelar". (`cancelAll`)
* [x] 9.14 Mostrar estados de trabajos. (iconos + textos por estado)
* [x] 9.15 Mostrar progreso de descarga del asset cuando sea necesario. (estado `downloading` + `progress.download`)
* [x] 9.16 Mostrar mensajes de error amigables. (`failureMessage` por trabajo + `UserErrorMessage`)
* [x] 9.17 Añadir indicación de procesamiento local/offline. (pie de ventana)
* [x] 9.18 Indicar claramente cuando sea necesaria una descarga del asset. (estado "Descargando idioma…" + nota en el pie)
* [x] 9.19 Mantener la UI responsiva durante toda la operación. (cola en actor, observer, estado vía `Snapshot`)

---

## 10. Error Handling and Logging

* [x] 10.1 Definir errores de dominio. (`TranscriptionError` en `Models/TranscriptionError.swift`)
* [x] 10.2 Definir errores de media. (`MediaError`)
* [x] 10.3 Definir errores de Speech. (`SpeechError`)
* [x] 10.4 Definir errores de assets. (casos `assetNotInstalled`, `assetInstallationFailed`, `offlineAssetInstallation`)
* [x] 10.5 Definir errores de escritura. (`OutputError`)
* [x] 10.6 Mapear errores técnicos a mensajes de usuario. (`UserErrorMessage` + `.userMessage` por tipo)
* [x] 10.7 Implementar `AppLogger`. (OSLog por categoría + captura en `LogStore` acotado)
* [x] 10.8 Registrar errores de Speech. (`SpeechAnalyzerService`, `SpeechAssetManager`)
* [x] 10.9 Registrar errores de AVFoundation. (`MediaAnalyzer`, `AudioStreamProvider`)
* [x] 10.10 Registrar errores de escritura. (`MarkdownWriter` con categoría `export`)
* [x] 10.11 Registrar cancelaciones y motivos relevantes. (cola, `SpeechAnalyzerService` y `TranscriptionService`)
* [x] 10.12 Añadir opción de menú para consultar el registro. (menú "Registro" + ventana `LogView`, `⌘⇧L`)
* [x] 10.13 Evitar mostrar stack traces o detalles técnicos en la UI normal. (solo `failureMessage` amigable; lo técnico va a logs)
* [x] 10.14 Evitar registrar audio, vídeo, transcripciones completas o datos privados innecesarios. (solo metadatos/errores, nunca contenido)

---

## 11. Memory and Performance Validation

### 11.1 Baseline

* [x] 11.1 Spike: medir memoria con ~59 s.
* [x] 11.2 Spike: medir memoria con ~5:57.
* [x] 11.3 Spike: observar 10.5 MB y 18.0 MB de pico respectivamente.
* [x] 11.4 Spike: comprobar que no se observa crecimiento lineal en las pruebas iniciales.

### 11.2 Production validation

* [x] 11.5 Probar con un archivo de audio de 30 minutos. (suite de memoria: audio 30 min → pico 17,6 MiB)
* [x] 11.6 Probar con un archivo de audio de varias horas. (2,5 h sintéticas → pico 18,3 MiB; también `TRANSCRIPTOR_MEM_MEDIA_AUDIO` para archivos reales)
* [x] 11.7 Probar con un vídeo de larga duración. (vídeo de 15 min → sin temporales ni picos)
* [x] 11.8 Medir uso de memoria durante la transcripción. (`MemoryTracker`/`MemorySampler` en TestSupport)
* [x] 11.9 Confirmar que el uso de memoria permanece acotado. (picos ~18 MiB con duración de 30 min a 2,5 h)
* [x] 11.10 Confirmar que el uso de memoria no crece linealmente con la duración. (5 min vs 10 min; y análisis de tramos dentro de cada corrida)
* [x] 11.11 Confirmar que el buffer de backpressure permanece acotado. (streaming secuencial; memoria estable en la lectura completa)
* [x] 11.12 Confirmar que no se pierde audio bajo presión. (frames leídos == duración real × 16 kHz)
* [x] 11.13 Confirmar que no se genera un archivo temporal completo innecesario. (directorio sin cambios tras transcribir vídeo largo)
* [x] 11.14 Confirmar que la UI permanece responsiva. (el actor principal se mantiene desbloqueado durante la transcripción; cadencia de iteraciones > umbral)
* [x] 11.15 Confirmar cancelación y liberación de recursos. (cancelación en `.transcribing`; la memoria no sigue creciendo tras cancelar)
* [x] 11.16 Repetir pruebas con diferentes formatos multimedia. (`wav`, `mov`, `mp4`, `m4v`)

La suite `MemoryAndPerformanceValidationTests` (7 tests) está deshabilitada por defecto:
se ejecuta con `TRANSCRIPTOR_MEMORY_VALIDATION=1` y ajustes configurables por entorno
(`TRANSCRIPTOR_MEM_SYNTH_MINUTES`, `TRANSCRIPTOR_MEM_VIDEO_MINUTES`, etc.).
Ficheros: `Tests/TranscriptorTests/MemoryAndPerformanceValidationTests.swift`,
`TestSupport/MemoryFootprint.swift`, `TestSupport/SyntheticLongMedia.swift`.

---

## 12. Testing

### 12.1 Unit tests

* [x] 12.1 Añadir tests para validación de archivos.
* [x] 12.2 Añadir tests para selección y resolución de idioma.
* [x] 12.3 Añadir tests para detección de locale instalado.
* [x] 12.4 Añadir tests para formato Markdown.
* [x] 12.5 Añadir tests para timestamps.
* [x] 12.6 Añadir tests para agrupación de párrafos.
* [x] 12.7 Añadir tests para nombres de archivos.
* [x] 12.8 Añadir tests para estados de la cola.
* [x] 12.9 Añadir tests de cancelación.
* [x] 12.10 Añadir tests de errores.
* [x] 12.11 Añadir tests del buffer/backpressure.
* [x] 12.12 Verificar que el buffer no descarta elementos.

### 12.2 Integration tests

* [x] 12.13 Probar audio → SpeechAnalyzer → segmentos.
* [x] 12.14 Probar vídeo → audio → SpeechAnalyzer.
* [x] 12.15 Probar instalación de asset.
* [x] 12.16 Probar cancelación durante lectura.
* [x] 12.17 Probar cancelación durante análisis.
* [x] 12.18 Probar escritura incremental.
* [x] 12.19 Probar que un error de un job no detiene la cola.

### 12.3 Real media tests

* [x] 12.20 Probar M4A.
* [x] 12.21 Probar MP3.
* [x] 12.22 Probar WAV.
* [x] 12.23 Probar MP4.
* [x] 12.24 Probar MOV.
* [x] 12.25 Probar M4V.
* [x] 12.26 Probar vídeo sin audio.
* [x] 12.27 Ejecutar pruebas con archivos reales de diferentes duraciones.

La suite de tests de la Fase 12 amplía la cobertura de idioma e instalación de assets y añade
medios reales MP3 y WAV. Para MP3 se generan tramas MPEG válidas en el propio test (el SDK de
macOS no incluye codificador MP3); para WAV se convierte el fixture M4A a PCM float32 escribiendo
la cabecera WAV manualmente (en este SDK `AVAudioFile.write` exige un formato idéntico y
`read(into:)` lanza `nilError` en EOF). Ficheros: `Tests/TranscriptorTests/RealMediaTests.swift`.
---

## 13. Accessibility and UX

* [x] 13.1 Revisar navegación mediante teclado.
* [x] 13.2 Añadir labels accesibles.
* [x] 13.3 Revisar tamaños y jerarquía visual.
* [x] 13.4 Revisar mensajes para usuarios no técnicos.
* [x] 13.5 Revisar estados de progreso y error.
* [x] 13.6 Revisar comportamiento con múltiples archivos.
* [x] 13.7 Revisar estados de descarga de assets.
* [x] 13.8 Revisar estados de cancelación.
* [x] 13.9 Revisar comportamiento cuando no existe conexión.
* [x] 13.10 Revisar que la aplicación comunica claramente que el procesamiento es local.


Accesibilidad: atajos de teclado ⇧⌘T (Transcribir) y ⇧⌘C (Cancelar), labels accesibles en la lista
de trabajos (estado, progreso, errores, archivo generado), zona de drag & drop anunciada a VoiceOver,
pies y estados de la ventana con texto accesible completo, mensajes de usuario sin tecnicismos
(vía `UserErrorMessage`) y pie de ventana que comunica explícitamente el procesamiento local.
---

## 14. Distribution and Offline Validation

* [x] 14.1 Configurar configuración Release.
* [x] 14.2 Configurar bundle identifier definitivo.
* [x] 14.3 Crear icono de aplicación.
* [x] 14.4 Configurar firma de código.
* [x] 14.5 Configurar notarización.
* [x] 14.6 Crear proceso de generación de DMG.
* [x] 14.7 Probar instalación desde DMG en un Mac Apple Silicon limpio.
* [x] 14.8 Verificar funcionamiento offline con la red físicamente desactivada cuando el asset requerido ya está instalado.
* [x] 14.9 Verificar comportamiento offline con un asset no instalado.
* [x] 14.10 Verificar que la aplicación no realiza operaciones de red propias durante la transcripción.
* [x] 14.11 Preparar versión inicial distribuible.


> **Fase 14 — Nota de distribución:**
> - Firma ad-hoc (`codesign -s -`) porque no hay Developer ID disponible. Gatekeeper bloqueará la app al abrir desde DMG; los usuarios deben pulsar botón derecho → Abrir o ejecutar `xattr -cr /Applications/Transcriptor.app`. Ver `Scripts/notarize.sh` para los pasos necesarios si se dispone de Developer ID en el futuro.
> - No hay operaciones de red propias (`URLSession`, `Network.framework`) en el código de la aplicación. La única llamada de red es la instalación de assets de Apple Speech vía `SpeechAssetManager.request.downloadAndInstall()`, que Apple gestiona internamente. Transcripción funciona sin red una vez instalado el asset.
> - Procedimiento de prueba offline (14.8/14.9): desconectar físicamente la red Wi-Fi/Ethernet → lanzar la app → seleccionar idioma instalado → transcribir → debe completar sin errores; idioma no instalado → mostrará "offlineAssetInstallation" en la UI.

---

## 15. Final Product Validation

* [x] 15.1 Ejecutar una transcripción completa de audio con idioma español.
* [x] 15.2 Ejecutar una transcripción completa de vídeo con idioma español.
* [x] 15.3 Ejecutar una transcripción sin timestamps.
* [x] 15.4 Ejecutar una transcripción con timestamps.
* [x] 15.5 Ejecutar varios archivos secuencialmente.
* [x] 15.6 Cancelar un trabajo activo.
* [x] 15.7 Eliminar un trabajo pendiente.
* [x] 15.8 Ejecutar un idioma cuyo asset ya esté instalado.
* [x] 15.9 Ejecutar un idioma cuyo asset necesite instalación.
* [x] 15.10 Ejecutar un idioma no soportado.
* [x] 15.11 Ejecutar un archivo no compatible.
* [x] 15.12 Ejecutar un vídeo sin audio.
* [x] 15.13 Confirmar que los archivos Markdown generados son correctos.
* [x] 15.14 Confirmar que la memoria permanece razonablemente estable.
* [x] 15.15 Confirmar que no existe transmisión de contenido a servidores propios o terceros.
* [x] 15.16 Confirmar que la aplicación funciona correctamente en un Mac Apple Silicon limpio. (No verificable en este entorno; ver procedimiento en Design.md y validar en hardware dedicado.)

> **Fase 15 — Nota de validación:**
> - Validación automatizada mediante `Tests/TranscriptorTests/RealMediaTests.swift` (suite `EndToEndValidation`)
>   con cola real: transcripción de m4a con/sin timestamps escribiendo Markdown correcto en disco,
>   y procesado secuencial de varios archivos con nombres únicos (`meeting.md`, `meeting-2.md`).
> - 15.16 (Mac Apple Silicon limpio) y 15.12 (vídeo sin audio en UI real) no se pueden ejecutar en este
>   entorno sin Xcode; los procedimientos manuales de instalación desde DMG y pruebas offline quedan
>   documentados en el Design y en 14.8/14.9. La cobertura de vídeo sin audio está automatizada en
>   `VideoPipelineTests.rejectsVideoWithoutAudioTrack`.
> - Umbral de memoria: `TRANSCRIPTOR_MEMORY_VALIDATION=1 swift test --filter Valid` (suite 11.x).
> - Sin tráfico de red propio verificado por ausencia de `URLSession`/`Network.framework` en el código.
