# Arquitectura del Sistema Home Assistant

El ecosistema Home Assistant es un asistente de voz **100% local, modular y enfocado a la privacidad**, diseñado para sistemas operativos Linux.

Su arquitectura se basa en el principio de **separación de responsabilidades** (Single Responsibility Principle) y en un diseño híbrido: combina **servicios nativos en el host** para el acceso directo y sin fricciones al hardware de audio, y **contenedores Docker** para la lógica de inteligencia y coordinación, facilitando su actualización y despliegue de forma reproducible.

---

## Topología General

El sistema se divide en dos planos de ejecución:

| Plano | Tipo | Servicios |
|---|---|---|
| **Hardware** | Systemd User Services (host) | `mic-daemon`, `speaker-watchdog`, `hid-daemon`, `host-service` |
| **Procesamiento** | Contenedores Docker | `interaction-manager`, `stt-capability`, `orchestrator`, `tts-capability`, `system-service`, `mail-watchdog`, `identity-service`, `weather-service`, `calendar-service`, `nats` |

### ¿Por qué esta separación?

Los servicios de audio y hardware (`mic-daemon`, `speaker-watchdog`, `hid-daemon` y `host-service`) necesitan interactuar directamente con el kernel o el servidor de sonido del usuario (PulseAudio o PipeWire), que opera dentro de la sesión activa de usuario de Linux. Ejecutarlos dentro de Docker añadiría una complejidad innecesaria con permisos, variables de entorno y sockets de audio. Por ello, se instalan como **servicios de usuario de systemd** (`systemd --user`).

El resto de servicios, al no necesitar acceso hardware o utilizar la capa de abstracción HAL provista por `host-service`, se ejecutan perfectamente en contenedores Docker, garantizando aislamiento, portabilidad y actualizaciones sin esfuerzo.

---

## Integración: El Filesystem como Bus de Mensajes

La comunicación entre los componentes también aprovecha el sistema de ficheros. Además de los archivos de audio en `data/`, se añade el subdirectorio `data/mail/` que funciona como bandeja de salida asíncrona para el servicio `mail-watchdog`. Esta bandeja de salida es escrita por el servicio `orchestrator` (cuando ejecuta el plugin `capabilities`) y consumida por `mail-watchdog`:

```text
home-assistant/data/
├── input/       ← mic-daemon deposita aquí los .wav grabados
├── processing/  ← interaction-manager mueve aquí los archivos mientras los procesa
├── output/      ← interaction-manager deposita aquí las respuestas de audio
├── error/       ← interaction-manager mueve aquí los archivos fallidos
└── mail/        ← Directorio de trabajo de mail-watchdog
    ├── pending/    ← Archivos JSON de correos pendientes de envío
    ├── processing/ ← Archivos JSON en proceso de envío
    └── failed/     ← Archivos JSON que fallaron tras todos los reintentos
```

Esta arquitectura tiene ventajas clave:
- **Observabilidad inmediata:** Con un simple `ls data/processing/` puedes ver si hay una petición en vuelo.
- **Depuración trivial:** Los errores se preservan en `data/error/` para su análisis posterior.
- **Desacoplamiento total:** Los servicios del host y los de Docker no se conocen entre sí; sólo conocen el directorio compartido.

---

## Integración: El Bus de Eventos (Event Bus)

Para el plano de procesamiento en Docker, se introduce un bus de eventos asíncrono basado en **NATS** y encapsulado por la librería común **nova-event-bus** (ver [ADR-018](adr/adr-018-libreria-nova-event-bus.md)).

Este bus permite un desacoplamiento reactivo de los servicios mediante la publicación y consumo de clases de eventos fuertemente tipadas que heredan de `Event` (ej. `ResponseGeneratedEvent`).

---

## Diagrama de Secuencia (Flujo End-to-End)

