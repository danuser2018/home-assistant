# Refinamiento de Feature: CommandResolver, Catálogo Centralizado de Comandos y Distribución NATS

- **Documento de Origen**: [command_resolver_specification.md](file:///home/danuser2018/workspace/home-assistant/docs/features/command_resolver_specification.md)
- **Fecha**: 2026-09-12
- **Estado**: Implementado

---

## 1. Resumen y Contexto de Negocio

### Objetivo Principal
El objetivo fundamental de esta feature es dotar al ecosistema Nova-2 de un mecanismo determinista, robusto y desacoplado para transformar órdenes en lenguaje natural producidas por el pipeline de interacción/planificación en un **identificador lógico de comando** (`name`), preservando en todo momento el aislamiento absoluto de los detalles físicos de ejecución dentro de `host-service`.

Para lograrlo, se establecen tres pilares arquitectónicos:
1. **Catálogo como Recurso Global de Nova (`config/commands.yaml`):** Se extrae la definición de comandos de la configuración interna privada de `host-service` y se eleva a fichero central de configuración de la plataforma Nova. Este archivo constituye la única fuente de verdad (*Single Source of Truth*) para los identificadores lógicos, los comandos físicos de ejecución en el host, la clasificación de riesgo asignada por el usuario y el repertorio de frases asociadas en lenguaje natural.
2. **Distribución Asíncrona Desacoplada vía NATS (`event.host.commands.available`):** `host-service` es el único custodio de la ejecución física. En su arranque y de forma periódica cada 60 segundos, publica en NATS una **proyección pública** del catálogo conteniendo exclusivamente el identificador lógico, el nivel de riesgo y las frases de activación, omitiendo estrictamente el ejecutable físico (`command` / `argv`). Dicha proyección es consumida asíncronamente por `orchestrator` y `security-service` para alimentar sus cachés en memoria, garantizando resiliencia y eliminando dependencias de sincronización temporal o reinicios coordinados.
3. **Resolución Determinista en Orchestrator (`CommandResolver`):** Se implementa el componente `CommandResolver` integrado en la infraestructura de resolución de parámetros existente (`ParameterResolverEngine`, según [ADR-024](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-024-interfaces-resolucion-parametros-orquestador.md)), manejando el tipo de parámetro `Command`. El algoritmo opera mediante normalización léxica (Unicode NFKD, minúsculas, eliminación de signos y diacríticos), coincidencia exacta de frase completa, coincidencia difusa (RapidFuzz) ponderada por nivel de riesgo (`low` más tolerante, `high` más estricto) y descarte inmediato ante ambigüedad entre candidatos, preservando la política **Fail-Closed** sin recurrir a LLMs, procesamiento semántico ni nuevas constantes en `ParameterResolutionStatus`.

### Actores e Interacciones
- **Usuario / Canal de Entrada (Voz, CLI, API):** Emite la orden verbal o textual (ej. *"Abre la calculadora"*).
- **Pipeline de Interacción / Orquestador (`orchestrator`):**
  - Recibe el evento NATS `event.host.commands.available` y mantiene una proyección en memoria del catálogo.
  - `ExecutionPlanner` identifica la intención y deriva la resolución del parámetro `command: Command` hacia `ParameterResolverEngine`.
  - `CommandResolver` procesa el texto normalizado, busca coincidencia exacta o difusa y retorna el identificador lógico `"calculator"`.
- **Servicio de Seguridad (`security-service`):**
  - Recibe el evento NATS `event.host.commands.available` y actualiza dinámicamente su tabla interna de riesgo `host_commands` en `LookupTableRegistry`.
  - Al recibir la solicitud de autorización del `ExecutionPlan`, verifica la existencia del comando en su catálogo y su nivel de riesgo contra las políticas del canal. Si el comando no existe o el catálogo no ha sido recibido, deniega inmediatamente (**Fail-Closed: DENY**).
- **Capa de Abstracción de Host (`host-service`):**
  - Valida y carga `config/commands.yaml` al arrancar.
  - Emite periódicamente la proyección pública a NATS.
  - Recibe la petición autorizada `POST /v1/commands/execute` con `{"command": "calculator"}` y despacha el proceso local desacoplado (`["gnome-calculator"]`).

```text
                       config/commands.yaml
                                │
                                ▼
                         ┌─────────────┐
                         │ host-service│
                         └──────┬──────┘
                                │
                 publish at startup + every 60s
                                │
                                ▼
                               NATS
                                │
                  event.host.commands.available
                                │
                       ┌────────┴────────┐
                       ▼                 ▼
                orchestrator       security-service
                       │                 │
                command catalog    security catalog
                       │
                       ▼
                ParameterResolver
                       │
                       ▼
                 CommandResolver
                       │
                  logical name
                       │
                       ▼
                  ExecutionPlan
                       │
                       ▼
                    Security
                       │
                  ALLOW / DENY
                       │
                       ▼
                  host-service
                       │
                physical command
                       │
                       ▼
                    execution
```

---

## 2. Análisis de Servicios e Impacto

| Servicio | Nivel de Impacto | Componentes / Archivos Afectados | Tipo de Cambio | Descripción del Cambio |
| :--- | :--- | :--- | :--- | :--- |
| `host-service` | **Alto** | `requirements.txt`<br>`src/config.py`<br>`src/models/commands.py`<br>`src/services/command_registry.py`<br>`src/services/catalog_publisher.py` (nuevo)<br>`src/app.py`<br>`tests/` | **Modificar / Añadir** | Incorporar dependencia `nova-event-bus`. Ampliar modelo `HostCommand` para incluir `phrases: List[str]`. Actualizar `CommandRegistry` para cargar `config/commands.yaml` y validar la presencia de frases. Implementar `CatalogPublisher` para publicar periódicamente (al inicio y cada 60s en una tarea en background de asyncio) el evento tipado `HostCommandsAvailableEvent` (`event.host.commands.available`) con payload versión 1 conteniendo `name`, `risk` y `phrases` (omitiendo estrictamente el `command` físico). Deprecar `config/host_commands.yaml` local. |
| `orchestrator` | **Alto** | `core/config.py`<br>`core/events.py`<br>`core/parameter_resolution/resolvers/command.py` (nuevo)<br>`core/parameter_resolution/resolvers/__init__.py`<br>`core/command_catalog.py` (nuevo)<br>`main.py`<br>`tests/` | **Modificar / Añadir** | Definir evento `HostCommandsAvailableEvent` en `core/events.py`. Suscribirse en `lifespan` al subject `event.host.commands.available` para alimentar `CommandCatalogProjection`. Implementar `CommandResolver` (`target_type = "Command"`) con pipeline determinista: normalización léxica (Unicode NFKD, minúsculas, strip de signos y tildes), coincidencia exacta, RapidFuzz con umbrales configurables por riesgo (`low: 60.0`, `medium: 65.0`, `high: 70.0`) y descarte por ambigüedad (`AMBIGUITY_DELTA: 5.0`). Registrar `CommandResolver` en `ParameterResolverRegistry`. |
| `security-service` | **Medio** | `requirements.txt`<br>`app/config.py`<br>`app/events.py` (nuevo)<br>`app/main.py`<br>`tests/` | **Modificar / Añadir** | Añadir dependencia `nova-event-bus`. Configurar conexión a NATS en `lifespan` utilizando `settings.NATS_URL`. Suscribirse al evento `HostCommandsAvailableEvent` (`event.host.commands.available`) y actualizar atómicamente la tabla en memoria `"host_commands"` en `LookupTableRegistry`. Mantener la política fail-closed: comando desconocido o catálogo ausente retorna `DENY`. Preservar el endpoint REST `POST /v1/security/tables/{table_name}` como fallback para tests unitarios. |
| `home-assistant` | **Medio** | `config/commands.yaml` (nuevo)<br>`docker-compose.yml`<br>`config/security-service.env`<br>`config/host-service.env`<br>`docs/services.md`<br>`docs/architecture.md`<br>`docs/adr/adr-027-command-resolver-catalogo-comandos-nats.md` (nuevo) | **Modificar / Añadir** | Crear `config/commands.yaml` como fuente central de verdad. Configurar `NATS_URL` y dependencias en `docker-compose.yml` para `security-service` y `host-service`. Actualizar documentación de arquitectura, catálogo de servicios y formalizar la decisión arquitectónica en [ADR-027](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-027-command-resolver-catalogo-comandos-nats.md). |
| `interaction-manager` | **Ninguno (Compatible)** | N/A | **Ninguno** | Compatible al 100%. Continúa recibiendo el `ExecutionPlan` generado por el orquestador con parámetros resueltos y enviándolo a autorización a `security-service`. |

### Justificación de Disparo de ADR (ADR-027)
Conforme a la skill [architecture-decisions](file:///home/danuser2018/workspace/home-assistant/.agent/skills/transversal/architecture-decisions/SKILL.md), esta feature:
1. Altera la frontera y propiedad del catálogo de comandos, convirtiéndolo en un recurso de configuración global de Nova (`config/commands.yaml`) en lugar de privado de `host-service`.
2. Introduce un nuevo patrón de sincronización eventual mediante un evento NATS periódico (`event.host.commands.available`) sin sincronización REST bidireccional.
3. Establece una política de resolución basada en riesgo donde la tolerancia difusa se adapta dinámicamente según la severidad del comando.
Por tanto, es **obligatorio formalizar y registrar el ADR-027** antes o durante la fase de desarrollo.

---

## 3. Especificación de Comportamiento (Criterios de Aceptación)

### Escenario 1: Carga y Validación Estricta del Catálogo en Host Service (AC-01, AC-02, AC-03)
```gherkin
Dado un archivo de configuración global "config/commands.yaml" con contenido válido:
  """
  commands:
    - name: calculator
      command:
        - gnome-calculator
      risk: low
      phrases:
        - calculadora
        - maquina de calcular
    - name: backup
      command:
        - /usr/local/bin/nova-backup
        - --quick
      risk: medium
      phrases:
        - copia de seguridad
        - hacer backup
  """
Cuando "host-service" inicia su ciclo de vida en el host
Entonces "CommandRegistry" carga satisfactoriamente las 2 entradas en memoria
Y asocia a cada comando su lista de argumentos físicos ("command"), nivel de riesgo ("risk") y frases ("phrases")
Y el servicio inicia correctamente quedando disponible en el puerto 8007
```

### Escenario 2: Publicación Periódica del Catálogo Público vía NATS (AC-04, AC-05, AC-07, AC-17)
```gherkin
Dado que "host-service" ha iniciado y cargado "config/commands.yaml"
Y que la conexión con el broker NATS está establecida
Cuando se ejecuta la rutina de publicación en el arranque
Y posteriormente cuando transcurre el intervalo de 60 segundos
Entonces "host-service" publica un mensaje en el subject "event.host.commands.available"
Y el payload contiene exactamente la versión contractual 1 y la lista de comandos proyectada:
  """
  {
    "version": 1,
    "commands": [
      {
        "name": "calculator",
        "risk": "low",
        "phrases": [
          "calculadora",
          "maquina de calcular"
        ]
      },
      {
        "name": "backup",
        "risk": "medium",
        "phrases": [
          "copia de seguridad",
          "hacer backup"
        ]
      }
    ]
  }
  """
Y el campo físico "command" (ej. "gnome-calculator") no está presente en ninguna parte del mensaje publicado
```

### Escenario 3: Reconstrucción Resiliente del Catálogo en Orchestrator y Security Service (AC-06)
```gherkin
Dado que "orchestrator" o "security-service" se inician después de "host-service" o sufren un reinicio inesperado
Y su proyección interna de comandos en memoria se encuentra vacía
Cuando "host-service" emite su siguiente publicación periódica (en un tiempo <= 60 segundos)
Entonces el consumidor recibe el evento en "event.host.commands.available"
Y reconstruye íntegramente su catálogo en memoria a partir de los datos del mensaje
Sin requerir reinicios manuales, peticiones HTTP ni coordinación temporal entre servicios
```

### Escenario 4: Sincronización Automática del Catálogo de Seguridad en Security Service (AC-06, AC-16)
```gherkin
Dado que "security-service" está suscrito al evento "event.host.commands.available"
Cuando recibe un evento con el comando "calculator" (riesgo "low") y "backup" (riesgo "medium")
Entonces "LookupTableRegistry" registra y actualiza la tabla "host_commands" con las entradas recibidas
Y cualquier consulta posterior a "get_entry_risk('host_commands', 'calculator')" retorna RiskLevel.LOW
Y cualquier consulta posterior a "get_entry_risk('host_commands', 'backup')" retorna RiskLevel.MEDIUM
```

### Escenario 5: Normalización Léxica Idéntica de Frases y Texto de Entrada (AC-09)
```gherkin
Dado el texto de entrada con mayúsculas, diacríticos y puntuación: "  ¡MÁQUINA   DE CALCULAR!  "
Y la frase de catálogo configurada: "Máquina de calcular"
Cuando "CommandResolver" ejecuta la función de normalización sobre ambas cadenas
Entonces ambas cadenas producen exactamente el mismo texto normalizado: "maquina de calcular"
Y los caracteres diacríticos, símbolos de puntuación ("¡", "!") y espacios redundantes son eliminados
```

### Escenario 6: Resolución por Coincidencia Exacta Determinista (AC-10)
```gherkin
Dado que el catálogo proyectado en "orchestrator" contiene:
  | name       | risk | phrases                                      |
  | calculator | low  | ["calculadora", "abre la calculadora"]       |
Cuando el usuario emite la instrucción "Abre la calculadora"
Y "CommandResolver" evalúa la entrada normalizada "abre la calculadora"
Entonces encuentra una coincidencia exacta con la frase configurada
Y retorna inmediatamente el estado "RESOLVED" con el valor "calculator"
Sin invocar el cálculo de similitud difusa con RapidFuzz
```

### Escenario 7: Resolución por Coincidencia Difusa ante Errores Leves de STT (AC-11, AC-12)
```gherkin
Dado que el comando "calculator" tiene nivel de riesgo "low" (umbral mínimo de similitud: 60.0)
Y sus frases asociadas incluyen "calculadora"
Cuando el usuario emite una frase con error leve de transcripción fonética: "calculadorra"
Y no existe coincidencia exacta
Cuando "CommandResolver" aplica el algoritmo de similitud difusa RapidFuzz
Entonces obtiene una puntuación de similitud de 91.6%
Y como 91.6 >= 60.0 (umbral para riesgo "low"), la coincidencia es aceptada
Y retorna el estado "RESOLVED" con el valor "calculator"
```

### Escenario 8: Restricción Estricta de Coincidencia Difusa para Comandos de Alto Riesgo (AC-12)
```gherkin
Dado que el comando "format-disk" tiene nivel de riesgo "high" (umbral mínimo de similitud: 70.0)
Y su frase configurada es "formatear disco externo"
Cuando el usuario emite una frase con discrepancias notables: "formatear particion externa"
Y la similitud calculada por RapidFuzz es de 62.0%
Entonces "CommandResolver" evalúa que 62.0 < 70.0 (umbral estricto para riesgo "high")
Y rechaza la coincidencia difusa
Y retorna el estado "UNRESOLVED_REQUIRED" con valor None
Evitando falsos positivos catastróficos en comandos críticos
```

### Escenario 9: Descarte Determinista ante Ambigüedad de Candidatos Compitiendo (AC-13, AC-14)
```gherkin
Dado un catálogo donde dos comandos distintos obtienen puntuaciones difusas cercanas para una misma entrada:
  | name       | risk | score |
  | calculator | low  | 68.0  |
  | calendar   | low  | 65.0  |
Y el margen de ambigüedad configurado ("AMBIGUITY_DELTA") es 5.0
Cuando "CommandResolver" compara la diferencia de puntuaciones: |68.0 - 65.0| = 3.0 <= 5.0
Entonces "CommandResolver" declara la resolución como ambigua
Y no selecciona arbitrariamente al candidato de mayor puntuación
Y retorna "UNRESOLVED_REQUIRED" (o "UNRESOLVED_OPTIONAL" si required=False) con valor None
Y registra en logs de diagnóstico la causa: "reason=ambiguous"
Y en ningún caso se genera una acción ejecutable
```

### Escenario 10: Comportamiento Fail-Closed ante Catálogo Ausente en Orchestrator (AC-15)
```gherkin
Dado que "orchestrator" no ha recibido aún ningún evento en "event.host.commands.available"
O la proyección en memoria del catálogo contiene 0 comandos
Cuando "ExecutionPlanner" invoca a "CommandResolver" para resolver un parámetro "Command"
Entonces "CommandResolver" retorna inmediatamente valor None con estado "UNRESOLVED_REQUIRED"
Y no realiza conjeturas, ni llamadas REST de emergencia a "host-service", ni genera identificadores por defecto
```

### Escenario 11: Autorización Fail-Closed en Security Service para Comandos Desconocidos (AC-16)
```gherkin
Dado que "security-service" no ha recibido el catálogo o el comando "unregistered-tool" no existe en la tabla "host_commands"
Cuando un cliente solicita autorización para una acción de ejecución con parameter "command"="unregistered-tool"
Entonces "security-service" evalúa que el riesgo es incalculable (None)
Y aplica la política de seguridad por defecto Fail-Closed
Y responde con decisión "DENY"
Impidiendo que cualquier comando no catalogado sea ejecutado en el host
```

### Escenario 12: Exclusión Total de Inferencia Semántica o Modelos de Lenguaje (AC-18)
```gherkin
Dado el comando "calculator" con frases ["calculadora", "abrir calculadora"]
Cuando el usuario emite una frase con significado equivalente pero léxico completamente distinto: "hazme una cuenta matematica"
Cuando "CommandResolver" evalúa la entrada
Entonces la similitud difusa léxica no supera el umbral requerido
Y el resolver no utiliza embeddings, sinónimos automáticos, lematización ni llamadas a LLMs
Y retorna valor None sin resolver
Preservando la predictibilidad determinista, la privacidad local y la baja latencia del sistema
```

### Escenario 13: Convergencia Eventual y Resiliencia post-desconexión / reconexión (AC-19)
```gherkin
Dado que "orchestrator" y "security-service" pierden temporalmente la conexión con NATS o se reinician
Y su catálogo en memoria se encuentra vacío
Cuando llega una petición de resolución o autorización durante dicho periodo
Entonces "CommandResolver" retorna "UNRESOLVED_REQUIRED" y "security-service" responde "DENY" (modo Fail-Closed seguro)
Sin colapsar ni lanzar excepciones no controladas
Cuando la conexión con NATS se restablece y "host-service" emite su siguiente publicación periódica
Entonces ambos consumidores reciben el evento y reconstruyen atómicamente su catálogo en memoria
Y las peticiones posteriores sobre comandos válidos se resuelven y autorizan con total normalidad
```

---

## 4. Diseño Técnico y Contratos

### 4.1. Catálogo Centralizado de Comandos (`config/commands.yaml`)

El catálogo de comandos se localiza en la raíz de configuración global de Nova (`config/commands.yaml`).

```yaml
# =============================================================================
# NOVA Central Command Catalog (Single Source of Truth)
# Defines logical commands, user-configured risk, natural language phrases,
# and private physical execution commands for host-service.
# =============================================================================

commands:
  - name: calculator
    command:
      - gnome-calculator
    risk: low
    phrases:
      - calculadora
      - maquina de calcular
      - el programa de cuentas
      - abre la calculadora

  - name: github
    command:
      - github
    risk: low
    phrases:
      - github
      - abrir github
      - git hub

  - name: backup
    command:
      - /usr/local/bin/nova-backup
      - --quick
    risk: medium
    phrases:
      - copia de seguridad
      - hacer backup
      - respaldar datos

  - name: format-disk
    command:
      - /usr/local/bin/nova-format-disk
    risk: high
    phrases:
      - formatear disco externo
      - formatear unidad usb
```

#### Modelo Pydantic de Validación en `host-service` (`src/models/commands.py`)
```python
from enum import Enum
from typing import List, Optional
from pydantic import BaseModel, Field, field_validator


class RiskLevel(str, Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"


class HostCommand(BaseModel):
    name: str = Field(..., min_length=1, description="Unique logical command identifier")
    command: List[str] = Field(..., min_length=1, description="Physical command and static argv (private to host-service)")
    risk: RiskLevel = Field(..., description="User-configured risk classification")
    phrases: List[str] = Field(..., min_length=1, description="Natural-language trigger phrases for CommandResolver")

    @field_validator("command")
    @classmethod
    def validate_command_elements(cls, v: List[str]) -> List[str]:
        if not v:
            raise ValueError("Command argv list must not be empty.")
        for arg in v:
            if not isinstance(arg, str) or not arg.strip():
                raise ValueError("Command argv elements must be non-empty strings.")
        return v

    @field_validator("phrases")
    @classmethod
    def validate_phrases(cls, v: List[str]) -> List[str]:
        if not v:
            raise ValueError("Phrases list must not be empty.")
        cleaned = [p.strip() for p in v if isinstance(p, str) and p.strip()]
        if not cleaned:
            raise ValueError("Command must have at least one non-empty trigger phrase.")
        return cleaned
```

---

### 4.2. Contrato del Evento Asíncrono NATS (`event.host.commands.available`)

El evento NATS modela la proyección pública distribuida y utiliza la librería de transporte `nova-event-bus` (ADR-018 y ADR-022).

> **Arquitectura de Eventos en Nova:** Siguiendo el estándar del proyecto, `nova-event-bus` provee la infraestructura base (`Event` y decorador `@event`), mientras que los esquemas de eventos de dominio se definen localmente en cada servicio (`host-service`: `src/models/commands.py` / `src/models/events.py`, `orchestrator`: `core/events.py`, `security-service`: `app/models/events.py`). Esto mantiene el desacoplamiento de despliegue entre microservicios independientes, garantizando la compatibilidad estricta mediante el contrato de serialización JSON en el subject `event.host.commands.available` (versión 1).

#### Definición del Evento Tipado (`core/events.py` / `nova-event-bus`)
```python
from dataclasses import dataclass
from typing import List
from nova_event_bus import Event, event


@dataclass
class PublicCommandEntry:
    name: str
    risk: str
    phrases: List[str]


@event("event.host.commands.available")
@dataclass
class HostCommandsAvailableEvent(Event):
    version: int
    commands: List[PublicCommandEntry]
```

#### Payload Serializado en NATS (Versión 1)
```json
{
  "type": "HostCommandsAvailableEvent",
  "payload": {
    "version": 1,
    "commands": [
      {
        "name": "calculator",
        "risk": "low",
        "phrases": [
          "calculadora",
          "maquina de calcular",
          "el programa de cuentas",
          "abre la calculadora"
        ]
      },
      {
        "name": "backup",
        "risk": "medium",
        "phrases": [
          "copia de seguridad",
          "hacer backup",
          "respaldar datos"
        ]
      }
    ]
  }
}
```

> **🔴 Invariante de Aislamiento:** El campo `command` (vector físico `argv`) **nunca** se incluye en este evento. Si un consumidor intenta deserializar o espera `command`, se considerará violación del contrato arquitectónico.

---

### 4.3. Implementación en `host-service`

#### Carga, Validación y Publicación Periódica (`src/services/catalog_publisher.py` y `src/app.py`)
```python
import asyncio
import logging
from typing import Optional
from nova_event_bus import NatsEventBus, EventBusConfig
from src.config import settings
from src.services.command_registry import CommandRegistry
from src.models.commands import HostCommandsAvailableEvent, PublicCommandEntry

logger = logging.getLogger(__name__)


class CatalogPublisher:
    def __init__(
        self,
        registry: CommandRegistry,
        event_bus: NatsEventBus,
        interval_seconds: Optional[float] = None,
    ):
        self.registry = registry
        self.event_bus = event_bus
        self._periodic_task: Optional[asyncio.Task] = None
        # Configurable interval (defaults to 60.0s in production, overridden in tests)
        self._interval_seconds = (
            interval_seconds
            if interval_seconds is not None
            else getattr(settings, "CATALOG_PUBLISH_INTERVAL_SECONDS", 60.0)
        )

    async def publish_catalog(self) -> bool:
        """Publishes the current public projection to NATS."""
        commands = self.registry.list_all()
        public_entries = [
            PublicCommandEntry(
                name=cmd.name,
                risk=cmd.risk.value,
                phrases=cmd.phrases
            )
            for cmd in commands
        ]
        evt = HostCommandsAvailableEvent(version=1, commands=public_entries)
        try:
            await self.event_bus.publish(evt)
            logger.info(f"Published catalog projection ({len(public_entries)} commands) to event.host.commands.available")
            return True
        except Exception as exc:
            logger.warning(f"Failed to publish commands catalog to NATS: {exc}")
            return False

    async def _periodic_loop(self):
        while True:
            try:
                await asyncio.sleep(self._interval_seconds)
                await self.publish_catalog()
            except asyncio.CancelledError:
                break
            except Exception as exc:
                logger.error(f"Error in catalog publication loop: {exc}", exc_info=True)

    def start(self):
        if self._periodic_task is None or self._periodic_task.done():
            self._periodic_task = asyncio.create_task(self._periodic_loop())
            logger.info(f"Started periodic catalog publisher loop (interval: {self._interval_seconds}s)")

    def stop(self):
        if self._periodic_task and not self._periodic_task.done():
            self._periodic_task.cancel()
            logger.info("Stopped periodic catalog publisher loop")
```

---

### 4.4. Implementación en `orchestrator`

#### 1. Proyección del Catálogo en Memoria (`core/command_catalog.py`)
```python
import logging
from typing import Dict, List, Optional
from dataclasses import dataclass
from core.events import PublicCommandEntry

logger = logging.getLogger(__name__)


@dataclass
class NormalizedCommandEntry:
    name: str
    risk: str
    phrases: List[str]
    normalized_phrases: List[str]


class CommandCatalogProjection:
    def __init__(self):
        self._commands: Dict[str, NormalizedCommandEntry] = {}
        self._is_ready: bool = False

    def update_from_event(self, commands: List[PublicCommandEntry], normalizer_fn):
        new_catalog: Dict[str, NormalizedCommandEntry] = {}
        for entry in commands:
            norm_phrases = [normalizer_fn(p) for p in entry.phrases if normalizer_fn(p)]
            new_catalog[entry.name] = NormalizedCommandEntry(
                name=entry.name,
                risk=entry.risk,
                phrases=entry.phrases,
                normalized_phrases=norm_phrases
            )
        self._commands = new_catalog
        self._is_ready = len(new_catalog) > 0
        logger.info(f"Command catalog projection updated in orchestrator with {len(self._commands)} commands.")

    @property
    def is_ready(self) -> bool:
        return self._is_ready

    def list_commands(self) -> List[NormalizedCommandEntry]:
        return list(self._commands.values())

    def get_command(self, name: str) -> Optional[NormalizedCommandEntry]:
        return self._commands.get(name)
```

#### 2. Implementación de `CommandResolver` (`core/parameter_resolution/resolvers/command.py`)
```python
import re
import unicodedata
import logging
from typing import Optional, List, Tuple
from rapidfuzz import fuzz

from core.config import settings
from core.models import PluginContext
from core.parameter_resolution.base import BaseParameterResolver
from core.parameter_resolution.models import (
    ParameterDefinition,
    ParameterResolutionResult,
    ParameterResolutionStatus,
)
from core.command_catalog import CommandCatalogProjection, NormalizedCommandEntry

logger = logging.getLogger(__name__)


class CommandResolver(BaseParameterResolver):
    """
    Deterministic resolver that transforms natural language phrases into
    logical command identifiers based on the public command catalog projection.

    Design rationale for fuzz.ratio (Specification §14, §15, §16):
    Matching operates strictly on the full normalized phrase (Full Phrase Matching)
    and forbids semantic inference or arbitrary substring extraction. Metrics such as
    partial_ratio or token_sort_ratio would allow phrases containing isolated overlapping
    words to trigger commands accidentally. fuzz.ratio computes the global Levenshtein
    similarity of the entire phrase, strictly bounded to absorb minor STT transcription
    errors without risking critical false positives.
    """

    # Default risk-dependent matching thresholds (0-100 scale)
    DEFAULT_RISK_THRESHOLDS = {
        "low": 60.0,
        "medium": 65.0,
        "high": 70.0,
    }
    DEFAULT_AMBIGUITY_DELTA = 5.0

    def __init__(
        self,
        catalog_projection: CommandCatalogProjection,
        thresholds: Optional[dict] = None,
        ambiguity_delta: Optional[float] = None,
    ):
        self.catalog = catalog_projection
        self.thresholds = thresholds or {
            "low": getattr(settings, "command_resolver_threshold_low", self.DEFAULT_RISK_THRESHOLDS["low"]),
            "medium": getattr(settings, "command_resolver_threshold_medium", self.DEFAULT_RISK_THRESHOLDS["medium"]),
            "high": getattr(settings, "command_resolver_threshold_high", self.DEFAULT_RISK_THRESHOLDS["high"]),
        }
        self.ambiguity_delta = (
            ambiguity_delta
            if ambiguity_delta is not None
            else getattr(settings, "command_resolver_ambiguity_delta", self.DEFAULT_AMBIGUITY_DELTA)
        )

    @property
    def target_type(self) -> str:
        return "Command"

    @staticmethod
    def normalize_phrase(text: str) -> str:
        """
        Applies Unicode normalization (NFKD), strips accents, removes punctuation,
        converts to lowercase and collapses whitespace.
        """
        if not text:
            return ""
        # 1. Unicode normalization and strip diacritics
        decomposed = unicodedata.normalize("NFKD", text)
        without_accents = "".join(c for c in decomposed if not unicodedata.combining(c))
        # 2. Lowercase
        lowered = without_accents.lower()
        # 3. Remove punctuation (keep alphanumeric and whitespace)
        cleaned = re.sub(r"[^\w\s]", " ", lowered)
        # 4. Collapse whitespace
        normalized = " ".join(cleaned.split())
        return normalized

    async def resolve(
        self,
        context: PluginContext,
        definition: ParameterDefinition
    ) -> ParameterResolutionResult:
        # Fail-closed if catalog is not available
        if not self.catalog.is_ready:
            logger.warning("CommandResolver: Cannot resolve parameter; command catalog not received yet.")
            return ParameterResolutionResult(
                parameter_name=definition.name,
                value=None,
                status=ParameterResolutionStatus.UNRESOLVED_REQUIRED if definition.required else ParameterResolutionStatus.UNRESOLVED_OPTIONAL,
                error_message="Command catalog is empty or has not been received from host-service."
            )

        # Forma canónica en Nova (conforme a core/models.py y resolvers existentes como IntegerResolver):
        # Priorizar context.normalized_text directamente, con fallback defensivo a context.raw_text si viniese vacío
        input_text = context.normalized_text or context.raw_text
        normalized_input = self.normalize_phrase(input_text)

        if not normalized_input:
            return ParameterResolutionResult(
                parameter_name=definition.name,
                value=None,
                status=ParameterResolutionStatus.UNRESOLVED_REQUIRED if definition.required else ParameterResolutionStatus.UNRESOLVED_OPTIONAL,
                error_message="Empty input phrase after normalization."
            )

        commands = self.catalog.list_commands()

        # Step 1: Exact Phrase Matching (Precedence over Fuzzy)
        for cmd in commands:
            for phrase in cmd.normalized_phrases:
                if normalized_input == phrase:
                    logger.info(
                        f"CommandResolver: Exact match found for '{normalized_input}' → '{cmd.name}'"
                    )
                    return ParameterResolutionResult(
                        parameter_name=definition.name,
                        value=cmd.name,
                        status=ParameterResolutionStatus.RESOLVED
                    )

        # Step 2: Fuzzy Matching with RapidFuzz
        candidates: List[Tuple[str, float, str]] = []  # (command_name, score, risk)
        for cmd in commands:
            threshold = self.thresholds.get(cmd.risk, self.thresholds["high"])
            best_score = 0.0
            for phrase in cmd.normalized_phrases:
                score = fuzz.ratio(normalized_input, phrase)
                if score > best_score:
                    best_score = score

            if best_score >= threshold:
                candidates.append((cmd.name, best_score, cmd.risk))

        if not candidates:
            logger.info(f"CommandResolver: No candidate matched threshold for input '{normalized_input}'")
            return ParameterResolutionResult(
                parameter_name=definition.name,
                value=None,
                status=ParameterResolutionStatus.UNRESOLVED_REQUIRED if definition.required else ParameterResolutionStatus.UNRESOLVED_OPTIONAL,
                error_message="No matching command found above risk threshold."
            )

        # Sort descending by score
        candidates.sort(key=lambda x: x[1], reverse=True)
        winner_name, winner_score, _ = candidates[0]

        # Step 3: Ambiguity Check
        if len(candidates) > 1:
            second_name, second_score, _ = candidates[1]
            if (winner_score - second_score) <= self.ambiguity_delta:
                logger.warning(
                    f"CommandResolver: Ambiguous resolution between '{winner_name}' ({winner_score:.1f}) "
                    f"and '{second_name}' ({second_score:.1f}). Discarding match."
                )
                return ParameterResolutionResult(
                    parameter_name=definition.name,
                    value=None,
                    status=ParameterResolutionStatus.UNRESOLVED_REQUIRED if definition.required else ParameterResolutionStatus.UNRESOLVED_OPTIONAL,
                    error_message=f"Ambiguous match between {winner_name} and {second_name}."
                )

        logger.info(
            f"CommandResolver: Fuzzy match accepted '{normalized_input}' → '{winner_name}' "
            f"(score={winner_score:.1f})"
        )
        return ParameterResolutionResult(
            parameter_name=definition.name,
            value=winner_name,
            status=ParameterResolutionStatus.RESOLVED
        )
```

---

### 4.5. Integración en `security-service`

#### Suscripción NATS y Actualización de Tabla Dinámica (`app/main.py`)
```python
from nova_event_bus import NatsEventBus, EventBusConfig
from app.models.security import HostCommandsAvailableEvent
from app.api import routes

# Inside lifespan startup:
event_bus = NatsEventBus(config=EventBusConfig(nats_url=settings.NATS_URL))
await event_bus.connect()

async def handle_commands_available(evt: HostCommandsAvailableEvent):
    logger.info(f"Received {len(evt.commands)} commands from host-service via NATS")
    entries = [{"name": c.name, "risk": c.risk} for c in evt.commands]
    routes.lookup_table_registry.register_table("host_commands", entries)

await event_bus.subscribe(HostCommandsAvailableEvent, handle_commands_available)
```

#### Desacoplamiento de la API REST de `security-service` (`app/api/routes.py`)
El endpoint REST `POST /v1/security/tables/{table_name}` se **preserva intacto** (sin modificaciones de código ni de contrato en `app/api/routes.py`). Sin embargo, su rol arquitectónico se redefine:
1. **Desacoplamiento en Producción:** `host-service` ya no realiza peticiones HTTP contra este endpoint. La tabla `"host_commands"` pasa a sincronizarse exclusivamente de forma reactiva y asíncrona a través del evento NATS `event.host.commands.available`.
2. **Propósito Residual:** Permanece disponible para pruebas unitarias aisladas de `security-service` (permitiendo poblar `LookupTableRegistry` sin requerir broker NATS) y para el registro de posibles tablas dinámicas secundarias de otros componentes.

---

## 5. Casos de Borde y Manejo de Errores

| Caso de Borde | Comportamiento Esperado | Implementación Técnica |
| :--- | :--- | :--- |
| **Archivo `config/commands.yaml` no existe o tiene sintaxis corrupta** | `host-service` aborta el arranque de inmediato con log de nivel `CRITICAL` (Fail-Closed). No inicia en estado parcial. | `CommandRegistry.load_from_file` lanza `InvalidCatalogError`, capturada en `lifespan` para detener el proceso. |
| **Identificadores `name` duplicados en `commands.yaml`** | Detección inmediata en la carga de configuración y aborto del arranque. | Validación en `CommandRegistry` comprobando `names_seen` y lanzando `InvalidCatalogError`. |
| **Entrada en el catálogo sin `phrases` o con lista vacía** | Rechazo estricto durante la validación en el arranque de `host-service`. | `field_validator("phrases")` en `HostCommand` exige lista no vacía con cadenas de texto no vacías. |
| **Valor de `risk` no soportado (ej. `critical` o `none`)** | Fallo de validación Pydantic en `host-service` abortando el inicio. | Enum `RiskLevel("low", "medium", "high")` con validación estricta en `HostCommand`. |
| **Pérdida de conexión o reinicio del broker NATS** | El cliente `NatsEventBus` reconecta automáticamente (`auto_reconnect=True`). En el siguiente tick de 60s se republíca el catálogo. | Conexión gestionada por `nova-event-bus` con callbacks de desconexión/reconexión y reintentos automáticos. |
| **Orquestador recibe una consulta antes del primer evento de NATS** | `CommandResolver` deniega la resolución retornando `UNRESOLVED_REQUIRED` / `UNRESOLVED_OPTIONAL`. | Chequeo preliminar `if not self.catalog.is_ready:` devolviendo `value=None` sin lanzar excepciones. |
| **Ambigüedad entre comandos similares (ej. `calculator` 68 pts vs `calendar` 65 pts)** | Ninguno de los dos comandos es seleccionado; el resultado es unresolved. | Si `(winner_score - second_score) <= ambiguity_delta` (5.0), se retorna `UNRESOLVED_REQUIRED` y se registra en logs. |
| **Comando de alto riesgo (`format-disk`) con similitud difusa del 62%** | Rechazado por no alcanzar el umbral de riesgo `high` (mínimo 70.0%). | Evaluación dinámica `score >= self.thresholds[cmd.risk]` antes de incorporar al candidato. |
| **Entrada con tildes, signos de puntuación invertidos y espacios múltiples** | Normalización léxica completa previa a la comparación. | `unicodedata.normalize("NFKD")`, eliminación de diacríticos y puntuación mediante expresión regular. |
| **Solicitud de ejecución a `host-service` para un comando desconocido** | Respuesta HTTP 404 con código de error estándar `COMMAND_NOT_FOUND` (ADR-004). | `CommandRegistry.get(command)` devuelve `None`, disparando `HTTPException(status_code=404)`. |

---

## 6. Estrategia de Testing

### Pruebas Unitarias

#### 1. Host Service (`host-service/tests/`)
- `tests/test_command_catalog_loader.py`:
  - Carga satisfactoria de `config/commands.yaml` con campos `name`, `command`, `risk` y `phrases`.
  - Aborto por fichero ausente, YAML inválido, identificadores duplicados o `phrases` vacías.
  - Verificación de que `HostCommand.phrases` valida y limpia cadenas con espacios redundantes.
- `tests/test_catalog_publisher.py`:
  - Publicación del evento `HostCommandsAvailableEvent` con contrato versión 1.
  - Verificación estricta de que el payload **no incluye** el campo físico `command` ni la ruta del ejecutable.
  - Verificación de la tarea periódica asíncrona parametrizando `interval_seconds=0.01` (o mockeando `asyncio.sleep`) para validar múltiples emisiones y cancelación limpia en milisegundos sin esperas reales de 60 segundos.

#### 2. Orchestrator (`orchestrator/tests/`)
- `tests/test_command_normalizer.py`:
  - Normalización de mayúsculas/minúsculas (`"CALCULADORA"` → `"calculadora"`).
  - Eliminación de acentos y diacríticos (`"máquina"` → `"maquina"`, `"cálculo"` → `"calculo"`).
  - Eliminación de signos de interrogación, exclamación y caracteres especiales (`"¡Abre la calculadora!"` → `"abre la calculadora"`).
  - Reducción de espacios intermedios y extremos (`"   abre   la    calculadora  "` → `"abre la calculadora"`).
- `tests/test_command_resolver.py`:
  - Coincidencia exacta determinista contra frases configuradas.
  - Coincidencia difusa con RapidFuzz para variaciones STT leves (`"calculadorra"` → `"calculator"`).
  - Verificación de umbrales diferenciados por riesgo: match aceptado en `low` pero rechazado para el mismo score en `high`.
  - Detección de ambigüedad: dos candidatos con diferencia `<= 5.0` puntos generan resultado no resuelto.
  - Ausencia de catálogo en memoria: retorna `UNRESOLVED_REQUIRED` con `value=None`.
- `tests/test_command_catalog_projection.py`:
  - Actualización de la proyección en memoria al recibir el evento NATS.
  - Pre-normalización de frases para optimizar la velocidad de búsqueda en tiempo de ejecución.

#### 3. Security Service (`security-service/tests/`)
- `tests/test_nats_catalog_sync.py`:
  - Recepción de `HostCommandsAvailableEvent` y actualización atómica de la tabla `"host_commands"`.
  - Verificación de que comandos no recibidos producen `RiskEvaluator` nulo y decisión `DENY`.

### Pruebas de Integración
- `orchestrator/tests/test_parameter_engine_command.py`:
  - Ejecución integrada de `ParameterResolverEngine` resolviendo definiciones de parámetros con `type="Command"`.
  - Inyección del parámetro resuelto en `ExecutionPlanStep.parameters["command"]`.
- `orchestrator/tests/test_catalog_nats_flow.py` (AC-19):
  - Simulación del flujo de resiliencia y convergencia eventual: corte transitorio / arranque en frío sin catálogo (Fail-Closed verificado), publicación con `CATALOG_PUBLISH_INTERVAL_SECONDS=0.05` y restauración autónoma del servicio en < 200 ms.

---

## 7. Plan de Implementación (Checklist)

- [x] **Fase 0: Preparación de Configuración y Formalización de ADR-027**
  - [x] Crear el archivo central [config/commands.yaml](file:///home/danuser2018/workspace/home-assistant/config/commands.yaml) conteniendo los comandos `calculator`, `github`, `backup` y `format-disk` con sus campos `name`, `command`, `risk` y `phrases`.
  - [x] Redactar y formalizar [docs/adr/adr-027-command-resolver-catalogo-comandos-nats.md](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-027-command-resolver-catalogo-comandos-nats.md) documentando las decisiones de catálogo central, publicación NATS periódica, aislamiento del ejecutable y lógica de riesgo en `CommandResolver`.
  - [x] Configurar la variable de infraestructura `NATS_URL=nats://nats:4222` directamente en [docker-compose.yml](file:///home/danuser2018/workspace/home-assistant/docker-compose.yml) para `security-service` (según [ADR-010](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-010.md)), manteniendo [config/security-service.env](file:///home/danuser2018/workspace/home-assistant/config/security-service.env) enfocado exclusivamente en parámetros de seguridad (`SECURITY_HMAC_SECRET`, `LOG_LEVEL`, `TOKEN_TTL_SECONDS`).
  - [x] Actualizar variables de entorno en [config/host-service.env](file:///home/danuser2018/workspace/home-assistant/config/host-service.env) definiendo `COMMANDS_FILE=config/commands.yaml`, `NATS_URL=nats://localhost:4222` y eliminando la variable obsoleta `SECURITY_SERVICE_BASE_URL`.
  - [x] Actualizar [docker-compose.yml](file:///home/danuser2018/workspace/home-assistant/docker-compose.yml) para que `security-service` dependa de `nats` (`condition: service_healthy`) y reciba la variable `NATS_URL`.

- [x] **Fase 1: Adaptación y Publicación en Host Service (`host-service`)**
  - [x] Añadir `nova-event-bus @ git+https://github.com/danuser2018/nova-event-bus.git@1.1.0` a [requirements.txt](file:///home/danuser2018/workspace/host-service/requirements.txt).
  - [x] Actualizar modelo `HostCommand` en [src/models/commands.py](file:///home/danuser2018/workspace/host-service/src/models/commands.py) para incluir el campo obligatorio `phrases: List[str]` con su validador.
  - [x] Definir los modelos de evento `PublicCommandEntry` y `HostCommandsAvailableEvent` decorado con `@event("event.host.commands.available")`.
  - [x] Modificar [src/config.py](file:///home/danuser2018/workspace/host-service/src/config.py) para definir `COMMANDS_FILE: str = "config/commands.yaml"`, `NATS_URL: str = "nats://localhost:4222"`, `CATALOG_PUBLISH_INTERVAL_SECONDS: float = 60.0`, y eliminar la variable obsoleta `SECURITY_SERVICE_BASE_URL`.
  - [x] Actualizar [src/services/command_registry.py](file:///home/danuser2018/workspace/host-service/src/services/command_registry.py) para validar y cargar el nuevo esquema con `phrases`, y eliminar la antigua función HTTP `publish_command_catalog`.
  - [x] Crear `src/services/catalog_publisher.py` con la clase `CatalogPublisher` para publicar en NATS el catálogo público al inicio y periódicamente según `interval_seconds` (por defecto 60s, configurable para tests).
  - [x] Integrar la conexión del EventBus y el ciclo de vida de `CatalogPublisher` en el `lifespan` de [src/app.py](file:///home/danuser2018/workspace/host-service/src/app.py), eliminando la antigua llamada HTTP síncrona a `security-service`.
  - [x] Deprecar y eliminar el catálogo local [config/host_commands.yaml](file:///home/danuser2018/workspace/host-service/config/host_commands.yaml) de `host-service`.
  - [x] Crear tests unitarios en `tests/test_command_registry.py` y `tests/test_catalog_publisher.py`.
  - [x] Ejecutar `pytest` en `host-service` y verificar 100% de éxito.

- [x] **Fase 2: Integración de Catálogo NATS en Security Service (`security-service`)**
  - [x] Añadir `nova-event-bus @ git+https://github.com/danuser2018/nova-event-bus.git@1.1.0` a [requirements.txt](file:///home/danuser2018/workspace/security-service/requirements.txt).
  - [x] Añadir `NATS_URL: str = "nats://nats:4222"` en [app/config.py](file:///home/danuser2018/workspace/security-service/app/config.py).
  - [x] Definir el modelo de evento `HostCommandsAvailableEvent` en [app/models/events.py](file:///home/danuser2018/workspace/security-service/app/models/events.py).
  - [x] Modificar [app/main.py](file:///home/danuser2018/workspace/security-service/app/main.py) para implementar un contexto `lifespan` que conecte `NatsEventBus`, se suscriba a `HostCommandsAvailableEvent` y actualice la tabla `"host_commands"` en `LookupTableRegistry`.
  - [x] Asegurar desconexión limpia del `NatsEventBus` durante el apagado del servicio.
  - [x] Crear test unitario en `tests/test_nats_catalog_sync.py` validando la actualización de la tabla dinámica al recibir el evento.
  - [x] Ejecutar `pytest` en `security-service` verificando que la suite de seguridad pasa sin regresiones.

- [x] **Fase 3: Implementación de CommandResolver y Catálogo en Orchestrator (`orchestrator`)**
  - [x] En [core/config.py](file:///home/danuser2018/workspace/orchestrator/core/config.py), añadir los parámetros de sintonización de CommandResolver en `Settings`: `command_resolver_threshold_low: float = 60.0`, `command_resolver_threshold_medium: float = 65.0`, `command_resolver_threshold_high: float = 70.0`, `command_resolver_ambiguity_delta: float = 5.0`.
  - [x] Definir `PublicCommandEntry` y `HostCommandsAvailableEvent` en [core/events.py](file:///home/danuser2018/workspace/orchestrator/core/events.py).
  - [x] Crear `core/command_catalog.py` implementando `CommandCatalogProjection` con soporte de actualización dinámica y pre-normalización de frases.
  - [x] Crear `core/parameter_resolution/resolvers/command.py` implementando `CommandResolver` con:
    - Normalización léxica (`normalize_phrase`).
    - Coincidencia exacta de frase completa con prioridad.
    - Similitud difusa con RapidFuzz ponderada por umbrales de riesgo configurables (`low: 60.0`, `medium: 65.0`, `high: 70.0`).
    - Detección y rechazo de ambigüedad configurable (`AMBIGUITY_DELTA: 5.0`).
    - Manejo fail-closed cuando no hay catálogo disponible.
  - [x] Exportar `CommandResolver` en [core/parameter_resolution/resolvers/__init__.py](file:///home/danuser2018/workspace/orchestrator/core/parameter_resolution/resolvers/__init__.py).
  - [x] En [main.py](file:///home/danuser2018/workspace/orchestrator/main.py):
    - Instanciar `CommandCatalogProjection`.
    - Suscribirse a `HostCommandsAvailableEvent` sobre el `event_bus` existente.
    - Registrar `CommandResolver` en `ParameterResolverRegistry`.
  - [x] Crear pruebas unitarias en `tests/test_command_normalizer.py`, `tests/test_command_catalog_projection.py` y `tests/test_command_resolver.py`.
  - [x] Crear prueba de integración de resolución de parámetro en `tests/test_parameter_engine_command.py`.
  - [x] Crear prueba de integración de flujo NATS en `tests/test_catalog_nats_flow.py` (simulando corte, comportamiento fail-closed transitorio y convergencia autónoma ultrarrápida con `CATALOG_PUBLISH_INTERVAL_SECONDS=0.05`).
  - [x] Ejecutar `pytest` en `orchestrator` y verificar 100% de éxito.

- [x] **Fase 4: Pruebas de Integración y Regresión Global**
  - [x] Verificar el flujo completo: publicación simulada de `HostCommandsAvailableEvent` -> recepción en `orchestrator` -> resolución de frase en `CommandResolver` -> emisión de `ExecutionPlan` -> evaluación de riesgo en `security-service` -> ejecución en `host-service`.
  - [x] Verificar comportamiento fail-closed ante catálogo ausente en todos los componentes.
  - [x] Verificar que ninguna definición física de ejecutable (`command` / `argv`) se expone en NATS ni en los modelos públicos de `orchestrator` o `security-service`.

- [x] **Fase 5: Documentación, Versionado y Entrega**
  - [x] Actualizar [docs/services.md](file:///home/danuser2018/workspace/home-assistant/docs/services.md) reflejando las nuevas responsabilidades de catálogo y registrando formalmente el nuevo subject NATS `event.host.commands.available` en el catálogo de eventos del sistema (productor: `host-service`, consumidores: `orchestrator` y `security-service`), actualizando la topología y variables de entorno de `host-service` y `security-service`.
  - [x] Actualizar [docs/architecture.md](file:///home/danuser2018/workspace/home-assistant/docs/architecture.md) incorporando el diagrama y explicación de la distribución del catálogo de comandos vía NATS.
  - [x] Actualizar `security-service/README.md` documentando la sincronización asíncrona vía NATS para `host_commands` y clarificando el rol residual de `POST /v1/security/tables/{table_name}`.
  - [x] Actualizar `host-service/README.md` documentando la publicación en NATS, `config/commands.yaml` y la eliminación de `SECURITY_SERVICE_BASE_URL`.
  - [x] Actualizar `CHANGELOG.md` en `host-service`, `orchestrator`, `security-service` y `home-assistant` bajo la sección `[Sin publicar]`.
  - [x] Actualizar el campo `version` en `pyproject.toml` / `src/app.py` según corresponda en cada repositorio.
