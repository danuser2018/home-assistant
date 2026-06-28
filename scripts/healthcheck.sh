#!/usr/bin/env bash
# =============================================================================
# healthcheck.sh — Verificador del estado del asistente de voz Home Assistant
# =============================================================================
# Comprueba el estado de todos los componentes del sistema:
#   - Servicios systemd del host (mic-daemon, speaker-watchdog)
#   - Contenedores Docker
#   - Endpoints HTTP de los servicios (STT, Orchestrator, TTS)
#   - Carpetas de datos
#
# Uso:
#   chmod +x scripts/healthcheck.sh
#   ./scripts/healthcheck.sh
# =============================================================================

set -uo pipefail

# ─── Colores ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0

ok()   { echo -e "  ${GREEN}✓${NC} $*"; PASS=$((PASS + 1)); }
fail() { echo -e "  ${RED}✗${NC} $*"; FAIL=$((FAIL + 1)); }
warn() { echo -e "  ${YELLOW}!${NC} $*"; }
header() { echo ""; echo -e "${BLUE}▶ $*${NC}"; }

# ─── Rutas ────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$PROJECT_DIR/data"

# ─── Banner ───────────────────────────────────────────────────────────────────
echo ""
echo "=============================================="
echo "   Home Assistant — Health Check"
echo "   $(date '+%Y-%m-%d %H:%M:%S')"
echo "=============================================="

# ─── Servicios Systemd ────────────────────────────────────────────────────────
header "Servicios del host (systemd)"

for service in mic-daemon speaker-watchdog; do
    if systemctl --user is-active --quiet "$service" 2>/dev/null; then
        ok "$service — activo"
    else
        status=$(systemctl --user is-active "$service" 2>/dev/null || echo "desconocido")
        fail "$service — $status"
    fi
done

# ─── Contenedores Docker ──────────────────────────────────────────────────────
header "Contenedores Docker"

declare -A CONTAINERS=(
    ["interaction-manager"]="interaction-manager"
    ["stt-capability"]="stt-capability"
    ["orchestrator"]="orchestrator"
    ["tts-capability"]="tts-capability"
    ["system-service"]="system-service"
    ["mail-watchdog"]="mail-watchdog"
    ["identity-service"]="identity-service"
)

for name in "${!CONTAINERS[@]}"; do
    container="${CONTAINERS[$name]}"
    if docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null | grep -q "running"; then
        ok "$name — running"
    else
        state=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "no encontrado")
        fail "$name — $state"
    fi
done

# ─── Endpoints HTTP ───────────────────────────────────────────────────────────
header "Endpoints HTTP (puertos expuestos al host)"

check_http() {
    local label="$1"
    local url="$2"
    local expected_field="${3:-status}"

    if curl --silent --max-time 5 "$url" 2>/dev/null | grep -q "\"$expected_field\""; then
        ok "$label — $url"
    else
        fail "$label — no responde en $url"
    fi
}

check_http "STT /health"          "http://localhost:8001/health"
check_http "STT /ready"           "http://localhost:8001/ready"
check_http "Orchestrator /health" "http://localhost:8002/api/v1/health" || \
    warn "Orchestrator: el endpoint /health puede no estar disponible según la versión"
check_http "TTS /health"          "http://localhost:8003/health" || \
    warn "TTS: el endpoint /health puede no estar disponible según la versión"
check_http "System Service /health" "http://localhost:8004/health"
check_http "Identity Service /health" "http://localhost:8005/health"

# ─── Carpetas de datos ────────────────────────────────────────────────────────
header "Carpetas de datos"

for dir in input processing output error; do
    full_path="$DATA_DIR/$dir"
    if [ -d "$full_path" ]; then
        count=$(find "$full_path" -maxdepth 1 -name "*.wav" 2>/dev/null | wc -l)
        ok "$dir/ — existe ($count archivos .wav)"
        if [ "$dir" = "processing" ] && [ "$count" -gt 0 ]; then
            warn "Hay $count archivo(s) en processing/ — puede indicar un proceso atascado"
        fi
        if [ "$dir" = "error" ] && [ "$count" -gt 0 ]; then
            warn "Hay $count archivo(s) en error/ — revisa los logs del interaction-manager"
        fi
    else
        fail "$dir/ — no existe"
    fi
done

# Verificar carpetas de mail
if [ -d "$DATA_DIR/mail" ]; then
    ok "mail/ — existe"
    for maildir in pending processing failed; do
        full_path="$DATA_DIR/mail/$maildir"
        if [ -d "$full_path" ]; then
            count=$(find "$full_path" -maxdepth 1 -name "*.json" 2>/dev/null | wc -l)
            ok "mail/$maildir/ — existe ($count archivos .json)"
            if [ "$maildir" = "failed" ] && [ "$count" -gt 0 ]; then
                warn "Hay $count correo(s) en mail/failed/ — revisa los logs de mail-watchdog"
            fi
        else
            fail "mail/$maildir/ — no existe"
        fi
    done
else
    fail "mail/ — no existe"
fi

# ─── Flag de grabación ────────────────────────────────────────────────────────
header "Estado del micrófono"

FLAG="/tmp/voice_assistant/recording.flag"
if [ -f "$FLAG" ]; then
    warn "recording.flag existe — el micrófono está actualmente grabando"
else
    ok "Micrófono en reposo (recording.flag no existe)"
fi

# ─── Resumen ──────────────────────────────────────────────────────────────────
echo ""
echo "=============================================="
TOTAL=$((PASS + FAIL))
if [ "$FAIL" -eq 0 ]; then
    echo -e "   ${GREEN}Sistema operativo${NC} — $PASS/$TOTAL comprobaciones OK"
else
    echo -e "   ${RED}Sistema degradado${NC} — $PASS/$TOTAL OK, $FAIL fallos"
    echo ""
    echo "   Consulta docs/troubleshooting.md para resolver los problemas."
fi
echo "=============================================="
echo ""

# Devuelve código de error si hay fallos (útil para uso en scripts)
[ "$FAIL" -eq 0 ]
