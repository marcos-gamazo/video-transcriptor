# Output

## MODIFIED Requirements

### Requirement: Output format

La aplicación SHALL generar un archivo por cada archivo transcrito en el formato elegido por el usuario: Markdown (`.md`, predeterminado) o texto plano (`.txt`).

#### Scenario: Formato Markdown

* **WHEN** el formato seleccionado es Markdown y una transcripción termina correctamente
* **THEN** SHALL existir un archivo `.md` en la carpeta seleccionada por el usuario.

#### Scenario: Formato texto

* **WHEN** el formato seleccionado es texto y una transcripción termina correctamente
* **THEN** SHALL existir un archivo `.txt` en la carpeta seleccionada
* **AND** el contenido SHALL NOT incluir sintaxis Markdown (`#`, `###`).

### Requirement: Output filename

El archivo de salida SHALL utilizar como base el nombre del archivo original y la extensión del formato elegido.

#### Scenario: Archivo reunion.mp4 en texto

* **WHEN** se transcribe `reunion.mp4` con formato texto
* **THEN** el resultado SHALL llamarse `reunion.txt` (o `reunion-2.txt` si ya existe).

### Requirement: Plain text timestamps

#### Scenario: Timestamps activados en texto

* **WHEN** el formato es texto y los timestamps están activados
* **THEN** cada párrafo SHALL comenzar con su timestamp de inicio entre corchetes, p. ej. `[00:02:05] Texto…`.
