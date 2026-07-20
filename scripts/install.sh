#!/usr/bin/env bash
# =============================================================================
# install.sh — Instalador del asistente de voz Home Assistant
# =============================================================================
# Instala y configura los servicios del host (mic-daemon y speaker-watchdog)
# como systemd user services. Las imágenes Docker se descargan con:
#   docker compose up -d
#
# Uso:
#   chmod +x scripts/install.sh
#   ./scripts/install.sh
# =============================================================================

set -euo pipefail

# ─── Colores ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'  # Sin color

log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()      { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ─── Rutas ────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
WORKSPACE_DIR="$(dirname "$PROJECT_DIR")"
DATA_DIR="$PROJECT_DIR/data"
STT_MODEL_DIR="$PROJECT_DIR/models/stt"
TTS_MODEL_DIR="$PROJECT_DIR/models/tts"

MIC_DAEMON_DIR="$WORKSPACE_DIR/mic-daemon"
SPEAKER_WATCHDOG_DIR="$WORKSPACE_DIR/speaker-watchdog"
HID_DAEMON_DIR="$WORKSPACE_DIR/hid-daemon"
HOST_SERVICE_DIR="$WORKSPACE_DIR/host-service"
NOVACTL_DIR="$WORKSPACE_DIR/novactl"

MIC_DAEMON_VENV="$MIC_DAEMON_DIR/venv"
SPEAKER_WATCHDOG_VENV="$SPEAKER_WATCHDOG_DIR/venv"
HID_DAEMON_VENV="$HID_DAEMON_DIR/venv"
HOST_SERVICE_VENV="$HOST_SERVICE_DIR/venv"
NOVACTL_VENV="$NOVACTL_DIR/venv"

SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
USER_UID="$(id -u)"

# ─── Banner ───────────────────────────────────────────────────────────────────
echo ""
echo "=============================================="
echo "   Home Assistant — Instalador"
echo "=============================================="
echo ""
log_info "Directorio del proyecto: $PROJECT_DIR"
log_info "Directorio de trabajo:   $WORKSPACE_DIR"
echo ""

# ─── Comprobaciones previas ───────────────────────────────────────────────────
log_info "Verificando requisitos del sistema..."

check_command() {
    if ! command -v "$1" &>/dev/null; then
        log_error "Comando '$1' no encontrado. Por favor, instálalo antes de continuar."
        log_error "Consulta docs/installation.md para más información."
        exit 1
    fi
}

check_command python3
check_command pip3
check_command docker
check_command mpv

# Verificar python3-venv
if ! python3 -m venv --help &>/dev/null; then
    log_error "El módulo 'venv' de Python no está disponible."
    log_error "Instálalo con: sudo apt install python3-venv"
    exit 1
fi

# Verificar libportaudio2
if ! python3 -c "import ctypes; ctypes.CDLL('libportaudio.so.2')" &>/dev/null 2>&1; then
    log_warn "libportaudio2 podría no estar instalada. Si mic-daemon falla, ejecuta:"
    log_warn "  sudo apt install libportaudio2"
fi

log_ok "Requisitos del sistema verificados."
echo ""

# Verificar grupo input para hid-daemon
if ! groups "$USER" | grep -q "\binput\b"; then
    log_warn "El usuario actual '$USER' no pertenece al grupo 'input'."
    log_warn "Esto es requerido para que hid-daemon pueda leer eventos de teclado físico sin privilegios de root."
    # Si la terminal es interactiva (o por defecto para asegurar aprobación), pedimos confirmación
    if [ -t 0 ]; then
        read -rp "¿Deseas añadir a '$USER' al grupo 'input' ahora? Se requerirán privilegios sudo. (s/N): " add_input
        if [[ "$add_input" == "s" || "$add_input" == "S" ]]; then
            log_info "Ejecutando: sudo usermod -aG input $USER"
            sudo usermod -aG input "$USER"
            log_ok "Usuario añadido al grupo 'input'. Nota: Es necesario reiniciar la sesión para aplicar cambios."
        else
            log_warn "No se añadió al usuario al grupo 'input'. hid-daemon podría fallar al arrancar."
        fi
    else
        log_warn "La instalación no es interactiva. Ejecuta manualmente: sudo usermod -aG input $USER"
    fi
fi
echo ""

# ─── Verificar repositorios de servicios del host ────────────────────────────
log_info "Verificando repositorios de mic-daemon, speaker-watchdog, host-service, hid-daemon y novactl..."

if [ ! -d "$HOST_SERVICE_DIR" ]; then
    log_error "No se encontró el repositorio host-service en: $HOST_SERVICE_DIR"
    log_error "Clónalo con: git clone https://github.com/danuser2018/host-service.git $HOST_SERVICE_DIR"
    exit 1
fi

if [ ! -d "$MIC_DAEMON_DIR" ]; then
    log_error "No se encontró el repositorio mic-daemon en: $MIC_DAEMON_DIR"
    log_error "Clónalo con: git clone https://github.com/danuser2018/mic-daemon.git $MIC_DAEMON_DIR"
    exit 1
fi

if [ ! -d "$SPEAKER_WATCHDOG_DIR" ]; then
    log_error "No se encontró el repositorio speaker-watchdog en: $SPEAKER_WATCHDOG_DIR"
    log_error "Clónalo con: git clone https://github.com/danuser2018/speaker-watchdog.git $SPEAKER_WATCHDOG_DIR"
    exit 1
fi

if [ ! -d "$NOVACTL_DIR" ]; then
    log_error "No se encontró el repositorio novactl en: $NOVACTL_DIR"
    log_error "Clónalo con: git clone https://github.com/danuser2018/novactl.git $NOVACTL_DIR"
    exit 1
fi

HAS_HID=true
if [ ! -d "$HID_DAEMON_DIR" ]; then
    log_warn "No se encontró el repositorio hid-daemon en: $HID_DAEMON_DIR. Se omitirá su instalación."
    HAS_HID=false
fi

log_ok "Repositorios verificados."
echo ""

# ─── Crear carpetas de datos ──────────────────────────────────────────────────
log_info "Creando estructura de carpetas de datos..."
mkdir -p "$DATA_DIR/input" "$DATA_DIR/processing" "$DATA_DIR/output" "$DATA_DIR/error"
mkdir -p "$DATA_DIR/mail/pending" "$DATA_DIR/mail/processing" "$DATA_DIR/mail/failed"
mkdir -p /tmp/voice_assistant
mkdir -p "$STT_MODEL_DIR"
mkdir -p "$TTS_MODEL_DIR"
mkdir -p "$PROJECT_DIR/calendar-data/holidays"
log_ok "Carpetas creadas en $DATA_DIR y $PROJECT_DIR/calendar-data"
echo ""

# Leer valores desde config/tts-capability.env
get_env_var() {
    local var_name="$1"
    local env_file="$PROJECT_DIR/config/tts-capability.env"
    if [ -f "$env_file" ]; then
        grep -E "^${var_name}=" "$env_file" | head -n1 | cut -d'=' -f2- | tr -d '"' | tr -d "'"
    fi
}

MODEL_NAME="$(get_env_var "TTS_MODEL_NAME")"
MODEL_URL="$(get_env_var "TTS_MODEL_URL")"

# Establecer valores por defecto si están vacíos o no se encuentra el archivo
MODEL_NAME="${MODEL_NAME:-es_ES-carlfm-x_low}"
MODEL_URL="${MODEL_URL:-https://huggingface.co/rhasspy/piper-voices/resolve/main/es/es_ES/carlfm/x_low/es_ES-carlfm-x_low.onnx}"

# Descargar modelo de voz configurado para TTS si no existe
if [ ! -f "$TTS_MODEL_DIR/${MODEL_NAME}.onnx" ]; then
    log_info "Descargando modelo de voz ($MODEL_NAME) desde: $MODEL_URL..."
    curl -L -S -f -o "$TTS_MODEL_DIR/${MODEL_NAME}.onnx" "$MODEL_URL"
fi

if [ ! -f "$TTS_MODEL_DIR/${MODEL_NAME}.onnx.json" ]; then
    log_info "Descargando configuración del modelo de voz ($MODEL_NAME) desde: ${MODEL_URL}.json..."
    curl -L -S -f -o "$TTS_MODEL_DIR/${MODEL_NAME}.onnx.json" "${MODEL_URL}.json"
    log_ok "Modelo de voz ($MODEL_NAME) descargado con éxito en $TTS_MODEL_DIR"
fi
echo ""

# ─── Configurar config/mic-daemon.env ────────────────────────────────────────
log_info "Configurando config/mic-daemon.env..."
if grep -q "^MIC_OUTPUT_DIR=$" "$PROJECT_DIR/config/mic-daemon.env" 2>/dev/null; then
    # El valor está vacío; lo rellenamos con la ruta correcta
    sed -i "s|^MIC_OUTPUT_DIR=$|MIC_OUTPUT_DIR=$DATA_DIR/input|" "$PROJECT_DIR/config/mic-daemon.env"
    log_ok "MIC_OUTPUT_DIR configurado en: $DATA_DIR/input"
else
    log_warn "MIC_OUTPUT_DIR ya está configurado. Comprueba que apunta a: $DATA_DIR/input"
fi

# ─── Configurar config/speaker-watchdog.env ──────────────────────────────────
log_info "Configurando config/speaker-watchdog.env..."
if grep -q "^WATCHDOG_DIR=$" "$PROJECT_DIR/config/speaker-watchdog.env" 2>/dev/null; then
    sed -i "s|^WATCHDOG_DIR=$|WATCHDOG_DIR=$DATA_DIR/output|" "$PROJECT_DIR/config/speaker-watchdog.env"
    log_ok "WATCHDOG_DIR configurado en: $DATA_DIR/output"
else
    log_warn "WATCHDOG_DIR ya está configurado. Comprueba que apunta a: $DATA_DIR/output"
fi

if [ "$HAS_HID" = true ]; then
    log_info "Configurando config/hid-daemon.yaml..."
    if [ ! -f "$PROJECT_DIR/config/hid-daemon.yaml" ]; then
        cp "$PROJECT_DIR/config/hid-daemon.yaml.example" "$PROJECT_DIR/config/hid-daemon.yaml"
        log_ok "Archivo de configuración config/hid-daemon.yaml creado a partir de la plantilla."
    else
        log_info "Archivo de configuración config/hid-daemon.yaml ya existe."
    fi
fi
echo ""

# ─── Instalar entorno virtual de mic-daemon ───────────────────────────────────
log_info "Instalando entorno virtual de mic-daemon..."
if [ ! -d "$MIC_DAEMON_VENV" ]; then
    python3 -m venv "$MIC_DAEMON_VENV"
    log_ok "Entorno virtual creado en $MIC_DAEMON_VENV"
fi

"$MIC_DAEMON_VENV/bin/pip" install --quiet --upgrade pip
"$MIC_DAEMON_VENV/bin/pip" install --quiet -r "$MIC_DAEMON_DIR/requirements.txt"
log_ok "Dependencias de mic-daemon instaladas."
echo ""

# ─── Instalar entorno virtual de speaker-watchdog ────────────────────────────
log_info "Instalando entorno virtual de speaker-watchdog..."
if [ ! -d "$SPEAKER_WATCHDOG_VENV" ]; then
    python3 -m venv "$SPEAKER_WATCHDOG_VENV"
    log_ok "Entorno virtual creado en $SPEAKER_WATCHDOG_VENV"
fi

"$SPEAKER_WATCHDOG_VENV/bin/pip" install --quiet --upgrade pip
"$SPEAKER_WATCHDOG_VENV/bin/pip" install --quiet -r "$SPEAKER_WATCHDOG_DIR/requirements.txt"
log_ok "Dependencias de speaker-watchdog instaladas."
echo ""

# ─── Instalar entorno virtual de host-service ────────────────────────────────
log_info "Instalando entorno virtual de host-service..."
if [ ! -d "$HOST_SERVICE_VENV" ]; then
    python3 -m venv "$HOST_SERVICE_VENV"
    log_ok "Entorno virtual creado en $HOST_SERVICE_VENV"
fi

"$HOST_SERVICE_VENV/bin/pip" install --quiet --upgrade pip
"$HOST_SERVICE_VENV/bin/pip" install --quiet -r "$HOST_SERVICE_DIR/requirements.txt"
log_ok "Dependencias de host-service instaladas."
echo ""

if [ "$HAS_HID" = true ]; then
    log_info "Instalando entorno virtual de hid-daemon..."
    if [ ! -d "$HID_DAEMON_VENV" ]; then
        python3 -m venv "$HID_DAEMON_VENV"
        log_ok "Entorno virtual creado en $HID_DAEMON_VENV"
    fi

    "$HID_DAEMON_VENV/bin/pip" install --quiet --upgrade pip
    "$HID_DAEMON_VENV/bin/pip" install --quiet -r "$HID_DAEMON_DIR/requirements.txt"
    log_ok "Dependencias de hid-daemon instaladas."
    echo ""
fi

# ─── Instalar entorno virtual del CLI novactl ────────────────────────────────
log_info "Instalando entorno virtual de novactl..."
if [ ! -d "$NOVACTL_VENV" ]; then
    python3 -m venv "$NOVACTL_VENV"
    log_ok "Entorno virtual creado en $NOVACTL_VENV"
fi

"$NOVACTL_VENV/bin/pip" install --quiet --upgrade pip
"$NOVACTL_VENV/bin/pip" install --quiet -e "$NOVACTL_DIR"
log_ok "Dependencias y CLI de novactl instalados."
echo ""

# ─── Instalar scripts de control de mic-daemon y novactl ───────────────────
log_info "Instalando scripts de control del micrófono y novactl CLI..."
mkdir -p "$HOME/.local/bin"

if [ -f "$MIC_DAEMON_DIR/scripts/mic-toggle.sh" ]; then
    cp "$MIC_DAEMON_DIR/scripts/mic-toggle.sh" "$HOME/.local/bin/mic-toggle"
    chmod +x "$HOME/.local/bin/mic-toggle"
    log_ok "mic-toggle instalado en ~/.local/bin/"
fi

if [ -f "$MIC_DAEMON_DIR/scripts/mic-start.sh" ]; then
    cp "$MIC_DAEMON_DIR/scripts/mic-start.sh" "$HOME/.local/bin/mic-start"
    chmod +x "$HOME/.local/bin/mic-start"
fi

if [ -f "$MIC_DAEMON_DIR/scripts/mic-stop.sh" ]; then
    cp "$MIC_DAEMON_DIR/scripts/mic-stop.sh" "$HOME/.local/bin/mic-stop"
    chmod +x "$HOME/.local/bin/mic-stop"
fi

# Wrapper script para novactl inyectando NATS_URL por defecto si no está definida
cat > "$HOME/.local/bin/novactl" << EOF
#!/usr/bin/env bash
export NATS_URL="\${NATS_URL:-nats://localhost:4222}"
exec "$NOVACTL_VENV/bin/novactl" "\$@"
EOF
chmod +x "$HOME/.local/bin/novactl"
log_ok "novactl wrapper instalado en ~/.local/bin/novactl (NATS_URL por defecto: nats://localhost:4222)"

# Verificar que ~/.local/bin está en el PATH
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    log_warn "~/.local/bin no está en tu PATH. Añade esto a ~/.bashrc o ~/.zshrc:"
    log_warn "  export PATH=\"\$HOME/.local/bin:\$PATH\""
fi
echo ""

# ─── Generar e instalar unidades systemd ─────────────────────────────────────
log_info "Instalando unidades de servicio systemd..."
mkdir -p "$SYSTEMD_USER_DIR"

# mic-daemon.service
cat > "$SYSTEMD_USER_DIR/mic-daemon.service" << EOF
[Unit]
Description=Microphone recording daemon for Home Assistant
Documentation=https://github.com/danuser2018/mic-daemon
After=default.target pipewire.service pipewire-pulse.service

[Service]
Type=simple
WorkingDirectory=$MIC_DAEMON_DIR
EnvironmentFile=$PROJECT_DIR/config/mic-daemon.env
ExecStart=$MIC_DAEMON_VENV/bin/python $MIC_DAEMON_DIR/src/mic_daemon.py
Restart=on-failure
RestartSec=3s
Environment=PYTHONPATH=$MIC_DAEMON_DIR
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF
log_ok "mic-daemon.service instalado en $SYSTEMD_USER_DIR/"

# speaker-watchdog.service
cat > "$SYSTEMD_USER_DIR/speaker-watchdog.service" << EOF
[Unit]
Description=Speaker Watchdog Service for Home Assistant
Documentation=https://github.com/danuser2018/speaker-watchdog
After=default.target sound.target

[Service]
Type=simple
WorkingDirectory=$SPEAKER_WATCHDOG_DIR
EnvironmentFile=$PROJECT_DIR/config/speaker-watchdog.env
ExecStart=$SPEAKER_WATCHDOG_VENV/bin/python src/main.py
Restart=always
RestartSec=3
Environment=XDG_RUNTIME_DIR=/run/user/$USER_UID
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF
log_ok "speaker-watchdog.service instalado en $SYSTEMD_USER_DIR/"

# host-service.service
cat > "$SYSTEMD_USER_DIR/host-service.service" << EOF
[Unit]
Description=Host Abstraction Layer for Nova-2
Documentation=https://github.com/danuser2018/host-service
After=default.target sound.target pipewire.service pipewire-pulse.service

[Service]
Type=simple
WorkingDirectory=$HOST_SERVICE_DIR
EnvironmentFile=$PROJECT_DIR/config/host-service.env
ExecStart=$HOST_SERVICE_VENV/bin/python -m src.main
Restart=always
RestartSec=3
Environment=PYTHONPATH=$HOST_SERVICE_DIR
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF
log_ok "host-service.service instalado en $SYSTEMD_USER_DIR/"

if [ "$HAS_HID" = true ]; then
    # hid-daemon.service
    cat > "$SYSTEMD_USER_DIR/hid-daemon.service" << EOF
[Unit]
Description=HID key events listener daemon for Nova-2
Documentation=https://github.com/danuser2018/hid-daemon
After=default.target

[Service]
Type=simple
WorkingDirectory=$HID_DAEMON_DIR
EnvironmentFile=$PROJECT_DIR/config/hid-daemon.env
ExecStart=$HID_DAEMON_VENV/bin/python $HID_DAEMON_DIR/src/hid_daemon.py
Restart=on-failure
RestartSec=3s
Environment=PYTHONPATH=$HID_DAEMON_DIR
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF
    log_ok "hid-daemon.service instalado en $SYSTEMD_USER_DIR/"
fi
echo ""

# ─── Habilitar e iniciar servicios ────────────────────────────────────────────
log_info "Habilitando e iniciando servicios systemd..."
systemctl --user daemon-reload

systemctl --user enable mic-daemon.service
systemctl --user start mic-daemon.service
log_ok "mic-daemon habilitado e iniciado."

systemctl --user enable speaker-watchdog.service
systemctl --user start speaker-watchdog.service
log_ok "speaker-watchdog habilitado e iniciado."

systemctl --user enable host-service.service
systemctl --user start host-service.service
log_ok "host-service habilitado e iniciado."

if [ "$HAS_HID" = true ]; then
    systemctl --user enable hid-daemon.service
    systemctl --user start hid-daemon.service
    log_ok "hid-daemon habilitado e iniciado."
fi
echo ""

# ─── Arrancar servicios Docker ────────────────────────────────────────────────
log_info "Descargando imágenes Docker y arrancando contenedores..."
cd "$PROJECT_DIR"
docker compose pull
docker compose up -d
log_ok "Contenedores Docker arrancados."
echo ""

# ─── Resumen final ────────────────────────────────────────────────────────────
echo "=============================================="
echo -e "   ${GREEN}Instalación completada correctamente${NC}"
echo "=============================================="
echo ""
echo "Estado de los servicios:"
systemctl --user is-active mic-daemon      && echo -e "  ${GREEN}✓${NC} mic-daemon" \
                                           || echo -e "  ${RED}✗${NC} mic-daemon"
systemctl --user is-active speaker-watchdog && echo -e "  ${GREEN}✓${NC} speaker-watchdog" \
                                            || echo -e "  ${RED}✗${NC} speaker-watchdog"
systemctl --user is-active host-service      && echo -e "  ${GREEN}✓${NC} host-service" \
                                            || echo -e "  ${RED}✗${NC} host-service"
if [ "$HAS_HID" = true ]; then
    systemctl --user is-active hid-daemon && echo -e "  ${GREEN}✓${NC} hid-daemon" \
                                          || echo -e "  ${RED}✗${NC} hid-daemon"
fi
[ -x "$HOME/.local/bin/novactl" ] && echo -e "  ${GREEN}✓${NC} novactl CLI" \
                                 || echo -e "  ${RED}✗${NC} novactl CLI"
echo ""
echo "Próximos pasos:"
echo "  1. Configura un atajo de teclado que ejecute: mic-toggle"
echo "     Consulta docs/installation.md para instrucciones por entorno de escritorio."
echo ""
echo "  2. Verifica la instalación con:"
echo "     ./scripts/healthcheck.sh"
echo ""
echo "  3. Si tienes problemas, consulta:"
echo "     docs/troubleshooting.md"
echo ""
