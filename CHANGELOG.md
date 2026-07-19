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

- Comprobación del estado del contenedor `context-service` y validación de salud de su endpoint REST (`/health`) en `scripts/healthcheck.sh`.
- Publicación del primer evento del dominio en el orquestador (`ResponseGeneratedEvent`) bajo el subject `orchestrator.response.generated` tras resolver y ejecutar con éxito un plan de plugins.
- Nuevo registro de decisión arquitectónica `docs/adr/adr-018-libreria-nova-event-bus.md` formalizando la creación de la librería común de abstracción `nova-event-bus` para desacoplar el código de los microservicios del broker NATS.
- Nueva skill transversal `event-driven-architecture` documentando las directrices, invariantes (leyes) y mejores prácticas para el modelado de eventos tipados en el ecosistema Nova-2.
- Integración de la infraestructura del broker de mensajería NATS (`nats:2.10-alpine`) en `docker-compose.yml` como cimiento para futuros eventos distribuidos inter-container.
- Nuevo registro de decisión arquitectónica `docs/adr/adr-017-integracion-nats.md` formalizando e indexando la integración de NATS y su coexistencia con el actual filesystem-bus.
- Integración de los cuatro nuevos plugins de festivos (`today_holiday`, `next_holiday`, `days_until_next_holiday`, `holidays_of_year`) en el `orchestrator`, consumiendo la API de `calendar-service`.
- Integración del microservicio `calendar-service` para la consulta local y offline de días festivos oficiales y cálculo del próximo festivo.
- Registro de decisión arquitectónica `docs/adr/adr-016-integracion-calendar-service.md` formalizando la integración de `calendar-service` en el ecosistema.
- Nuevo archivo de variables de entorno `config/calendar-service.env` para configurar el nivel de logs y ruta de datos de `calendar-service`.
- Automatización de la creación y verificación de las carpetas de datos de calendario en `scripts/install.sh`, `scripts/uninstall.sh` y `scripts/healthcheck.sh`.

- Nuevo registro de decisión arquitectónica `docs/adr/adr-015-consolidacion-execution-plan.md` formalizando la consolidación del flujo desacoplado y la remoción de compatibilidades legacy.
- Dos nuevos endpoints REST en el orquestador (`POST /api/v1/resolve` y `POST /api/v1/execute-plan`) y soporte para el esquema de plan de ejecución (`ExecutionPlan`).
- Nuevo registro de decisión arquitectónica `docs/adr/adr-014-refactorizacion-orquestador.md` para formalizar la separación de responsabilidades entre el Intent Resolver y el Plugin Executor en el orquestador.
- Integración de cinco nuevos plugins de control de volumen (`volume-up`, `volume-down`, `volume-status`, `mute`, `unmute`) en el orquestador de Nova-2, que consumen la API REST del microservicio `host-service`.
- Integración del microservicio `host-service` como Capa de Abstracción del Host (HAL) para centralizar y proteger el control de volumen físico y silenciado mediante comandos nativos `pactl` bajo `systemd --user`.
- Nuevo archivo de variables de entorno `config/host-service.env` para configurar la IP, puerto y nivel de log de `host-service`.
- Nuevo registro de decisión arquitectónica `docs/adr/adr-013-integracion-host-service.md` definiendo el diseño de la capa HAL y las ventajas de desacoplar el hardware de audio físico de los contenedores Docker.
- Nuevas capacidades aleatorias en el ecosistema de Nova-2: lanzamiento de moneda (`coin`), tiro de dado (`dice`) y número aleatorio (`random-number`) soportadas por el orquestador y documentadas en el catálogo de servicios.
- Soporte nativo a nivel de ecosistema para responder consultas de fecha (`date`) y hora (`time`) mediante los nuevos plugins `TimePlugin` y `DatePlugin` cargados por el orquestador.
- Nuevas capacidades y plugins públicos en el ecosistema Nova-2: `author` (información del autor), `version` (versión del sistema) y `help` (ayuda de uso del asistente) expuestos por el orquestador.
- Actualización de la documentación de `system-service` en `docs/services.md` para reflejar el consumo por los nuevos plugins de identidad, autoría y versión, e incorporar las capacidades `time`, `date` y las 5 nuevas de volumen en los ejemplos del catálogo de servicios.
- Integración del servicio nativo `hid-daemon` para el control mediante botones físicos USB o pedales.
- Nuevo archivo de variables de entorno `config/hid-daemon.env` y plantilla de bindings `config/hid-daemon.yaml.example` para `hid-daemon`.
- Nuevo documento ADR-012 en `docs/adr/adr-012-integracion-hid-daemon.md` describiendo la decisión técnica para capturar eventos de entrada física en el host.
- Integración real del `WeatherPlugin` del `orchestrator` con el `weather-service` local, definiendo la variable de entorno `WEATHER_SERVICE_BASE_URL` inline en `docker-compose.yml`.
- Integración del microservicio `weather-service` en `docker-compose.yml` usando la imagen `danuser2018/weather-service:latest` mapeada al puerto `8006` del host, estableciendo dependencias saludables para el orquestador.
- Nuevo archivo de variables de entorno `config/weather-service.env` para la configuración aislada de coordenadas y parámetros del servicio meteorológico.
- Nuevo ADR-011 documentando la integración del servicio de clima y su red privada interna.
- Comprobación del estado del contenedor `weather-service` y validación de salud de su endpoint REST (`/health`) en `scripts/healthcheck.sh`.

