# User Interface

## Purpose

La aplicación debe proporcionar una interfaz gráfica sencilla para usuarios sin conocimientos técnicos.

## ADDED Requirements

### Requirement: Drag and drop

La interfaz SHALL permitir añadir archivos mediante drag & drop.

#### Scenario: Archivo arrastrado

* **WHEN** el usuario arrastra un archivo compatible sobre la zona de importación
* **THEN** el archivo SHALL añadirse a la cola.

### Requirement: File picker

La interfaz SHALL proporcionar un botón para seleccionar archivos mediante el selector estándar de macOS.

#### Scenario: Selección manual

* **WHEN** el usuario pulsa el botón de selección
* **THEN** SHALL aparecer el selector de archivos de macOS.

### Requirement: Language selection

La interfaz SHALL mostrar claramente el idioma seleccionado.

#### Scenario: Idioma predeterminado

* **WHEN** se inicia la aplicación
* **THEN** Español SHALL ser el idioma seleccionado inicialmente.

### Requirement: Timestamp option

La interfaz SHALL mostrar una opción explícita para activar o desactivar timestamps.

#### Scenario: Timestamps desactivados

* **WHEN** el usuario desactiva la opción
* **THEN** el resultado SHALL generarse sin timestamps.

### Requirement: Destination selection

La interfaz SHALL permitir seleccionar la carpeta de destino mediante un selector estándar de macOS.

### Requirement: Job queue

La interfaz SHALL mostrar los trabajos pendientes, en curso, completados, cancelados y fallidos.

#### Scenario: Multiple files

* **WHEN** el usuario añade varios archivos
* **THEN** SHALL aparecer una lista de trabajos
* **AND** SHALL poder identificarse claramente cuál está procesándose.

### Requirement: Progress

La interfaz SHALL mostrar el progreso del trabajo actual cuando sea posible.

#### Scenario: Transcripción en curso

* **WHEN** un trabajo está siendo procesado
* **THEN** la interfaz SHALL mostrar que está activo
* **AND** SHALL proporcionar información de progreso cuando esté disponible.

### Requirement: User-friendly errors

Los errores destinados al usuario SHALL utilizar lenguaje comprensible y no deberán mostrar detalles técnicos innecesarios.

### Requirement: Technical logs

La aplicación SHALL proporcionar acceso a un registro técnico para diagnóstico.

#### Scenario: Error de transcripción

* **WHEN** ocurre un error técnico
* **THEN** el usuario SHALL recibir un mensaje sencillo
* **AND** los detalles técnicos SHALL quedar disponibles en el registro de errores.

### Requirement: Privacy messaging

La interfaz SHALL comunicar que las transcripciones se realizan localmente.

#### Scenario: Normal operation

* **WHEN** el usuario utiliza la aplicación
* **THEN** SHALL poder identificar claramente que los archivos no se envían a servidores externos.
