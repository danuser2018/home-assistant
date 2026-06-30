# Registro de cambios

Todos los cambios notables de este proyecto se documentan en este fichero.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/)
y este proyecto adhiere a [Versionado Semántico](https://semver.org/lang/es/).

## Guía de uso

Cada versión se documenta bajo su número de versión y fecha de publicación.
Los cambios se agrupan en las siguientes categorías:

- **Añadido** — nuevas funcionalidades.
- **Cambiado** — cambios en funcionalidades existentes.
- **Obsoleto** — funcionalidades que serán eliminadas en versiones futuras.
- **Eliminado** — funcionalidades eliminadas en esta versión.
- **Corregido** — corrección de errores.
- **Seguridad** — correcciones de vulnerabilidades.

---

## [Sin publicar]

### Añadido

- Configuración y documentación para el servicio `tts-capability` en `config/assistant.env` con las nuevas variables de entorno `TTS_MODEL_NAME` y `TTS_MODEL_DIR`.
- Nueva skill transversal de agente `feature-refinement` para guiar el refinamiento estructurado y técnico de nuevas características.
- Nuevo workflow de agente `DoR_review` en `.agent/workflows/` para auditar el DoR de documentos de refinamiento de features.
- Nuevo workflow de agente `DoD_review` en `.agent/workflows/` para realizar la revisión de Definition of Done (DoD) de features implementadas.
- Se añade adr-008 para explicar que se descarta la idea del mpv daemon para speaker watchdog.
- Integración del microservicio `identity-service` en `docker-compose.yml` usando la imagen `danuser2018/identity-service:latest` mapeada al puerto `8005` del host.
- Configuración de la variable `USER_NAME=David` en `config/assistant.env` para la parametrización de la identidad.
- Monitoreo automático del contenedor `identity-service` y validación de salud de su endpoint REST (`/health`) en `scripts/healthcheck.sh`.
- Documentación de la decisión táctica sobre la dirección de correo destino en el MVP mediante el nuevo [ADR-007](docs/adr/adr-007.md).


- Se añade la carpeta `docs/adr` con la justificación de las decisiones arquitectónicas.
- Se añade la carpeta `.agent/skills` con todas las skills que la IA necesita para implementar Nova.
- Añadido documento de `skills_proposals.md` donde se detallan la propuesta de skills para el sistema.
- Configuración para el plugin `capabilities` en el `orchestrator`, incluyendo las variables de entorno `USER_EMAIL` y `MAIL_PENDING_DIR` en `config/assistant.env`.
- Montaje del volumen `./data/mail:/shared/mail` para el servicio `orchestrator` en `docker-compose.yml` para posibilitar el envío asíncrono de correos mediante `mail-watchdog`.
- Documentación detallada del plugin `capabilities` y sus variables asociadas en `docs/services.md` y `docs/architecture.md`.
- Integración del servicio `mail-watchdog` en `docker-compose.yml` y configuración de variables SMTP en `config/assistant.env`.
- Creación automática de directorios de correo en `scripts/install.sh` y comprobaciones de estado y conteo de emails en `scripts/healthcheck.sh`.
- Documentación completa para el nuevo microservicio `mail-watchdog` en `README.md` y en los documentos de arquitectura, catálogo de servicios, instalación y solución de problemas.
- Nuevo volumen para cachear el modelo whisper (stt) y no descargarlo cada vez.
- Inclusión de la carpeta `data` en .gitignore.
- Nueva imagen de cover para `README.md`
- Inclusión del microservicio `system-service` para exponer información de identidad del sistema (Nova).
- Documentación completa para el nuevo microservicio Python dockerizado `system-service` en `README.md` y en los documentos de arquitectura, catálogo de servicios, instalación y solución de problemas.
- Fichero `CONTRIBUTING.md` con el flujo de trabajo Trunk Based Development,
  convenciones de commits, guía de Pull Requests y buenas prácticas para
  desarrollo asistido con IA.
- Fichero `CHANGELOG.md` con el formato Keep a Changelog v1.1.0 en castellano.
- Scaffolding del servicio (carpetas, archivos que deben existir vacíos).
- Documentos rellenos (arquitectura, instalación, servicios, troubleshooting).
- Implementación del servicio (docker-compose, services y scripts de instalación y mantenimiento).

### Cambiado

- Edición de la skill de api-contract para añadir la referencia al ADR del orchestrator `adr-001-adicion-timestamp-userrequest.md`.
- Actualización de `docs/services.md`, `docs/installation.md` y `docs/architecture.md` para integrar e ilustrar la inclusión de `identity-service` en el ecosistema global de Nova.
- Unificación del nombre de la red Docker interna a `assistant-network` en `docker-compose.yml` y `docs/services.md` para corregir la inconsistencia con el resto de la documentación técnica.
- Clarificación del mapeo de puertos (internos vs host) y actualización de endpoints a `/v1` en `docs/services.md` y `docs/architecture.md`.
- Ajuste en las skills para que tengan en cuenta los ADRs
- Correcciones al formato del archivo `docs/services.md`
- Correcciones al desinstalador
- Correcciones al instalador
- Se actualiza el endpoint de healthcheck del orchestrator
- Se corrige el script de actualización (update.sh). El nombre del entorno virtual estaba mal.
- Se cambian los datos de Nova. Versión básica, autor.

### Corregido

- Corrección de discrepancias en la documentación (`docs/services.md`, `docs/architecture.md`, `docs/installation.md`, `README.md`) alineando la cantidad de servicios a 9, y removiendo la dependencia directa e incorrecta del orchestrator hacia `identity-service`.
- Reubicación de la variable `USER_EMAIL` en `config/assistant.env` bajo la sección del `identity-service`.
- Eliminación de la carpeta obsoleta `systemd/` que contenía plantillas inactivas y actualización de la documentación de instalación.
- Corrección de discrepancias en el documento de decisión arquitectónica [ADR-006](docs/adr/adr-006.md), clarificando la distinción entre las rutas de directorios de correo compartidas en el host (`data/mail/...`) y los contenedores (`/shared/mail/...`).

---

<!-- Plantilla para nuevas versiones:

## [X.Y.Z] - AAAA-MM-DD

### Añadido
-

### Cambiado
-

### Obsoleto
-

### Eliminado
-

### Corregido
-

### Seguridad
-

-->

[Sin publicar]: https://github.com/danuser2018/home-assistant/compare/HEAD...HEAD
