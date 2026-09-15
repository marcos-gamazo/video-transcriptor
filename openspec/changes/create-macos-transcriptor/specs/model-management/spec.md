# Model Management

## Purpose

La aplicación debe gestionar correctamente los modelos de Speech requeridos para cada idioma sin incluir ni mantener modelos propios dentro de la aplicación.

## ADDED Requirements

### Requirement: Supported language check

La aplicación SHALL comprobar que el idioma seleccionado está soportado por el motor de transcripción antes de iniciar el trabajo.

#### Scenario: Unsupported language

* **WHEN** el usuario selecciona un idioma no compatible
* **THEN** la aplicación SHALL impedir iniciar la transcripción
* **AND** SHALL mostrar un mensaje comprensible.

### Requirement: Installed model check

La aplicación SHALL comprobar si los recursos necesarios para el idioma seleccionado están instalados.

#### Scenario: Model installed

* **WHEN** el modelo necesario está instalado
* **THEN** la transcripción SHALL poder comenzar sin descargar recursos adicionales.

### Requirement: Model download

Si el idioma es compatible pero el modelo no está instalado, la aplicación SHALL poder solicitar su instalación mediante las APIs de gestión de assets de Apple.

#### Scenario: Internet disponible

* **WHEN** el modelo no está instalado y existe conectividad
* **THEN** la aplicación SHALL poder iniciar la descarga
* **AND** SHALL mostrar su progreso.

### Requirement: Offline operation

La aplicación SHALL funcionar sin conexión a Internet cuando todos los recursos necesarios estén instalados.

#### Scenario: Offline transcription

* **GIVEN** el modelo del idioma seleccionado está instalado
* **AND** el Mac no tiene conexión a Internet
* **WHEN** el usuario inicia una transcripción
* **THEN** la aplicación SHALL poder realizarla localmente.

### Requirement: Offline missing model

La aplicación SHALL detectar cuando el modelo necesario no está instalado y no existe conectividad.

#### Scenario: Missing model without Internet

* **GIVEN** el modelo necesario no está instalado
* **AND** no existe conexión a Internet
* **WHEN** el usuario intenta transcribir
* **THEN** la aplicación SHALL impedir iniciar la transcripción
* **AND** SHALL informar de que debe conectarse a Internet para instalar el recurso necesario.

### Requirement: Apple-managed assets

La aplicación SHALL utilizar los mecanismos proporcionados por Apple para gestionar los assets de Speech.

La aplicación SHALL NOT incluir modelos de Speech propios dentro del bundle.
