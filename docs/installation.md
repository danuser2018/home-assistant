# Guía de Instalación

Esta guía te permitirá tener el asistente de voz funcionando en tu equipo Linux en aproximadamente **10 minutos**.

> [!IMPORTANT]
> El sistema funciona en distribuciones Linux basadas en **Debian/Ubuntu** o similares (Fedora, Arch). Se necesita acceso a Internet sólo durante la instalación para descargar las imágenes Docker. Una vez instalado, todo funciona **sin conexión**.

---

## Requisitos del Sistema

Antes de comenzar, asegúrate de que tu equipo cumple los siguientes requisitos:

**Hardware:**
- CPU de 64 bits (x86_64 o arm64)
- Mínimo **4 GB de RAM** (recomendado 8 GB para el modelo Whisper `base`)
- Micrófono y altavoces o auriculares

**Software del sistema:**
- Linux con PulseAudio o PipeWire (cualquier distro moderna)
- `systemd` (modo usuario)
- `Docker` y `Docker Compose`
- `Python 3.10` o superior
- `mpv` (reproductor de audio por línea de comandos)
- `libportaudio2` (necesaria para la captura de audio con Python)

---

## Paso 1: Instalar dependencias del sistema

Abre una terminal y ejecuta el siguiente comando según tu distribución:

**Debian / Ubuntu / Linux Mint:**
```bash
sudo apt update && sudo apt install -y \
  python3 python3-venv python3-pip \
  libportaudio2 \
  mpv \
  curl
```

**Fedora:**
```bash
sudo dnf install -y \
  python3 python3-virtualenv \
  portaudio \
  mpv \
  curl
```

**Arch Linux:**
```bash
sudo pacman -S --noconfirm \
  python python-virtualenv \
  portaudio \
  mpv \
  curl
```

**Instalar Docker** (si no lo tienes ya instalado):
```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# ⚠️ Cierra sesión y vuelve a entrar para que el grupo docker surta efecto
```

---

## Paso 2: Clonar los repositorios

```bash
git clone https://github.com/danuser2018/home-assistant.git
git clone https://github.com/danuser2018/mic-daemon.git
git clone https://github.com/danuser2018/speaker-watchdog.git
git clone https://github.com/danuser2018/host-service.git
# Opcional (si deseas usar botones o pedales físicos USB):
git clone https://github.com/danuser2018/hid-daemon.git
cd home-assistant
```

---

## Paso 3: Crea la carpeta de datos
```bash
mkdir -p data/mail/{pending,processing,failed}
```

---

## Paso 4: Configurar las rutas del sistema

Edita el archivo `.env.example`, cópialo como `.env` y personaliza la ruta de tu usuario:

```bash
cp .env.example .env
```

Abre `.env` con tu editor favorito y ajusta la variable `HOME_ASSISTANT_DATA_DIR` para que apunte a la carpeta `data/` del proyecto:

```bash
# Ejemplo: si clonaste el repositorio en ~/home-assistant
HOME_ASSISTANT_DATA_DIR=/home/TU_USUARIO/home-assistant/data
```

> [!TIP]
> Puedes obtener la ruta actual con el comando `pwd` desde dentro de la carpeta del proyecto.

---

## Paso 5: Configurar los servicios del host

Los dos servicios que se instalan en el sistema (`mic-daemon` y `speaker-watchdog`) necesitan conocer las rutas de las carpetas de audio.

### 4a. Configurar mic-daemon

Edita `config/mic-daemon.env`:

```bash
nano config/mic-daemon.env
```

Contenido mínimo necesario (reemplaza `/home/TU_USUARIO`):
```env
# Directorio donde mic-daemon depositará los archivos .wav grabados
MIC_OUTPUT_DIR=/home/TU_USUARIO/home-assistant/data/input

# Intervalo de detección del hotkey (en milisegundos)
MIC_POLL_INTERVAL_MS=100

# Sample rate (debe ser 16000 Hz para compatibilidad con el servicio STT)
MIC_SAMPLE_RATE=16000

# Canales de audio (1 = mono, recomendado)
MIC_CHANNELS=1
```

