# Arquitectura del Sistema Home Assistant

El ecosistema Home Assistant es un asistente de voz **100% local, modular y enfocado a la privacidad**, diseñado para sistemas operativos Linux.

Su arquitectura se basa en el principio de **separación de responsabilidades** (Single Responsibility Principle) y en un diseño híbrido: combina **servicios nativos en el host** para el acceso directo y sin fricciones al hardware de audio, y **contenedores Docker** para la lógica de inteligencia y coordinación, facilitando su actualización y despliegue de forma reproducible.

---

## Topología General

El sistema se divide en dos planos de ejecución:

| Plano | Tipo | Servicios |
|---|---|---|
| **Hardware** | Systemd User Services (host) | `mic-daemon`, `speaker-watchdog` |
| **Procesamiento** | Contenedores Docker | `interaction-manager`, `stt-capability`, `orchestrator`, `tts-capability`, `system-service` |

### ¿Por qué esta separación?

Los servicios de audio (`mic-daemon` y `speaker-watchdog`) necesitan acceso directo al servidor de sonido del usuario (PulseAudio o PipeWire), que opera dentro de la sesión de usuario de Linux. Ejecutarlos dentro de Docker añadiría una complejidad innecesaria con permisos, variables de entorno y sockets de audio. Por ello, se instalan como **servicios de usuario de systemd** (`systemd --user`).

El resto de servicios, al no necesitar acceso hardware, se ejecutan perfectamente en contenedores Docker, garantizando aislamiento, portabilidad y actualizaciones sin esfuerzo.

---

## Integración: El Filesystem como Bus de Mensajes

La comunicación entre el plano de hardware y el plano de procesamiento se realiza a través del sistema de ficheros. El directorio `data/` del proyecto actúa como un **bus de mensajes asíncrono y observable**:

```text
home-assistant/data/
├── input/       ← mic-daemon deposita aquí los .wav grabados
├── processing/  ← interaction-manager mueve aquí los archivos mientras los procesa
├── output/      ← interaction-manager deposita aquí las respuestas de audio
└── error/       ← interaction-manager mueve aquí los archivos fallidos
```

Esta arquitectura tiene ventajas clave:
- **Observabilidad inmediata:** Con un simple `ls data/processing/` puedes ver si hay una petición en vuelo.
- **Depuración trivial:** Los errores se preservan en `data/error/` para su análisis posterior.
- **Desacoplamiento total:** Los servicios del host y los de Docker no se conocen entre sí; sólo conocen el directorio compartido.

---

## Diagrama de Secuencia (Flujo End-to-End)

