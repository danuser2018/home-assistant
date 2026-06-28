# Catálogo de Servicios

El sistema Home Assistant está compuesto por **8 microservicios** con responsabilidades claramente delimitadas. Cada servicio tiene su propio repositorio con documentación técnica detallada.

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
| `mail-watchdog` | Docker | `danuser2018/mail-watchdog:latest` | Envía correos electrónicos asíncronos vía SMTP |

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
| `STT_BASE_URL` | URL del servicio STT para comunicación interna en la red Docker (ej. `http://stt:8000`) |
| `ORCHESTRATOR_BASE_URL` | URL del Orchestrator para comunicación interna en la red Docker (ej. `http://orchestrator:8000`) |
| `TTS_BASE_URL` | URL del servicio TTS para comunicación interna en la red Docker (ej. `http://tts:8000`) |
| `INPUT_DIR` | Carpeta de entrada (por defecto: `/data/input`) |
| `PROCESSING_DIR` | Carpeta de procesamiento (por defecto: `/data/processing`) |
| `OUTPUT_DIR` | Carpeta de salida (por defecto: `/data/output`) |
| `ERROR_DIR` | Carpeta de errores (por defecto: `/data/error`) |
| `POLL_INTERVAL_SECONDS` | Intervalo de sondeo en segundos (por defecto: `1`) |
| `LOG_LEVEL` | Nivel de logging (por defecto: `INFO`) |

---

### stt-capability

**Imagen:** `danuser2018/stt-capability:latest`  
**Puerto interno:** `8000` (expuesto en puerto host `8001` para depuración/desarrollo)

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
**Puerto interno:** `8000` (expuesto en puerto host `8002` para depuración/desarrollo)

**Propósito:** Motor de decisión determinista. Evalúa el texto transcrito contra las keywords y expresiones regulares de cada plugin disponible, asigna una puntuación (score) y ejecuta el plugin ganador. No usa LLMs; es predecible, rápido (< 50ms) y funciona sin GPU.

**Sistema de plugins:**
- Los plugins se cargan dinámicamente desde el directorio `plugins/` del contenedor.
- Cada plugin define sus propias keywords y regex para ser seleccionado.
- Si ningún plugin supera el umbral mínimo, responde el `FallbackPlugin`.

**Plugin de Capacidades (CapabilitiesPlugin):**
Este nuevo plugin permite al usuario preguntar a Nova sobre las funciones disponibles.
1. Consulta las capacidades registradas en `system-service` llamando a `GET /v1/system/capabilities`.
2. Ordena las capacidades alfabéticamente por su descripción.
3. Escribe un archivo JSON con el correo formateado en `MAIL_PENDING_DIR` (por defecto `/shared/mail/pending`) siguiendo el contrato del servicio `mail-watchdog`.
4. El envío del correo se gestiona de forma asíncrona y transparente por `mail-watchdog`.

**Variables de entorno relevantes:**

| Variable | Requerida | Valor por defecto | Descripción |
|---|---|---|---|
| `SYSTEM_SERVICE_BASE_URL` | ❌ No | `http://system-service:8000` | URL del servicio `system-service` para consultar identidad y capacidades |
| `USER_EMAIL` | ✅ Sí | `user@example.com` | Dirección de correo del usuario destinatario para las notificaciones del `CapabilitiesPlugin` |
| `MAIL_PENDING_DIR` | ❌ No | `/shared/mail/pending` | Directorio compartido donde se escriben los correos pendientes para que los procese `mail-watchdog` |

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
**Puerto interno:** `8000` (expuesto en puerto host `8003` para depuración/desarrollo)

**Propósito:** Servicio de Text-to-Speech. Recibe texto en formato JSON y devuelve audio binario WAV sintetizado. Basado en **Piper TTS**, un motor neuronal local ultra-rápido capaz de generar voz en tiempo real incluso en hardware modesto.

**Endpoint principal:**
```http
POST /v1/synthesize
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
GET /v1/system/info
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

#### 2. Registrar capacidades de los plugins
```http
POST /v1/system/capabilities
Content-Type: application/json

{
  "capabilities": [
    {"id": "identity", "description": "Información sobre Nova"},
    {"id": "weather", "description": "Consultar el tiempo"}
  ]
}
```

**Respuesta:**
```json
{
  "success": true
}
```

#### 3. Listar capacidades registradas
```http
GET /v1/system/capabilities
```

**Respuesta:**
```json
{
  "capabilities": [
    {"id": "identity", "description": "Información sobre Nova"},
    {"id": "weather", "description": "Consultar el tiempo"}
  ]
}
```

#### 4. Health check
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
```
---

