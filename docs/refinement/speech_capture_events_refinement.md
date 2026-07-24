# Refinamiento de Feature: Eliminación de Parámetros en `StartSpeechCaptureCommand` y `StopSpeechCaptureCommand`

- **Documento de Origen**: [ADR-021: Detección de Habla basada en Eventos en mic-daemon](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-021-deteccion-habla-eventos-mic-daemon.md) y [speech_detection_by_events.md](file:///home/danuser2018/workspace/mic-daemon/doc/features/speech_detection_by_events.md)
- **Fecha**: 2026-07-23
- **Estado**: Refinado / Listo para Desarrollo

---

## 1. Resumen y Contexto de Negocio

### Objetivo Principal
Refactorizar los comandos de inicio y parada de captura de voz (`StartSpeechCaptureCommand` y `StopSpeechCaptureCommand`) para eliminar los atributos `correlation_id` y `channel`. La captura de audio a nivel de micrófono del sistema gestionada por `mic-daemon` es un control global de hardware que no requiere contextualización por canal ni identificadores de correlación. 

### Actores e Interacciones
- **Emisor / Publicador**: `novactl` (CLI del ecosistema Nova) emite los comandos de control NATS al ejecutarse subcomandos como `novactl start-capture` o `novactl stop-capture`.
- **Receptor / Suscriptor**: `mic-daemon` (Daemon de captura de audio) se suscribe a los eventos NATS a través de `EventSubscriber` para iniciar o detener la grabación de audio local sin requerir parámetros.

---

## 2. Análisis de Servicios e Impacto

| Servicio | Nivel de Impacto | Componentes / Archivos Afectados | Tipo de Cambio | Descripción del Cambio |
| :--- | :--- | :--- | :--- | :--- |
| `novactl` | **Alto** | `src/novactl/events.py`<br>`src/novactl/plugins/start_capture_plugin.py`<br>`src/novactl/plugins/stop_capture_plugin.py`<br>`tests/test_plugins.py` | **Modificar** | Convertir `StartSpeechCaptureCommand` y `StopSpeechCaptureCommand` a dataclasses vacías. Eliminar el argumento `--channel` de los plugins de la CLI y actualizar tests unitarios. |
| `mic-daemon` | **Alto** | `src/event_subscriber.py`<br>`src/mic_daemon.py`<br>`tests/test_event_subscriber.py`<br>`doc/refinements/speech_detection_by_events_refinement.md`<br>`doc/features/speech_detection_by_events.md`<br>`scripts/mic-start.sh` *(verificar)*<br>`scripts/mic-stop.sh` *(verificar)* | **Modificar** | Modificar `EventSubscriber` para procesar los eventos sin parámetros. Cambiar firmas de callbacks `on_start` y `on_stop` a `Callable[[], None]`. Actualizar especificaciones internas. Los scripts `mic-start.sh` y `mic-stop.sh` delegan en `novactl start-capture` / `novactl stop-capture` (ADR-021, punto 4); dado que la CLI ya no acepta `--channel` ni `correlation_id`, no requieren cambios siempre que no pasen parámetros posicionales. Verificar durante la implementación y confirmar que no hay llamadas con argumentos obsoletos. |
| `home-assistant` | **Medio** | `docs/adr/adr-021-deteccion-habla-eventos-mic-daemon.md`<br>`docs/architecture.md`<br>`docs/services.md` | **Modificar** | Actualizar la especificación del contrato de eventos NATS en la documentación general del sistema y en ADR-021. |
| `interaction-manager` | **Ninguno** | N/A | **Ninguno** | No consume ni emite estos comandos de control de bajo nivel. |

---

## 3. Especificación de Comportamiento (Criterios de Aceptación)

### Scenario 1: Publish StartSpeechCaptureCommand from CLI without arguments
```gherkin
Given that the user executes the command "novactl start-capture"
When the CLI plugin StartCapturePlugin executes
Then it publishes a StartSpeechCaptureCommand event to subject "novactl.command.start_speech_capture"
And the event payload is empty ({})
And stdout prints "Started speech capture"
```

### Scenario 2: Publish StopSpeechCaptureCommand from CLI without arguments
```gherkin
Given that the user executes the command "novactl stop-capture"
When the CLI plugin StopCapturePlugin executes
Then it publishes a StopSpeechCaptureCommand event to subject "novactl.command.stop_speech_capture"
And the event payload is empty ({})
And stdout prints "Stopped speech capture"
```

### Scenario 3: mic-daemon handles StartSpeechCaptureCommand
```gherkin
Given that mic-daemon is running and subscribed to NATS events
When a StartSpeechCaptureCommand event is published to "novactl.command.start_speech_capture"
Then EventSubscriber receives the event
And EventSubscriber calls on_start() without arguments
And mic-daemon starts audio recording
```

### Scenario 4: mic-daemon handles StopSpeechCaptureCommand
```gherkin
Given that mic-daemon is currently recording audio
When a StopSpeechCaptureCommand event is published to "novactl.command.stop_speech_capture"
Then EventSubscriber receives the event
And EventSubscriber calls on_stop() without arguments
And mic-daemon stops audio recording and saves the WAV file
```

---

## 4. Diseño Técnico y Contratos

### 4.1 Contrato de Eventos (`novactl/src/novactl/events.py`)

```python
from dataclasses import dataclass
from nova_event_bus import Event, event

@event("novactl.command.start_speech_capture")
@dataclass
class StartSpeechCaptureCommand(Event):
    """Command event to trigger speech capture start in mic-daemon."""
    pass

@event("novactl.command.stop_speech_capture")
@dataclass
class StopSpeechCaptureCommand(Event):
    """Command event to trigger speech capture stop in mic-daemon."""
    pass
```

### 4.2 Arquitectura del Suscriptor (`mic-daemon/src/event_subscriber.py`)

```python
import logging
from typing import Callable
from nova_event_bus import EventBus
from novactl.events import StartSpeechCaptureCommand, StopSpeechCaptureCommand

logger = logging.getLogger(__name__)

class EventSubscriber:
    def __init__(
        self,
        event_bus: EventBus,
        on_start: Callable[[], None],
        on_stop: Callable[[], None],
    ) -> None:
        self._event_bus = event_bus
        self._on_start = on_start
        self._on_stop = on_stop

    async def start(self) -> None:
        await self._event_bus.connect()
        await self._event_bus.subscribe(StartSpeechCaptureCommand, self._handle_start)
        await self._event_bus.subscribe(StopSpeechCaptureCommand, self._handle_stop)
        logger.info("EventSubscriber subscribed to StartSpeechCaptureCommand and StopSpeechCaptureCommand")

    async def stop(self) -> None:
        await self._event_bus.disconnect()
        logger.info("EventSubscriber disconnected from NATS")

    async def _handle_start(self, event: StartSpeechCaptureCommand) -> None:
        logger.info("Handling StartSpeechCaptureCommand")
        self._on_start()

    async def _handle_stop(self, event: StopSpeechCaptureCommand) -> None:
        logger.info("Handling StopSpeechCaptureCommand")
        self._on_stop()
```

### 4.3 Puntos de Entrada CLI (`novactl/src/novactl/plugins/`)

- **`StartCapturePlugin`**:
  - `configure_parser(self, parser)`: No añade argumentos opcionales como `--channel`.
  - `execute(self, args, event_bus)`: Publica `StartSpeechCaptureCommand()`.
- **`StopCapturePlugin`**:
  - `configure_parser(self, parser)`: No añade argumentos opcionales como `--channel`.
  - `execute(self, args, event_bus)`: Publica `StopSpeechCaptureCommand()`.

### 4.4 Decisión sobre creación de nuevo ADR

Este cambio modifica el payload público de los eventos `StartSpeechCaptureCommand` y `StopSpeechCaptureCommand`, contratos de comunicación NATS entre `novactl` y `mic-daemon`. Conforme a la skill `architecture-decisions`, se evalúa la necesidad de un nuevo ADR:

- **Decisión: No se crea un nuevo ADR.** La simplificación del payload (eliminación de `correlation_id` y `channel`) es una consecuencia directa y explícita del ADR-021 ya aceptado, que establece que `mic-daemon` opera como control global de hardware sin contextualización por canal. No se introduce ningún patrón arquitectónico nuevo ni se altera el flujo de comunicación entre servicios.
- **Trazabilidad:** La Tarea 3.1 cubre la actualización formal del ADR-021 para reflejar la ausencia de parámetros en la sección "Decisión", garantizando así la coherencia entre el ADR vigente y el contrato implementado.

---

## 5. Casos de Borde y Manejo de Errores

1. **Llamadas duplicadas / Idempotencia en `mic-daemon`**:
   - Si `mic-daemon` recibe un `StartSpeechCaptureCommand` mientras ya se encuentra grabando, `Recorder.start()` captura la condición de estar activo, emite un aviso en logs (`logger.warning`) y descarta la petición sin alterar el stream de grabación en curso.
   - Si `mic-daemon` recibe un `StopSpeechCaptureCommand` sin estar grabando, `Recorder.stop()` se ejecuta de forma no destructiva sin lanzar excepciones.
2. **Reconexión o desapariencia del Broker NATS**:
   - `EventSubscriber` mantiene reconexión gestionada por la librería subyacente `nova-event-bus`. Los eventos perdidos durante una desconexión no se reencadenan si se restaura el enlace, manteniendo el estado seguro actual de la captura.
3. **Petición desde CLI sin conexión NATS activa**:
   - `novactl` detecta el error de conexión con el servidor NATS y finaliza la ejecución con código de salida `1` escribiendo el mensaje en `stderr`.

---

## 6. Estrategia de Testing

### Tests Unitarios
1. **`novactl/tests/test_plugins.py`**:
   - Validar que `StartCapturePlugin.execute()` publica una instancia de `StartSpeechCaptureCommand` vacía sin requerir flags de canal.
   - Validar que `StopCapturePlugin.execute()` publica una instancia de `StopSpeechCaptureCommand` vacía sin requerir flags de canal.
2. **`mic-daemon/tests/test_event_subscriber.py`**:
   - Validar que al recibir `StartSpeechCaptureCommand()` se invoca el callback `on_start()` sin argumentos.
   - Validar que al recibir `StopSpeechCaptureCommand()` se invoca el callback `on_stop()` sin argumentos.

### Tests de Integración
- Verificar mediante un mock de bus NATS la publicación del comando desde `novactl` y la recepción correspondiente por el handler de `EventSubscriber` en `mic-daemon`.

---

## 7. Plan de Implementación

- [ ] **Tarea 1: Refactorización en `novactl`**
  - [ ] 1.1 Modificar `src/novactl/events.py` eliminando `correlation_id` y `channel` de `StartSpeechCaptureCommand` y `StopSpeechCaptureCommand`.
  - [ ] 1.2 Actualizar `src/novactl/plugins/start_capture_plugin.py` para eliminar la opción `--channel` de CLI y publicar `StartSpeechCaptureCommand()`.
  - [ ] 1.3 Actualizar `src/novactl/plugins/stop_capture_plugin.py` para eliminar la opción `--channel` de CLI y publicar `StopSpeechCaptureCommand()`.
  - [ ] 1.4 Actualizar `tests/test_plugins.py` adaptando las aserciones de los tests de captura de habla.
- [ ] **Tarea 2: Refactorización en `mic-daemon`**
  - [ ] 2.1 Modificar `src/event_subscriber.py` ajustando callbacks a `Callable[[], None]` y removiendo referencias a `event.correlation_id`.
  - [ ] 2.2 Modificar `src/mic_daemon.py` simplificando las funciones `on_start()` y `on_stop()`.
  - [ ] 2.3 Modificar `tests/test_event_subscriber.py` para instanciar comandos sin parámetros y validar llamadas de callbacks.
- [ ] **Tarea 3: Actualización de Documentación General y Especificaciones**
  - [ ] 3.1 Actualizar `home-assistant/docs/adr/adr-021-deteccion-habla-eventos-mic-daemon.md` documentando la simplificación de contratos.
  - [ ] 3.2 Actualizar `home-assistant/docs/architecture.md` y `home-assistant/docs/services.md` en la sección del catálogo de eventos NATS.
  - [ ] 3.3 Actualizar `mic-daemon/doc/refinements/speech_detection_by_events_refinement.md` y `mic-daemon/doc/features/speech_detection_by_events.md`.
  - [ ] 3.4 Actualizar `README.md` en `novactl` y `mic-daemon` reflejando la eliminación de los parámetros `--channel` y `correlation_id`.
  - [ ] 3.5 Actualizar `novactl/CHANGELOG.md` bajo la sección `[Sin publicar]` documentando la eliminación de `correlation_id` y `channel` de `StartSpeechCaptureCommand` y `StopSpeechCaptureCommand` y del argumento `--channel` en los plugins de CLI.
  - [ ] 3.6 Actualizar `mic-daemon/CHANGELOG.md` bajo la sección `[Sin publicar]` documentando la simplificación de las firmas de callback `on_start` y `on_stop` a `Callable[[], None]` y la eliminación de la referencia a `event.correlation_id` en `EventSubscriber`.
