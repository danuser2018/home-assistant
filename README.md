![nova-2](assets/nova-2.png)

# 🏠 Home Assistant

Asistente de voz **100% local** para Linux. Procesa tu voz sin conexión a Internet, sin servicios en la nube y sin LLMs pesados. Diseñado para funcionar en hardware de consumo modesto con un tiempo de respuesta bajo.

---

## ¿Cómo funciona?

1. **Hablas** → Pulsas un hotkey y dices lo que necesitas.
2. **Tu voz se transcribe** → El modelo Whisper (local) convierte el audio a texto.
3. **El asistente decide** → El Orchestrator selecciona la acción correcta mediante un motor determinista de palabras clave.
4. **Responde en voz** → El motor Piper TTS sintetiza la respuesta y la reproduce por los altavoces.

Todo ocurre en tu equipo, en pocos segundos.

---

## Arquitectura

El sistema está formado por **7 microservicios** con responsabilidades bien delimitadas:

| Servicio | Tipo | Función |
|---|---|---|
| `mic-daemon` | Systemd (host) | Graba voz del micrófono al pulsar un hotkey |
| `speaker-watchdog` | Systemd (host) | Reproduce las respuestas de audio por los altavoces |
| `interaction-manager` | Docker | Coordina el flujo completo (STT → Orchestrator → TTS) |
| `stt-capability` | Docker | Convierte voz a texto con Faster-Whisper |
| `orchestrator` | Docker | Selecciona y ejecuta la acción correcta |
| `tts-capability` | Docker | Convierte texto a voz con Piper TTS |
| `system-service` | Docker | Expone información de identidad del sistema (Nova) |

Los servicios del host se instalan como **systemd user services** para tener acceso directo al servidor de audio. Los servicios Docker se gestionan con un único `docker-compose.yml` y sus imágenes están disponibles en DockerHub.

> Consulta [docs/architecture.md](docs/architecture.md) para una descripción técnica detallada y el diagrama de flujo completo.

---

## Instalación rápida

### Requisitos previos

- Linux (Debian/Ubuntu, Fedora o Arch)
- Docker y Docker Compose
- Python 3.10+
- `mpv` y `libportaudio2`

### Pasos

```bash
# 1. Clonar los repositorios
git clone https://github.com/danuser2018/home-assistant.git
git clone https://github.com/danuser2018/mic-daemon.git
git clone https://github.com/danuser2018/speaker-watchdog.git

# 2. Muévete al directorio raiz de home-assistant
cd home-assistant

# 3. Crear el directorio data
mkdir data

# 4. Copiar y editar la configuración
cp .env.example .env

# 5. Edita .env y ajusta HOME_ASSISTANT_DATA_DIR a tu ruta
nano .env

# 6. Instalar los servicios del host (mic-daemon y speaker-watchdog)
chmod +x scripts/install.sh
./scripts/install.sh

```

> La guía completa paso a paso, incluyendo la configuración del hotkey para GNOME, KDE, sxhkd e Hyprland, está en [docs/installation.md](docs/installation.md).

---

## Documentación

| Documento | Descripción |
|---|---|
| [docs/architecture.md](docs/architecture.md) | Arquitectura del sistema, componentes y decisiones de diseño |
| [docs/services.md](docs/services.md) | Catálogo de los 7 servicios con sus APIs y configuración |
| [docs/installation.md](docs/installation.md) | Guía de instalación paso a paso |
| [docs/troubleshooting.md](docs/troubleshooting.md) | Solución a los problemas más comunes |

---

## Gestión del sistema

```bash
# Ver el estado de todos los servicios
./scripts/healthcheck.sh

# Actualizar las imágenes Docker
./scripts/update.sh

# Desinstalar
./scripts/uninstall.sh

# Logs de los servicios del host
journalctl --user -u mic-daemon -f
journalctl --user -u speaker-watchdog -f

# Logs de los servicios Docker
docker compose logs -f
```

---

## Contribuciones

Antes de contribuir, consulta [CONTRIBUTING.md](CONTRIBUTING.md).  
El historial de cambios está en [CHANGELOG.md](CHANGELOG.md).

---

## Licencia

Pendiente de definir por el propietario del repositorio.