### mail-watchdog

**Imagen:** `danuser2018/mail-watchdog:latest`  
**Puerto:** No expuesto al host.

**Propósito:** Procesar solicitudes de envío de emails de forma asíncrona mediante SMTP. Sigue el diseño desacoplado de Nova de *capabilities* basadas en watchdog del sistema de ficheros.

**Cómo funciona:**
1. Escucha de forma continua el directorio `/shared/mail/pending` en busca de archivos JSON de mensajes.
2. Lee, parsea y valida el JSON según el contrato establecido.
3. Intenta enviar el correo electrónico vía SMTP utilizando la configuración cargada.
4. Si el envío es exitoso, elimina el archivo JSON de forma segura.
5. Si ocurre un fallo en la conexión SMTP, reintenta el envío aplicando un backoff exponencial.
6. Si se agotan los reintentos configurados, mueve el archivo a `/shared/mail/failed/` para análisis y depuración manual.

**Contrato de Entrada (JSON):**
El servicio consume archivos `.json` con la siguiente estructura:
```json
{
  "id": "mail-12345",
  "to": "user@example.com",
  "subject": "Asunto del mensaje",
  "body": "Cuerpo o contenido del mensaje",
  "content_type": "text/plain"
}
```
* **Campos obligatorios:** `id` (identificador único), `to` (destinatario), `subject` (asunto), `body` (contenido).
* **Campos opcionales:** `content_type` (`"text/plain"` o `"text/html"`, por defecto `text/plain`).

**Estructura de Directorios Compartidos:**
El volumen montado en el contenedor bajo `/shared/mail` debe tener la siguiente estructura en el host:
* `pending/`: Carpeta de entrada para los correos a enviar.
* `processing/`: Estado transitorio durante el envío (opcional).
* `failed/`: Contiene los mensajes que fallaron permanentemente tras agotar los intentos.

**Variables de entorno relevantes:**

| Variable | Requerida | Valor por defecto | Descripción |
|---|---|---|---|
| `SMTP_HOST` | ✅ Sí | — | Dirección del servidor SMTP (ej. `smtp.gmail.com`) |
| `SMTP_PORT` | ✅ Sí | — | Puerto del servidor SMTP (normalmente `587` o `465`) |
| `SMTP_USER` | ✅ Sí | — | Usuario / Email de autenticación SMTP |
| `SMTP_PASSWORD` | ✅ Sí | — | Contraseña de autenticación (se recomienda usar contraseñas de aplicación) |
| `SMTP_FROM` | ❌ No | (Mismo que usuario) | Nombre y dirección de origen (ej. `"Nova <user@example.com>"`) |
| `MAIL_POLL_INTERVAL` | ❌ No | `2` | Intervalo de sondeo en segundos |
| `MAIL_MAX_RETRIES` | ❌ No | `3` | Límite máximo de intentos de envío |
| `MAIL_BACKOFF_BASE` | ❌ No | `2` | Factor de multiplicación para el backoff exponencial |

**Observabilidad (Logs):**
Ejemplo de flujo registrado por el contenedor:
```text
[INFO] Processing mail mail-12345
[INFO] Sending to user@example.com
[WARN] SMTP retry 1/3
[ERROR] Mail failed after retries
[INFO] Moved to /failed/mail-12345.json
```

---

## Comunicación entre Servicios

```text
                    ┌──────────────────────────────────────────────────┐
                    │      Red Docker: assistant-network               │
                    │                                                  │
                    │  interaction-manager                             │
                    │      │                                           │
                    │      ├──► stt:8000                               │
                    │      ├──► orchestrator:8000 ───┐                 │
                    │      │                         │                 │
                    │      │                         ▼                 │
                    │      │                   system-service:8000     │
                    │      └──► tts:8000                               │
                    │                                                  │
                    │  mail-watchdog ──► Servidor SMTP (exterior)      │
                    └──────────────────────────────────────────────────┘
                              │           │
                         Volumen Docker: ./data
                              │           │
                    ┌─────────┴───────────┴──────────┐
                    │         HOST (Linux)             │
                    │                                 │
                    │  mic-daemon ──► data/input/     │
                    │  speaker-watchdog ◄── data/output/│
                    │  plugins ──► data/mail/pending/  │
                    └─────────────────────────────────┘
```