```text
Usuario          mic-daemon        data/input   interaction-manager   stt-capability   orchestrator   system-service   tts-capability   data/output   speaker-watchdog
   |                  |                 |                |                    |               |                |              |               |                |
   |-- Presiona ----->|                 |                |                    |               |                |              |               |                |
   |   hotkey y habla |                 |                |                    |               |                |              |               |                |
   |                  |--- graba y ---->|                |                    |               |                |              |               |                |
   |                  |    guarda .wav  |                |                    |               |                |              |               |                |
   |                  |                 |-- inotify ---->|                    |               |                |              |               |                |
   |                  |                 |   evento       |-- mueve a -------->|               |                |              |               |                |
   |                  |                 |                |   /processing      |               |                |              |               |                |
   |                  |                 |                |-- POST ----------->|               |                |              |               |                |
   |                  |                 |                |   /v1/transcriptions|              |                |              |               |                |
   |                  |                 |                |<-- {"text": "..."} |               |                |              |               |                |
   |                  |                 |                |-- POST ------------|-------------->|                |              |               |                |
   |                  |                 |                |   /api/v1/execute  |               |                |              |               |                |
   |                  |                 |                |                    |               |-- GET -------->|              |               |                |
   |                  |                 |                |                    |               |   /system/info |              |               |                |
   |                  |                 |                |                    |               |<-- JSON -------|              |               |                |
   |                  |                 |                |<------------------ |{"speech":"..."}|                |              |               |                |
   |                  |                 |                |-- POST ------------|---------------|----------------|-------------->|               |                |
   |                  |                 |                |   /synthesize      |               |                |              |               |                |
   |                  |                 |                |<--  audio/wav  ----|---------------|----------------|------------- |               |                |
   |                  |                 |                |-- guarda ----------|---------------|----------------|--------------|-------------->|                |
   |                  |                 |                |   respuesta .wav   |               |                |              |               |                |
   |                  |                 |                |                    |               |                |              |               |-- inotify ----->|
   |                  |                 |                |                    |               |                |              |               |   evento       |
   |<-- Escucha audio |                 |                |                    |               |                |              |               |                |-- mpv reproduce
   |   del altavoz    |                 |                |                    |               |                |              |               |                |   y elimina .wav
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
- **Puerto interno:** `8001`
- **Rol:** Servicio stateless de Speech-to-Text basado en **Faster-Whisper**. Carga el modelo de IA una sola vez al arrancar para minimizar la latencia en peticiones subsiguientes.
- **API:** `POST /v1/transcriptions` (multipart/form-data con el campo `audio`)

#### `orchestrator`
- **Imagen:** `danuser2018/orchestrator:latest`
- **Puerto interno:** `8002`
- **Rol:** Motor de intenciones determinista. Evalúa el texto recibido contra las keywords y expresiones regulares de cada plugin cargado, selecciona el plugin con mayor puntuación y ejecuta su lógica.
- **API:** `POST /api/v1/execute` (JSON `{"text": "..."}`)
- **Extensibilidad:** Se pueden añadir nuevos plugins sin tocar el núcleo del orquestador.

#### `system-service`
- **Imagen:** `danuser2018/system-service:latest`
- **Puerto interno:** `8000` (expuesto en puerto host `8004`)
- **Rol:** Servicio de información de identidad. Expone datos estáticos sobre el asistente Nova. Consumido exclusivamente por el `orchestrator` mediante el `Identity Plugin`.
- **API:** `GET /system/info` (devuelve información del sistema en formato JSON) y `GET /health` (estado de salud).

#### `tts-capability`
- **Imagen:** `danuser2018/tts-capability:latest`
- **Puerto interno:** `8003`
- **Rol:** Servicio stateless de Text-to-Speech basado en **Piper TTS**. Recibe texto y devuelve audio binario PCM 16-bit mono a 16000 Hz empaquetado en formato WAV.
- **API:** `POST /synthesize` (JSON `{"msg": "..."}`)

---

## Red Interna de Docker

Todos los contenedores se conectan a través de una red Docker privada (`assistant-network`) definida en el `docker-compose.yml`. Ningún servicio expone puertos al exterior salvo que sea necesario para depuración.

```text
┌─────────────────────────────────────────────┐
│           assistant-network (Docker)         │
│                                             │
│  interaction-manager ──► stt:8001           │
│                      ──► orchestrator:8002  │
│                      ──► tts:8003           │
│  orchestrator        ──► system-service:8004│
│                                             │
└─────────────────────────────────────────────┘
```

---

## Decisiones de Diseño Clave

| Decisión | Alternativa Descartada | Razón |
|---|---|---|
| Filesystem como bus de mensajes | Message broker (RabbitMQ, MQTT) | Complejidad innecesaria para el MVP; el filesystem es suficiente, fácil de depurar y no requiere infraestructura adicional. |
| Systemd --user para audio | Docker con pasthrough de PulseAudio | La integración Docker con el servidor de audio del usuario es frágil y depende de la distribución. Systemd --user es el mecanismo estándar de Linux. |
| Scoring determinista de plugins | LLM para enrutamiento | Latencia < 50ms vs segundos, sin costo en GPU, 100% predecible y sin riesgo de alucinaciones. |
| Imágenes precompiladas en DockerHub | Build local desde fuentes | El usuario no necesita clonar ni compilar los 4 repositorios Docker. Una imagen precompilada garantiza una instalación en minutos. |
