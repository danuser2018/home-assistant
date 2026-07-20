# Refinamiento de la Feature: Integración del CLI novactl en los Scripts de Home Assistant

- **Origen**: Petición del usuario y [ADR-020: Integración del CLI novactl](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-020-integracion-novactl.md)
- **Fecha**: 2026-07-20
- **Estado**: Refinado

---

## 1. Resumen y Contexto de Negocio

### Objetivo Principal
Integrar el CLI `novactl` (definido en ADR-020) en el ciclo de vida completo de administración e instalación de `home-assistant`. Esto abarca la modificación de los scripts de instalación (`scripts/install.sh`), desinstalación (`scripts/uninstall.sh`), actualización (`scripts/update.sh`) y comprobación de salud (`scripts/healthcheck.sh`), asegurando que la herramienta `novactl` se instale en su entorno virtual Python dedicado, se exponga globalmente en `~/.local/bin/novactl`, se mantenga actualizada y se verifique su estado de funcionamiento.

### Actores y Flujo de Alto Nivel
1. **Administrador / Desarrollador**: Ejecuta los scripts de administración (`install.sh`, `update.sh`, `uninstall.sh`, `healthcheck.sh`) desde el directorio del proyecto `home-assistant`.
2. **Script `install.sh`**:
   - Comprueba la existencia del repositorio `novactl` en `$WORKSPACE_DIR/novactl`.
   - Crea el entorno virtual `$WORKSPACE_DIR/novactl/venv` si no existe.
   - Instala las dependencias y el paquete `novactl` mediante `pip install -e "$WORKSPACE_DIR/novactl"`.
   - Genera el enlace simbólico o ejecutable en `$HOME/.local/bin/novactl` apuntando a `$WORKSPACE_DIR/novactl/venv/bin/novactl`.
   - Incluye el estado de `novactl` en el resumen final de la instalación.
3. **Script `uninstall.sh`**:
   - Elimina el ejecutable / enlace `$HOME/.local/bin/novactl`.
   - Notifica en el resumen final que el directorio del repositorio y su `venv` se conservan.
4. **Script `update.sh`**:
   - Verifica la presencia del entorno virtual `$WORKSPACE_DIR/novactl/venv`.
   - Actualiza `pip` y reinstala/actualiza el paquete `novactl` y sus dependencias.
   - Asegura la validez del enlace ejecutable en `$HOME/.local/bin/novactl`.
5. **Script `healthcheck.sh`**:
   - Añade una sección para verificar la disponibilidad del ejecutable `novactl` en `PATH` o `$HOME/.local/bin/novactl`.
   - Comprueba que la invocación de `novactl --help` finalice con código de salida 0.

---

## 2. Análisis de Servicios e Impacto

| Servicio | Tipo de Cambio | Descripción del Impacto |
| :--- | :--- | :--- |
| `home-assistant` | Modificar | Se modifican los scripts `scripts/install.sh`, `scripts/uninstall.sh`, `scripts/update.sh` y `scripts/healthcheck.sh` para incorporar la gestión de `novactl`. Se actualiza `CHANGELOG.md` y la documentación relevante. |
| `novactl` | Ninguno (Existente) | Repositorio Python localizado en `$WORKSPACE_DIR/novactl`. No requiere cambios de código fuente, sólo su integración mediante los scripts de despliegue de `home-assistant`. |

---

## 3. Especificación de Comportamiento (Criterios de Aceptación)

### Escenario 1: Instalación exitosa de novactl mediante install.sh
```gherkin
Dado que el repositorio "novactl" existe en "$WORKSPACE_DIR/novactl"
Cuando el desarrollador ejecuta "./scripts/install.sh"
Entonces se crea el entorno virtual en "$WORKSPACE_DIR/novactl/venv"
Y se instalan las dependencias descritas en "$WORKSPACE_DIR/novactl/pyproject.toml"
Y se crea el enlace ejecutable "$HOME/.local/bin/novactl"
Y la comprobación "novactl --help" devuelve código de salida 0
```

### Escenario 2: Error en install.sh por ausencia del repositorio novactl
```gherkin
Dado que el directorio "$WORKSPACE_DIR/novactl" no existe en el sistema
Cuando el desarrollador ejecuta "./scripts/install.sh"
Entonces el script detiene la ejecución con un mensaje de error explícito
Y notifica que se debe clonar el repositorio "novactl" antes de continuar
```

