# Model Management

## Purpose

La aplicación debe gestionar los modelos Vosk requeridos para cada idioma sin depender de las APIs de gestión de assets de Apple. Los modelos son directorios locales que la aplicación debe comprobar, instalar y liberar correctamente.

## ADDED Requirements

### Requirement: Model installation check

La aplicación SHALL comprobar si el directorio del modelo Vosk correspondiente al idioma seleccionado existe antes de iniciar una transcripción.

#### Scenario: Model installed

* **WHEN** el modelo para el idioma seleccionado está instalado
* **THEN** la transcripción SHALL poder comenzar sin descargar recursos adicionales.

#### Scenario: Model not installed

* **WHEN** el modelo para el idioma seleccionado no está instalado
* **THEN** la aplicación SHALL intentar descargarlo si existe conectividad
* **AND** SHALL informar al usuario del progreso de la descarga.

### Requirement: Model download

Si el modelo no está instalado, la aplicación SHALL poder descargarlo automáticamente.

#### Scenario: Internet disponible

* **WHEN** el modelo no está instalado y existe conectividad
* **THEN** la aplicación SHALL descargar el modelo desde la fuente oficial
* **AND** SHALL mostrar progreso de descarga al usuario
* **AND** SHALL almacenar el modelo en una ruta local persistente.

#### Scenario: Internet no disponible

* **WHEN** el modelo no está instalado y no existe conectividad
* **THEN** la aplicación SHALL impedir iniciar la transcripción
* **AND** SHALL informar de que debe conectarse a Internet para instalar el modelo necesario.

### Requirement: Offline operation

La aplicación SHALL funcionar sin conexión a Internet cuando el modelo necesario esté instalado.

#### Scenario: Offline transcription

* **GIVEN** el modelo del idioma seleccionado está instalado
* **AND** el Mac no tiene conexión a Internet
* **WHEN** el usuario inicia una transcripción
* **THEN** la aplicación SHALL realizarla completamente de forma local.

### Requirement: No Apple-managed assets

La aplicación SHALL NOT utilizar las APIs de gestión de assets de Apple (`Speech.AssetInventory`, `SpeechTranscriber.installedLocales`).

### Requirement: Model storage

Los modelos Vosk se almacenarán en una ruta local controlada por la aplicación.

#### Scenario: Ruta de almacenamiento

* **WHEN** un modelo se descarga e instala
* **THEN** SHALL almacenarse en una ruta bajo `~/Library/Application Support/Transcriptor/` (o equivalente)
* **AND** SHALL poderse eliminar manualmente por el usuario si se necesita espacio.