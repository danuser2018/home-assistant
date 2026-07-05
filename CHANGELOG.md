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

- Integración del servicio nativo `hid-daemon` para el control mediante botones físicos USB o pedales.
- Nuevo archivo de variables de entorno `config/hid-daemon.env` y plantilla de bindings `config/hid-daemon.yaml.example` para `hid-daemon`.
- Nuevo documento ADR-012 en `docs/adr/adr-012-integracion-hid-daemon.md` describiendo la decisión técnica para capturar eventos de entrada física en el host.
- Integración real del `WeatherPlugin` del `orchestrator` con el `weather-service` local, definiendo la variable de entorno `WEATHER_SERVICE_BASE_URL` inline en `docker-compose.yml`.
- Integración del microservicio `weather-service` en `docker-compose.yml` usando la imagen `danuser2018/weather-service:latest` mapeada al puerto `8006` del host, estableciendo dependencias saludables para el orquestador.
- Nuevo archivo de variables de entorno `config/weather-service.env` para la configuración aislada de coordenadas y parámetros del servicio meteorológico.
- Nuevo ADR-011 documentando la integración del servicio de clima y su red privada interna.
- Comprobación del estado del contenedor `weather-service` y validación de salud de su endpoint REST (`/health`) en `scripts/healthcheck.sh`.

- Nuevas variables de entorno del motor de similitud semántica en `config/orchestrator.env`: `SIMILARITY_THRESHOLD`, `TIE_BREAKER_THRESHOLD`, `WEIGHT_RATIO`, `WEIGHT_PARTIAL_RATIO`, `WEIGHT_TOKEN_SORT_RATIO` y `WEIGHT_TOKEN_SET_RATIO`, con sus valores por defecto documentados, como soporte al nuevo motor `PluginMatcher` basado en `rapidfuzz`.
- Separación de la configuración en archivos `.env` independientes por servicio: se crean `config/stt-capability.env`, `config/tts-capability.env`, `config/system-service.env`, `config/orchestrator.env`, `config/mail-watchdog.env` y `config/identity-service.env`, cada uno con exclusivamente las variables necesarias para su dominio.
- Nuevo ADR-010 documentando el patrón de aislamiento de variables de entorno por servicio como estándar del ecosistema Nova-2.
- Se añade descripción del ciclo de desarrollo en Nova-2.
- Se añaden indicaciones para la ejecución de workflows.
- Configuración y documentación para el servicio `tts-capability` en `config/assistant.env` con las nuevas variables de entorno `TTS_MODEL_NAME`, `TTS_MODEL_DIR` y `TTS_MODEL_URL`.
- Comprobación y descarga automática del modelo TTS configurado en `config/assistant.env` dentro del script `scripts/update.sh` para permitir cambios de voz sin necesidad de reinstalación.
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
- Configuración para el plugin `capabilities` en el `orchestrator`, incluyendo la variable de entorno `MAIL_PENDING_DIR` en `config/assistant.env`.
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

- Actualización de la documentación del sistema (`docs/services.md`, `docs/installation.md`, `docs/architecture.md`) para incorporar el servicio `hid-daemon` como componente opcional del plano de hardware.
- Sincronización de las skills transversales `feature-refinement`, `service-responsibilities` y `system-deployment` con referencias al nuevo ADR-012 y las directrices de hardware HID.
- Adaptación de los scripts globales `install.sh`, `uninstall.sh`, `update.sh` y `healthcheck.sh` para soportar la instalación, mantenimiento, actualización y monitoreo del servicio `hid-daemon`.
- Actualización de la documentación general (`docs/services.md` y `docs/architecture.md`) para agregar `weather-service` al catálogo de servicios y descripción de componentes.
- Actualización de la skill `system-deployment` para referenciar the nuevo `ADR-011`.

