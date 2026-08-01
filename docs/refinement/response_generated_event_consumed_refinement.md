# Refinamiento de Feature: Consumo del Evento `SpeechCapturedEvent` en `interaction-manager` (Fase 5 Refactor de Entrada)

- **Documento de Origen**: [response_generated_event_consumed.md](file:///home/danuser2018/workspace/home-assistant/docs/features/response_generated_event_consumed.md)
- **Fecha**: 2026-08-01
- **Estado**: Refinado / Listo para Desarrollo

---

## 1. Resumen y Contexto de Negocio

### Objetivo Principal
Sustituir el mecanismo de detección de nuevas locuciones en `interaction-manager` (basado hasta ahora en la monitorización del sistema de archivos mediante `watchdog` o polling periódico) por la recepción asíncrona del evento de dominio `SpeechCapturedEvent`. 

Al finalizar esta fase, `interaction-manager` dejará de supervisar el directorio compartido de entrada y reaccionará de forma reactiva e inmediata a las notificaciones emitidas por `mic-daemon` a través del broker NATS. El flujo posterior del pipeline de interacción (STT -> Orchestrator -> TTS) y el comportamiento observable del asistente Nova permanecerán inalterados.

### Actores e Interacciones
- **Emisor / Publicador**: `mic-daemon` (componente de captura de audio del host) emite el evento de dominio `SpeechCapturedEvent` al subject `event.speech.captured` tras almacenar la locución `.wav` en el volumen compartido.
- **Receptor / Suscriptor**: `interaction-manager` (coordinador del pipeline) escucha el evento `SpeechCapturedEvent` mediante `nova-event-bus`, resuelve la ruta física local del fichero de audio y activa la ejecución del pipeline de interacción.

---

## 2. Análisis de Servicios e Impacto

| Servicio | Nivel de Impacto | Componentes / Archivos Afectados | Tipo de Cambio | Descripción del Cambio |
| :--- | :--- | :--- | :--- | :--- |
| `interaction-manager` | **Alto** | `requirements.txt`<br>`app/config/settings.py`<br>`app/events.py`<br>`app/services/event_subscriber.py`<br>`app/main.py`<br>`app/services/file_watcher.py`<br>`docker-compose.yml`<br>`tests/test_event_subscriber.py`<br>`tests/test_watcher.py` | **Modificar / Eliminar** | Incorporar la dependencia `nova-event-bus`. Definir el evento `SpeechCapturedEvent` en `app/events.py`. Implementar `InteractionEventSubscriber` en `app/services/event_subscriber.py`. Modificar `app/main.py` para gestionar la conexión del event bus en el arranque/parada. Eliminar o deprecar `file_watcher.py` y la dependencia `watchdog`. Configurar `NATS_URL` en `settings.py`. Reemplazar `test_watcher.py` por `test_event_subscriber.py`. |
| `home-assistant` | **Medio** | `docs/services.md`<br>`docs/architecture.md`<br>`config/interaction-manager.env` | **Modificar** | Actualizar la especificación del catálogo de servicios y la máquina de estados de `interaction-manager`. Añadir `NATS_URL` a `config/interaction-manager.env` y marcar `POLL_INTERVAL_SECONDS` como obsoleta. |
| `mic-daemon` | **Ninguno** | N/A | **Ninguno** | Ya publica `SpeechCapturedEvent` en `event.speech.captured` (ADR-022). |
| `orchestrator` | **Ninguno** | N/A | **Ninguno** | Sin cambios en el contrato ni en la comunicación HTTP. |
| `stt-capability` | **Ninguno** | N/A | **Ninguno** | Sin cambios. |
| `tts-capability` | **Ninguno** | N/A | **Ninguno** | Sin cambios. |

---

## 3. Especificación de Comportamiento (Criterios de Aceptación)

### Scenario 1: Successful subscription to SpeechCapturedEvent on startup
```gherkin
Given that interaction-manager service starts up
When the main application loop initializes
Then it connects NatsEventBus to the configured NATS_URL
And it subscribes InteractionEventSubscriber to SpeechCapturedEvent on subject "event.speech.captured"
And logs an informational message indicating active event listening
```

### Scenario 2: Reaction to SpeechCapturedEvent and pipeline invocation
```gherkin
Given that interaction-manager is running and subscribed to NATS events
When a SpeechCapturedEvent is received with audio_path "20260801/abcd1234.wav"
Then interaction-manager resolves the absolute file path as "/data/input/20260801/abcd1234.wav"
And it invokes interaction_pipeline.process_interaction with the resolved path
And the interaction pipeline processes the audio through STT, Orchestrator, and TTS seamlessly
```

### Scenario 3: Error handling when audio file is missing on shared volume
```gherkin
Given that interaction-manager receives a SpeechCapturedEvent with audio_path "non_existent.wav"
When interaction-manager attempts to resolve and process the audio file
Then it detects that the file does not exist at the resolved path
And it logs an error specifying the missing file
And it triggers error_handler.handle_error without crashing the NATS event subscriber loop
```

### Scenario 4: Exception containment during interaction pipeline execution
```gherkin
Given that a SpeechCapturedEvent triggers audio processing
When an unhandled exception occurs inside interaction_pipeline.process_interaction
Then the event handler captures the exception
And delegates error response generation to error_handler.handle_error
And the NatsEventBus connection remains open and ready for subsequent events
```

### Scenario 5: Graceful service shutdown
```gherkin
Given that interaction-manager receives a SIGINT or SIGTERM signal
When the service shutdown sequence is executed
Then NatsEventBus disconnects cleanly from NATS broker
And unsubscribes from subject "event.speech.captured"
And logs a clean shutdown completion message
```

### Scenario 6: Idempotent handling of duplicate SpeechCapturedEvent delivery
```gherkin
Given that interaction-manager is processing or has processed a SpeechCapturedEvent for "20260801/abcd1234.wav"
When a duplicate SpeechCapturedEvent for the same audio_path is received
Then interaction-manager checks the existence of the source file at resolved_path
And if the source file has already been moved to processing or output, it logs a warning about duplicate event delivery
And gracefully completes without crashing or re-executing the interaction pipeline
```

---

## 4. Diseño Técnico y Contratos

### 4.1 Contrato del Evento (`interaction-manager/app/events.py`)

```python
from dataclasses import dataclass
from nova_event_bus import Event, event

@event("event.speech.captured")
@dataclass
class SpeechCapturedEvent(Event):
    """Domain event received when mic-daemon completes audio capture."""
    correlation_id: str
    channel: str
    audio_path: str
```

### 4.2 Arquitectura del Suscriptor (`interaction-manager/app/services/event_subscriber.py`)

```python
import os
import logging
import asyncio
from typing import Callable, Awaitable
from nova_event_bus import EventBus
from app.config import settings
from app.events import SpeechCapturedEvent
from app.services import interaction_pipeline, error_handler

logger = logging.getLogger(__name__)

class InteractionEventSubscriber:
    def __init__(self, event_bus: EventBus) -> None:
        self._event_bus = event_bus

    async def start(self) -> None:
        await self._event_bus.connect()
        await self._event_bus.subscribe(SpeechCapturedEvent, self._handle_speech_captured)
        logger.info("InteractionEventSubscriber successfully subscribed to event.speech.captured")

    async def stop(self) -> None:
        await self._event_bus.disconnect()
        logger.info("InteractionEventSubscriber disconnected from NATS broker")

    async def _handle_speech_captured(self, evt: SpeechCapturedEvent) -> None:
        logger.info(
            f"Received SpeechCapturedEvent: correlation_id={evt.correlation_id}, "
            f"channel={evt.channel}, audio_path={evt.audio_path}"
        )
        
        # Resolución de la ruta física usando la configuración local de INPUT_DIR
        resolved_path = os.path.normpath(os.path.join(settings.INPUT_DIR, evt.audio_path))
        
        # Protección contra path traversal
        if not resolved_path.startswith(os.path.abspath(settings.INPUT_DIR)):
            logger.error(f"Path traversal detected for audio_path: {evt.audio_path}")
            return

        if not os.path.exists(resolved_path):
            logger.error(f"Audio file not found at resolved path: {resolved_path}")
            await error_handler.handle_error(FileNotFoundError(f"File missing: {resolved_path}"))
            return

        try:
            await self._process_audio_file(resolved_path)
        except Exception as e:
            logger.error(f"Error processing audio file {resolved_path}: {e}", exc_info=True)
            await error_handler.handle_error(e)

    async def _process_audio_file(self, file_path: str) -> None:
        start_time = time.perf_counter()
        filename = os.path.basename(file_path)
        processing_path = os.path.join(settings.PROCESSING_DIR, filename)
        output_path = os.path.join(settings.OUTPUT_DIR, filename)
        error_path = os.path.join(settings.ERROR_DIR, filename)

        logger.info(f"Processing audio file: {file_path}")

        try:
            shutil.move(file_path, processing_path)
            logger.debug(f"Moved {file_path} to {processing_path}")
        except Exception as e:
            elapsed = time.perf_counter() - start_time
            logger.error(f"Failed to move file to processing after {elapsed:.3f}s: {e}")
            await self._handle_processing_error(e, filename, output_path)
            return

        feedback_output_path = os.path.join(settings.OUTPUT_DIR, f"interaction_{filename}")
        feedback_copied = False

        try:
            if os.path.exists(settings.INTERACTION_AUDIO_FILE):
                await asyncio.to_thread(shutil.copy, settings.INTERACTION_AUDIO_FILE, feedback_output_path)
                logger.info("Started playing interaction feedback audio")
                feedback_copied = True

            audio_bytes = await interaction_pipeline.process_interaction(processing_path)

            if feedback_copied:
                self._remove_file_silent(feedback_output_path)

            with open(output_path, "wb") as f:
                f.write(audio_bytes)

            elapsed = time.perf_counter() - start_time
            logger.info(f"Successfully processed interaction and saved to {output_path} in {elapsed:.3f}s")

            self._remove_file_silent(processing_path)

        except Exception as e:
            elapsed = time.perf_counter() - start_time
            logger.error(f"Error executing interaction pipeline for {filename} after {elapsed:.3f}s: {e}", exc_info=True)

            if feedback_copied:
                self._remove_file_silent(feedback_output_path)

            if os.path.exists(processing_path):
                try:
                    shutil.move(processing_path, error_path)
                    logger.info(f"Moved failed file to {error_path}")
                except Exception as move_e:
                    logger.error(f"Failed to move file to error directory: {move_e}")

            await self._handle_processing_error(e, filename, output_path)

    async def _handle_processing_error(self, error: Exception, filename: str, output_path: str) -> None:
        try:
            error_audio = await error_handler.handle_error(error)
            if error_audio:
                with open(output_path, "wb") as f:
                    f.write(error_audio)
                logger.info(f"Saved error response audio to {output_path}")
        except Exception as handler_e:
            logger.error(f"Failed to generate and save error audio for {filename}: {handler_e}")

    def _remove_file_silent(self, path: str) -> None:
        try:
            if os.path.exists(path):
                os.remove(path)
        except Exception as e:
            logger.warning(f"Failed to remove file {path}: {e}")
```

### 4.3 Puntos de Entrada y Ciclo de Vida (`interaction-manager/app/main.py`)

```python
import sys
import asyncio
import logging
from nova_event_bus import NatsEventBus
from app.config import settings
from app.services.event_subscriber import InteractionEventSubscriber

def setup_logging():
    logging.basicConfig(
        level=getattr(logging, settings.LOG_LEVEL.upper(), logging.INFO),
        format="%(asctime)s [%(levelname)s] %(name)s - %(message)s",
        handlers=[logging.StreamHandler(sys.stdout)]
    )

async def main():
    setup_logging()
    logger = logging.getLogger(__name__)
    logger.info("Starting Interaction Manager (Event-Driven Mode)")

    event_bus = NatsEventBus(url=settings.NATS_URL)
    subscriber = InteractionEventSubscriber(event_bus)

    await subscriber.start()

    try:
        # Mantiene el servicio activo escuchando eventos NATS
        while True:
            await asyncio.sleep(3600)
    except (KeyboardInterrupt, asyncio.CancelledError):
        logger.info("Stopping Interaction Manager...")
    finally:
        await subscriber.stop()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
```

### 4.4 Configuración y Variables de Entorno (`interaction-manager/app/config/settings.py`)

- **Añadir**: `NATS_URL = os.getenv("NATS_URL", "nats://localhost:4222")`
- **Deprecar**: `POLL_INTERVAL_SECONDS` (se elimina su uso del runtime).
- **Nota de Configuración**: El documento de origen utiliza `/data/audio` como ejemplo de ruta de volumen compartido. El valor real configurado en el ecosistema es `settings.INPUT_DIR` (por defecto `/data/input`, mapeado desde el host a `./data/input`). La resolución del archivo se realiza combinando `settings.INPUT_DIR` + `evt.audio_path`.

### 4.5 Decisión sobre creación de nuevo ADR

Conforme a la skill `architecture-decisions`, se evalúa la necesidad de un nuevo ADR:
- **Decisión: No se requiere un nuevo ADR.** Este cambio es la concreción directa de la **Fase 5 del Refactor de Entrada**, cuyos principios arquitectónicos, broker de mensajería (NATS) y convención de nombres (`event.speech.captured`) ya fueron formalizados y aceptados en los **ADR-017**, **ADR-018**, **ADR-021** y **ADR-022**.
- **Trazabilidad:** La documentación general del sistema (`docs/services.md` y `docs/architecture.md`) se actualizará como parte de las tareas del plan de implementación para reflejar el fin del modelo polling en `interaction-manager`.

---

## 5. Casos de Borde y Manejo de Errores

1. **Fichero de audio inexistente o ruta corrupta (`FileNotFoundError`)**:
   - `InteractionEventSubscriber` verifica la existencia física con `os.path.exists()`. Si el archivo no existe, emite un log de error y llama a `error_handler.handle_error()`.
2. **Ataques de Path Traversal (`../`)**:
   - Se valida que `os.path.normpath(os.path.join(settings.INPUT_DIR, evt.audio_path))` permanezca dentro del directorio base `settings.INPUT_DIR`. De lo contrario, se descarta el evento.
3. **Desconexión o caída del Broker NATS**:
   - `nova-event-bus` (a través de `nats-py`) gestiona la reconexión automática en segundo plano. Cuando el broker se restaura, las suscripciones activas se reanudan sin necesidad de reiniciar el servicio `interaction-manager`.
4. **Captura de excepciones en Callback de NATS**:
   - Toda excepción producida durante la ejecución de `_handle_speech_captured` se envuelve en un bloque `try/except` local. Esto garantiza que una falla en la interpretación de un audio nunca interrumpa el bucle asíncrono de eventos de NATS.

---

## 6. Estrategia de Testing

### Tests Unitarios
1. **`tests/test_event_subscriber.py`**:
   - Test de suscripción: Verificar que `subscriber.start()` invoca `connect()` y `subscribe()` con `SpeechCapturedEvent`.
   - Test de recepción exitosa: Simular la emisión de `SpeechCapturedEvent` y verificar que resuelve la ruta y ejecuta `_process_audio_file`.
   - Test de fichero no encontrado: Simular evento con `audio_path` inexistente y verificar la invocación de `error_handler.handle_error`.
   - Test de path traversal: Simular evento con `audio_path="../../etc/passwd"` y validar su descarte con log de error.
   - Test de desconexión: Verificar que `subscriber.stop()` invoca `disconnect()`.

### Tests de Integración
- Se testeará el comportamiento asíncrono instanciando `InteractionEventSubscriber` con una implementación mock de la interfaz `EventBus` (`nova-event-bus`), simulando la recepción de eventos `SpeechCapturedEvent` sin depender de una instancia real de `nats-server` durante la suite de CI unitaria/integración rápida (alineado con el patrón en `mic-daemon`).

### Limpieza de Tests Obsoletos
- Eliminar o refactorizar `tests/test_watcher.py`, removiendo dependencias de `watchdog.observers.Observer`.

---

## 7. Plan de Implementación

- [ ] **Tarea 1: Configuración y Dependencias en `interaction-manager`**
  - [ ] 1.1 Actualizar `interaction-manager/requirements.txt` añadiendo `nova-event-bus @ git+https://github.com/danuser2018/nova-event-bus.git@1.1.0` y eliminando `watchdog`.
  - [ ] 1.2 Actualizar `interaction-manager/app/config/settings.py` agregando la variable `NATS_URL` y removiendo `POLL_INTERVAL_SECONDS`.
  - [ ] 1.3 Actualizar `interaction-manager/docker-compose.yml` e `interaction-manager.env` añadiendo la variable `NATS_URL=nats://nats:4222`.

- [ ] **Tarea 2: Definición de Evento y Suscriptor NATS**
  - [ ] 2.1 Crear `interaction-manager/app/events.py` con la definición de la clase `SpeechCapturedEvent` decorada con `@event("event.speech.captured")`.
  - [ ] 2.2 Crear `interaction-manager/app/services/event_subscriber.py` implementando `InteractionEventSubscriber` con resolución de rutas, verificación de existencia y captura de excepciones.
  - [ ] 2.3 Desmantelar y eliminar `interaction-manager/app/services/file_watcher.py`.

- [ ] **Tarea 3: Puntos de Entrada y Ciclo de Vida**
  - [ ] 3.1 Refactorizar `interaction-manager/app/main.py` sustituyendo `file_watcher.start_watcher()` por la inicialización y ciclo de vida asíncrono de `InteractionEventSubscriber`.

- [ ] **Tarea 4: Estrategia de Testing**
  - [ ] 4.1 Crear `interaction-manager/tests/test_event_subscriber.py` cubriendo suscripción, recepción de eventos, resolución de rutas, manejo de errores y desconexión.
  - [ ] 4.2 Eliminar `interaction-manager/tests/test_watcher.py`.

- [ ] **Tarea 5: Documentación y Registros de Cambios**
  - [ ] 5.1 Actualizar `home-assistant/docs/services.md` actualizando el propósito, diagrama de flujo interno y tabla de variables de entorno de `interaction-manager`.
  - [ ] 5.2 Actualizar `home-assistant/docs/architecture.md` reflejando que el pipeline de voz es 100% orientados a eventos (sin polling de filesystem).
  - [ ] 5.3 Actualizar `interaction-manager/README.md` documentando el consumo de `SpeechCapturedEvent` y la configuración de `NATS_URL`.
  - [ ] 5.4 Actualizar `interaction-manager/CHANGELOG.md` bajo la sección `[Sin publicar]` detallando la migración de `file_watcher.py` hacia `InteractionEventSubscriber`.
  - [ ] 5.5 Actualizar `home-assistant/docker-compose.yml` añadiendo la dependencia `depends_on: nats: condition: service_healthy` en el servicio `interaction-manager`.
  - [ ] 5.6 Actualizar `home-assistant/config/interaction-manager.env` añadiendo `NATS_URL=nats://nats:4222` y eliminando `POLL_INTERVAL_SECONDS`.
