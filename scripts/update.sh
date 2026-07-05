#!/usr/bin/env bash
# =============================================================================
# update.sh — Actualizador del asistente de voz Home Assistant
# =============================================================================
# Descarga las últimas imágenes Docker de DockerHub y reinicia los contenedores.
# Las dependencias Python de los servicios del host también se actualizan.
#
# Uso:
#   chmod +x scripts/update.sh
#   ./scripts/update.sh
# =============================================================================

set -euo pipefail

# ─── Colores ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ─── Rutas ────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
WORKSPACE_DIR="$(dirname "$PROJECT_DIR")"
TTS_MODEL_DIR="$PROJECT_DIR/models/tts"

MIC_DAEMON_DIR="$WORKSPACE_DIR/mic-daemon"
SPEAKER_WATCHDOG_DIR="$WORKSPACE_DIR/speaker-watchdog"
HID_DAEMON_DIR="$WORKSPACE_DIR/hid-daemon"

MIC_DAEMON_VENV="$MIC_DAEMON_DIR/venv"
SPEAKER_WATCHDOG_VENV="$SPEAKER_WATCHDOG_DIR/venv"
HID_DAEMON_VENV="$HID_DAEMON_DIR/venv"

# ─── Banner ───────────────────────────────────────────────────────────────────
echo ""
echo "=============================================="
echo "   Home Assistant — Actualizador"
echo "=============================================="
echo ""

# ─── Actualizar imágenes Docker ───────────────────────────────────────────────
log_info "Descargando las últimas imágenes Docker desde DockerHub..."
cd "$PROJECT_DIR"
docker compose pull
log_ok "Imágenes actualizadas."
echo ""

# ─── Comprobar y descargar modelos TTS configurados ──────────────────────────
log_info "Verificando modelos de voz de Piper TTS..."

# Asegurar que el directorio de modelos existe
mkdir -p "$TTS_MODEL_DIR"

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
    log_ok "Modelo de voz ($MODEL_NAME) verificado y listo."
fi
echo ""

# ─── Reiniciar contenedores con las nuevas imágenes ──────────────────────────
log_info "Reiniciando contenedores Docker..."
docker compose down
docker compose up -d
log_ok "Contenedores reiniciados con las nuevas imágenes."
echo ""

# ─── Actualizar dependencias de mic-daemon ────────────────────────────────────
if [ -d "$MIC_DAEMON_VENV" ] && [ -f "$MIC_DAEMON_DIR/requirements.txt" ]; then
    log_info "Actualizando dependencias Python de mic-daemon..."
    "$MIC_DAEMON_VENV/bin/pip" install --quiet --upgrade pip
    "$MIC_DAEMON_VENV/bin/pip" install --quiet --upgrade -r "$MIC_DAEMON_DIR/requirements.txt"
    systemctl --user restart mic-daemon
    log_ok "mic-daemon actualizado y reiniciado."
else
    log_warn "Entorno virtual de mic-daemon no encontrado. ¿Está instalado?"
fi
echo ""

# ─── Actualizar dependencias de speaker-watchdog ─────────────────────────────
if [ -d "$SPEAKER_WATCHDOG_VENV" ] && [ -f "$SPEAKER_WATCHDOG_DIR/requirements.txt" ]; then
    log_info "Actualizando dependencias Python de speaker-watchdog..."
    "$SPEAKER_WATCHDOG_VENV/bin/pip" install --quiet --upgrade pip
    "$SPEAKER_WATCHDOG_VENV/bin/pip" install --quiet --upgrade -r "$SPEAKER_WATCHDOG_DIR/requirements.txt"
    systemctl --user restart speaker-watchdog
    log_ok "speaker-watchdog actualizado y reiniciado."
else
    log_warn "Entorno virtual de speaker-watchdog no encontrado. ¿Está instalado?"
fi
echo ""

# ─── Actualizar dependencias de hid-daemon (si está presente) ──────────────────
if [ -d "$HID_DAEMON_VENV" ] && [ -f "$HID_DAEMON_DIR/requirements.txt" ]; then
    log_info "Actualizando dependencias Python de hid-daemon..."
    "$HID_DAEMON_VENV/bin/pip" install --quiet --upgrade pip
    "$HID_DAEMON_VENV/bin/pip" install --quiet --upgrade -r "$HID_DAEMON_DIR/requirements.txt"
    # Solo reiniciamos si el servicio systemd está habilitado/activo
    if systemctl --user is-enabled --quiet hid-daemon.service 2>/dev/null; then
        systemctl --user restart hid-daemon
        log_ok "hid-daemon actualizado y reiniciado."
    else
        log_ok "hid-daemon actualizado (servicio systemd no activo/habilitado)."
    fi
elif [ -d "$HID_DAEMON_DIR" ]; then
    log_warn "Entorno virtual de hid-daemon no encontrado. ¿Está instalado?"
fi
echo ""

# ─── Verificación final ───────────────────────────────────────────────────────
log_info "Verificando el estado del sistema tras la actualización..."
sleep 3  # Dar tiempo a los contenedores para arrancar
"$SCRIPT_DIR/healthcheck.sh"
