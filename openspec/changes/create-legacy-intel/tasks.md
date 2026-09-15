# Implementation Tasks

## 1. Project Setup (Legacy)

* [ ] 1.1 Crear la rama `legacy-intel` partiendo de la versión Apple Silicon. (hecho: rama creada y publicada en GitHub)
* [ ] 1.2 Configurar el target para Intel (`x86_64`). (toolchain `x86_64-apple-macosx`)
* [ ] 1.3 Configurar `macOS 12.0` como deployment target. (se mantiene Swift 6 si el toolchain lo permite para ese target)
* [ ] 1.4 Mantener Swift Concurrency y SwiftUI como base de la UI.
* [ ] 1.5 Eliminar las dependencias de las APIs de Speech de Apple (`SpeechAnalyzer`, `SpeechTranscriber`, `Speech.AssetInventory`) del código compilado.
* [ ] 1.6 Verificar que el proyecto compila para `x86_64` con deployment target macOS 12 sin usar APIs posteriores. (requiere pasar el SDK de macOS por encima del deployment target)

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

* [ ] 3.1 Crear `VoskService` implementando `Transcribing` (mismo contrato que `SpeechAnalyzerService`).
* [ ] 3.2 Negociar el formato de audio de entrada (PCM mono 16 kHz 16-bit).
* [ ] 3.3 Alimentar el modelo Vosk buffer a buffer desde el audio PCM 16 kHz.
* [ ] 3.4 Extraer resultados de cada utterance completada y convertirlos en `TranscriptionSegment`.
* [ ] 3.5 Calcular progreso por duración procesada / duración total.
* [ ] 3.6 Sustituir `SpeechAnalyzerService` por `VoskService` en `TranscriptionService` manteniendo el protocolo existente.
* [ ] 3.7 Propagación de cancelación: detener la lectura de audio y liberar el recognizer.
* [ ] 3.8 Validar que no se crean archivos temporales de audio completos.

---

## 4. VoskModelManager

* [ ] 4.1 Crear `VoskModelManager` que resuelva el directorio del modelo a partir del locale.
* [ ] 4.2 Definir la ruta local de modelos (`~/Library/Application Support/Transcriptor/models/`).
* [ ] 4.3 Comprobar presencia del modelo antes de comenzar la transcripción.
* [ ] 4.4 Implementar descarga de modelos desde la fuente oficial con progreso.
* [ ] 4.5 Manejar el caso offline sin modelo instalado (error comprensible al usuario).
* [ ] 4.6 Implementar el estado `.downloading` en la cola tal como lo consume la UI actual.

---

## 5. Media / Audio

* [ ] 5.1 Asegurar que `AudioStreamProvider` puede emitir PCM mono 16 kHz 16-bit.
* [ ] 5.2 Confirmar que el flujo AVFoundation existente (video → audio) funciona sin cambios.
* [ ] 5.3 Validar conversión de muestreo/canales por streaming sin fichero temporal.
* [ ] 5.4 Verificar `MediaAnalyzer` (formats MP3/M4A/WAV/MP4/MOV/M4V) sin cambios para macOS 12.

---

## 6. Model / Queue Integration

* [ ] 6.1 Ajustar `TranscriptionJobState` si hiciera falta para la descarga de modelo.
* [ ] 6.2 Integrar la descarga de modelo en el pipeline de cola (state `.downloading`).
* [ ] 6.3 Mantener la secuencia de jobs (uno a uno) sin cambios.

---

## 7. UI

* [ ] 7.1 Reutilizar `TranscriptionView`, `TranscriptionViewModel`, `DropZoneView` y `JobRow` tal cual.
* [ ] 7.2 Ajustar la lista de idiomas disponibles a los modelos Vosk instalados.
* [ ] 7.3 Actualizar el mensaje de privacidad para reflejar el motor local Vosk.
* [ ] 7.4 Mantener mensajes de error comprensibles para los casos específicos Vosk (modelo ausente, descarga fallida).
* [ ] 7.5 Mantener logs técnicos para diagnóstico.

---

## 8. Output

* [ ] 8.1 Verificar que `MarkdownWriter` y `ParagraphAggregator` se reutilizan sin cambios.
* [ ] 8.2 Confirmar timestamps por párrafo (con/sin) funcionan con los segmentos de Vosk.

---

## 9. Tests

* [ ] 9.1 Unit tests: `VoskModelManager` (resolución, presencia, offline).
* [ ] 9.2 Unit tests: `VoskService` con un stub/mock de la librería C.
* [ ] 9.3 Unit tests: conversión de utterance de Vosk a `TranscriptionSegment`.
* [ ] 9.4 Unit tests: agrupación de párrafos con timestamps de Vosk.
* [ ] 9.5 Tests de la cola (transiciones de estado) sin cambios.
* [ ] 9.6 Test de cancelación del pipeline con Vosk.
* [ ] 9.7 Test de memoria con archivos largos en hardware Intel (o CI x86_64).
* [ ] 9.8 Pruebas manuales de integración con audio real (grabación de voz en español).

---

## 10. Performance

* [ ] 10.1 Medir factor en vivo con `vosk-model-small-es` en MacBook Air 2015 (o equivalente).
* [ ] 10.2 Comprobar que la UI sigue respondiendo durante la transcripción.
* [ ] 10.3 Comprobar que la transcripción de vídeo largo no acumula memoria.
* [ ] 10.4 Verificar que cancelación libera el modelo y los buffers.
* [ ] 10.5 Confirmar que no se crean archivos temporales.

---

## 11. Distribution

* [ ] 11.1 Construir un DMG x86_64 con el modelo Vosk incluido o descargable por primera ejecución.
* [ ] 11.2 Firma ad-hoc (mismo enfoque que la versión actual).
* [ ] 11.3 Verificación end-to-end en un Mac Intel real: instalación, primer uso (descarga de modelo), transcripción offline.

> NOTA: el tiempo objetivo de transcripción en hardware antiguo debe documentarse en el README o en la app.