- Actualización de la documentación global (`docs/architecture.md` y `docs/troubleshooting.md`) y del skill de dominio `plugin-domain` (`.agent/skills/domains/plugin-domain/SKILL.md`) en `home-assistant` para reflejar la eliminación de la lógica de coincidencia por keywords/regex legada en el `orchestrator`, consolidando el enrutamiento por similitud semántica determinista (RapidFuzz) y prioridad.
- Migración del archivo de configuración unificado `config/assistant.env` a archivos `.env` específicos por servicio: se actualiza `docker-compose.yml` para que cada servicio Docker referencie su propio archivo de configuración mediante la directiva `env_file`, y las variables de infraestructura interna (URLs entre servicios, rutas de directorios compartidos) se mantienen declaradas inline bajo `environment:` en `docker-compose.yml`.
- Actualización de `scripts/install.sh` y `scripts/update.sh` para leer las variables del modelo de voz TTS (`TTS_MODEL_NAME`, `TTS_MODEL_URL`) desde `config/tts-capability.env` en lugar del antiguo `config/assistant.env`.
- Actualización de `docs/installation.md` para reflejar la nueva estructura de archivos de configuración individuales por servicio, incluyendo el árbol de directorios completo.
- Actualización de `docs/services.md` para documentar las variables de cada servicio referenciando su archivo `.env` específico.
- Actualización de `docs/troubleshooting.md` para orientar al usuario al archivo `.env` correcto según el tipo de problema (SMTP → `mail-watchdog.env`, modelo TTS → `tts-capability.env`, etc.).
- Se completa la skill de `feature-refinement`.
- Se añade más información al flujo de ejecución de los workflows.
- Centralización del destinatario de correo en `identity-service` (ADR-009): `mail-watchdog` resuelve ahora dinámicamente la dirección del destinatario consultando `GET /v1/identity/email` en `identity-service`, eliminando la dependencia del `orchestrator` sobre datos de identidad del usuario.
- Variable de entorno `IDENTITY_SERVICE_BASE_URL` definida directamente en el bloque `environment` del servicio `mail-watchdog` en `docker-compose.yml` (URL interna entre servicios, no configurable por el usuario). Nota: el contrato del refinamiento `environment_vars_separation_refinement.md` indicaba esta variable dentro de `config/mail-watchdog.env`; la implementación la movió al bloque inline por coherencia con el patrón arquitectónico establecido para URLs internas de servicios.
- Se añade `depends_on: identity-service: condition: service_healthy` al servicio `mail-watchdog` en `docker-compose.yml` para garantizar el arranque ordenado.
- Actualizado el contrato de entrada de `mail-watchdog` en `docs/services.md` y `docs/architecture.md`: el campo `to` ya no forma parte del payload JSON; se documenta la nueva relación `mail-watchdog → identity-service:8000`.
- ADR-009 promovido de estado `Propuesto` a `Aceptado` tras la integración de la implementación.
- ADR-007 marcado como superado con referencia a ADR-009.
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

- Se corrigen pequeños errores y discrepancias encontrados en algunas de las skills.
- Corrección de discrepancias en la documentación (`docs/services.md`, `docs/architecture.md`, `docs/installation.md`, `README.md`) alineando la cantidad de servicios a 9, y removiendo la dependencia directa e incorrecta del orchestrator hacia `identity-service`.
- Reubicación de la variable `USER_EMAIL` en `config/assistant.env` bajo la sección del `identity-service`.
- Eliminación de la carpeta obsoleta `systemd/` que contenía plantillas inactivas y actualización de la documentación de instalación.
- Corrección de discrepancias en el documento de decisión arquitectónica [ADR-006](docs/adr/adr-006.md), clarificando la distinción entre las rutas de directorios de correo compartidas en el host (`data/mail/...`) y los contenedores (`/shared/mail/...`).

### Eliminado

- Eliminación total de la lógica de coincidencia y propiedades heredadas (`keywords`, `regex_patterns`, `exclusive_regex`) en todos los plugins del sistema `orchestrator` y en la clase base `Plugin`.
- Archivo `config/assistant.env` eliminado definitivamente del repositorio. Su contenido ha sido distribuido en los 6 archivos `.env` individuales por servicio.
- Variable de entorno `USER_EMAIL` eliminada de la sección del `orchestrator` en `config/assistant.env`. El orchestrator ya no tiene responsabilidad sobre la identidad del destinatario de correo.

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
