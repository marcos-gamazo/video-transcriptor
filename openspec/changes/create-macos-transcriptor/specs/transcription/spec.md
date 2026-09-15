# Transcription

## Purpose

La aplicación debe convertir audio hablado en texto utilizando el motor de transcripción local disponible en macOS, manteniendo la información temporal necesaria para generar posteriormente una salida con o sin timestamps.

## ADDED Requirements

### Requirement: Local transcription

La aplicación SHALL realizar la transcripción utilizando exclusivamente las capacidades locales de Speech proporcionadas por Apple.

#### Scenario: Transcripción normal

* **WHEN** el usuario inicia una transcripción con un idioma compatible y su modelo está disponible
* **THEN** la aplicación SHALL procesar el contenido localmente
* **AND** SHALL producir resultados de texto progresivamente
* **AND** SHALL not enviar el contenido del archivo a servidores externos.

### Requirement: User-selected language

El idioma de transcripción SHALL ser seleccionado explícitamente por el usuario.

#### Scenario: Idioma español

* **WHEN** el usuario selecciona Español
* **THEN** la transcripción SHALL realizarse en español.

#### Scenario: Otro idioma

* **WHEN** el usuario selecciona otro idioma compatible
* **THEN** la transcripción SHALL realizarse en ese idioma.

#### Scenario: No automatic language detection

* **WHEN** comienza una transcripción
* **THEN** la aplicación SHALL NOT intentar detectar automáticamente el idioma del contenido.

### Requirement: Streaming processing

La aplicación SHALL procesar el contenido de audio de forma incremental.

#### Scenario: Archivo largo

* **WHEN** el usuario transcribe un archivo de larga duración
* **THEN** la aplicación SHALL evitar cargar el archivo completo en memoria
* **AND** SHALL evitar mantener la transcripción completa en memoria cuando no sea necesario.

### Requirement: Timestamp information

El sistema SHALL conservar información temporal suficiente para localizar cada bloque de texto en el contenido original.

#### Scenario: Transcripción con timestamps

* **WHEN** el usuario habilita los timestamps
* **THEN** cada párrafo o bloque de texto SHALL incluir el instante temporal correspondiente a su inicio.

#### Scenario: Transcripción sin timestamps

* **WHEN** el usuario deshabilita los timestamps
* **THEN** el texto SHALL exportarse sin información temporal visible.

### Requirement: Cancellation

El usuario SHALL poder cancelar una transcripción en curso.

#### Scenario: Cancelación

* **WHEN** el usuario cancela un trabajo
* **THEN** el procesamiento SHALL detenerse de forma controlada
* **AND** los recursos asociados SHALL liberarse
* **AND** el trabajo SHALL quedar marcado como cancelado.

### Requirement: Sequential processing

La aplicación SHALL procesar inicialmente una única transcripción simultáneamente.

#### Scenario: Cola con múltiples archivos

* **WHEN** existen varios archivos pendientes
* **THEN** solamente un trabajo SHALL ejecutarse simultáneamente
* **AND** los restantes SHALL permanecer en estado pendiente.