### Escenario 3: Desinstalación limpia de novactl mediante uninstall.sh
```gherkin
Dado que "novactl" está instalado y el enlace "$HOME/.local/bin/novactl" existe
Cuando el desarrollador ejecuta "./scripts/uninstall.sh" y confirma la operación
Entonces el archivo "$HOME/.local/bin/novactl" es eliminado
Y el resumen de desinstalación indica que los binarios globales han sido removidos
```

### Escenario 4: Actualización de dependencias de novactl mediante update.sh
```gherkin
Dado que el entorno virtual "$WORKSPACE_DIR/novactl/venv" existe
Cuando el desarrollador ejecuta "./scripts/update.sh"
Entonces el script actualiza "pip" y reinstala "novactl" con "pip install --upgrade -e ."
Y notifica que "novactl" ha sido actualizado correctamente
```

### Escenario 5: Comprobación de estado del CLI mediante healthcheck.sh
```gherkin
Dado que "novactl" se encuentra instalado en "$HOME/.local/bin/novactl" o en el PATH
Cuando el desarrollador ejecuta "./scripts/healthcheck.sh"
Entonces el script reporta "novactl CLI — disponible" en verde (✓)
Y ejecuta la validación "novactl --help" sin errores
```

---

## 4. Diseño Técnico y Contratos

### Definición de Variables de Rutas en Bash Scripts
En los scripts de `home-assistant/scripts/`, se incorporan las constantes relativas a `novactl`:

```bash
NOVACTL_DIR="$WORKSPACE_DIR/novactl"
NOVACTL_VENV="$NOVACTL_DIR/venv"
```

### Lógica de Instalación en `install.sh`
```bash
# Comprobación de repositorio
if [ ! -d "$NOVACTL_DIR" ]; then
    log_error "No se encontró el repositorio novactl en: $NOVACTL_DIR"
    log_error "Clónalo con: git clone https://github.com/danuser2018/novactl.git $NOVACTL_DIR"
    exit 1
fi

# Instalación de venv y paquete
log_info "Instalando entorno virtual de novactl..."
if [ ! -d "$NOVACTL_VENV" ]; then
    python3 -m venv "$NOVACTL_VENV"
    log_ok "Entorno virtual creado en $NOVACTL_VENV"
fi

"$NOVACTL_VENV/bin/pip" install --quiet --upgrade pip
"$NOVACTL_VENV/bin/pip" install --quiet -e "$NOVACTL_DIR"
log_ok "Dependencias y CLI de novactl instalados."

# Wrapper ejecutable en ~/.local/bin/novactl para inyectar NATS_URL por defecto si no se especifica
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/novactl" << EOF
#!/usr/bin/env bash
export NATS_URL="\${NATS_URL:-nats://localhost:4222}"
exec "$NOVACTL_VENV/bin/novactl" "\$@"
EOF
chmod +x "$HOME/.local/bin/novactl"
log_ok "Wrapper de novactl instalado en ~/.local/bin/novactl (NATS_URL por defecto: nats://localhost:4222)"
```

### Lógica de Desinstalación en `uninstall.sh`
```bash
log_info "Eliminando ejecutable de novactl..."
if [ -f "$HOME/.local/bin/novactl" ] || [ -L "$HOME/.local/bin/novactl" ]; then
    rm -f "$HOME/.local/bin/novactl"
    log_ok "novactl eliminado de ~/.local/bin/"
fi
```

### Lógica de Actualización en `update.sh`
```bash
if [ -d "$NOVACTL_VENV" ] && [ -f "$NOVACTL_DIR/pyproject.toml" ]; then
    log_info "Actualizando dependencias Python de novactl..."
    "$NOVACTL_VENV/bin/pip" install --quiet --upgrade pip
    "$NOVACTL_VENV/bin/pip" install --quiet --upgrade -e "$NOVACTL_DIR"
    
    # Regenerar el script wrapper por si ha habido cambios
    cat > "$HOME/.local/bin/novactl" << EOF
#!/usr/bin/env bash
export NATS_URL="\${NATS_URL:-nats://localhost:4222}"
exec "$NOVACTL_VENV/bin/novactl" "\$@"
EOF
    chmod +x "$HOME/.local/bin/novactl"
    log_ok "novactl actualizado."
else
    log_warn "Entorno virtual de novactl no encontrado. ¿Está instalado?"
fi
```

### Lógica de Verificación en `healthcheck.sh`
```bash
header "Herramientas CLI"

NOVACTL_BIN="$HOME/.local/bin/novactl"
if command -v novactl &>/dev/null; then
    if novactl --help &>/dev/null; then
        ok "novactl CLI — disponible y ejecutable"
    else
        fail "novactl CLI — error al ejecutar novactl --help"
    fi
elif [ -x "$NOVACTL_BIN" ]; then
    if "$NOVACTL_BIN" --help &>/dev/null; then
        ok "novactl CLI — disponible en $NOVACTL_BIN"
    else
        fail "novactl CLI — error al ejecutar $NOVACTL_BIN --help"
    fi
else
    fail "novactl CLI — no encontrado en PATH ni en $NOVACTL_BIN"
fi
```