```text
Usuario          mic-daemon        data/input   interaction-manager   stt-capability   orchestrator   system-service   identity-service   tts-capability   data/output   speaker-watchdog
   |                  |                 |                |                    |               |                |                 |              |               |                |
   |-- Presiona ----->|                 |                |                    |               |                |                 |              |               |                |
   |   hotkey y habla |                 |                |                    |               |                |                 |              |               |                |
   |                  |--- graba y ---->|                |                    |               |                |                 |              |               |                |
   |                  |    guarda .wav  |                |                    |               |                |                 |              |               |                |
   |                  |                 |-- inotify ---->|                    |               |                |                 |              |               |                |
   |                  |                 |   evento       |-- mueve a -------->|               |                |                 |              |               |                |
   |                  |                 |                |   /processing      |               |                |                 |              |               |                |
   |                  |                 |                |-- POST ----------->|               |                |                 |              |               |                |
   |                  |                 |                |   /v1/transcriptions|              |                |                 |              |               |                |
   |                  |                 |                |<-- {"text": "..."} |               |                |                 |              |               |                |
   |                  |                 |                |-- POST ------------|-------------->|                |                 |              |               |                |
   |                  |                 |                |   /api/v1/resolve  |               |                |                 |              |               |                |
   |                  |                 |                |<-- {"steps": [...]} |              |                |                 |              |               |                |
   |                  |                 |                |-- POST ------------|-------------->|                |                 |              |               |                |
   |                  |                 |                |   /execute-plan    |               |-- GET -------->|                 |              |               |                |
   |                  |                 |                |                    |               |   /v1/system/info|               |              |               |                |
   |                  |                 |                |                    |               |<-- JSON -------|                 |              |               |                |
   |                  |                 |                |<------------------ |{"speech":"..."}|                |                 |              |               |                |
   |                  |                 |                |-- POST ------------|---------------|----------------|-----------------|------------->|               |                |
   |                  |                 |                |   /v1/synthesize   |               |                |                 |              |               |                |
   |                  |                 |                |<--  audio/wav  ----|---------------|----------------|-----------------|------------- |               |                |
   |                  |                 |                |-- guarda ----------|---------------|----------------|-----------------|--------------|-------------->|                |
   |                  |                 |                |   respuesta .wav   |               |                |                 |              |               |                |
   |                  |                 |                |                    |               |                |                 |              |               |-- inotify ----->|
   |                  |                 |                |                    |               |                |                 |              |               |   evento       |
   |<-- Escucha audio |                 |                |                    |               |                |                 |              |               |                |-- mpv reproduce
   |   del altavoz    |                 |                |                    |               |                |                 |              |               |                |   y elimina .wav
```

---

## Descripción de Componentes

### Servicios del Host (Systemd)

#### `mic-daemon`
- **Repositorio:** `danuser2018/mic-daemon`
- **Lenguaje:** Python 3.10+
- **Rol:** Graba audio del micrófono al detectar la presencia de un archivo de estado (`recording.flag`) que es creado/eliminado por scripts de hotkey.
- **Salida:** Archivos `.wav` con nombre en formato timestamp (`YYYY-MM-DD_HH-MM-SS.wav`) depositados en `data/input/`.
- **Principio clave:** El daemon no mantiene estado en memoria; consulta el filesystem para decidir qué hacer. Extremadamente ligero.

#### `speaker-watchdog`
- **Repositorio:** `danuser2018/speaker-watchdog`
- **Lenguaje:** Python 3.8+
- **Rol:** Monitoriza `data/output/` mediante `inotify`. Al detectar un nuevo `.wav`, lo encola en una cola FIFO thread-safe y lo reproduce secuencialmente mediante `mpv`. Elimina el archivo tras la reproducción.
- **Principio clave:** Patrón Productor-Consumidor para evitar solapamiento de audios.

#### `hid-daemon`
- **Repositorio:** `danuser2018/hid-daemon`
- **Lenguaje:** Python 3.10+
- **Rol:** Escucha eventos de entrada de bajo nivel desde dispositivos HID físicos mediante la biblioteca `evdev` y ejecuta comandos del sistema configurados (ej. `mic-toggle.sh`) en un subproceso de forma aislada.
- **Principio clave:** Integración robusta de hardware físico desacoplada de gestores gráficos.

