# Refinamiento de la Feature: Eliminación de los Scripts de Control de Micrófono (mic-start / mic-stop / mic-toggle)

- **Origen**: Petición del usuario — consolidación del punto de entrada CLI en `novactl` como única interfaz de integración (ADR-020)
- **Fecha**: 2026-08-02
- **Estado**: Refinado / Listo para revisión de DoR

---

## 1. Resumen y Contexto de Negocio

### Objetivo Principal

Eliminar definitivamente los scripts de control de micrófono `scripts/mic-start.sh`, `scripts/mic-stop.sh` y `scripts/mic-toggle.sh` del repositorio `mic-daemon`, ya que constituyen una capa de indirección redundante cuya única función es invocar a `novactl start-capture` y `novactl stop-capture`. La interacción CLI con el ecosistema Nova debe realizarse exclusivamente a través del cliente oficial `novactl`, sin intermediarios de scripting.

Esta eliminación implica:
1. **Eliminar los scripts** en `mic-daemon/scripts/`.
2. **Actualizar los scripts de despliegue** de `home-assistant` para que dejen de copiar estos scripts al PATH del sistema.
3. **Actualizar la documentación** de ambos repositorios para que todas las referencias a `mic-start`, `mic-stop` y `mic-toggle` sean sustituidas por los comandos `novactl start-capture`, `novactl stop-capture` y una lógica basada en `novactl`.
4. **Eliminar las pruebas de integración de scripts** (`tests/test_scripts.py`) del repositorio `mic-daemon`, que prueban scripts que ya no existirán.
5. **Registrar un Addendum en ADR-021** reflejando que la fase de coexistencia de scripts ha finalizado con su eliminación total.

### Evaluación de Necesidad de un nuevo ADR (D-05)

No se requiere la creación de un nuevo ADR para esta feature. La consolidación del CLI oficial en `novactl` y la migración progresiva de atajos y scripts legacy ya fue formalizada y aprobada en el [ADR-020 (Punto 5)](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-020-integracion-novactl.md). La eliminación de los scripts intermediarios en `mic-daemon` representa la conclusión del periodo de transición. Las modificaciones en [ADR-021](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-021-deteccion-habla-eventos-mic-daemon.md) se gestionarán mediante un *Addendum* sin necesidad de introducir un nuevo registro arquitectónico.

### Actores y Flujo de Alto Nivel

1. **Administrador / Desarrollador (mic-daemon)**: Elimina los tres scripts del directorio `scripts/` y borra su test de integración.
2. **Administrador / Desarrollador (home-assistant)**: Actualiza `scripts/install.sh` para que deje de copiar `mic-start`, `mic-stop` y `mic-toggle` a `~/.local/bin/`; actualiza `scripts/uninstall.sh` para que no los borre al desinstalar; actualiza `docs/installation.md` para que el Paso 8 de configuración de hotkeys apunte directamente a `novactl`; y añade un Addendum en `ADR-021`.
3. **Usuario Final**: Para configurar su atajo de teclado, usará `novactl start-capture` / `novactl stop-capture` de forma directa, sin scripts intermediarios.

### Estado actual de los scripts a eliminar

| Script | Contenido actual |
| :--- | :--- |
| `mic-daemon/scripts/mic-start.sh` | Llama a `novactl start-capture`. Si `novactl` no está en PATH, sale con código 1. |
| `mic-daemon/scripts/mic-stop.sh` | Llama a `novactl stop-capture`. Si `novactl` no está en PATH, sale con código 1. |
| `mic-daemon/scripts/mic-toggle.sh` | Usa `/tmp/mic_toggle_active` como flag de estado para llamar a `novactl start-capture` o `novactl stop-capture` alternativamente. |

---

## 2. Análisis de Servicios e Impacto

