# Output

## Purpose

La aplicación debe generar una transcripción legible en Markdown, permitiendo al usuario decidir si necesita información temporal.

## ADDED Requirements

### Requirement: Markdown output

La aplicación SHALL generar un archivo Markdown por cada archivo transcrito.

#### Scenario: Transcripción completada

* **WHEN** una transcripción termina correctamente
* **THEN** SHALL existir un archivo `.md` en la carpeta seleccionada por el usuario.

### Requirement: Output filename

El archivo Markdown SHALL utilizar como base el nombre del archivo original.

#### Scenario: Archivo reunión.mp4

* **WHEN** se transcribe `reunion.mp4`
* **THEN** el resultado SHALL utilizar un nombre equivalente a `reunion.md`.

### Requirement: Clean transcription

La aplicación SHALL permitir generar únicamente el texto transcrito.

#### Scenario: Timestamps desactivados

* **WHEN** timestamps están desactivados
* **THEN** el Markdown SHALL contener el texto agrupado en párrafos legibles
* **AND** SHALL NOT mostrar timestamps.

### Requirement: Paragraph timestamps

La aplicación SHALL permitir generar timestamps asociados a párrafos.

#### Scenario: Timestamps activados

* **WHEN** timestamps están activados
* **THEN** cada párrafo SHALL incluir su timestamp de inicio
* **AND** el timestamp SHALL representar el comienzo temporal del bloque de texto.

### Requirement: Incremental writing

La aplicación SHALL escribir el resultado progresivamente en disco cuando sea posible.

#### Scenario: Archivo de larga duración

* **WHEN** una transcripción produce una gran cantidad de texto
* **THEN** la aplicación SHALL evitar mantener todo el resultado en memoria antes de escribir el archivo.

### Requirement: Output destination

El usuario SHALL poder seleccionar la carpeta donde se guardarán los resultados.

#### Scenario: Carpeta seleccionada

* **WHEN** el usuario selecciona una carpeta de destino
* **THEN** los archivos Markdown SHALL guardarse en dicha carpeta.