---

## 5. Casos de Borde y Manejo de Errores

| Caso de Borde | Comportamiento Esperado | Implementación Técnica |
| :--- | :--- | :--- |
| **Repositorio `novactl` no clonado** | `install.sh` falla temprano con un mensaje explicativo y código de retorno `1`. | Comprobación `[ ! -d "$NOVACTL_DIR" ]` al inicio de la verificación de repositorios. |
| **`~/.local/bin` no presente en `PATH`** | Emitir advertencia en `install.sh` sugiriendo al usuario exportar la variable `PATH`. | Reutilizar la comprobación existente `[[ ":$PATH:" != *":$HOME/.local/bin:"* ]]`. |
| **Entorno virtual corrompido** | `update.sh` advierte y no interrumpe el resto de actualizaciones de servicios. | Mensaje `log_warn` si no existe `NOVACTL_VENV`. |
| **Fallos de instalación con pip** | `install.sh` aborta la instalación con `set -e` al fallar el comando `pip install`. | Manejado nativamente por el flag `set -euo pipefail`. |

---

## 6. Estrategia de Testing

### Pruebas Manuales y de Scripting (E2E)
1. **Verificación de Instalación**:
   - Invocación de `./scripts/install.sh`.
   - Confirmar salida limpia y creación de `$HOME/.local/bin/novactl`.
   - Ejecución de `novactl --help` y `novactl status` en la terminal.
2. **Verificación de Salud**:
   - Invocación de `./scripts/healthcheck.sh`.
   - Confirmar check verde `✓ novactl CLI — disponible`.
3. **Verificación de Actualización**:
   - Invocación de `./scripts/update.sh`.
   - Confirmar log `novactl actualizado`.
4. **Verificación de Desinstalación**:
   - Invocación de `./scripts/uninstall.sh`.
   - Confirmar eliminación del enlace `$HOME/.local/bin/novactl`.

---

## 7. Plan de Implementación (Checklist)

- [ ] **Fase 1: Actualización del Script de Instalación (`scripts/install.sh`)**
  - [ ] Declarar `NOVACTL_DIR` y `NOVACTL_VENV` en las rutas del script.
  - [ ] Añadir `novactl` a la comprobación previa de repositorios requeridos en `$WORKSPACE_DIR`.
  - [ ] Añadir la sección de creación del entorno virtual `$NOVACTL_VENV` e instalación en modo editable de `novactl`.
  - [ ] Añadir la creación del enlace simbólico ejecutable `$HOME/.local/bin/novactl`.
  - [ ] Incluir la comprobación del estado de `novactl` en el resumen final del script.

- [ ] **Fase 2: Actualización del Script de Desinstalación (`scripts/uninstall.sh`)**
  - [ ] Añadir la eliminación del binario/enlace `$HOME/.local/bin/novactl`.
  - [ ] Documentar en el resumen final que el repositorio y el entorno virtual de `novactl` se conservan.

- [ ] **Fase 3: Actualización del Script de Actualización (`scripts/update.sh`)**
  - [ ] Declarar `NOVACTL_DIR` y `NOVACTL_VENV`.
  - [ ] Añadir la sección de actualización del entorno virtual de `novactl` e instalación con `--upgrade`.
  - [ ] Recrear el enlace simbólico `$HOME/.local/bin/novactl` para asegurar validez.

- [ ] **Fase 4: Actualización del Script de Healthcheck (`scripts/healthcheck.sh`)**
  - [ ] Crear la cabecera `Herramientas CLI`.
  - [ ] Añadir la verificación de presencia e invocación de `novactl --help`.

- [ ] **Fase 5: Actualización de Documentación y Changelog**
  - [ ] Actualizar `CHANGELOG.md` bajo la sección `[Unreleased]` / `[Sin publicar]` registrando las modificaciones en los scripts.
  - [ ] Actualizar `docs/installation.md` documentando la disponibilidad y uso de `novactl`.

- [ ] **Fase 6: Verificación E2E**
  - [ ] Ejecutar `./scripts/install.sh` y certificar instalación limpia.
  - [ ] Ejecutar `./scripts/healthcheck.sh` y verificar `✓ novactl CLI`.
  - [ ] Ejecutar `./scripts/update.sh` y comprobar actualización.
