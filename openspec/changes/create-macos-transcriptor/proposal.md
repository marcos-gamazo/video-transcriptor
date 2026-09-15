# macOS Transcriptor

## Why

Se necesita una aplicación nativa de macOS que permita a usuarios no técnicos convertir grabaciones de audio y vídeos en transcripciones de texto de forma sencilla, privada y eficiente.

La aplicación debe utilizar las capacidades de transcripción on-device proporcionadas por Apple mediante `SpeechAnalyzer` y `SpeechTranscriber`, evitando servidores, APIs externas o servicios de terceros. El objetivo principal es ofrecer una experiencia de arrastrar y soltar un archivo, seleccionar el idioma y obtener un documento Markdown con la transcripción.

## What Changes

Se crea una nueva aplicación macOS nativa para Apple Silicon con las siguientes capacidades:

* Importación de archivos de audio y vídeo mediante drag & drop.
* Selección de archivos mediante el selector estándar de macOS.
* Validación de los formatos antes de iniciar una transcripción.
* Transcripción local mediante las APIs modernas de Speech de Apple.
* Selección explícita del idioma de transcripción por parte del usuario.
* Español como idioma predeterminado.
* Soporte para otros idiomas compatibles con `SpeechTranscriber`.
* Gestión de los modelos de idioma mediante `AssetInventory`.
* Descarga de modelos cuando sea necesaria y exista conexión a Internet.
* Funcionamiento completamente offline una vez que el modelo necesario esté instalado.
* Procesamiento de audio mediante streaming para minimizar el uso de memoria.
* Procesamiento de audio contenido dentro de vídeos mediante AVFoundation.
* No generar archivos de audio temporales completos cuando no sea necesario.
* Cola de múltiples archivos.
* Procesamiento secuencial de trabajos para limitar consumo de memoria y recursos.
* Indicador de progreso.
* Cancelación de trabajos.
* Selección de carpeta de destino.
* Generación de archivos Markdown.
* Opción para incluir o no timestamps.
* Cuando los timestamps estén habilitados, se agruparán por párrafos/bloques de texto.
* Escritura incremental del Markdown para evitar mantener transcripciones largas completas en memoria.
* Manejo de errores comprensible para usuarios no técnicos.
* Registro técnico de errores accesible desde la aplicación.
* Arquitectura preparada para distribuir la aplicación como DMG.
* Aplicación compilada exclusivamente para Apple Silicon (`arm64`).

## Capabilities

### New Capabilities

* `transcription`

  * Motor de transcripción local mediante las APIs de Speech de Apple.
  * Selección de idioma.
  * Resultados temporales.
  * Cancelación y progreso.

* `media-input`

  * Importación de audio y vídeo.
  * Validación de formatos.
  * Lectura eficiente de audio.
  * Streaming de audio desde vídeo.

* `output`

  * Generación de Markdown.
  * Timestamps opcionales.
  * Agrupación de timestamps por párrafo.
  * Escritura incremental.

* `user-interface`

  * Drag & drop.
  * Selector de archivos.
  * Configuración de idioma.
  * Configuración de timestamps.
  * Selección de destino.
  * Cola de trabajos.
  * Progreso y cancelación.
  * Mensajes de error amigables.

* `model-management`

  * Comprobación de idiomas compatibles.
  * Comprobación de modelos instalados.
  * Descarga de assets cuando sea necesario.
  * Funcionamiento offline cuando el modelo esté disponible.

## Non-Goals

Esta primera versión no incluirá:

* Traducción entre idiomas.
* Detección automática de idioma.
* Identificación o separación de hablantes.
* Generación de subtítulos SRT/VTT.
* Reproductor de vídeo integrado.
* Edición avanzada de transcripciones.
* Sincronización con servicios cloud.
* Backend propio.
* APIs externas de inteligencia artificial.
* Procesamiento paralelo de múltiples transcripciones.
* Soporte para Intel/x86_64.
* Aplicación iOS/iPadOS.
* Modelos de inteligencia artificial propios incluidos dentro del bundle.
