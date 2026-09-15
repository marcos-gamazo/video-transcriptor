# Transcriptor Legacy (Intel / macOS 12)

## Why

La versión actual de Transcriptor requiere macOS 26 y Apple Silicon (`arm64`), porque depende de `SpeechAnalyzer`, `SpeechTranscriber` y `Speech.AssetInventory`.

Existe público objetivo que no puede ejecutar esa versión:

* Macs Intel de la generación 2015 en adelante (por ejemplo el MacBook Air de 2015 con 8 GB de RAM).
* Sistemas anteriores a macOS 26 (el MacBook Air 2015 soporta como máximo macOS 12 Monterey en su soporte oficial).

En macOS 12, la API de Speech disponible (`SFSpeechRecognizer`) no permite transcripción on-device sin Neural Engine: en Intel carece de NPU y deriva (requiere conexión a los servidores de Apple). Esto rompería los requisitos de privacidad y funcionamiento offline de la aplicación.

Por tanto, esta versión necesita un motor de transcripción local ajeno a las APIs de Speech de Apple, eficiente en CPUs Intel modestas, y embebido dentro de la propia aplicación.

## What Changes

Se crea una variante de la misma aplicación para Macs Intel y sistemas anteriores, reutilizando la mayor parte de la arquitectura actual:

* Mismo flujo de UI en SwiftUI (drag & drop, selección de idioma, timestamps, carpeta de destino, cola, progreso, cancelación, logs).
* Mismo pipeline de media basado en AVFoundation y streaming (`AudioStreamProvider`, `MediaAnalyzer`).
* Misma cola secuencial de trabajos, modelo de memoria streaming, agregación de párrafos y escritura Markdown incremental.
* El motor de transcripción cambia de las APIs de Speech de Apple a **Vosk** (Kaldi), usado como biblioteca C estática embebida con una API C mínima propia.

Cambios concretos:

* Deployment target macOS 12.0 y arquitectura `x86_64`.
* Nuevo `VoskService` que sustituye a `SpeechAnalyzerService`.
* `SpeechAssetManager` se sustituye por un gestor de modelos Vosk locales (modelo por idioma, comprobación de presencia y descarga/instalación).
* El formato de audio negociado pasa a ser PCM mono de 16 kHz (requisito de Vosk) con conversión mediante streaming.
* El binario debe poder compilarse x86_64 y funcionar en equipos con 8 GB de RAM.

## Capabilities

### New Capabilities

* `transcription`

  * Motor de transcripción local mediante Vosk (Kaldi) embebido.
  * Selección de idioma.
  * Resultados con información temporal (timestamps por palabra dentro de cada utterance).
  * Cancelación y progreso.
  * Procesamiento por streaming.

* `media-input`

  * Importación de audio y vídeo (mismos formatos que la versión actual).
  * Validación de formatos.
  * Lectura eficiente de audio con AVFoundation.
  * Conversión a PCM mono 16 kHz mediante streaming.

* `output`

  * Generación de Markdown.
  * Timestamps opcionales por párrafo.
  * Escritura incremental.

* `user-interface`

  * Drag & drop.
  * Selector de archivos.
  * Configuración de idioma.
  * Configuración de timestamps.
  * Selección de destino.
  * Cola de trabajos.
  * Progreso y cancelación.

* `model-management`

  * Gestión de modelos Vosk por idioma.
  * Comprobación de modelos instalados.
  * Descarga de modelos cuando sea necesario.
  * Funcionamiento offline cuando el modelo esté disponible.

## Non-Goals

Esta variante no incluirá:

* Ejecutar mediante hacks de distribución la versión actual (macOS 26 / arm64) sobre sistemas anteriores.
* Traducción.
* Detección automática de idioma.
* Identificación o separación de hablantes.
* Generación de subtítulos SRT/VTT.
* Procesamiento paralelo de transcripciones.
* Backend ni APIs externas (salvo la descarga de modelos Vosk).
* Mantener dos motores de transcripción dentro del mismo binario.
* Soporte para Apple Silicon en esta variante (es un producto separado).