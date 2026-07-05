# Arquitectura del Sistema Home Assistant

El ecosistema Home Assistant es un asistente de voz **100% local, modular y enfocado a la privacidad**, diseñado para sistemas operativos Linux.

Su arquitectura se basa en el principio de **separación de responsabilidades** (Single Responsibility Principle) y en un diseño híbrido: combina **servicios nativos en el host** para el acceso directo y sin fricciones al hardware de audio, y **contenedores Docker** para la lógica de inteligencia y coordinación, facilitando su actualización y despliegue de forma reproducible.

---

## Topología General

El sistema se divide en dos planos de ejecución:

| Plano | Tipo | Servicios |
|---|---|---|
| **Hardware** | Systemd User Services (host) | `mic-daemon`, `speaker-watchdog` |
| **Procesamiento** | Contenedores Docker | `interaction-manager`, `stt-capability`, `orchestrator`, `tts-capability`, `system-service`, `mail-watchdog`, `identity-service`, `weather-service` |

### ¿Por qué esta separación?

Los servicios de audio (`mic-daemon` y `speaker-watchdog`) necesitan acceso directo al servidor de sonido del usuario (PulseAudio o PipeWire), que opera dentro de la sesión de usuario de Linux. Ejecutarlos dentro de Docker añadiría una complejidad innecesaria con permisos, variables de entorno y sockets de audio. Por ello, se instalan como **servicios de usuario de systemd** (`systemd --user`).

El resto de servicios, al no necesitar acceso hardware, se ejecutan perfectamente en contenedores Docker, garantizando aislamiento, portabilidad y actualizaciones sin esfuerzo.

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
   |                  |                 |                |   /api/v1/execute  |               |                |                 |              |               |                |
   |                  |                 |                |                    |               |-- GET -------->|                 |              |               |                |
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
- **Rol:** Motor de intenciones determinista. Evalúa la similitud semántica del texto recibido contra las frases de ejemplo de cada plugin cargado (usando RapidFuzz), selecciona el plugin con mayor puntuación resolviendo empates por prioridad, y ejecuta su lógica.
- **Integraciones externas:** Además de conectarse a `system-service` para consultar identidad y capacidades, monta el volumen compartido `data/mail` para interactuar de forma asíncrona con `mail-watchdog` escribiendo peticiones de correo cuando se ejecuta el plugin `capabilities`.
- **API:** `POST /api/v1/execute` (JSON `{"text": "..."}`)
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

---

## Red Interna de Docker

Todos los contenedores se conectan a través de una red Docker privada (`assistant-network`) definida en el `docker-compose.yml`. Ningún servicio expone puertos al exterior salvo que sea necesario para depuración.

```text
┌─────────────────────────────────────────────┐
│           assistant-network (Docker)         │
│                                             │
│  interaction-manager ──► stt:8000           │
│                      ──► orchestrator:8000  │
│                      ──► tts:8000           │
│  orchestrator        ──► system-service:8000│
│  mail-watchdog       ──► identity-service:8000│
│  mail-watchdog (salida SMTP al exterior)    │
│                                             │
└─────────────────────────────────────────────┘
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
