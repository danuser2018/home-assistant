# Catálogo de Servicios

El sistema Home Assistant está compuesto por **7 microservicios** con responsabilidades claramente delimitadas. Cada servicio tiene su propio repositorio con documentación técnica detallada.

---

## Resumen

| Servicio | Tipo | Imagen / Fuente | Función |
|---|---|---|---|
| `mic-daemon` | Host (Systemd) | `danuser2018/mic-daemon` | Graba voz del micrófono |
| `speaker-watchdog` | Host (Systemd) | `danuser2018/speaker-watchdog` | Reproduce respuestas de audio |
| `interaction-manager` | Docker | `danuser2018/interaction-manager:latest` | Coordina el flujo completo |
| `stt-capability` | Docker | `danuser2018/stt-capability:latest` | Convierte voz a texto (STT) |
| `orchestrator` | Docker | `danuser2018/orchestrator:latest` | Selecciona y ejecuta la acción adecuada |
| `tts-capability` | Docker | `danuser2018/tts-capability:latest` | Convierte texto a voz (TTS) |
| `system-service` | Docker | `danuser2018/system-service:latest` | Expone información de identidad del sistema (Nova) |

---

## Servicios del Host

Estos servicios se instalan directamente en tu sistema Linux como **servicios de usuario de systemd** (`systemd --user`). Necesitan acceso directo al servidor de sonido de tu sesión (PulseAudio / PipeWire), por lo que no se dockerizan.

---

### mic-daemon

**Repositorio:** `danuser2018/mic-daemon`

**Propósito:** Graba audio del micrófono cuando el usuario lo solicita mediante un atajo de teclado, y deposita el resultado en la carpeta de entrada del sistema.

**Cómo funciona:**
1. El usuario presiona el hotkey configurado.
2. Un script (`mic-toggle.sh`) crea o elimina un archivo de estado (`/tmp/voice_assistant/recording.flag`).
3. `mic-daemon` observa ese archivo: si existe, graba; si desaparece, guarda el `.wav` y vuelve a esperar.

**Archivos producidos:** `data/input/YYYY-MM-DD_HH-MM-SS.wav`

**Configuración relevante** (`config/mic-daemon.env`):

| Variable | Requerida | Valor por defecto | Descripción |
|---|---|---|---|
| `MIC_OUTPUT_DIR` | ✅ Sí | — | Ruta absoluta a `data/input/` |
| `MIC_DEVICE` | ❌ No | Dispositivo del sistema | Índice o nombre del micrófono |
| `MIC_SAMPLE_RATE` | ❌ No | `16000` | Sample rate en Hz |
| `MIC_CHANNELS` | ❌ No | `1` | Número de canales (1=mono) |
| `MIC_POLL_INTERVAL_MS` | ❌ No | `100` | Intervalo de polling en ms |

**Gestión:**
```bash
systemctl --user status mic-daemon
systemctl --user restart mic-daemon
journalctl --user -u mic-daemon -f
```

---

### speaker-watchdog

**Repositorio:** `danuser2018/speaker-watchdog`

**Propósito:** Monitoriza la carpeta de salida y reproduce por los altavoces los archivos de audio que van apareciendo, eliminándolos tras la reproducción.

**Cómo funciona:**
1. Observa `data/output/` mediante `inotify` (librería `watchdog` de Python).
2. Cuando detecta un nuevo `.wav`, lo añade a una cola FIFO thread-safe.
3. Un hilo consumidor saca archivos de la cola de uno en uno, los reproduce con `mpv --no-video --quiet`, y los elimina.
4. Si hay varios archivos a la vez, se reproducen en orden, nunca superpuestos.

**Dependencias del sistema:** `mpv` debe estar instalado (`sudo apt install mpv`).

**Configuración relevante** (`config/speaker-watchdog.env`):

| Variable | Requerida | Valor por defecto | Descripción |
|---|---|---|---|
| `WATCHDOG_DIR` | ✅ Sí | — | Ruta absoluta a `data/output/` |
| `LOG_LEVEL` | ❌ No | `INFO` | Nivel de logging |

**Gestión:**
```bash
systemctl --user status speaker-watchdog
systemctl --user restart speaker-watchdog
journalctl --user -u speaker-watchdog -f
```

---

## Servicios Docker

Estos servicios se ejecutan en contenedores Docker gestionados por el `docker-compose.yml` del proyecto. Las imágenes están publicadas en DockerHub y se descargan automáticamente.

---

### interaction-manager

**Imagen:** `danuser2018/interaction-manager:latest`  
**Puerto:** No expuesto al host.

**Propósito:** Coordinador central del pipeline de voz. Implementa una máquina de estados basada en el sistema de ficheros y orquesta las llamadas a los servicios STT, Orchestrator y TTS de forma síncrona y ordenada.

**Flujo interno:**
```text
data/input/ → [detecta .wav] → data/processing/ → STT → Orchestrator → TTS → data/output/
                                                                                       ↕
                                                               (si hay error) → data/error/
```

**Variables de entorno relevantes:**

| Variable | Descripción |
|---|---|
| `STT_BASE_URL` | URL del servicio STT (ej. `http://stt:8001`) |
| `ORCHESTRATOR_BASE_URL` | URL del Orchestrator (ej. `http://orchestrator:8002`) |
| `TTS_BASE_URL` | URL del servicio TTS (ej. `http://tts:8003`) |
| `INPUT_DIR` | Carpeta de entrada (por defecto: `/data/input`) |
| `PROCESSING_DIR` | Carpeta de procesamiento (por defecto: `/data/processing`) |
| `OUTPUT_DIR` | Carpeta de salida (por defecto: `/data/output`) |
| `ERROR_DIR` | Carpeta de errores (por defecto: `/data/error`) |
| `POLL_INTERVAL_SECONDS` | Intervalo de sondeo en segundos (por defecto: `1`) |
| `LOG_LEVEL` | Nivel de logging (por defecto: `INFO`) |