### Cambiado

- Modificado `docker-compose.yml` para incorporar el soporte del broker NATS e inyectar la variable de entorno `NATS_URL` en el servicio `orchestrator`, estableciendo la correspondiente dependencia de arranque ordenado.
- Sincronización de las skills transversales `communication-patterns`, `development-workflow` y `service-responsibilities` para referenciar el nuevo ADR-018 y la skill de arquitectura dirigida por eventos.
- Actualización de la documentación general (`docs/services.md` y `docs/architecture.md`) para incorporar la librería común `nova-event-bus` al catálogo de servicios y la topología de red y componentes.
- Modificado el script de verificación global `scripts/healthcheck.sh` para verificar el Docker health status (`healthy`) de los contenedores que tengan healthcheck, y validar la disponibilidad del puerto de mensajería `4222` de NATS mediante sockets nativos de bash.
- Sincronización de las skills transversales `system-deployment` y `communication-patterns` con la referencia al nuevo ADR-017 de NATS.

- Actualización de la documentación general del sistema (`docs/services.md` y `docs/architecture.md`) para incorporar el servicio NATS en la topología de red privada, catálogo y decisiones de diseño clave.
- Renombradas las clases del orquestador a `ExecutionPlanner` (antes `IntentResolver`) y `PlanExecutor` (antes `PluginExecutor`), y eliminada la clase `Router` junto con su método `route_request`.
- Refactorizado el motor de decisión del orquestador en dos módulos desacoplados: `IntentResolver` (resolución semántica) y `PluginExecutor` (ejecución física de planes).
- Sincronizadas las skills transversales `service-responsibilities` y `api-contracts` con referencias a `adr-014-refactorizacion-orquestador.md`.
- Actualización de los scripts globales de sistema (`install.sh`, `uninstall.sh`, `update.sh` y `healthcheck.sh`) para incorporar el clonado, la configuración, el control de ciclo de vida systemd y el monitoreo de salud del microservicio `host-service`.
- Configuración de puente de red mediante `extra_hosts` con `host.docker.internal:host-gateway` y declaración de la variable de entorno `HOST_SERVICE_BASE_URL` para el contenedor `orchestrator` en `docker-compose.yml`, permitiendo la comunicación saliente hacia `host-service` en el host.
- Actualización de la documentación del sistema (`docs/services.md`, `docs/installation.md`, `docs/architecture.md`, `docs/troubleshooting.md`) y de las skills de agente (`system-deployment`, `audio-subsystem`, `service-responsibilities`) para incluir el nuevo componente de hardware `host-service` y las leyes de uso de su API REST.
- Actualización de la documentación del sistema (`docs/services.md`, `docs/installation.md`, `docs/architecture.md`) para incorporar el servicio `hid-daemon` como componente opcional del plano de hardware.
- Sincronización de las skills transversales `feature-refinement`, `service-responsibilities` y `system-deployment` con referencias al nuevo ADR-012 y las directrices de hardware HID.
- Adaptación de los scripts globales `install.sh`, `uninstall.sh`, `update.sh` y `healthcheck.sh` para soportar la instalación, mantenimiento, actualización y monitoreo del servicio `hid-daemon`.
- Actualización de la documentación general (`docs/services.md` y `docs/architecture.md`) para agregar `weather-service` al catálogo de servicios y descripción de componentes.
- Actualización de la skill `system-deployment` para referenciar el nuevo `ADR-011`.

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

- Corrección del diagrama de red interna de Docker en `docs/architecture.md` (sección "Red Interna de Docker") para reflejar la ruta de salida `orchestrator → host.docker.internal:8007 → host-service (HAL)`, haciéndolo consistente con el diagrama equivalente ya correcto en `docs/services.md`.
- Corrección del desfase horario en todos los contenedores Docker del ecosistema Nova-2 mediante el montaje en modo lectura de los ficheros `/etc/localtime` y `/etc/timezone` del host en `docker-compose.yml`, sincronizando el entorno de ejecución (incluyendo los plugins de fecha y hora del `orchestrator`) con la zona horaria del sistema host (Europe/Madrid).
- Se corrigen pequeños errores y discrepancias encontrados en algunas de las skills.
- Corrección de discrepancias en la documentación (`docs/services.md`, `docs/architecture.md`, `docs/installation.md`, `README.md`) alineando la cantidad de servicios a 9, y removiendo la dependencia directa e incorrecta del orchestrator hacia `identity-service`.
- Reubicación de la variable `USER_EMAIL` en `config/assistant.env` bajo la sección del `identity-service`.
- Eliminación de la carpeta obsoleta `systemd/` que contenía plantillas inactivas y actualización de la documentación de instalación.
- Corrección de discrepancias en el documento de decisión arquitectónica [ADR-006](docs/adr/adr-006.md), clarificando la distinción entre las rutas de directorios de correo compartidas en el host (`data/mail/...`) y los contenedores (`/shared/mail/...`).

### Eliminado

- Eliminado definitivamente el endpoint legado `POST /api/v1/execute` en el orquestador y toda su documentación asociada.
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
