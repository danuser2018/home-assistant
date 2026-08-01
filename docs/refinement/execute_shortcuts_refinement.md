# Refinamiento de Feature: Ejecución Directa de Shortcuts desde CLI en `interaction-manager`

- **Documento de Origen**: [execute_shortcuts.md](file:///home/danuser2018/workspace/home-assistant/docs/features/execute_shortcuts.md)
- **Fecha**: 2026-08-02
- **Estado**: Refinado / Listo para Desarrollo

---

## 1. Resumen y Contexto de Negocio

### Objetivo Principal
Incorporar un nuevo flujo de ejecución en `interaction-manager` que procese comandos de ejecución directa (`ExecuteShortcutCommand`) recibidos vía NATS sin realizar captura de voz ni resolución semántica mediante el Orquestador.

Al recibir este comando, `interaction-manager` construirá de forma síncrona un `ExecutionPlan` determinista con confianza del 100.0 y lo enviará directamente al endpoint `POST /api/v1/execute-plan` de `orchestrator`. Posteriormente, reutilizará el pipeline habitual para la síntesis TTS del mensaje de respuesta y el almacenamiento del archivo audio WAV en el directorio de salida.

Este mecanismo permite reducir drásticamente la latencia en la ejecución de atajos de teclado, subcomandos CLI (`novactl execute`) y automatizaciones donde la intención ya está perfectamente identificada.

### Actores e Interacciones
- **Emisor / Publicador**: `novactl` (u otro cliente del host como atajos de teclado o scripts) publica el comando `ExecuteShortcutCommand` al subject `command.interaction.execute-shortcut`.
- **Receptor / Suscriptor**: `interaction-manager` escucha el comando mediante `nova-event-bus`, reproduce la señal sonora de espera, construye el `ExecutionPlan` determinista, invoca a `orchestrator`, procesa la respuesta textual con `tts-capability` y genera el fichero WAV de salida en `OUTPUT_DIR`.
- **Orquestador**: `orchestrator` recibe el `ExecutionPlan` en `POST /api/v1/execute-plan`, valida la existencia del plugin indicado y ejecuta el plugin correspondiente.

---

## 2. Análisis de Servicios e Impacto

| Servicio | Nivel de Impacto | Componentes / Archivos Afectados | Tipo de Cambio | Descripción del Cambio |
| :--- | :--- | :--- | :--- | :--- |
| `interaction-manager` | **Alto** | `app/events.py`<br>`app/services/event_subscriber.py`<br>`app/services/interaction_pipeline.py`<br>`tests/test_shortcut_execution.py` | **Modificar / Añadir** | Definir la clase de comando `ExecuteShortcutCommand`. Ampliar `InteractionEventSubscriber` para suscribirse a `command.interaction.execute-shortcut`. Implementar `process_shortcut_interaction()` en el pipeline reutilizando el feedback de espera, la invocación a `POST /api/v1/execute-plan`, TTS y guardado de audio. |
| `home-assistant` | **Medio** | `docs/services.md`<br>`docs/architecture.md`<br>`docs/refinement/execute_shortcuts_refinement.md` | **Modificar** | Actualizar la documentación del catálogo de servicios y diagramas de flujo de `interaction-manager` para reflejar el canal de ejecución directa de shortcuts. |
| `novactl` | **Ninguno (Ya contemplado)** | N/A | **Ninguno** | Ya emite `ExecuteShortcutCommand` conforme a ADR-020 y ADR-022. |
| `orchestrator` | **Ninguno** | N/A | **Ninguno** | Ya expone el endpoint `POST /api/v1/execute-plan` (ADR-014 y ADR-015). |
| `stt-capability` | **Ninguno** | N/A | **Ninguno** | No interviene en este flujo. |
| `tts-capability` | **Ninguno** | N/A | **Ninguno** | Reutilizado de forma transparente para sintetizar la respuesta del plugin. |

---

## 3. Especificación de Comportamiento (Criterios de Aceptación)

### Scenario 1: Subscription to ExecuteShortcutCommand on startup
```gherkin
Given that interaction-manager service starts up and connects to NATS broker
When the event subscriber initializes
Then it subscribes InteractionEventSubscriber to ExecuteShortcutCommand on subject "command.interaction.execute-shortcut"
And logs an informational message indicating active shortcut command listening
```

### Scenario 2: Successful execution of valid shortcut command
```gherkin
Given that interaction-manager is running and subscribed to "command.interaction.execute-shortcut"
When an ExecuteShortcutCommand is received with shortcut "weather", channel "cli", and correlation_id "781870fc-80fe-4165-ae55-4ebdc36b1c60"
Then interaction-manager reproduces the wait sound feedback
And constructs an ExecutionPlan with a single step:
  | plugin      | weather                              |
  | confidence  | 100.0                                |
  | channel     | cli                                  |
  | context     | correlation_id, raw_text, channel    |
And posts the plan to Orchestrator endpoint "POST /api/v1/execute-plan"
And receives a successful speech response "En Madrid hace 20 grados"
And synthesizes the response text using tts-capability
And saves the generated WAV file to settings.OUTPUT_DIR preserving correlation_id in logs
```

### Scenario 3: Non-existent plugin error handled by Orchestrator
```gherkin
Given that interaction-manager receives an ExecuteShortcutCommand with shortcut "invalid_plugin_name"
When interaction-manager posts the constructed ExecutionPlan to Orchestrator "POST /api/v1/execute-plan"
And Orchestrator returns an HTTP 404/422 error or success false indicating plugin not found
Then interaction-manager does not crash or execute custom pre-validation
And delegates error audio generation to error_handler.handle_error
And logs the error details with the original correlation_id
```

### Scenario 4: Correlation ID preservation across shortcut pipeline
```gherkin
Given an incoming ExecuteShortcutCommand with correlation_id "abc-123-xyz"
When interaction-manager processes the shortcut through execution plan construction, Orchestrator call, and TTS synthesis
Then the correlation_id "abc-123-xyz" is propagated in the ExecutionPlan context
And all log entries produced during processing contain correlation_id "abc-123-xyz"
```

### Scenario 5: Re-entrancy and exception isolation in NATS listener
```gherkin
Given that interaction-manager receives an ExecuteShortcutCommand
When an unexpected network exception occurs during HTTP communication with Orchestrator or TTS
Then the exception is caught within the NATS event callback
And error_handler.handle_error is triggered
And the NATS event subscriber connection remains open and ready for subsequent commands
```

---

## 4. Diseño Técnico y Contratos

### 4.1 Contrato del Comando (`interaction-manager/app/events.py`)

```python
from dataclasses import dataclass
from nova_event_bus import Event, event

@event("command.interaction.execute-shortcut")
@dataclass
class ExecuteShortcutCommand(Event):
    """Command event received from CLI or system hotkeys to directly execute a shortcut plugin."""
    correlation_id: str
    shortcut: str
    channel: str = "cli"
```

### 4.2 Esquema del ExecutionPlan Generado Directamente

Al recibir el comando, `interaction-manager` debe construir el objeto JSON `ExecutionPlan` sin invocar `POST /api/v1/resolve`:

```json
{
  "steps": [
    {
      "plugin": "weather",
      "confidence": 100.0,
      "parameters": {},
      "channel": "cli",
      "context": {
        "raw_text": "weather",
        "normalized_text": "weather",
        "correlation_id": "781870fc-80fe-4165-ae55-4ebdc36b1c60",
        "channel": "cli",
        "metadata": {}
      },
      "security": {}
    }
  ]
}
```

### 4.3 Integración del Suscriptor (`interaction-manager/app/services/event_subscriber.py`)

```python
import logging
from nova_event_bus import EventBus
from app.events import SpeechCapturedEvent, ExecuteShortcutCommand
from app.services import interaction_pipeline, error_handler

logger = logging.getLogger(__name__)

class InteractionEventSubscriber:
    def __init__(self, event_bus: EventBus) -> None:
        self._event_bus = event_bus

    async def start(self) -> None:
        await self._event_bus.connect()
        await self._event_bus.subscribe(SpeechCapturedEvent, self._handle_speech_captured)
        await self._event_bus.subscribe(ExecuteShortcutCommand, self._handle_execute_shortcut)
        logger.info("InteractionEventSubscriber subscribed to speech captured events and shortcut commands")

    async def stop(self) -> None:
        await self._event_bus.disconnect()
        logger.info("InteractionEventSubscriber disconnected from NATS broker")

    async def _handle_execute_shortcut(self, cmd: ExecuteShortcutCommand) -> None:
        logger.info(
            f"Received ExecuteShortcutCommand: correlation_id={cmd.correlation_id}, "
            f"shortcut={cmd.shortcut}, channel={cmd.channel}"
        )
        try:
            await interaction_pipeline.process_shortcut_interaction(
                shortcut=cmd.shortcut,
                channel=cmd.channel,
                correlation_id=cmd.correlation_id
            )
        except Exception as e:
            logger.error(
                f"Error executing shortcut '{cmd.shortcut}' [correlation_id={cmd.correlation_id}]: {e}",
                exc_info=True
            )
            await error_handler.handle_error(e)
```

### 4.4 Lógica de Procesamiento del Shortcut (`interaction-manager/app/services/interaction_pipeline.py`)

```python
import os
import time
import shutil
import asyncio
import logging
import httpx
from app.config import settings
from app.services import tts_client, error_handler

logger = logging.getLogger(__name__)

async def process_shortcut_interaction(shortcut: str, channel: str, correlation_id: str) -> None:
    start_time = time.perf_counter()
    feedback_output_path = os.path.join(settings.OUTPUT_DIR, f"shortcut_wait_{correlation_id}.wav")
    final_output_path = os.path.join(settings.OUTPUT_DIR, f"shortcut_response_{correlation_id}.wav")
    feedback_copied = False

    # 1. Reproducción de sonido de espera / feedback inicial
    try:
        if os.path.exists(settings.INTERACTION_AUDIO_FILE):
            await asyncio.to_thread(shutil.copy, settings.INTERACTION_AUDIO_FILE, feedback_output_path)
            logger.info(f"Started playing wait feedback audio for shortcut {shortcut}")
            feedback_copied = True

        # 2. Construcción determinista del ExecutionPlan
        execution_plan = {
            "steps": [
                {
                    "plugin": shortcut,
                    "confidence": 100.0,
                    "parameters": {},
                    "channel": channel,
                    "context": {
                        "raw_text": shortcut,
                        "normalized_text": shortcut,
                        "correlation_id": correlation_id,
                        "channel": channel,
                        "metadata": {}
                    },
                    "security": {}
                }
            ]
        }

        # 3. Invocación a POST /api/v1/execute-plan del Orchestrator
        orchestrator_url = f"{settings.ORCHESTRATOR_BASE_URL}/api/v1/execute-plan"
        async with httpx.AsyncClient(timeout=settings.HTTP_TIMEOUT) as client:
            resp = await client.post(orchestrator_url, json=execution_plan)
            resp.raise_for_status()
            result = resp.json()

        speech_text = result.get("speech", "")
        logger.info(f"Orchestrator plan execution completed for shortcut '{shortcut}': '{speech_text}'")

        # 4. Eliminar audio de feedback temporal
        if feedback_copied:
            _remove_file_silent(feedback_output_path)

        # 5. Síntesis mediante TTS
        if speech_text:
            audio_bytes = await tts_client.synthesize(speech_text)
            with open(final_output_path, "wb") as f:
                f.write(audio_bytes)
            logger.info(f"Shortcut audio response saved to {final_output_path}")

        elapsed = time.perf_counter() - start_time
        logger.info(f"Successfully processed shortcut '{shortcut}' in {elapsed:.3f}s")

    except Exception as e:
        elapsed = time.perf_counter() - start_time
        logger.error(f"Shortcut processing failed for '{shortcut}' after {elapsed:.3f}s: {e}", exc_info=True)

        if feedback_copied:
            _remove_file_silent(feedback_output_path)

        error_audio = await error_handler.handle_error(e)
        if error_audio:
            with open(final_output_path, "wb") as f:
                f.write(error_audio)

def _remove_file_silent(path: str) -> None:
    try:
        if os.path.exists(path):
            os.remove(path)
    except Exception as e:
        logger.warning(f"Failed to remove temporary file {path}: {e}")
```

### 4.5 Decisión sobre creación de nuevo ADR

Conforme a la skill `architecture-decisions`:
- **Decisión: No se requiere un nuevo ADR.** 
- **Justificación:** Este cambio es una extensión directa del caso de uso de ejecución desacoplada formalizado en **ADR-014** y **ADR-015** (separación `/resolve` y `/execute-plan`), alineado con el CLI `novactl` en **ADR-020** y cumpliendo estrictamente la nomenclatura de mensajería de **ADR-022** (`command.interaction.execute-shortcut`).
- **Trazabilidad:** Se actualizará la documentación de arquitectura y servicios (`docs/services.md` y `docs/architecture.md`) para incluir este segundo canal de entrada en `interaction-manager`.

---

## 5. Casos de Borde y Manejo de Errores

1. **Plugin inexistente o no cargado en Orchestrator**:
   - `orchestrator` devolverá una respuesta de error (ej. `HTTP 404 Not Found` o `HTTP 422 Unprocessable Entity` o JSON con `success: false`). `process_shortcut_interaction` capturará la excepción HTTP/negocio y la enviará a `error_handler.handle_error()`, generando el audio de error genérico en `final_output_path`.
2. **Parámetro `shortcut` vacío o `None`**:
   - `ExecuteShortcutCommand` requiere el campo `shortcut`. Si se recibe un string vacío, Orchestrator fallará al intentar mapear el plugin, activando el flujo de error estándar sin romper el bucle de NATS.
3. **Caída o Timeout de Orchestrator o TTS**:
   - `httpx.AsyncClient` aplicará el timeout configurado en `settings.HTTP_TIMEOUT`. Si ocurre un `httpx.TimeoutException` o `httpx.ConnectError`, se captura la excepción, se limpia el fichero de feedback temporal y se genera el audio de respuesta de error.
4. **Fallo al guardar el fichero de audio final**:
   - Si no hay permisos o el disco está lleno al escribir en `final_output_path`, la excepción se registra en el log indicando el `correlation_id`.
5. **Aislamiento en Callback de NATS**:
   - El método `_handle_execute_shortcut` envuelve la llamada al pipeline en un bloque `try/except` general para garantizar que cualquier fallo crítico no desconecte la suscripción NATS.

---

## 6. Estrategia de Testing

### Tests Unitarios
1. **`tests/test_shortcut_events.py`**:
   - Verificar la instanciación y serialización/deserialización de `ExecuteShortcutCommand` decorada con `@event("command.interaction.execute-shortcut")`.
2. **`tests/test_shortcut_execution.py`**:
   - Test de construcción de `ExecutionPlan`: Validar que `process_shortcut_interaction` genera la estructura JSON requerida con `plugin=shortcut`, `confidence=100.0` y preservando `correlation_id`.
   - Test de invocación a Orchestrator: Mockear `httpx.AsyncClient.post` respondiendo `{"speech": "OK"}` y verificar la llamada a `tts_client.synthesize`.
   - Test de manejo de errores de Orchestrator: Mockear respuesta HTTP 404 de Orchestrator y verificar invocación a `error_handler.handle_error`.
   - Test de suscripción NATS: Verificar que `InteractionEventSubscriber` registra el handler para `ExecuteShortcutCommand`.

### Tests de Integración
- Test asíncrono instanciando `InteractionEventSubscriber` con un bus `EventBus` mock, emitiendo `ExecuteShortcutCommand` y verificando que el flujo completo hasta TTS se ejecuta sin lanzar excepciones.

---

## 7. Plan de Implementación

- [ ] **Tarea 1: Definición del Evento de Comando en `interaction-manager`**
  - [ ] 1.1 Editar `interaction-manager/app/events.py` definiendo `ExecuteShortcutCommand` con el decorador `@event("command.interaction.execute-shortcut")`.

- [ ] **Tarea 2: Lógica de Procesamiento de Shortcuts en el Pipeline**
  - [ ] 2.1 Editar `interaction-manager/app/services/interaction_pipeline.py` añadiendo la función asíncrona `process_shortcut_interaction(shortcut, channel, correlation_id)`.
  - [ ] 2.2 Implementar la construcción del `ExecutionPlan` determinista con `confidence=100.0` y la llamada HTTP a `ORCHESTRATOR_BASE_URL/api/v1/execute-plan`.
  - [ ] 2.3 Integrar el flujo de sonido de espera, síntesis TTS y gestión de errores reutilizando los helpers de `interaction_pipeline.py`.

- [ ] **Tarea 3: Suscripción al Evento en `InteractionEventSubscriber`**
  - [ ] 3.1 Editar `interaction-manager/app/services/event_subscriber.py` suscribiendo `ExecuteShortcutCommand` a `_handle_execute_shortcut`.
  - [ ] 3.2 Añadir captura de excepciones y logging estructurado con `correlation_id`.

- [ ] **Tarea 4: Suite de Pruebas Automatizadas**
  - [ ] 4.1 Crear `interaction-manager/tests/test_shortcut_execution.py` con tests unitarios e integración para el comando, construcción del plan y manejo de fallos.
  - [ ] 4.2 Ejecutar la suite completa de pruebas de `interaction-manager` mediante `pytest`.

- [ ] **Tarea 5: Actualización de Documentación y Changelogs**
  - [ ] 5.1 Actualizar `home-assistant/docs/services.md` describiendo la capacidad de ejecución directa de shortcuts en `interaction-manager`.
  - [ ] 5.2 Actualizar `home-assistant/docs/architecture.md` incorporando la vía directa `ExecuteShortcutCommand -> ExecutePlan -> TTS` en el diagrama y tabla de interacciones.
  - [ ] 5.3 Actualizar `interaction-manager/README.md` documentando el evento de comando `command.interaction.execute-shortcut`.
  - [ ] 5.4 Actualizar `interaction-manager/CHANGELOG.md` en la sección `[Sin publicar]` detallando la adición del soporte para ejecución directa de shortcuts.
