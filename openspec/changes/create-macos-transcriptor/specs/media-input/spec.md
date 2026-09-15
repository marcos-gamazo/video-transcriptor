# Media Input

## Purpose

La aplicación debe aceptar archivos de audio y vídeo habituales y proporcionar al motor de transcripción un flujo de audio adecuado sin consumir memoria innecesariamente.

## ADDED Requirements

### Requirement: Supported media files

La aplicación SHALL aceptar los formatos de audio y vídeo soportados por el pipeline multimedia de macOS seleccionado para la versión inicial.

La implementación inicial SHALL priorizar:

* MP3
* M4A
* WAV
* MP4
* MOV
* M4V

#### Scenario: Archivo compatible

* **WHEN** el usuario añade un archivo compatible
* **THEN** la aplicación SHALL aceptarlo y mostrarlo como trabajo pendiente.

#### Scenario: Archivo incompatible

* **WHEN** el usuario añade un archivo no compatible
* **THEN** la aplicación SHALL rechazarlo
* **AND** SHALL mostrar un mensaje explicando que el formato no está soportado.

### Requirement: Video audio extraction

La aplicación SHALL obtener el audio de archivos de vídeo mediante el pipeline multimedia de macOS.

#### Scenario: Vídeo con pista de audio

* **WHEN** el usuario añade un vídeo que contiene audio
* **THEN** la aplicación SHALL utilizar su pista de audio para la transcripción
* **AND** SHALL evitar crear un archivo de audio temporal completo salvo que sea técnicamente imprescindible.

### Requirement: Audio format preparation

El audio SHALL prepararse en un formato compatible con el motor de Speech antes de comenzar el análisis.

#### Scenario: Formato de entrada diferente

* **WHEN** el formato natural del archivo no coincide con el formato óptimo requerido por Speech
* **THEN** la aplicación SHALL realizar la conversión necesaria mediante streaming
* **AND** SHALL evitar cargar el audio completo en memoria.

### Requirement: No unnecessary copies

El pipeline multimedia SHALL minimizar las copias innecesarias de buffers cuando sea seguro hacerlo.

#### Scenario: Lectura de samples

* **WHEN** los buffers de audio no necesitan ser modificados
* **THEN** el pipeline SHOULD evitar copias innecesarias de los datos.
