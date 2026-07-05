#!/usr/bin/env bash
# =============================================================================
# uninstall.sh — Desinstalador del asistente de voz Home Assistant
# =============================================================================
# Detiene y elimina los servicios del host (mic-daemon y speaker-watchdog).
# Los contenedores Docker se paran pero las imágenes se conservan.
# Los datos en data/ y los archivos de configuración NO se eliminan.
#
# Uso:
#   chmod +x scripts/uninstall.sh
#   ./scripts/uninstall.sh
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
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"

# ─── Banner ───────────────────────────────────────────────────────────────────
echo ""
echo "=============================================="
echo "   Home Assistant — Desinstalador"
echo "=============================================="
echo ""
log_warn "Este proceso detendrá y eliminará los servicios del sistema."
log_warn "Los datos en data/ y los archivos de configuración se conservarán."
echo ""
read -rp "¿Deseas continuar? (s/N): " confirm
if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
    echo "Desinstalación cancelada."
    exit 0
fi
echo ""

# ─── Parar y deshabilitar servicios systemd ───────────────────────────────────
log_info "Deteniendo servicios systemd del host..."

for service in mic-daemon speaker-watchdog hid-daemon; do
    if systemctl --user is-active --quiet "$service" 2>/dev/null; then
        systemctl --user stop "$service"
        log_ok "$service detenido."
    else
        log_warn "$service no estaba activo."
    fi

    if systemctl --user is-enabled --quiet "$service" 2>/dev/null; then
        systemctl --user disable "$service"
        log_ok "$service deshabilitado."
    fi

    SERVICE_FILE="$SYSTEMD_USER_DIR/$service.service"
    if [ -f "$SERVICE_FILE" ]; then
        rm "$SERVICE_FILE"
        log_ok "Archivo de servicio eliminado: $SERVICE_FILE"
    fi
done

systemctl --user daemon-reload
log_ok "Daemon de systemd recargado."
echo ""

# ─── Parar contenedores Docker ────────────────────────────────────────────────
log_info "Parando contenedores Docker..."
cd "$PROJECT_DIR"

if docker compose ps --quiet 2>/dev/null | grep -q .; then
    docker compose down
    log_ok "Contenedores Docker detenidos y eliminados."
else
    log_warn "No había contenedores Docker en ejecución."
fi
echo ""

# ─── Eliminar scripts de control ──────────────────────────────────────────────
log_info "Eliminando scripts de control del micrófono..."
for script in mic-toggle mic-start mic-stop; do
    if [ -f "$HOME/.local/bin/$script" ]; then
        rm "$HOME/.local/bin/$script"
        log_ok "$script eliminado de ~/.local/bin/"
    fi
done
echo ""

# ─── Resumen ──────────────────────────────────────────────────────────────────
echo "=============================================="
echo -e "   ${GREEN}Desinstalación completada${NC}"
echo "=============================================="
echo ""
log_info "Los siguientes elementos NO han sido eliminados:"
log_info "  - Directorio de datos: $PROJECT_DIR/data/"
log_info "  - Directorio con el modelo de STT: $PROJECT_DIR/models/stt"
log_info "  - Archivos de configuración: $PROJECT_DIR/config/"
log_info "  - Entornos virtuales Python (en los repos mic-daemon, speaker-watchdog y hid-daemon)"
log_info "  - Imágenes Docker (usa 'docker image rm' para eliminarlas manualmente)"
echo ""
log_info "Para reinstalar el sistema, ejecuta: ./scripts/install.sh"
echo ""
