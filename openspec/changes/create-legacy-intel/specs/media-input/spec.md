# Media Input

## Purpose

La aplicación debe aceptar archivos de audio y vídeo habituales y proporcionar al motor de transcripción Vosk un flujo de audio PCM mono de 16 kHz sin consumir memoria innecesariamente.

## ADDED Requirements

### Requirement: Supported media files

La aplicación SHALL aceptar los mismos formatos que la versión Apple Silicon actual:

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

La aplicación SHALL obtener el audio de archivos de vídeo mediante AVFoundation.

#### Scenario: Vídeo con pista de audio

* **WHEN** el usuario añade un vídeo que contiene audio
* **THEN** la aplicación SHALL extraer su pista de audio
* **AND** SHALL convertirla a PCM mono 16 kHz 16-bit antes de pasársela a Vosk
* **AND** SHALL evitar crear un archivo de audio temporal completo.

#### Scenario: Vídeo sin pista de audio

* **WHEN** el usuario añade un vídeo que no contiene audio
* **THEN** la aplicación SHALL informar de que el archivo no contiene audio utilizable.

### Requirement: Audio format preparation

El audio SHALL convertirse a PCM mono 16 kHz 16-bit obligatoriamente, ya que es el formato de entrada requerido por Vosk.

#### Scenario: Audio en formato diferente al objetivo

* **WHEN** el archivo tiene una frecuencia de muestreo o número de canales distinto al objetivo
* **THEN** la conversión SHALL realizarse mediante streaming, procesando buffers pequeños secuencialmente
* **AND** SHALL evitar cargar el audio completo en memoria.

### Requirement: No unnecessary copies

El pipeline multimedia SHALL minimizar las copias innecesarias de buffers cuando sea seguro hacerlo.

#### Scenario: Lectura de samples

* **WHEN** los buffers de audio no necesitan ser modificados
* **THEN** el pipeline SHOULD evitar copias innecesarias de los datos.