| Servicio / Documento | Tipo de Cambio | Descripción del Impacto |
| :--- | :--- | :--- |
| `mic-daemon` | **Modificar** | Eliminar `scripts/mic-start.sh`, `scripts/mic-stop.sh`, `scripts/mic-toggle.sh` y `tests/test_scripts.py`. Actualizar `README.md` (incluyendo sección Hotkeys) y `CHANGELOG.md` para reflejar la eliminación. |
| `home-assistant` (`install.sh`) | **Modificar** | Eliminar el bloque de copia de los scripts de micrófono a `~/.local/bin/`. Actualizar el mensaje de "Próximos pasos" sustituyendo `mic-toggle` por `novactl`. |
| `home-assistant` (`uninstall.sh`) | **Modificar** | Eliminar `mic-toggle`, `mic-start` y `mic-stop` del bucle de limpieza de `~/.local/bin/`. |
| `home-assistant` (`update.sh`) | **Ninguno** | No requiere cambios. El script ya no copia ni regenera los scripts de micrófono; únicamente actualiza dependencias Python de `mic-daemon` y regenera el wrapper de `novactl`, ambas acciones correctas. |
| `home-assistant` (`docs/installation.md`) | **Modificar** | Reescribir el Paso 8 para documentar la integración de hotkeys directamente con `novactl start-capture` / `novactl stop-capture`. |
| `home-assistant` (`docs/adr/adr-021-...`) | **Modificar** | Añadir Addendum formalizando que el punto 4 queda superado tras la eliminación completa de los scripts. |
| `home-assistant` (`CHANGELOG.md`) | **Modificar** | Registrar la eliminación bajo `[Sin publicar]` e incluir el aviso de migración manual para instalaciones previas. |
| `novactl` | **Ninguno** | No requiere cambios. El CLI ya expone `start-capture` y `stop-capture` como comandos oficiales. |
| `hid-daemon` | **Ninguno** | No referencia los scripts directamente. No se ve afectado. |

---

## 3. Especificación de Comportamiento (Criterios de Aceptación)

### Escenario 1: Los scripts mic-start.sh, mic-stop.sh y mic-toggle.sh ya no existen en mic-daemon
```gherkin
Dado que el desarrollador ha completado la tarea de eliminación
Cuando se inspecciona el directorio "mic-daemon/scripts/"
Entonces el directorio "scripts/" no contiene "mic-start.sh", "mic-stop.sh" ni "mic-toggle.sh"
Y el directorio "scripts/" ha sido eliminado al quedar vacío
```

### Escenario 2: El script install.sh ya no copia los scripts de micrófono al PATH
```gherkin
Dado que se ha actualizado "scripts/install.sh" en "home-assistant"
Cuando el desarrollador ejecuta "./scripts/install.sh"
Entonces "~/.local/bin/mic-start", "~/.local/bin/mic-stop" y "~/.local/bin/mic-toggle" NO son creados
Y "~/.local/bin/novactl" sigue siendo instalado correctamente
```

### Escenario 3: El script uninstall.sh ya no intenta borrar los scripts de micrófono
```gherkin
Dado que se ha actualizado "scripts/uninstall.sh" en "home-assistant"
Cuando el desarrollador ejecuta "./scripts/uninstall.sh"
Entonces el script no referencia "mic-toggle", "mic-start" ni "mic-stop" en su bucle de limpieza
Y "~/.local/bin/novactl" sigue siendo eliminado correctamente
```

### Escenario 4: La documentación de instalación indica novactl como mecanismo de hotkey
```gherkin
Dado que se ha actualizado "docs/installation.md"
Cuando el usuario consulta el Paso 8 (configuración del atajo de teclado)
Entonces la documentación muestra "novactl start-capture" y "novactl stop-capture" como comandos a ejecutar
Y no contiene ninguna referencia a "mic-toggle", "mic-start" ni "mic-stop"
```

### Escenario 5: El README de mic-daemon no referencia los scripts eliminados
```gherkin
Dado que se ha actualizado "mic-daemon/README.md"
Cuando el usuario consulta las secciones de arquitectura, modos de operación, estructura o integración con hotkeys
Entonces no aparecen referencias a "mic-start.sh", "mic-stop.sh" ni "mic-toggle.sh"
Y la documentación indica que el control del daemon se realiza directamente mediante "novactl start-capture" y "novactl stop-capture"
```

### Escenario 6: Las pruebas de integración de scripts son eliminadas
```gherkin
Dado que se ha eliminado el fichero "mic-daemon/tests/test_scripts.py"
Cuando se ejecuta la suite de tests "pytest tests/"
Entonces no se produce ningún error relacionado con los scripts eliminados
Y la suite completa termina con estado "passed"
```

### Escenario 7: Manejo de instalaciones previas con binarios legacy (D-03)
```gherkin
Dado que el sistema tiene una instalación previa con los binarios legacy "mic-toggle", "mic-start" y "mic-stop" en "~/.local/bin/"
Cuando el desarrollador ejecuta "./scripts/install.sh"
Entonces los binarios legacy no son modificados ni eliminados automáticamente por el instalador
Y el archivo "CHANGELOG.md" incluye la instrucción explícita de eliminación manual ("rm -f ~/.local/bin/mic-toggle ~/.local/bin/mic-start ~/.local/bin/mic-stop")
```