---

### stt-capability

**Imagen:** `danuser2018/stt-capability:latest`  
**Puerto interno:** `8001`

**Propósito:** Servicio de Speech-to-Text. Recibe un archivo de audio WAV y devuelve la transcripción en texto. Basado en **Faster-Whisper**, una implementación optimizada del modelo Whisper de OpenAI que funciona completamente en local.

**Endpoint principal:**
```http
POST /v1/transcriptions
Content-Type: multipart/form-data

Campos: audio (file), language (string, opcional)
```

**Respuesta:**
```json
{
  "text": "qué tiempo hace hoy",
  "language": "es",
  "processing_ms": 842
}
```

**Modelos disponibles** (más pequeño = más rápido, menos preciso):

| Modelo | RAM aprox. | Velocidad | Precisión |
|---|---|---|---|
| `tiny` | ~400 MB | Muy rápido | Básica |
| `base` | ~750 MB | Rápido | Buena ✅ (recomendado) |
| `small` | ~1.5 GB | Moderado | Muy buena |
| `medium` | ~3 GB | Lento | Excelente |

**Variables de entorno:**

| Variable | Valor por defecto | Descripción |
|---|---|---|
| `WHISPER_MODEL` | `base` | Modelo Whisper a cargar |
| `WHISPER_DEVICE` | `cpu` | Dispositivo de inferencia (`cpu` o `cuda`) |
| `LOG_LEVEL` | `INFO` | Nivel de logging |

**Health check:**
```bash
curl http://localhost:8001/health    # {"status": "ok"}
curl http://localhost:8001/ready     # {"status": "ready"}
```

---

### orchestrator

**Imagen:** `danuser2018/orchestrator:latest`  
**Puerto interno:** `8002`

**Propósito:** Motor de decisión determinista. Evalúa el texto transcrito contra las keywords y expresiones regulares de cada plugin disponible, asigna una puntuación (score) y ejecuta el plugin ganador. No usa LLMs; es predecible, rápido (< 50ms) y funciona sin GPU.

**Sistema de plugins:**
- Los plugins se cargan dinámicamente desde el directorio `plugins/` del contenedor.
- Cada plugin define sus propias keywords y regex para ser seleccionado.
- Si ningún plugin supera el umbral mínimo, responde el `FallbackPlugin`.

**Endpoint principal:**
```http
POST /api/v1/execute
Content-Type: application/json

{"text": "qué tiempo hace hoy"}
```

**Respuesta:**
```json
{
  "success": true,
  "plugin_used": "WeatherPlugin",
  "speech": "Actualmente hace 22 grados. No parece que vaya a llover.",
  "execution_time_ms": 45
}
```

---

### tts-capability

**Imagen:** `danuser2018/tts-capability:latest`  
**Puerto interno:** `8003`

**Propósito:** Servicio de Text-to-Speech. Recibe texto en formato JSON y devuelve audio binario WAV sintetizado. Basado en **Piper TTS**, un motor neuronal local ultra-rápido capaz de generar voz en tiempo real incluso en hardware modesto.

**Endpoint principal:**
```http
POST /synthesize
Content-Type: application/json

{"msg": "Actualmente hace 22 grados"}
```

**Respuesta:** Binario `audio/wav` (PCM 16-bit, mono, 16000 Hz).

---

### system-service

**Imagen:** `danuser2018/system-service:latest`  
**Puerto interno:** `8000` (expuesto en puerto host `8004`)

**Propósito:** Servicio de información de identidad. Expone información básica del asistente Nova en formato JSON. Es consumido exclusivamente por el `Orchestrator` a través del `Identity Plugin` para responder preguntas de identidad del usuario (ej. "¿quién eres?").

**Variables de entorno:**

| Variable | Valor por defecto | Descripción |
|---|---|---|
| `NOVA_NAME` | `Nova` | Nombre del asistente |
| `NOVA_AUTHOR` | `David` | Nombre del creador/autor |
| `NOVA_VERSION` | `0.1.0` | Versión del sistema |
| `NOVA_DESCRIPTION` | `Asistente personal de voz y automatización` | Descripción corta de la plataforma |

**Endpoints principales:**

#### 1. Obtener información del sistema
```http
GET /system/info
```

**Respuesta:**
```json
{
  "name": "Nova",
  "author": "David",
  "version": "0.1.0",
  "description": "Asistente personal de voz y automatización"
}
```

#### 2. Health check
```http
GET /health
```

**Respuesta:**
```json
{
  "status": "ok"
}
```

**Configuración de Healthcheck en Docker:**
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
  interval: 30s
  timeout: 5s
  retries: 3
```

---

## Comunicación entre Servicios

```text
                    ┌──────────────────────────────────────────────────┐
                    │      Red Docker: assistant-net                   │
                    │                                                  │
                    │  interaction-manager                             │
                    │      │                                           │
                    │      ├──► stt:8001                               │
                    │      ├──► orchestrator:8002 ───┐                 │
                    │      │                         │                 │
                    │      │                         ▼                 │
                    │      │                   system-service:8004     │
                    │      └──► tts:8003                               │
                    │                                                  │
                    └──────────────────────────────────────────────────┘
                              │           │
                        Volumen Docker: ./data
                              │           │
                    ┌─────────┴───────────┴──────────┐
                    │         HOST (Linux)             │
                    │                                 │
                    │  mic-daemon ──► data/input/     │
                    │  speaker-watchdog ◄── data/output/│
                    │                                 │
                    └─────────────────────────────────┘
```
