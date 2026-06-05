# Troubleshooting

Esta guía recoge los problemas más comunes que puedes encontrar durante la instalación o el uso del asistente, junto con sus soluciones.

---

## Índice de Problemas

1. [El micrófono no graba nada](#1-el-micrófono-no-graba-nada)
2. [No se escucha nada por los altavoces](#2-no-se-escucha-nada-por-los-altavoces)
3. [Los contenedores Docker no arrancan](#3-los-contenedores-docker-no-arrancan)
4. [El servicio STT tarda mucho o devuelve error](#4-el-servicio-stt-tarda-mucho-o-devuelve-error)
5. [Se queda un archivo en `data/processing/`](#5-se-queda-un-archivo-en-dataprocessing)
6. [Aparecen archivos en `data/error/`](#6-aparecen-archivos-en-dataerror)
7. [Los servicios de systemd no arrancan](#7-los-servicios-de-systemd-no-arrancan)
8. [El hotkey no hace nada](#8-el-hotkey-no-hace-nada)
9. [El asistente no entiende lo que digo](#9-el-asistente-no-entiende-lo-que-digo)
10. [El asistente responde "no he entendido" a todo](#10-el-asistente-responde-no-he-entendido-a-todo)

---

## 1. El micrófono no graba nada

**Síntoma:** Pulsas el hotkey, hablas, pero no aparece ningún archivo en `data/input/`.

### Verificar que mic-daemon está activo

```bash
systemctl --user status mic-daemon
```

Si aparece `inactive` o `failed`:
```bash
systemctl --user start mic-daemon
journalctl --user -u mic-daemon -f  # Ver el error en tiempo real
```

### Verificar el archivo de estado (flag)

El hotkey debe crear este archivo:
```bash
ls -la /tmp/voice_assistant/recording.flag
```

Si el archivo no aparece al pulsar el hotkey, el problema está en el script `mic-toggle.sh` o en la configuración del atajo de teclado. Prueba a ejecutarlo manualmente:
```bash
~/.local/bin/mic-toggle
ls /tmp/voice_assistant/  # Debe aparecer recording.flag
~/.local/bin/mic-toggle
ls /tmp/voice_assistant/  # Debe desaparecer
```

### Verificar permisos de audio

El usuario que ejecuta el daemon debe pertenecer al grupo `audio`:
```bash
groups $USER | grep audio
```

Si no aparece `audio`:
```bash
sudo usermod -aG audio $USER
# ⚠️ Cierra sesión y vuelve a entrar
```

### Verificar el micrófono disponible

```bash
python3 -c "import sounddevice as sd; print(sd.query_devices())"
```

Si da error de librería no encontrada:
```bash
sudo apt install libportaudio2
```

Si el dispositivo correcto no es el predeterminado, configura `MIC_DEVICE` en `config/mic-daemon.env` con el índice del dispositivo correcto.

### Prueba de grabación manual

```bash
python3 -c "
import sounddevice as sd, soundfile as sf, numpy as np
data = sd.rec(int(3 * 16000), samplerate=16000, channels=1, dtype='int16')
print('Grabando 3 segundos...')
sd.wait()
sf.write('/tmp/test-mic.wav', data, 16000)
print('OK: /tmp/test-mic.wav')
"
```

---

## 2. No se escucha nada por los altavoces

**Síntoma:** Los archivos de audio aparecen en `data/output/` pero no se reproducen, o el archivo se queda ahí sin ser procesado.

### Verificar que speaker-watchdog está activo

```bash
systemctl --user status speaker-watchdog
journalctl --user -u speaker-watchdog -f
```

### Verificar que mpv está instalado

```bash
which mpv
```

Si no está instalado:
```bash
sudo apt install mpv        # Debian/Ubuntu
sudo dnf install mpv        # Fedora
sudo pacman -S mpv          # Arch
```

### Prueba de reproducción manual

Copia un archivo `.wav` en `data/output/` y observa los logs de `speaker-watchdog`:
```bash
cp /tmp/test-mic.wav data/output/test.wav
journalctl --user -u speaker-watchdog -f
```

### Problema con PulseAudio / PipeWire

Si `mpv` no tiene acceso al servidor de audio del usuario:
```bash
# Verificar que PipeWire/PulseAudio está activo en la sesión
systemctl --user status pipewire
systemctl --user status pulseaudio
```

Asegúrate de que el archivo `systemd/speaker-watchdog.service` incluye:
```ini
Environment=XDG_RUNTIME_DIR=/run/user/1000
```

(Reemplaza `1000` con tu UID real: `id -u`)

---

## 3. Los contenedores Docker no arrancan

**Síntoma:** `docker compose ps` muestra contenedores en estado `Exit` o `Restarting`.

### Ver los logs del contenedor con fallos

```bash
docker compose logs interaction-manager
docker compose logs stt-capability
docker compose logs orchestrator
docker compose logs tts-capability
```

### La carpeta `data/` no está montada correctamente

Verifica que la variable `HOME_ASSISTANT_DATA_DIR` en tu `.env` apunta a la ruta correcta y que la carpeta existe:
```bash
cat .env | grep DATA_DIR
ls -la data/
```

Si la carpeta no existe:
```bash
mkdir -p data/{input,processing,output,error}
```

### Sin suficiente memoria RAM

El servicio `stt-capability` carga el modelo Whisper en RAM. Si el sistema se queda sin memoria, el contenedor se reiniciará en bucle. 

Comprueba la memoria disponible:
```bash
free -h
```

Si tienes poca RAM, usa un modelo más pequeño. Edita `config/assistant.env`:
```env
WHISPER_MODEL=tiny   # ~400 MB en lugar de ~750 MB del modelo base
```

Y reinicia:
```bash
docker compose down && docker compose up -d
```

### El puerto ya está en uso

Si otro proceso usa el mismo puerto:
```bash
docker compose logs | grep "address already in use"
```

Revisa `docker-compose.yml` y cambia el mapeo de puertos si es necesario.

---

## 4. El servicio STT tarda mucho o devuelve error

**Síntoma:** El `interaction-manager` tarda decenas de segundos en procesar cada petición, o se registran errores de timeout en los logs.

### El modelo Whisper aún está cargando

La primera vez que arranca el contenedor `stt-capability`, descarga y carga el modelo en memoria, lo cual puede tardar de 30 segundos a 2 minutos dependiendo del modelo y el hardware.

Espera a que el servicio esté listo:
```bash
curl http://localhost:8001/ready
# Espera hasta obtener: {"status": "ready"}
```

### Verificar el endpoint STT directamente

```bash
curl -X POST \
  -F "audio=@data/input/$(ls data/input/ | head -1)" \
  http://localhost:8001/v1/transcriptions
```

---

## 5. Se queda un archivo en `data/processing/`

**Síntoma:** Hay un `.wav` en `data/processing/` pero el sistema ya no está haciendo nada.

Esto indica que el `interaction-manager` falló durante el procesamiento de ese archivo y no lo movió a `error/` correctamente (por ejemplo, el contenedor fue reiniciado a mitad de proceso).

**Solución:** Mueve manualmente el archivo de vuelta a `input/` para que sea reprocesado, o a `error/` para descartarlo:

```bash
# Reprocesar
mv data/processing/*.wav data/input/

# O descartar
mv data/processing/*.wav data/error/
```

---

## 6. Aparecen archivos en `data/error/`

**Síntoma:** Después de hablar, el archivo aparece en `data/error/` en lugar de escucharse la respuesta.

Los archivos en `data/error/` indican que alguno de los servicios (STT, Orchestrator o TTS) devolvió un error durante el procesamiento del audio.

### Diagnóstico

```bash
# Ver qué ocurrió con ese archivo
docker compose logs interaction-manager | tail -50

# Nombre del archivo para correlacionar con el timestamp
ls -la data/error/
```

### Causas comunes

| Causa | Solución |
|---|---|
| El servicio STT no estaba listo (aún cargando el modelo) | Esperar más tiempo tras el arranque y volver a intentarlo |
| El audio era demasiado corto o no tenía voz | Hablar con más claridad y durante más tiempo |
| El audio estaba corrupto | Revisar la configuración del micrófono |
| El servicio Orchestrator o TTS no responde | Comprobar `docker compose ps` y los logs |

---

## 7. Los servicios de systemd no arrancan

**Síntoma:** `systemctl --user status mic-daemon` muestra `failed`.

### Ver el error completo

```bash
journalctl --user -u mic-daemon --since "5 minutes ago"
```

### El entorno virtual de Python no existe

```bash
# ¿Existe el venv?
ls ~/.local/share/home-assistant/mic-daemon/venv/

# Si no existe, ejecuta de nuevo el script de instalación
./scripts/install.sh
```

### Ruta incorrecta en el archivo .service

Comprueba que las rutas en `~/.config/systemd/user/mic-daemon.service` son correctas para tu usuario:
```bash
cat ~/.config/systemd/user/mic-daemon.service
```

Tras cualquier modificación:
```bash
systemctl --user daemon-reload
systemctl --user restart mic-daemon
```

### Recarga completa del demonio

```bash
systemctl --user daemon-reload
systemctl --user reset-failed
systemctl --user start mic-daemon
```

---

## 8. El hotkey no hace nada

**Síntoma:** Pulsas el atajo de teclado pero no ocurre nada (no aparece `recording.flag`, mic-daemon no reacciona).

### Prueba el script manualmente

```bash
~/.local/bin/mic-toggle
```

Si funciona desde la terminal pero no con el hotkey, el problema está en la configuración del gestor de atajos de teclado, no en el asistente.

### sxhkd no recarga la configuración

```bash
pkill -USR1 sxhkd
```

### Comprueba que el script es ejecutable

```bash
ls -la ~/.local/bin/mic-toggle
# Debe mostrar -rwxr-xr-x
chmod +x ~/.local/bin/mic-toggle
```

### El PATH no incluye `~/.local/bin`

Algunos gestores de hotkeys no heredan el PATH completo del usuario:
```bash
echo $PATH | grep ".local/bin"
```

Si no aparece, usa la **ruta absoluta** en la configuración del hotkey:
```
/home/TU_USUARIO/.local/bin/mic-toggle
```

---

## 9. El asistente no entiende lo que digo

**Síntoma:** La transcripción del servicio STT es incorrecta o vacía.

### Calidad del audio

- Habla a unos 30-50 cm del micrófono, con voz clara.
- Evita ruidos de fondo intensos.
- Comprueba que el micrófono correcto está siendo usado (ver [sección 1](#1-el-micrófono-no-graba-nada)).

### Verificar la transcripción directamente

Después de grabar un archivo (que estará en `data/error/` si falla el pipeline), prueba a enviárselo directamente al STT:
```bash
curl -X POST \
  -F "audio=@data/error/NOMBRE_DEL_ARCHIVO.wav" \
  -F "language=es" \
  http://localhost:8001/v1/transcriptions
```

### Usar un modelo Whisper más grande

Si la transcripción es consistentemente mala, prueba a cambiar al modelo `small` editando `config/assistant.env`:
```env
WHISPER_MODEL=small
```

Y reinicia los contenedores:
```bash
docker compose down && docker compose up -d
```

---

## 10. El asistente responde "no he entendido" a todo

**Síntoma:** El pipeline funciona (hay respuesta de audio), pero la respuesta siempre es del `FallbackPlugin`.

Esto indica que el **Orchestrator** no reconoce la intención del texto transcrito.

### Ver qué texto llega al Orchestrator

```bash
docker compose logs orchestrator | tail -20
```

### Causas comunes

- El texto transcrito no contiene las keywords de ningún plugin instalado.
- El idioma del texto no coincide con el configurado en los plugins.
- No hay plugins instalados que cubran esa funcionalidad.

Consulta la documentación del Orchestrator para ver cómo añadir nuevos plugins o extender los existentes.

---

## Comandos de Diagnóstico Rápido

```bash
# Estado general del sistema
./scripts/healthcheck.sh

# Logs de todos los contenedores en tiempo real
docker compose logs -f

# Estado de todos los servicios de systemd
systemctl --user status mic-daemon speaker-watchdog

# Contenido de las carpetas de datos (para ver el flujo)
watch -n 1 "ls -la data/input/ data/processing/ data/output/ data/error/"

# Reinicio completo del sistema
docker compose restart
systemctl --user restart mic-daemon speaker-watchdog
```