---

## 4. Diseño Técnico y Contratos

### 4.1 Cambios en `mic-daemon`

#### Archivos a eliminar
```
mic-daemon/scripts/mic-start.sh
mic-daemon/scripts/mic-stop.sh
mic-daemon/scripts/mic-toggle.sh
mic-daemon/scripts/             (directorio, si queda vacío)
mic-daemon/tests/test_scripts.py
```

#### Cambios en `mic-daemon/README.md`

**Sección "Arquitectura del sistema" — diagrama ASCII (líneas ~52-53):**
Sustituir:
```
│   novactl (start-capture / stop-capture)                        │
│   o scripts de control: mic-start.sh / mic-stop.sh             │
```
Por:
```
│   novactl (start-capture / stop-capture)                        │
```

**Tabla de Componentes:**
Sustituir la fila:
```
| `novactl` / `scripts` | Emite comandos NATS ... |
```
Por:
```
| `novactl` | Emite comandos NATS `StartSpeechCaptureCommand` y `StopSpeechCaptureCommand` |
```

**Sección "Modos de operación" — Modo Push-to-Talk (líneas ~175-181):**
Sustituir:
```bash
# Al presionar / ejecutar -> invoca novactl start-capture
mic-start.sh

# Al soltar / ejecutar -> invoca novactl stop-capture
mic-stop.sh
```
Por:
```bash
# Al presionar la tecla configurada -> inicia captura
novactl start-capture

# Al soltar / volver a pulsar -> detiene captura
novactl stop-capture
```

**Sección "Integración con hotkeys" (Sección 12 del README) (D-02):**
Actualizar el bloque de ejemplo sustituyendo la referencia a `mic-start.sh` / `mic-stop.sh` por las invocaciones directas a `novactl start-capture` y `novactl stop-capture`.

**Sección "Flujo de ejecución" — Inicio y Fin de grabación:**
Sustituir en ambos bloques las referencias `ej: novactl start-capture o mic-start.sh` por simplemente `novactl start-capture` (y equivalente para stop).

**Sección "Estructura del proyecto" (árbol de directorios):**
Eliminar las entradas:
```
├── scripts/
│   ├── mic-start.sh             # Script de control (invoca novactl start-capture)
│   └── mic-stop.sh              # Script de control (invoca novactl stop-capture)
```

### 4.2 Cambios en `home-assistant/scripts/install.sh`

**Bloque a eliminar (líneas ~279–297):**
```bash
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
```

**Sustitución:** El bloque anterior se reemplaza por las dos líneas estrictamente necesarias para garantizar la existencia del directorio (ya que el wrapper de `novactl` las necesita). El título del comentario y el `log_info` de la sección se actualizan para referirse exclusivamente a `novactl`:
```bash
# ─── Instalar wrapper de novactl ─────────────────────────────────────────────
log_info "Instalando wrapper de novactl CLI..."
mkdir -p "$HOME/.local/bin"
```

**Mensaje de "Próximos pasos" (línea ~465):**
Sustituir:
```bash
echo "  1. Configura un atajo de teclado que ejecute: mic-toggle"
```
Por:
```bash
echo "  1. Configura un atajo de teclado que ejecute: novactl start-capture / novactl stop-capture"
```

### 4.3 Cambios en `home-assistant/scripts/uninstall.sh`

**Sección de eliminación de scripts (líneas ~88–95):**
Sustituir:
```bash
log_info "Eliminando scripts de control del micrófono y novactl CLI..."
for script in mic-toggle mic-start mic-stop novactl; do
```
Por:
```bash
log_info "Eliminando CLI novactl..."
for script in novactl; do
```

### 4.4 Cambios en `home-assistant/docs/installation.md`

**Paso 8 — Configurar el atajo de teclado (líneas ~241–280):**

Sustituir el contenido actual del Paso 8 por:

```markdown
## Paso 8: Configurar el atajo de teclado (Hotkey)

El script `install.sh` ha instalado `novactl` en `~/.local/bin/novactl`.
Configura un atajo de teclado en tu entorno de escritorio para invocar directamente los comandos de captura.

### Modo Push-to-Talk (recomendado)

Asigna **dos atajos de teclado** en tu gestor de atajos:
- **Inicio de captura:** `novactl start-capture`
- **Fin de captura:** `novactl stop-capture`

### GNOME
1. Ve a **Configuración → Teclado → Atajos de teclado → Ver y personalizar atajos**.
2. Haz clic en **+** para añadir un atajo personalizado.
3. **Nombre:** `Nova — Iniciar captura` | **Comando:** `novactl start-capture` | **Atajo:** `Super + F8`
4. Repite el proceso: **Nombre:** `Nombre:` `Nova — Detener captura` | **Comando:** `novactl stop-capture` | **Atajo:** `Super + F9`

### KDE Plasma
1. Ve a **Configuración del sistema → Atajos → Atajos personalizados**.
2. Crea dos atajos de tipo **Ejecutar comando**:
   - `novactl start-capture` → atajo deseado.
   - `novactl stop-capture` → atajo deseado.

### sxhkd (bspwm, i3, Openbox)
Añade esto a `~/.config/sxhkd/sxhkdrc`:
```ini
super + F8
    novactl start-capture
super + F9
    novactl stop-capture
```
Luego recarga sxhkd: `pkill -USR1 sxhkd`

### Hyprland (Wayland)
Añade a `~/.config/hypr/hyprland.conf`:
```ini
bind = SUPER, F8, exec, novactl start-capture
bind = SUPER, F9, exec, novactl stop-capture
```
```

### 4.5 Actualización de `docs/adr/adr-021-deteccion-habla-eventos-mic-daemon.md` (D-01)

Añadir el siguiente bloque al final del archivo `ADR-021`:

```markdown
### Addendum (2026-08-02): Eliminación definitiva de scripts legacy
El punto 4 de las decisiones de este ADR establecía la actualización de `scripts/mic-start.sh` y `scripts/mic-stop.sh` para delegar en `novactl`. Tras la consolidación total del CLI oficial `novactl` (ADR-020), dichos scripts han sido eliminados definitivamente del ecosistema. La interacción CLI se realiza de forma directa e incontestable a través de `novactl start-capture` y `novactl stop-capture`.
```

---

## 5. Casos de Borde y Manejo de Errores

| Caso de Borde | Comportamiento Esperado | Implementación Técnica |
| :--- | :--- | :--- |
| **Instalaciones previas con `mic-toggle` / `mic-start` / `mic-stop` en `~/.local/bin/`** | Los binarios legacy no son eliminados automáticamente por el nuevo `install.sh`. | Documentar en `CHANGELOG.md` que los usuarios con instalaciones previas deben eliminar los scripts manualmente (`rm -f ~/.local/bin/mic-toggle ~/.local/bin/mic-start ~/.local/bin/mic-stop`) o ejecutar `uninstall.sh` antes de reinstalar. |
| **`hid-daemon` configurado con `mic-start` / `mic-stop`** | `hid-daemon` no referencia estos scripts en su código fuente. Sin impacto. | No requiere acción. |
| **Refinamiento histórico `mic_scripts_novactl_integration_refinement.md` en `mic-daemon`** | El documento documenta una fase de transición ya superada. | Actualizar el campo `Estado` del documento a `Superado` con una nota. No modificar el contenido histórico. |
| **Suite de tests de `mic-daemon` tras eliminar `test_scripts.py`** | `pytest` no debe recoger el fichero eliminado ni arrojar errores. | Verificar ejecución limpia de `pytest tests/` en `mic-daemon` tras la eliminación. |

---

## 6. Estrategia de Testing

### Pruebas manuales en `mic-daemon`
1. Ejecutar `pytest tests/` y verificar que la suite completa pasa sin errores.
2. Verificar con `ls mic-daemon/scripts/` que el directorio no existe o está vacío.

### Pruebas manuales en `home-assistant`
1. Ejecutar `./scripts/install.sh` y verificar:
   - `~/.local/bin/mic-start`, `~/.local/bin/mic-stop` y `~/.local/bin/mic-toggle` **no** son creados.
   - `~/.local/bin/novactl` **sí** es creado y ejecutable (`novactl --help` retorna código 0).
2. Ejecutar `./scripts/uninstall.sh` y verificar:
   - Se elimina `~/.local/bin/novactl`.
   - No se generan errores por intentar eliminar scripts de micrófono.
3. Ejecutar `./scripts/healthcheck.sh` y verificar que el check de `novactl CLI` sigue en verde.

---

## 7. Plan de Implementación (Checklist)