#### `host-service`
- **Repositorio:** `danuser2018/host-service`
- **Lenguaje:** Python 3.10+
- **Rol:** Actúa como la Capa de Abstracción del Host (HAL). Expone una API REST local en el puerto `8007` para controlar de manera segura recursos físicos del host como el volumen del sistema y su estado de silencio mediante la utilidad `pactl`.
- **Principio clave:** Capa intermedia segura que aísla las herramientas y dependencias del sistema operativo del plano de procesamiento en Docker.

### Servicios Docker

#### `interaction-manager`
- **Imagen:** `danuser2018/interaction-manager:latest`
- **Puerto:** ninguno expuesto al host
- **Rol:** Coordinador del flujo completo. Implementa una máquina de estados basada en directorios: detecta archivos en `input/`, los mueve a `processing/` y orquesta las llamadas síncronas a STT → Orchestrator → TTS. El resultado se guarda en `output/` o, en caso de error, en `error/`.
- **Comunicación:** Volumen Docker compartido para los directorios `data/`, HTTP/REST para los servicios internos.

#### `stt-capability`
- **Imagen:** `danuser2018/stt-capability:latest`
- **Puerto interno:** `8000` (expuesto en puerto host `8001`)
- **Rol:** Servicio stateless de Speech-to-Text basado en **Faster-Whisper**. Carga el modelo de IA una sola vez al arrancar para minimizar la latencia en peticiones subsiguientes.
- **API:** `POST /v1/transcriptions` (multipart/form-data con el campo `audio`)

#### `orchestrator`
- **Imagen:** `danuser2018/orchestrator:latest`
- **Puerto interno:** `8000` (expuesto en puerto host `8002`)
- **Rol:** Motor de intenciones determinista. Se compone de dos módulos desacoplados: `ExecutionPlanner` (procesamiento del lenguaje natural, cálculo de similitud mediante RapidFuzz y generación del plan `ExecutionPlan`) y `PlanExecutor` (validación y ejecución secuencial del plan de pasos usando los plugins).
- **Integraciones externas:** Además de conectarse a `system-service` para consultar identidad y capacidades, monta el volumen compartido `data/mail` para interactuar de forma asíncrona con `mail-watchdog` escribiendo peticiones de correo cuando se ejecuta el plugin `capabilities`.
- **API:**
  - `POST /api/v1/resolve` (JSON `{"text": "..."}`)
  - `POST /api/v1/execute-plan` (JSON `ExecutionPlan`)
- **Extensibilidad:** Se pueden añadir nuevos plugins sin tocar el núcleo del orquestador.

#### `system-service`
- **Imagen:** `danuser2018/system-service:latest`
- **Puerto interno:** `8000` (expuesto en puerto host `8004`)
- **Rol:** Servicio de información de identidad. Expone datos estáticos sobre el asistente Nova. Consumido exclusivamente por el `orchestrator` mediante el `Identity Plugin`.
- **API:** `GET /v1/system/info` (devuelve información del sistema en formato JSON), `POST /v1/system/capabilities` (registrar capacidades), `GET /v1/system/capabilities` (listar capacidades) y `GET /health` (estado de salud).

#### `tts-capability`
- **Imagen:** `danuser2018/tts-capability:latest`
- **Puerto interno:** `8000` (expuesto en puerto host `8003`)
- **Rol:** Servicio stateless de Text-to-Speech basado en **Piper TTS**. Recibe texto y devuelve audio binario PCM 16-bit mono a 16000 Hz empaquetado en formato WAV.
- **API:** `POST /v1/synthesize` (JSON `{"msg": "..."}`)