Si quieres usar un micrófono específico en lugar del predeterminado, ejecuta esto para ver los disponibles y anota el índice:
```bash
python3 -c "import sounddevice as sd; print(sd.query_devices())"
# Luego añade a mic-daemon.env:
# MIC_DEVICE=2  (el número del micrófono deseado)
```

### 4b. Configurar speaker-watchdog

Edita `config/speaker-watchdog.env`:

```bash
nano config/speaker-watchdog.env
```

Contenido mínimo necesario:
```env
# Directorio donde speaker-watchdog buscará archivos .wav para reproducir
WATCHDOG_DIR=/home/TU_USUARIO/home-assistant/data/output
LOG_LEVEL=INFO
```

### 4c. Configurar hid-daemon (Opcional)

Si has clonado el repositorio `hid-daemon`, el instalador generará automáticamente los archivos de configuración por defecto:
1. `config/hid-daemon.env`: Ruta al archivo YAML de atajos y variables de anulación opcionales.
2. `config/hid-daemon.yaml`: Configuración de bindings y nombre del dispositivo de entrada. Abre este archivo para editar el nombre de tu dispositivo USB (ej: `"USB Foot Switch"`) y verificar las teclas.

### 4d. Configurar host-service

Edita `config/host-service.env`:

```bash
nano config/host-service.env
```

Contenido mínimo necesario:
```env
HOST=0.0.0.0
PORT=8007
LOG_LEVEL=INFO
```

---

## Paso 6: Instalar los servicios de systemd

Este paso crea los entornos Python necesarios y registra los servicios en systemd para que arranquen automáticamente con tu sesión.

```bash
chmod +x scripts/install.sh
./scripts/install.sh
```

El script realiza automáticamente las siguientes acciones:
- Instala `mic-daemon`, `speaker-watchdog`, `host-service` y `hid-daemon` (si está presente en el workspace) con sus entornos virtuales de Python.
- Genera dinámicamente las unidades de servicio systemd en `~/.config/systemd/user/`.
- Habilita e inicia los servicios instalados.

Verifica que los servicios estén activos:
```bash
systemctl --user status mic-daemon
systemctl --user status speaker-watchdog
systemctl --user status host-service
# Opcional (si se ha instalado):
systemctl --user status hid-daemon
```

Deberías ver `Active: active (running)` en ellos.

---

## Paso 7: Arrancar los servicios Docker

Descarga las imágenes de DockerHub y arranca los 8 contenedores:

```bash
docker compose up -d
```

Esto descargará automáticamente las siguientes imágenes (la primera vez tardará unos minutos dependiendo de tu conexión):
- `danuser2018/interaction-manager:latest`
- `danuser2018/stt-capability:latest`
- `danuser2018/orchestrator:latest`
- `danuser2018/tts-capability:latest`
- `danuser2018/system-service:latest`
- `danuser2018/mail-watchdog:latest`
- `danuser2018/identity-service:latest`
- `danuser2018/weather-service:latest`

> [!NOTE]
> Para que el servicio `mail-watchdog` funcione correctamente, debes configurar los parámetros SMTP de tu servidor de correo en el archivo `config/mail-watchdog.env` antes de levantar los contenedores. Consulta [docs/services.md](services.md) para ver la lista de variables requeridas.

Verifica que todos los contenedores están en funcionamiento:
```bash
docker compose ps
```

Deberías ver 8 contenedores con estado `Up`.

---

## Paso 8: Configurar el atajo de teclado (Hotkey)

Necesitas asociar un atajo de teclado de tu sistema operativo al script `mic-toggle.sh` del repositorio `mic-daemon`. Aquí tienes las instrucciones para los entornos de escritorio más comunes.

Primero, instala el script de control:
```bash
mkdir -p ~/.local/bin
# Asumiendo que también tienes el repositorio mic-daemon disponible
cp /ruta/a/mic-daemon/scripts/mic-toggle.sh ~/.local/bin/mic-toggle
chmod +x ~/.local/bin/mic-toggle
```

### GNOME
1. Ve a **Configuración → Teclado → Atajos de teclado → Ver y personalizar atajos**.
2. Desplázate hasta abajo y haz clic en el botón **+** para añadir un atajo personalizado.
3. **Nombre:** `Asistente de Voz`
4. **Comando:** `/home/TU_USUARIO/.local/bin/mic-toggle`
5. **Atajo:** Pulsa la combinación deseada (ej. `Super + F9`).