- [ ] **Tarea 1: Eliminación de scripts en `mic-daemon`**
  - [ ] Eliminar `mic-daemon/scripts/mic-start.sh`
  - [ ] Eliminar `mic-daemon/scripts/mic-stop.sh`
  - [ ] Eliminar `mic-daemon/scripts/mic-toggle.sh`
  - [ ] Eliminar el directorio `mic-daemon/scripts/` (queda vacío)
  - [ ] Eliminar `mic-daemon/tests/test_scripts.py`

- [ ] **Tarea 2: Actualizar `mic-daemon/README.md`**
  - [ ] Eliminar la línea `o scripts de control: mic-start.sh / mic-stop.sh` del diagrama ASCII de arquitectura
  - [ ] Actualizar la tabla de componentes eliminando la mención a `/ scripts`
  - [ ] Actualizar la sección "Modos de operación" sustituyendo `mic-start.sh` / `mic-stop.sh` por `novactl start-capture` / `novactl stop-capture`
  - [ ] Actualizar la sección "Integración con hotkeys" (sección 12 del README) sustituyendo referencias a scripts por `novactl start-capture` y `novactl stop-capture` (D-02)
  - [ ] Actualizar los bloques de "Flujo de ejecución" eliminando las referencias a los scripts
  - [ ] Actualizar la sección "Estructura del proyecto" eliminando `scripts/` del árbol

- [ ] **Tarea 3: Actualizar `mic-daemon/CHANGELOG.md`**
  - [ ] Añadir entrada `[Sin publicar]` con categoría `Eliminado` documentando la supresión de los tres scripts y de `tests/test_scripts.py`

- [ ] **Tarea 4: Marcar el refinamiento histórico de `mic-daemon` como superado**
  - [ ] Actualizar el campo `Estado` de `mic-daemon/doc/refinements/mic_scripts_novactl_integration_refinement.md` añadiendo la nota `Superado — scripts eliminados, novactl es el único punto de entrada CLI`

- [ ] **Tarea 5: Actualizar `home-assistant/scripts/install.sh`**
  - [ ] Eliminar el bloque de copia de `mic-toggle.sh`, `mic-start.sh` y `mic-stop.sh` a `~/.local/bin/`
  - [ ] Actualizar el comentario y `log_info` de la sección para referirse exclusivamente a `novactl`
  - [ ] Actualizar el mensaje de "Próximos pasos" sustituyendo `mic-toggle` por `novactl start-capture / novactl stop-capture`

- [ ] **Tarea 6: Actualizar `home-assistant/scripts/uninstall.sh`**
  - [ ] Eliminar `mic-toggle`, `mic-start` y `mic-stop` del bucle de limpieza de `~/.local/bin/`
  - [ ] Actualizar el mensaje de `log_info` de la sección

- [ ] **Tarea 7: Actualizar `home-assistant/docs/installation.md`**
  - [ ] Reescribir el Paso 8 para documentar la integración de hotkeys con `novactl start-capture` / `novactl stop-capture`
  - [ ] Eliminar las instrucciones de copia manual de `mic-toggle.sh` a `~/.local/bin/`
  - [ ] Actualizar los ejemplos de GNOME, KDE, sxhkd e Hyprland

- [ ] **Tarea 8: Actualizar `home-assistant/CHANGELOG.md` (D-04)**
  - [ ] Añadir entrada en `[Sin publicar]` con categorías `Eliminado` y `Cambiado` documentando todos los cambios de esta feature
  - [ ] Incluir explícitamente la nota de migración manual para instalaciones previas: `rm -f ~/.local/bin/mic-toggle ~/.local/bin/mic-start ~/.local/bin/mic-stop`

- [ ] **Tarea 9: Actualizar `docs/adr/adr-021-deteccion-habla-eventos-mic-daemon.md` con Addendum (D-01)**
  - [ ] Añadir sección `Addendum (2026-08-02)` al final de ADR-021 indicando la supresión completa del punto 4 por eliminación de los scripts legacy.

- [ ] **Tarea 10: Verificación E2E**
  - [ ] Ejecutar `./scripts/install.sh` en entorno limpio y verificar que no se crean scripts legacy en `~/.local/bin/`
  - [ ] Ejecutar `./scripts/healthcheck.sh` y verificar que `novactl CLI` sigue en verde
  - [ ] Ejecutar `pytest tests/` en `mic-daemon` y verificar que la suite pasa sin errores