#### `mail-watchdog`
- **Imagen:** `danuser2018/mail-watchdog:latest`
- **Puerto:** Ninguno expuesto al host.
- **Rol:** Servicio de envío asíncrono de correos electrónicos vía SMTP. Observa la carpeta `/shared/mail/pending` y envía los mensajes estructurados en formato JSON. En cada ciclo de procesamiento, resuelve dinámicamente la dirección de correo del destinatario mediante una llamada REST síncrona a `identity-service` (`GET /v1/identity/email`).
- **Entrada:** Archivos JSON que representan los correos en `data/mail/pending/`.
- **Salida:** Envío de correo a través del servidor SMTP configurado y eliminación del archivo JSON (o traslado a `failed/` en caso de error definitivo).
- **Dependencia en arranque:** Requiere que `identity-service` esté sano (`service_healthy`) para arrancar.

#### `identity-service`
- **Imagen:** `danuser2018/identity-service:latest`
- **Puerto interno:** `8000` (expuesto en puerto host `8005`)
- **Rol:** Almacena y proporciona de manera centralizada la información de identidad privada del usuario (nombre y correo electrónico), actuando como la fuente de verdad única (*Single Source of Truth*) para el perfil del usuario.
- **API:** `GET /v1/identity` (retorna nombre y correo), `GET /v1/identity/name`, `GET /v1/identity/email`, `GET /health` (estado de salud).

#### `weather-service`
- **Imagen:** `danuser2018/weather-service:latest`
- **Puerto interno:** `8000` (expuesto en puerto host `8006`)
- **Rol:** Encapsula la comunicación con la API de Open-Meteo, proporcionando datos normalizados de temperatura y probabilidad de precipitación, y manejando la caché mediante TTL.
- **API:** `GET /v1/weather/current` (obtiene clima actual), `GET /health` (estado de salud).

#### `calendar-service`
- **Imagen:** `danuser2018/calendar-service:latest`
- **Puerto interno:** `8000` (expuesto en puerto host `8008`)
- **Rol:** Servicio local y offline para comprobar festivos oficiales y calcular el próximo festivo cronológico a partir de una fecha determinada, cargando archivos JSON estructurados por año.
- **API:** `GET /api/v1/holidays` (obtiene festivos de un año o fecha), `GET /api/v1/holidays/next` (obtiene el próximo festivo), `GET /api/v1/health` (estado de salud).

#### `nova-event-bus` (Librería Común)
- **Repositorio:** `danuser2018/nova-event-bus`
- **Lenguaje:** Python 3.10+
- **Rol:** Librería compartida que encapsula el acceso al bus de eventos. Proporciona una interfaz unificada y tipada para la publicación y suscripción de eventos, abstrayendo por completo el uso de NATS para los microservicios del dominio.

#### `nats`
- **Imagen:** `nats:2.10-alpine`
- **Puerto interno:** `8222` (monitoreo interno) / `4222` (cliente expuesto al host)
- **Rol:** Servidor de mensajería (broker) oficial de NATS, preparado para soportar el tránsito de eventos y pub/sub distribuido en el ecosistema en fases futuras.

---

## Red Interna de Docker

Todos los contenedores se conectan a través de una red Docker privada (`assistant-network`) definida en el `docker-compose.yml`. Ningún servicio expone puertos al exterior salvo que sea necesario para depuración.

