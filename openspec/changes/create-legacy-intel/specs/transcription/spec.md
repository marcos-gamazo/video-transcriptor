# Transcription

## Purpose

La aplicación debe convertir audio hablado en texto utilizando el motor de transcripción local Vosk, manteniendo la información temporal necesaria para generar salida con o sin timestamps, y procesando el contenido de forma incremental.

## ADDED Requirements

### Requirement: Local transcription

La aplicación SHALL realizar la transcripción utilizando exclusivamente el motor local Vosk embebido, sin enviar el contenido del archivo a servidores externos.

#### Scenario: Transcripción normal

* **WHEN** el usuario inicia una transcripción con un idioma soportado y su modelo está disponible
* **THEN** la aplicación SHALL procesar el contenido localmente en el dispositivo
* **AND** SHALL producir resultados de texto incrementalmente
* **AND** SHALL NOT enviar audio ni texto a ningún servicio remoto.

### Requirement: Supported languages

La aplicación SHALL admitir como mínimo los idiomas para los que exista un modelo Vosk disponible y haya sido instalado por el usuario.

#### Scenario: Idioma español

* **WHEN** el usuario selecciona Español
* **THEN** la transcripción SHALL realizarse en español usando el modelo Vosk correspondiente.

#### Scenario: Idioma no disponible

* **WHEN** el usuario selecciona un idioma sin modelo Vosk instalado
* **THEN** la aplicación SHALL informar de que no existe un modelo disponible para ese idioma.

#### Scenario: No automatic language detection

* **WHEN** comienza una transcripción
* **THEN** la aplicación SHALL NOT intentar detectar automáticamente el idioma del contenido.

### Requirement: User-selected language

El idioma de transcripción SHALL ser seleccionado explícitamente por el usuario. Español SHALL ser el idioma predeterminado.

### Requirement: Streaming processing

La aplicación SHALL procesar el contenido de audio de forma incremental sin cargar el archivo completo en memoria.

#### Scenario: Archivo largo

* **WHEN** el usuario transcribe un archivo de larga duración
* **THEN** la aplicación SHALL alimentar buffers de audio pequeños a Vosk de forma secuencial
* **AND** SHALL liberar los buffers procesados
* **AND** SHALL evitar mantener la transcripción completa en memoria.

### Requirement: Timestamp information

El sistema SHALL conservar información temporal suficiente para localizar cada bloque de texto en el contenido original.

#### Scenario: Transcripción con timestamps

* **WHEN** el usuario habilita los timestamps
* **THEN** cada párrafo SHALL incluir el instante temporal correspondiente a su inicio.

#### Scenario: Transcripción sin timestamps

* **WHEN** el usuario deshabilita los timestamps
* **THEN** el texto SHALL exportarse sin información temporal visible.

### Requirement: Cancellation

El usuario SHALL poder cancelar una transcripción en curso.

#### Scenario: Cancelación

* **WHEN** el usuario cancela un trabajo
* **THEN** la lectura de audio SHALL detenerse
* **AND** el modelo Vosk SHALL liberar sus recursos
* **AND** el trabajo SHALL quedar marcado como cancelado.

### Requirement: Sequential processing

La aplicación SHALL procesar inicialmente una única transcripción simultáneamente.

#### Scenario: Cola con múltiples archivos

* **WHEN** existen varios archivos pendientes
* **THEN** solamente un trabajo SHALL ejecutarse simultáneamente
* **AND** los restantes SHALL permanecer en estado pendiente.

### Requirement: Audio format

El motor Vosk requiere PCM mono de 16 kHz con 16 bits por muestra.

#### Scenario: Formato de entrada diferente

* **WHEN** el audio original tiene una frecuencia de muestreo o número de canales diferente
* **THEN** la aplicación SHALL convertir el audio a PCM mono 16 kHz 16-bit mediante streaming
* **AND** SHALL evitar generar un archivo de audio temporal completo.