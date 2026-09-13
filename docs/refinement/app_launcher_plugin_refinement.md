# Refinamiento de la Feature: Plugin `AppLauncherPlugin` (`open_app`)

- **Documento de Origen**: [docs/features/app_launcher_plugin_specification.md](file:///home/danuser2018/workspace/home-assistant/docs/features/app_launcher_plugin_specification.md)
- **Identificador Canónico de Plugin**: `open_app`
- **Fecha**: 2026-09-13
- **Estado**: Implementado

---

## 1. Resumen y Contexto de Negocio

### Objetivo Principal
Implementar en el microservicio `orchestrator` el componente conectable `AppLauncherPlugin` (con identificador canónico `open_app` según [ADR-023](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-023-estandarizacion-identificador-plugin-execution-plan.md) y la especificación de origen) para interpretar órdenes en lenguaje natural dirigidas al lanzamiento y ejecución de aplicaciones del entorno host (Linux).

El plugin completará el ecosistema de ejecución segura de comandos locales establecido en [ADR-026](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-026-host-service-command-execution.md) y [ADR-027](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-027-command-resolver-catalogo-comandos-nats.md):
1. **Activación Semántica Dinámica:** El plugin se activará en `ExecutionPlanner` utilizando el motor determinista `RapidFuzzSimilarityEngine`, manteniendo un corpus de frases de activación actualizado reactivamente en tiempo de ejecución.
2. **Extracción y Resolución de Parámetros:** Declarará contractualmente el parámetro obligatorio `command` de tipo `Command`, cuya resolución delega en `ParameterResolverEngine` y en el componente existente `CommandResolver`.
3. **Delegación Física en HAL (`host-service`):** Delegará la ejecución física sin shell en `host-service` a través del cliente HTTP asíncrono `HostServiceClient.execute_command(command)` consumiendo el endpoint `POST /v1/commands/execute`.
4. **Respeto Estricto de Tone Guide:** Responderá con confirmaciones breves, deterministas e impersonales según `TONE_GUIDE.md` (*"Aplicación abierta."*, *"Servicio no disponible."*, *"No he podido abrir la aplicación."*).
5. **Estrategia Híbrida de Ejemplos Dinámicos:** Garantizará el arranque en frío mediante frases de contingencia estáticas (*Cold-Start Fallback*) y enriquecerá su repertorio dinámicamente suscribiéndose al evento NATS `event.host.commands.available` emitido periódicamente por `host-service`.

### Actores e Interacciones
- **Usuario / Canal de Entrada (Voz, CLI, API):** Emite la orden verbal o textual (ej. *"Abre la calculadora"* o *"Inicia la máquina de calcular"*).
- **Pipeline de Interacción / Orquestador (`orchestrator`):**
  - Recibe la petición en `POST /api/v1/resolve`.
  - `ExecutionPlanner` compara la entrada normalizada contra los ejemplos dinámicos de los plugins activos y selecciona `open_app`.
  - `ParameterResolverEngine` invoca a `CommandResolver` (tipo `Command`), resolviendo el identificador lógico canónico (ej. `"calculator"`).
  - Construye el `ExecutionPlan` conteniendo el paso con `plugin: "open_app"` y `parameters: {"command": "calculator"}`.
- **Servicio de Seguridad (`security-service`):**
  - Evalúa la autorización del paso del plan contra la política de riesgo declarada por el plugin (`policy="lookup"`, `source="command"`, `table="host_commands"`).
  - Al validar el comando en la tabla `host_commands`, emite el token firmado HMAC-SHA256.
- **Ejecutor del Plan (`PlanExecutor` en `orchestrator`):**
  - Verifica la firma y validez del token HMAC en el paso.
  - Invoca `AppLauncherPlugin.execute(context)`.
- **Capa de Abstracción de Host (`host-service`):**
  - Recibe la petición autorizada `POST /v1/commands/execute` con `{"command": "calculator"}`.
  - Lanza el proceso gráfico desacoplado del sistema (`subprocess.Popen(["gnome-calculator"], shell=False, start_new_session=True)`).
  - Responde con HTTP 200 conteniendo `{"command": "calculator", "status": "started", "pid": 12345}`.
- **Servicio de Catálogo del Sistema (`system-service`):**
  - Durante el arranque de `orchestrator`, `lifespan` publica automáticamente la capacidad `open_app` en `/v1/system/capabilities`.

```text
Usuario: "Abre la calculadora"
           │
           ▼
     orchestrator
 ┌─────────────────────────────────────────────────────────────┐
 │ 1. SimilarityEngine -> AppLauncherPlugin (id: open_app)      │
 │ 2. ParameterResolverEngine -> CommandResolver -> calculator │
 │ 3. ExecutionPlanStep(plugin="open_app",                      │
 │                      parameters={"command": "calculator"}) │
 └─────────────────────────────┬───────────────────────────────┘
                               │
                               ▼
                        security-service
                 LookupTableRegistry["host_commands"]
                 (calculator -> Risk: low -> ALLOW)
                               │
                               ▼
                         orchestrator
 ┌─────────────────────────────────────────────────────────────┐
 │ 4. PlanExecutor verifica HMAC token de seguridad            │
 │ 5. AppLauncherPlugin.execute()                              │
 │ 6. HostServiceClient.execute_command("calculator")          │
 └─────────────────────────────┬───────────────────────────────┘
                               │ POST /v1/commands/execute
                               ▼
                          host-service
                 (Despacha gnome-calculator)
                               │
                               ▼
                     "Aplicación abierta."
```

---

## 2. Análisis de Servicios e Impacto

| Servicio | Nivel de Impacto | Componentes / Archivos Afectados | Tipo de Cambio | Descripción del Cambio |
| :--- | :--- | :--- | :--- | :--- |
| `orchestrator` | **Alto** | `plugins/app_launcher/__init__.py` (nuevo)<br>`plugins/app_launcher/main.py` (nuevo)<br>`core/host_service_client.py`<br>`main.py`<br>`tests/test_app_launcher_plugin.py` (nuevo)<br>`tests/test_app_launcher_integration.py` (nuevo)<br>`pyproject.toml`<br>`CHANGELOG.md` | **Modificar / Añadir** | 1. Implementar `AppLauncherPlugin` en `plugins/app_launcher/main.py` declarando `id = "open_app"`, `priority = 60`, parámetro `command: Command` (obligatorio), política de riesgo dinámica por lookup en tabla `host_commands`, y método `load_dynamic_phrases(new_phrases: List[str])`.<br>2. Extender `HostServiceClient` con `ExecuteCommandResponse` y el método asíncrono `execute_command(command: str) -> ExecuteCommandResponse` invocando `POST /v1/commands/execute`.<br>3. Conectar en `main.py` (`lifespan`) el manejador `handle_host_commands` para inyectar las frases dinámicas del evento NATS `HostCommandsAvailableEvent` en la instancia activa de `AppLauncherPlugin`.<br>4. Añadir suite completa de pruebas unitarias y de integración. |
| `host-service` | **Ninguno (Ya compatible)** | N/A | **Ninguno** | El endpoint `POST /v1/commands/execute` ya se encuentra implementado y operativo ([ADR-026](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-026-host-service-command-execution.md)). La publicación periódica NATS en `event.host.commands.available` ya emite `name`, `risk` y `phrases` cada 60s ([ADR-027](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-027-command-resolver-catalogo-comandos-nats.md)). |
| `security-service` | **Ninguno (Ya compatible)** | N/A | **Ninguno** | Ya sincroniza reactivamente la tabla en memoria `host_commands` vía NATS y evalúa políticas de riesgo de tipo `LookupRiskPolicy(source="command", table="host_commands")` de forma nativa. |
| `system-service` | **Ninguno (Ya compatible)** | N/A | **Ninguno** | Al arrancar `orchestrator`, el ciclo de vida `lifespan` descubre automáticamente el plugin `open_app` y registra su capacidad vía REST en `/v1/system/capabilities`. |
| `interaction-manager` | **Ninguno (Ya compatible)** | N/A | **Ninguno** | Compatible al 100%. Continúa recibiendo el `ExecutionPlan` con `plugin: "open_app"` y orquestando la autorización y síntesis de voz sin alteraciones. |
| `home-assistant` | **Bajo** | `docs/services.md`<br>`docs/architecture.md`<br>`CHANGELOG.md` | **Modificar** | Documentar la incorporación del plugin `open_app` en el catálogo de plugins y en la arquitectura global de Nova-2. |

### Justificación de Disparo de ADR
Conforme a la skill [architecture-decisions](file:///home/danuser2018/workspace/home-assistant/.agent/skills/transversal/architecture-decisions/SKILL.md), esta feature **no requiere un nuevo ADR**, dado que:
1. No altera las responsabilidades ni los límites de los servicios (`service-responsibilities`).
2. No modifica contratos de API públicos existentes ni crea nuevos endpoints REST (`api-contracts`). El endpoint `POST /v1/commands/execute` ya fue aprobado en el [ADR-026](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-026-host-service-command-execution.md).
3. No introduce nuevos patrones de transporte o mensajería asíncrona (`communication-patterns`). El evento NATS `event.host.commands.available` y el resolver `CommandResolver` ya están formalizados en el [ADR-027](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-027-command-resolver-catalogo-comandos-nats.md).
4. La inyección en memoria de frases dinámicas en el plugin es un mecanismo interno de `orchestrator` alineado con el ciclo de vida establecido en el [ADR-024](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-024-interfaces-resolucion-parametros-orquestador.md) y [ADR-027](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-027-command-resolver-catalogo-comandos-nats.md).

---

## 3. Especificación de Comportamiento (Criterios de Aceptación)

### Escenario 1: Activación y Ejecución Exitosa de una Aplicación Registrada (RF-01, RF-02, RF-03, RF-04)
```gherkin
Dado que el servicio "orchestrator" ha recibido el catálogo público desde "host-service" vía NATS
Y el catálogo contiene el comando "calculator" con la frase "abre la calculadora"
Cuando el usuario emite la instrucción "Abre la calculadora"
Entonces "ExecutionPlanner" selecciona el plugin "open_app" con confianza superior al umbral mínimo
Y "ParameterResolverEngine" resuelve el parámetro "command" con el valor "calculator"
Y "PlanExecutor" invoca a "AppLauncherPlugin.execute()"
Y el plugin ejecuta una petición HTTP "POST /v1/commands/execute" hacia "host-service" con el cuerpo:
  """
  {
    "command": "calculator"
  }
  """
Y "host-service" responde con estado HTTP 200 y cuerpo conteniendo status "started" y el pid generado
Y el plugin retorna un resultado de éxito con la respuesta hablada exacta "Aplicación abierta."
```

### Escenario 2: Enriquecimiento Dinámico de Frases de Activación vía NATS (RF-01, Diseño §4)
```gherkin
Dado que "AppLauncherPlugin" ha inicializado su estado interno con frases estáticas de contingencia
Cuando "orchestrator" recibe el evento NATS "event.host.commands.available" con los comandos:
  | name       | risk   | phrases                                              |
  | calculator | low    | ["calculadora", "maquina de calcular"]              |
  | backup     | medium | ["copia de seguridad", "hacer backup"]              |
Entonces el manejador del ciclo de vida localiza la instancia de "AppLauncherPlugin"
Y llama al método "load_dynamic_phrases()" inyectando las frases capturadas
Y la propiedad "examples" de "AppLauncherPlugin" contiene las frases inyectadas sin duplicados
Y una orden posterior como "Hacer backup" es clasificada deterministamente hacia el plugin "open_app"
```

### Escenario 3: Resiliencia y Comportamiento en Frío Previo al Primer Evento NATS (Diseño §4.1)
```gherkin
Dado que "orchestrator" acaba de arrancar y aún no ha recibido el evento NATS de "host-service"
Y el catálogo dinámico de comandos en memoria se encuentra vacío
Cuando se carga el plugin "AppLauncherPlugin" en "PluginManager"
Entonces el plugin expone en "examples" su lista estática de frases de contingencia ("Abre una aplicación", "Iniciar programa")
Y si el usuario emite una orden genérica como "Abre una aplicación"
Entonces "ExecutionPlanner" activa "open_app"
Y "CommandResolver" detecta que el catálogo no está listo retornando el parámetro como no resuelto
Y "AppLauncherPlugin.execute()" detecta la ausencia de parámetro válido
Y detiene la ejecución sin enviar peticiones HTTP a "host-service"
Y retorna un resultado fallido con la respuesta hablada "No he podido abrir la aplicación."
```

### Escenario 4: Actualización Continua del Catálogo en Caliente sin Reinicio (Diseño §4.4)
```gherkin
Dado que el sistema se encuentra en ejecución operativa
Cuando el usuario añade un nuevo comando "text-editor" con frase "abrir bloc de notas" en "config/commands.yaml"
Y "host-service" publica su siguiente evento periódico en "event.host.commands.available"
Entonces "AppLauncherPlugin" incorpora la nueva frase "abrir bloc de notas" a su corpus en memoria
Y cuando el usuario solicita "Abrir bloc de notas"
Entonces el orquestador enruta la orden hacia "open_app"
Y resuelve el parámetro "command" como "text-editor"
Sin requerir reinicio del contenedor "orchestrator"
```

### Escenario 5: Manejo de Indisponibilidad o Timeout de Comunicación con Host Service (RF-04, RNF-03)
```gherkin
Dado que "host-service" no se encuentra alcanzable por fallo de red o el tiempo de respuesta supera los 5.0 segundos
Cuando "AppLauncherPlugin" ejecuta la llamada a "HostServiceClient.execute_command('calculator')"
Entonces el cliente HTTP captura "httpx.ConnectError" o "httpx.TimeoutException"
Y el plugin retorna un resultado de fallo controlado
Y la respuesta hablada generada es exactamente "Servicio no disponible."
```

### Escenario 6: Rechazo del Host por Comando Desconocido o No Configurado (RF-04)
```gherkin
Dado que el parámetro "command" se resuelve con un identificador inexistente en el host "unknown-tool"
Cuando "AppLauncherPlugin" invoca "POST /v1/commands/execute" con command "unknown-tool"
Y "host-service" rechaza la petición con código HTTP 404 ("COMMAND_NOT_FOUND")
Entonces "HostServiceClient" captura el error de estado HTTP ("httpx.HTTPStatusError")
Y el plugin retorna un resultado fallido
Y la respuesta hablada generada es exactamente "No he podido abrir la aplicación."
```

### Escenario 7: Rechazo del Host por Fallo Interno al Lanzar el Proceso (RF-04)
```gherkin
Dado que el binario configurado para el comando "broken-app" no existe o carece de permisos de ejecución en el host
Cuando "AppLauncherPlugin" invoca "POST /v1/commands/execute" con command "broken-app"
Y "host-service" falla al invocar el subproceso retornando código HTTP 500 ("COMMAND_EXECUTION_FAILED")
Entonces "HostServiceClient" captura la excepción HTTP
Y el plugin retorna un resultado fallido con la respuesta hablada "No he podido abrir la aplicación."
```

### Escenario 8: Rechazo Defensivo ante Parámetro de Comando Ausente o Vacío
```gherkin
Dado que "AppLauncherPlugin" declara el parámetro "command" como obligatorio (required=True)
Cuando "ExecutionPlanner" no puede resolver el parámetro y pasa un contexto con "command" ausente o None
Cuando "AppLauncherPlugin.execute()" evalúa el contexto recibido
Entonces el plugin detecta que el parámetro "command" no es una cadena válida
Y no realiza ninguna llamada HTTP a "host-service"
Y retorna un resultado fallido con la respuesta hablada "No he podido abrir la aplicación."
```

### Escenario 9: Aislamiento Zero-Shell dentro del Contenedor Orchestrator (RNF-01)
```gherkin
Dado el contenedor Docker del servicio "orchestrator"
Cuando se inspecciona la implementación y ejecución de "AppLauncherPlugin"
Entonces el plugin no importa ni ejecuta los módulos "subprocess", "os.system", "shutil" ni ninguna shell interactiva
Y toda la interacción con el sistema operativo se realiza exclusivamente vía cliente HTTP hacia "host-service"
```

### Escenario 10: Declaración de Política de Riesgo Dinámica por Tabla de Búsqueda (RNF-02, ADR-025, ADR-027)
```gherkin
Dado que "AppLauncherPlugin" se carga en el arranque de "orchestrator"
Cuando el ciclo de vida registra las acciones de seguridad en "security-service"
Entonces publica para la acción "open_app" una política de riesgo de tipo "lookup":
  """
  {
    "id": "open_app",
    "risk": {
      "policy": "lookup",
      "source": "command",
      "table": "host_commands"
    }
  }
  """
Y "security-service" clasifica el riesgo de cada invocación consultando dinámicamente el parámetro "command" en su tabla "host_commands"
```

---

## 4. Diseño Técnico y Contratos

### 4.1. Extensión del Cliente HTTP `HostServiceClient` (`orchestrator/core/host_service_client.py`)

Se añade el modelo Pydantic de respuesta y el método asíncrono `execute_command` en `HostServiceClient`:

```python
from typing import Optional
from pydantic import BaseModel, Field


class ExecuteCommandResponse(BaseModel):
    command: str = Field(..., description="Logical identifier of the executed command")
    status: str = Field(default="started", description="Execution status of the command")
    pid: Optional[int] = Field(None, description="Operating system Process ID of the spawned process")


class HostServiceClient:
    # ... métodos existentes (get_volume, volume_up, volume_down, mute, unmute, set_volume) ...

    async def execute_command(self, command: str) -> ExecuteCommandResponse:
        """
        Invokes host-service to execute a registered host command by its logical name.
        Target endpoint: POST /v1/commands/execute
        """
        url = f"{self.base_url.rstrip('/')}/v1/commands/execute"
        logger.info(f"Consuming URL: {url} with command: {command}")
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.post(url, json={"command": command})
            response.raise_for_status()
            data = response.json()
            logger.info(f"Response received from host-service: {data}")
            return ExecuteCommandResponse(**data)
```

### 4.2. Implementación de `AppLauncherPlugin` (`orchestrator/plugins/app_launcher/main.py`)

```python
import logging
from typing import List, Optional
import httpx

from core.logger import logger
from core.models import PluginContext, PluginResult
from core.parameter_resolution.models import ParameterDefinition
from core.host_service_client import HostServiceClient
from plugins.base import Plugin


class AppLauncherPlugin(Plugin):
    """
    Plugin that routes natural-language instructions to launch host applications
    via host-service HAL. Supports dynamically updated trigger examples received
    asynchronously via NATS.
    """

    DEFAULT_COLD_START_EXAMPLES: List[str] = [
        "abre una aplicacion",
        "abrir aplicacion",
        "ejecuta una aplicacion",
        "ejecutar programa",
        "iniciar programa",
        "lanzar aplicacion",
        "abrir el programa",
        "abre el programa",
        "ejecuta un programa",
        "inicia la aplicacion",
    ]

    def __init__(self):
        super().__init__()
        self.client: Optional[HostServiceClient] = None
        self._dynamic_examples: List[str] = list(self.DEFAULT_COLD_START_EXAMPLES)

    @property
    def name(self) -> str:
        return "AppLauncherPlugin"

    @property
    def description(self) -> str:
        return "Abre y ejecuta aplicaciones del entorno host local"

    @property
    def id(self) -> str:
        return "open_app"

    @property
    def priority(self) -> int:
        return 60

    @property
    def parameters(self) -> List[ParameterDefinition]:
        return [
            ParameterDefinition(
                name="command",
                type="Command",
                required=True,
                description="Identificador logico del comando o aplicacion a ejecutar",
            )
        ]

    @property
    def risk_policy(self) -> dict:
        return {
            "policy": "lookup",
            "source": "command",
            "table": "host_commands",
        }

    @property
    def examples(self) -> List[str]:
        return list(self._dynamic_examples)

    def load_dynamic_phrases(self, new_phrases: List[str]) -> None:
        """
        Updates in-memory trigger examples with dynamic phrases received from host-service via NATS.
        Preserves cold-start fallback examples and appends unique new phrases.
        """
        cleaned = [p.strip() for p in new_phrases if isinstance(p, str) and p.strip()]
        combined = list(dict.fromkeys(self.DEFAULT_COLD_START_EXAMPLES + cleaned))
        self._dynamic_examples = combined
        logger.info(
            f"AppLauncherPlugin: updated dynamic examples ({len(self._dynamic_examples)} total phrases)."
        )

    def initialize(self) -> None:
        logger.info("Initializing AppLauncherPlugin")
        self.client = HostServiceClient()

    async def execute(self, context: PluginContext) -> PluginResult:
        logger.info("Starting execution of AppLauncherPlugin")
        raw_command = context.parameters.get("command") if context.parameters else None

        if not raw_command or not isinstance(raw_command, str) or not raw_command.strip():
            logger.warning("AppLauncherPlugin: Missing or invalid 'command' parameter in context.")
            return PluginResult(
                success=False,
                speech="No he podido abrir la aplicación.",
            )

        command_name = raw_command.strip()
        try:
            if not self.client:
                self.client = HostServiceClient()

            result = await self.client.execute_command(command_name)
            logger.info(
                f"AppLauncherPlugin: Successfully launched '{command_name}' (pid={result.pid})"
            )
            return PluginResult(
                success=True,
                speech="Aplicación abierta.",
                data=result.model_dump(),
            )
        except (httpx.ConnectError, httpx.TimeoutException) as exc:
            logger.error(
                f"AppLauncherPlugin: Connection error or timeout reaching host-service: {exc}"
            )
            return PluginResult(
                success=False,
                speech="Servicio no disponible.",
            )
        except httpx.HTTPStatusError as exc:
            logger.warning(
                f"AppLauncherPlugin: host-service rejected command '{command_name}' with HTTP {exc.response.status_code}"
            )
            return PluginResult(
                success=False,
                speech="No he podido abrir la aplicación.",
            )
        except Exception as exc:
            logger.error(
                f"AppLauncherPlugin: Unexpected error executing command '{command_name}': {exc}",
                exc_info=True,
            )
            return PluginResult(
                success=False,
                speech="No he podido abrir la aplicación.",
            )
```

### 4.3. Conexión del Ciclo de Vida NATS en `orchestrator/main.py`

En la rutina `lifespan` de FastAPI, se actualiza el callback `handle_host_commands` para alimentar simultáneamente el catálogo de resolución `CommandCatalogProjection` y la lista de ejemplos dinámicos de `AppLauncherPlugin`:

```python
    async def handle_host_commands(evt: HostCommandsAvailableEvent):
        logger.info(f"Received {len(evt.commands)} commands from host-service projection via NATS")
        command_catalog.update_from_event(evt.commands, CommandResolver.normalize_phrase)

        # Inyeccion reactiva de frases en AppLauncherPlugin
        app_launcher = plugin_manager.get_plugin("open_app")
        if app_launcher and hasattr(app_launcher, "load_dynamic_phrases"):
            all_phrases = []
            for cmd in evt.commands:
                all_phrases.extend(cmd.phrases)
            app_launcher.load_dynamic_phrases(all_phrases)
            logger.info(f"Injected {len(all_phrases)} dynamic phrases into AppLauncherPlugin")
```

### 4.4. Contrato REST Existente en `host-service` (Verificación de Interfaces)

- **Endpoint:** `POST /v1/commands/execute`
- **Request Body (`ExecuteCommandRequest`):**
  ```json
  {
    "command": "calculator"
  }
  ```
- **Response Body (`ExecuteCommandResponse` — HTTP 200 OK):**
  ```json
  {
    "command": "calculator",
    "status": "started",
    "pid": 12345
  }
  ```
- **Response Error (`ErrorResponse` — HTTP 404 / 500):**
  ```json
  {
    "error": "COMMAND_NOT_FOUND",
    "message": "Command 'unknown' not found in host commands catalog.",
    "status": 404
  }
  ```

---

## 5. Casos de Borde y Manejo de Errores

| Caso de Borde | Comportamiento Esperado | Implementación Técnica |
| :--- | :--- | :--- |
| **Arranque en frío sin eventos NATS recibidos** | El plugin no falla al cargar; expone `DEFAULT_COLD_START_EXAMPLES`. Ante peticiones, `CommandResolver` retorna no resuelto y el plugin devuelve *"No he podido abrir la aplicación."*. | `_dynamic_examples` inicializado con lista estática. Chequeo de `if not raw_command:` en `execute()`. |
| **Petición con parámetro `command` ausente o vacío** | Detención inmediata previa a cualquier invocación HTTP. Retorna `success=False` y `speech="No he podido abrir la aplicación."`. | Validación defensiva en `AppLauncherPlugin.execute`: `if not raw_command or not isinstance(raw_command, str) or not raw_command.strip():`. |
| **Pérdida de conexión o timeout con `host-service`** | Se captura `httpx.ConnectError` o `httpx.TimeoutException`. Retorna `success=False` y `speech="Servicio no disponible."`. | Bloque `except (httpx.ConnectError, httpx.TimeoutException):` con timeout de 5.0 segundos en cliente HTTP. |
| **Comando no encontrado en el host (HTTP 404)** | Se captura `httpx.HTTPStatusError`. Retorna `success=False` y `speech="No he podido abrir la aplicación."`. | Bloque `except httpx.HTTPStatusError:`. |
| **Fallo en ejecución del proceso en el host (HTTP 500)** | Se captura `httpx.HTTPStatusError`. Retorna `success=False` y `speech="No he podido abrir la aplicación."`. | Bloque `except httpx.HTTPStatusError:`. |
| **Evento NATS con lista de frases vacía para un comando** | La deduplicación y limpieza ignora cadenas vacías y preserva las frases de contingencia sin corromper el estado. | `[p.strip() for p in new_phrases if isinstance(p, str) and p.strip()]` y preservación de `DEFAULT_COLD_START_EXAMPLES`. |
| **Actualización repetida de frases NATS idénticas** | No se duplican frases en memoria. El orden y tamaño permanecen estables. | Uso de `list(dict.fromkeys(...))` en `load_dynamic_phrases`. |
| **Denegación de autorización en seguridad (HMAC inválido o no autorizado)** | `PlanExecutor` detiene el plan antes de invocar a `AppLauncherPlugin` y responde HTTP 403 `UNAUTHORIZED_ACTION`. | Control existente en `PlanExecutor.execute_plan` vía `verify_step_token`. |
| **Excepción inesperada en runtime** | Captura genérica con log de traza completa y respuesta controlada *"No he podido abrir la aplicación."*. | Bloque defensivo `except Exception as exc:` con `logger.error(..., exc_info=True)`. |

---

## 6. Estrategia de Testing

### Pruebas Unitarias (`orchestrator/tests/test_app_launcher_plugin.py`)

1. **Metadatos y Contrato del Plugin:**
   - Verificar que `plugin.name == "AppLauncherPlugin"`.
   - Verificar que `plugin.id == "open_app"`.
   - Verificar que `plugin.priority == 60`.
   - Verificar que `plugin.description` es no vacía.
   - Verificar que `plugin.parameters` contiene exactamente un parámetro `command` de tipo `Command` con `required=True`.
   - Verificar que `plugin.risk_policy` declara política `lookup` apuntando a `source="command"` y `table="host_commands"`.
2. **Ciclo de Vida y Ejemplos Dinámicos:**
   - Verificar que en el arranque `plugin.examples` contiene los ejemplos de contingencia de `DEFAULT_COLD_START_EXAMPLES`.
   - Verificar que `load_dynamic_phrases(["calculadora", "abre la calculadora"])` incorpora las nuevas frases sin eliminar las de contingencia.
   - Verificar que llamadas repetidas con frases duplicadas o con espacios en blanco limpian y deduplican adecuadamente la lista.
3. **Cliente HTTP `HostServiceClient.execute_command`:**
   - Mockear `httpx.AsyncClient.post`:
     - Retorno HTTP 200 con `{"command": "calculator", "status": "started", "pid": 4321}`. Comprobar que `ExecuteCommandResponse` parsea los campos correctamente.
     - Simular HTTP 404 (`COMMAND_NOT_FOUND`) comprobando que lanza `httpx.HTTPStatusError`.
     - Simular HTTP 500 (`COMMAND_EXECUTION_FAILED`) comprobando que lanza `httpx.HTTPStatusError`.
     - Simular error de conexión `httpx.ConnectError` y timeout `httpx.TimeoutException`.
4. **Lógica de Ejecución `AppLauncherPlugin.execute`:**
   - Con parámetro `{"command": "calculator"}` y respuesta exitosa del mock HTTP: retorna `success=True`, `speech="Aplicación abierta."` y `data` con el pid.
   - Con parámetro ausente o `None`: retorna `success=False`, `speech="No he podido abrir la aplicación."` y no llama al cliente HTTP.
   - Con simulación de `ConnectError` o `TimeoutException`: retorna `success=False`, `speech="Servicio no disponible."`.
   - Con simulación de HTTP 404 o 500 (`HTTPStatusError`): retorna `success=False`, `speech="No he podido abrir la aplicación."`.
   - Con excepción inesperada: retorna `success=False`, `speech="No he podido abrir la aplicación."`.
5. **Auditoría Zero-Shell (RNF-01):**
   - Inspeccionar el código de `plugins/app_launcher/main.py` mediante AST o análisis de módulos para certificar que no importa ni invoca `subprocess`, `os.system` ni `shutil`.

### Pruebas de Integración (`orchestrator/tests/test_app_launcher_integration.py`)

1. **Flujo de Planificación con Ejemplos Dinámicos (`ExecutionPlanner` + `CommandResolver`):**
   - Poblar `CommandCatalogProjection` y `AppLauncherPlugin` con el comando `calculator` y frase `"abre la calculadora"`.
   - Enviar `UserRequest(text="Abre la calculadora")` a `planner.resolve()`.
   - Verificar que el paso seleccionado tiene `plugin="open_app"`, confianza alta (> 80.0) y `parameters={"command": "calculator"}`.
2. **Ejecución Completa del Plan (`PlanExecutor`):**
   - Crear un `ExecutionPlan` con paso `open_app`, mockeando `HostServiceClient.execute_command`.
   - Inyectar token de seguridad HMAC válido para la acción `open_app`.
   - Ejecutar el plan mediante `PlanExecutor.execute_plan()`.
   - Verificar que retorna `AssistantResponse(success=True, plugin_used="AppLauncherPlugin", speech="Aplicación abierta.")`.
   - Verificar que `ResponseGeneratedEvent` es emitido al event bus con los datos de respuesta.
3. **Convergencia Dinámica en Caliente:**
   - Simular la llegada de un evento `HostCommandsAvailableEvent` con una nueva aplicación `"editor"` y frase `"abrir editor de texto"`.
   - Verificar que una petición posterior `"abrir editor de texto"` se enruta automáticamente hacia `open_app` con `command="editor"` sin reiniciar el servicio.

---

## 7. Plan de Implementación (Checklist)

- [x] **Fase 1: Extensión del Cliente HTTP en Orchestrator**
  - [x] Añadir la clase `ExecuteCommandResponse` en `orchestrator/core/host_service_client.py`.
  - [x] Añadir el método asíncrono `execute_command(self, command: str) -> ExecuteCommandResponse` en `orchestrator/core/host_service_client.py` con timeout de 5.0 segundos y manejo de URL `/v1/commands/execute`.

- [x] **Fase 2: Implementación de `AppLauncherPlugin`**
  - [x] Crear el directorio `orchestrator/plugins/app_launcher/` y el archivo `orchestrator/plugins/app_launcher/__init__.py`.
  - [x] Implementar la clase `AppLauncherPlugin` en `orchestrator/plugins/app_launcher/main.py` cumpliendo `id = "open_app"`, `priority = 60`, parámetro obligatorio `command: Command`, política de riesgo por lookup en `host_commands`, ejemplos estáticos de contingencia y método `load_dynamic_phrases()`.
  - [x] Implementar el método `execute(context: PluginContext)` con validación estricta de parámetros, llamada a `HostServiceClient.execute_command()` y gestión de respuestas según `TONE_GUIDE.md` (*"Aplicación abierta."*, *"Servicio no disponible."*, *"No he podido abrir la aplicación."*).

- [x] **Fase 3: Integración del Ciclo de Vida NATS en Orchestrator**
  - [x] Modificar `handle_host_commands` en la función `lifespan` de `orchestrator/main.py` para obtener la instancia de `open_app` mediante `plugin_manager.get_plugin("open_app")` e invocar `load_dynamic_phrases()` con todas las frases del evento recibido.

- [x] **Fase 4: Pruebas Automatizadas**
  - [x] Crear el archivo de pruebas unitarias `orchestrator/tests/test_app_launcher_plugin.py` cubriendo contratos, carga dinámica, cliente HTTP, escenarios de error y validación zero-shell.
  - [x] Crear el archivo de pruebas de integración `orchestrator/tests/test_app_launcher_integration.py` validando la resolución completa en `ExecutionPlanner`, ejecución en `PlanExecutor` y convergencia en caliente.
  - [x] Ejecutar la suite de tests en `orchestrator` con `pytest` y confirmar 100% de éxito.

- [x] **Fase 5: Documentación y Versionado**
  - [x] Actualizar `orchestrator/CHANGELOG.md` e incrementar la versión en `orchestrator/main.py` (v3.11.0) siguiendo `development-workflow`.
  - [x] Actualizar `home-assistant/CHANGELOG.md` bajo la sección `[Sin publicar]` registrando el nuevo plugin `open_app`.
  - [x] Actualizar `home-assistant/docs/services.md` y `home-assistant/docs/architecture.md` documentando la presencia y funcionamiento del plugin `open_app`.

- [x] **Fase 6: Despliegue y Validación Local**
  - [x] Reconstruir y arrancar el servicio con `docker compose up --build orchestrator`.
  - [x] Comprobar en logs del orquestador la publicación de la capacidad `open_app` en `system-service` y la recepción de las frases dinámicas desde `host-service`.