```text
┌─────────────────────────────────────────────────────────────┐
│                 assistant-network (Docker)                   │
│                                                             │
│  interaction-manager ──► stt:8000                           │
│                      ──► orchestrator:8000                  │
│                      ──► tts:8000                           │
│  orchestrator        ──► system-service:8000                │
│  orchestrator        ──► weather-service:8000               │
│  orchestrator        ──► calendar-service:8000              │
│  orchestrator        ──► host.docker.internal:8007 ────────►│── host-service (HAL)
│  mail-watchdog       ──► identity-service:8000              │
│  mail-watchdog (salida SMTP al exterior)                    │
│  nats (sin acoplar - puerto 4222)                           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Decisiones de Diseño Clave (ADRs)

Las decisiones arquitectónicas críticas del ecosistema están formalizadas e indexadas secuencialmente en el registro de ADRs en [docs/adr/](adr/). Si dos decisiones entran en conflicto y ambas están en estado Aceptado, prevalece la que posea la fecha de registro más reciente (`Fecha` en formato `DD-MM-YYYY`).

| Decisión | Alternativa Descartada | Razón |
|---|---|---|
| [ADR-001: Filesystem como bus de mensajes](adr/adr-001.md) | Message broker (RabbitMQ, MQTT) | Complejidad innecesaria para el MVP; el filesystem es suficiente, fácil de depurar y no requiere infraestructura adicional. |
| [ADR-002: Modularización de Servicios](adr/adr-002.md) | Docker con passthrough de PulseAudio | La integración Docker con el servidor de audio del usuario es frágil y depende de la distribución. Systemd --user es el mecanismo estándar de Linux. |
| [ADR-003: Scoring determinista de plugins](adr/adr-003.md) (Superado) | LLM para enrutamiento | Latencia < 50ms, sin costo en GPU y 100% predecible. Superado por similitud semántica determinista con RapidFuzz. |
| [ADR-004: Estandarización de APIs REST](adr/adr-004.md) | Estilo libre ad-hoc sin estándar | Evita la inconsistencia en payloads, nombres de endpoints y formatos de error dispares en el ecosistema. |
| [ADR-005: Imágenes precompiladas en DockerHub](adr/adr-005.md) | Build local desde fuentes | El usuario no necesita clonar ni compilar los repositorios Docker. Una imagen precompilada garantiza una instalación en minutos. |
| [ADR-006: Cola de mensajería asíncrona JSON](adr/adr-006.md) | Integración SMTP síncrona en el Orquestador | Desacopla la lógica de red externa del flujo síncrono de voz, evitando bloqueos y ofreciendo persistencia de envíos. |
| [ADR-012: Integración del Servicio HID Daemon (hid-daemon)](adr/adr-012-integracion-hid-daemon.md) | Atajos del sistema gráfico | Permite capturar eventos de entrada de teclado físico a bajo nivel para control del micrófono sin requerir privilegios de superusuario ni sesiones de escritorio gráfico activas. |
| [ADR-013: Integración del Servicio Host (host-service)](adr/adr-013-integracion-host-service.md) | Mapeo de sockets de audio a contenedores Docker | Aísla completamente el plano de procesamiento Docker del hardware y las utilidades nativas de audio, interactuando con PipeWire/PulseAudio a través de una API REST local limpia e independiente. |
| [ADR-014: Separación de Responsabilidades en el Orquestador](adr/adr-014-refactorizacion-orquestador.md) | Enrutamiento acoplado en un único método | Desacopla la lógica de resolución semántica de la ejecución del plan de pasos, permitiendo pre-validaciones seguras y multi-acciones atómicas. |
| [ADR-015: Consolidación del Modelo ExecutionPlan](adr/adr-015-consolidacion-execution-plan.md) | Mantener el endpoint legado `/execute` | Consolida definitivamente el flujo desacoplado resolve/execute-plan, limpia los contratos de la API y renombra los componentes internos a `ExecutionPlanner` y `PlanExecutor` para mayor coherencia. |
| [ADR-016: Integración del Servicio Calendario](adr/adr-016-integracion-calendar-service.md) | Integrar SQLite o consultas directas en el Orquestador | Proporciona un servicio de consulta offline rápido, modular y de bajo mantenimiento para determinar días festivos sin depender de red externa. |
| [ADR-017: Integración de NATS como Message Broker](adr/adr-017-integracion-nats.md) | Migración total e inmediata de daemons | Introduce el broker NATS en el plano de procesamiento Docker, permitiendo la coexistencia con el filesystem-bus para no comprometer el audio. |
| [ADR-018: Abstracción de Event Bus](adr/adr-018-libreria-nova-event-bus.md) | Uso directo de nats-py o diccionarios planos | Desacopla la lógica de negocio del broker de mensajería NATS mediante una librería común con tipado fuerte. |