### KDE Plasma
1. Ve a **Configuración del sistema → Atajos → Atajos personalizados**.
2. Crea un nuevo atajo de tipo **Ejecutar comando**.
3. **Comando:** `/home/TU_USUARIO/.local/bin/mic-toggle`
4. **Atajo:** Asigna la combinación deseada.

### sxhkd (bspwm, i3, Openbox)
Añade esto a `~/.config/sxhkd/sxhkdrc`:
```ini
# Modo toggle: una pulsación inicia, otra detiene
super + F9
    mic-toggle
```
Luego recarga sxhkd: `pkill -USR1 sxhkd`

### Hyprland (Wayland)
Añade a `~/.config/hypr/hyprland.conf`:
```ini
bind = SUPER, F9, exec, mic-toggle
```

---

## Paso 9: Verificar la instalación

Realiza una prueba completa del sistema:

1. **Comprueba los servicios Docker:**
   ```bash
   ./scripts/healthcheck.sh
   ```

2. **Prueba el micrófono** (modo toggle):
   - Pulsa el hotkey configurado.
   - Di una frase sencilla (ej. "hola").
   - Vuelve a pulsar el hotkey para detener la grabación.
   - Comprueba que aparece un archivo en `data/input/`:
     ```bash
     ls -la data/input/
     ```

3. **Observa el flujo en tiempo real:**
   ```bash
   # En una terminal: observa los logs del interaction-manager
   docker compose logs -f interaction-manager
   
   # En otra terminal: observa los logs del speaker-watchdog
   journalctl --user -u speaker-watchdog -f
   ```

4. Si todo funciona, deberías escuchar la respuesta del asistente por los altavoces en pocos segundos.

---

## Desinstalación

Para eliminar completamente el sistema de tu equipo:

```bash
chmod +x scripts/uninstall.sh
./scripts/uninstall.sh
```

---

## Actualización

Para actualizar las imágenes Docker a la última versión disponible:

```bash
chmod +x scripts/update.sh
./scripts/update.sh
```

---

## Estructura de directorios tras la instalación

```text
home-assistant/
├── config/
│   ├── mic-daemon.env          ← Configuración del daemon de grabación
│   ├── speaker-watchdog.env    ← Configuración del daemon de reproducción
│   ├── hid-daemon.env          ← Configuración del daemon de atajos físicos (opcional)
│   ├── hid-daemon.yaml         ← Bindings de teclas físicas y comandos (opcional)
│   ├── host-service.env        ← Configuración del daemon de control local de host (API)
│   ├── interaction-manager.env ← Configuración del gestor de interacciones
│   ├── stt-capability.env      ← Configuración del servicio de voz a texto (STT)
│   ├── tts-capability.env      ← Configuración del servicio de texto a voz (TTS)
│   ├── orchestrator.env        ← Configuración del orquestador de intenciones
│   ├── system-service.env      ← Configuración de la identidad del asistente
│   ├── mail-watchdog.env       ← Configuración de la cola de correos y SMTP
│   ├── identity-service.env    ← Configuración de la identidad del usuario
│   └── weather-service.env     ← Configuración del servicio meteorológico y coordenadas
├── data/
│   ├── input/                  ← mic-daemon deposita aquí los .wav grabados
│   ├── processing/             ← interaction-manager procesa aquí los archivos
│   ├── output/                 ← Respuestas de audio listas para reproducir
│   ├── error/                  ← Archivos que fallaron durante el procesamiento
│   └── mail/                   ← Carpeta de trabajo de mail-watchdog
│       ├── pending/            ← Emails pendientes de envío (formato JSON)
│       ├── processing/         ← Emails en proceso de envío (opcional)
│       └── failed/             ← Emails que fallaron permanentemente
├── docs/                       ← Esta documentación
├── scripts/
│   ├── install.sh
│   ├── uninstall.sh
│   ├── update.sh
│   └── healthcheck.sh
├── systemd/
│   ├── mic-daemon.service
│   ├── speaker-watchdog.service
│   ├── host-service.service    ← Servicio systemd para host-service
│   └── hid-daemon.service      ← Servicio systemd para hid-daemon (opcional)
└── docker-compose.yml
```
