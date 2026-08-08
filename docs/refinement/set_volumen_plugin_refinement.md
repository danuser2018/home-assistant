# Refinamiento de la Feature: Plugin `volume-set`

- **Archivo de origen**: [docs/features/set_volumen_plugin.md](file:///home/danuser2018/workspace/home-assistant/docs/features/set_volumen_plugin.md)
- **Identificador en Especificación Origen**: `volume.set` (Mapeado al identificador canónico `volume-set` según [ADR-023](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-023-estandarizacion-identificador-plugin-execution-plan.md))
- **Fecha**: 2026-08-09
- **Estado**: Refinado

---

## 1. Resumen y Contexto de Negocio

### Objetivo Principal
Implementar en el microservicio `orchestrator` el plugin de intenciones `VolumeSetPlugin` (con identificador canónico `volume-set` en cumplimiento del [ADR-023](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-023-estandarizacion-identificador-plugin-execution-plan.md), correspondiente a la especificación de la feature `volume.set`) para permitir que el asistente local Nova interprete instrucciones verbales de ajuste de volumen a un valor objetivo absoluto comprendido entre `0` y `100` inclusive (ej. *"Pon el volumen al 50"*, *"Establece el volumen en 30"*).

El plugin se integrará con el motor determinista de resolución de parámetros (`ParameterResolverEngine` e `IntegerResolver`, definidos en el [ADR-024](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-024-interfaces-resolucion-parametros-orquestador.md)) y delegará la modificación física de los niveles del mezclador del sistema operativo en el componente de abstracción de hardware `host-service` a través del endpoint `POST /v1/audio/volume/set` ([ADR-002](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-002.md) y [ADR-013](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-013-integracion-host-service.md)).

### Actores y Flujo de Alto Nivel
1. **User Request**: La orden hablada o escrita del usuario (ej. *"Pon el volumen al 80"*) entra a través del pipeline de `interaction-manager` hacia `orchestrator`.
2. **Intent Selection**: `SimilarityEngine` identifica la coincidencia semántica con `VolumeSetPlugin` (`id`: `"volume-set"`).
3. **Parameter Resolution**: `ExecutionPlanner` solicita a `ParameterResolverEngine` resolver el parámetro obligatorio `volume: Integer` expuesto por `VolumeSetPlugin`. `IntegerResolver` parsea el entero `80` a partir del texto normalizado.
4. **Validation**: `VolumeSetPlugin` valida defensivamente que la cifra `80` se encuentra dentro del rango biyectivo `[0, 100]`.
5. **HAL Invocation**: `PlanExecutor` ejecuta el plugin, el cual invoca de forma asíncrona al cliente `HostServiceClient.set_volume(80)`, enviando un payload HTTP `POST /v1/audio/volume/set` a `host-service`.
6. **Verbal Feedback**: Se devuelve al flujo principal un `PluginResult` con el estado de éxito y la síntesis verbal directa `"Volumen al 80 por ciento."`, respetando el principio de respuesta mínima e impersonal de Nova-2 (`TONE_GUIDE.md`).

```text
"Pon el volumen al 80"
          ↓
   IntentResolver (SimilarityEngine)
          ↓
  VolumeSetPlugin (id: volume-set)
          ↓
   ParameterResolverEngine (IntegerResolver -> 80)
          ↓
 ExecutionPlanStep (parameters: {"volume": 80})
          ↓
 VolumeSetPlugin.execute()
          ↓
 HostServiceClient -> POST /v1/audio/volume/set {"volume": 80}
          ↓
 "Volumen al 80 por ciento."
```

---

## 2. Análisis de Servicios e Impacto

| Servicio | Tipo de Cambio | Descripción del Impacto |
| :--- | :--- | :--- |
| `orchestrator` | Modificar | - Extensión de `HostServiceClient` en `core/host_service_client.py` con el método asíncrono `set_volume(self, volume: int) -> AudioState`.<br>- Adición de `VolumeSetPlugin` en `plugins/volume/main.py` declarando `parameters = [ParameterDefinition(name="volume", type="Integer", required=True)]`, `id = "volume-set"` y `priority = 60`.<br>- *Nota de resolución de parámetros*: `IntegerResolver` ya se encuentra implementado en `core/parameter_resolution/resolvers/integer.py` y registrado en `main.py`, por lo que no requiere trabajo de desarrollo adicional en esta feature.<br>- Validación defensiva de rango `0 <= volume <= 100` previa a la llamada remota.<br>- Creación de tests unitarios e integración en `tests/test_volume_set_plugin.py`. |
| `host-service` | Ninguno | El endpoint `POST /v1/audio/volume/set` ya se encuentra implementado y expuesto en `src/routes/audio.py` recibiendo `VolumeSetRequest(volume=int)` y respondiendo `AudioStateResponse(volume=int, muted=bool)`. |
| `system-service` | Ninguno | Al arrancar `orchestrator`, `lifespan` registrará automáticamente la nueva capacidad `volume-set` mediante la llamada HTTP existente a `/v1/system/capabilities`. |
| `interaction-manager` | Ninguno | Permanece 100% compatible sin cambios. Recibe e interpreta de manera transparente el paso `ExecutionPlanStep` con `plugin: "volume-set"`. |
| `home-assistant` | Modificar | Actualización de la documentación viva del ecosistema en `docs/services.md` y `docs/architecture.md` para reflejar la incorporación de `VolumeSetPlugin`. |

---

## 3. Especificación de Comportamiento (Criterios de Aceptación)

### Escenario 1: Ajuste de volumen absoluto a un nivel intermedio válido
```gherkin
Dado que el plugin "VolumeSetPlugin" está activo en el servicio "orchestrator"
Y que "IntegerResolver" resuelve el parámetro "volume" con el valor 50
Cuando se procesa la instrucción "Pon el volumen al 50"
Entonces "VolumeSetPlugin" invoca "HostServiceClient.set_volume(50)"
Y "host-service" procesa el cambio mediante "POST /v1/audio/volume/set" con body `{"volume": 50}`
Y el plugin retorna un resultado exitoso con el mensaje hablado "Volumen al 50 por ciento."
```

### Escenario 2: Ajuste de volumen al límite inferior (0%)
```gherkin
Dado que "VolumeSetPlugin" recibe el parámetro "volume" con valor 0
Cuando el usuario indica "Pon el volumen al 0" o "Pon el volumen a cero"
Entonces el plugin ejecuta "POST /v1/audio/volume/set" con body `{"volume": 0}`
Y la respuesta hablada retornada es "Volumen al 0 por ciento."
```

### Escenario 3: Ajuste de volumen al límite superior (100%)
```gherkin
Dado que "VolumeSetPlugin" recibe el parámetro "volume" con valor 100
Cuando el usuario indica "Pon el volumen al 100"
Entonces el plugin ejecuta "POST /v1/audio/volume/set" con body `{"volume": 100}`
Y la respuesta hablada retornada es "Volumen al 100 por ciento."
```

### Escenario 4: Rechazo por parámetro de volumen no especificado o ausente
```gherkin
Dado que "VolumeSetPlugin" declara el parámetro "volume" como obligatorio (required=True)
Cuando el usuario emite una frase incompleta como "Pon el volumen"
Entonces "ParameterResolverEngine" determina que el parámetro obligatorio "volume" no ha sido resuelto
Y "VolumeSetPlugin.execute()" detecta la ausencia del parámetro
Y detiene la ejecución sin enviar ninguna petición a "host-service"
Y retorna un resultado fallido con la respuesta hablada "Indica un nivel de volumen."
```

### Escenario 5: Rechazo por cifra fuera de rango inferior (menor a 0)
```gherkin
Dado que se recibe la orden "Pon el volumen a menos diez" con un valor resuelto de -10
Cuando "VolumeSetPlugin.execute()" valida la cifra recibida
Entonces el plugin detecta que el valor es inferior a 0
Y detiene la ejecución sin realizar llamadas a "host-service"
Y retorna un resultado fallido con la respuesta hablada "Indica un volumen entre 0 y 100."
```

### Escenario 6: Rechazo por cifra fuera de rango superior (mayor a 100)
```gherkin
Dado que se recibe la orden "Pon el volumen al 120" con un valor resuelto de 120
Cuando "VolumeSetPlugin.execute()" evalúa las restricciones de seguridad y negocio
Entonces el plugin detecta que el valor supera el máximo permitido de 100
Y no realiza ninguna petición HTTP hacia "host-service"
Y retorna un resultado fallido con la respuesta hablada "Indica un volumen entre 0 y 100."
```

### Escenario 7: No interferencia con plugins de ajuste relativo (volume-up / volume-down)
```gherkin
Dado el conjunto de frases de entrenamiento del plugin "volume-set"
Cuando se evalúan expresiones que implican una variación relativa como "Sube el volumen" o "Baja el volumen"
Entonces "SimilarityEngine" clasifica la intención hacia "volume-up" o "volume-down" respectivamente
Y no activa la ejecución de "volume-set"
```

### Escenario 8: Manejo de indisponibilidad de comunicación con host-service
```gherkin
Dado que "host-service" no se encuentra alcanzable por problemas de red o tiempo de espera agotado
Cuando "VolumeSetPlugin" intenta invocar "HostServiceClient.set_volume(50)"
Entonces el cliente captura "httpx.ConnectError" o "httpx.TimeoutException"
Y el plugin retorna un resultado de fallo controlado con la respuesta hablada "Servicio no disponible."
```

---

## 4. Diseño Técnico y Contratos

### 1. Extensión del Cliente HTTP `HostServiceClient` (`orchestrator/core/host_service_client.py`)

Se añade el método de invocación directa del endpoint de fijación de volumen en `HostServiceClient`:

```python
class HostServiceClient:
    # ... métodos existentes (get_volume, volume_up, volume_down, mute, unmute) ...

    async def set_volume(self, volume: int) -> AudioState:
        url = f"{self.base_url.rstrip('/')}/v1/audio/volume/set"
        logger.info(f"Consuming URL: {url} with volume: {volume}")
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.post(url, json={"volume": volume})
            response.raise_for_status()
            data = response.json()
            logger.info(f"Response received: {data}")
            return AudioState(**data)
```

### 2. Implementación de `VolumeSetPlugin` (`orchestrator/plugins/volume/main.py`)

Se añade la clase `VolumeSetPlugin` al archivo de plugins de volumen existente. 

> **Nota de Justificación Arquitectónica (Defensa en Profundidad)**: Aunque la skill `service-responsibilities` establece que los plugins deben mantenerse sin lógica de negocio propia de dominio, la verificación del rango `0 <= volume <= 100` en `VolumeSetPlugin.execute()` se adopta explícitamente como una *guardia de defensa en profundidad*. Esta validación evita peticiones HTTP remotas innecesarias hacia `host-service` ante parámetros fuera de rango y proporciona una respuesta hablada contextual e inmediata al usuario.

```python
class VolumeSetPlugin(Plugin):
    def __init__(self):
        super().__init__()
        self.client = None

    @property
    def name(self) -> str:
        return "VolumeSetPlugin"

    @property
    def description(self) -> str:
        return "Establece el volumen de audio del sistema a un valor absoluto entre 0 y 100"

    @property
    def id(self) -> str:
        return "volume-set"

    @property
    def priority(self) -> int:
        return 60

    @property
    def parameters(self) -> List[ParameterDefinition]:
        return [
            ParameterDefinition(
                name="volume",
                type="Integer",
                required=True
            )
        ]

    @property
    def examples(self) -> List[str]:
        return [
            "Pon el volumen al 50",
            "Establece el volumen en 30",
            "Fija el volumen al 75",
            "Pon el volumen al 100",
            "Volumen al 20",
            "Pon el volumen a cero",
            "Ajusta el volumen al 80 por ciento",
            "Pon el volumen en cincuenta",
            "Pon el volumen al 10",
            "Fijar el volumen a 40"
        ]

    def initialize(self) -> None:
        logger.info("Initializing VolumeSetPlugin")
        self.client = HostServiceClient()

    async def execute(self, context: PluginContext) -> PluginResult:
        logger.info("Starting execution of VolumeSetPlugin")
        raw_val = context.parameters.get("volume") if context.parameters else None

        if raw_val is None:
            return PluginResult(
                success=False,
                speech="Indica un nivel de volumen."
            )

        if not isinstance(raw_val, int) or raw_val < 0 or raw_val > 100:
            return PluginResult(
                success=False,
                speech="Indica un volumen entre 0 y 100."
            )

        try:
            result = await self.client.set_volume(raw_val)
            speech = f"Volumen al {result.volume} por ciento."
            return PluginResult(
                success=True,
                speech=speech,
                data=result.model_dump()
            )
        except (httpx.ConnectError, httpx.TimeoutException) as conn_err:
            logger.error(f"Connection error connecting to host-service: {conn_err}")
            return PluginResult(success=False, speech="Servicio no disponible.")
        except Exception as e:
            logger.error(f"Error executing VolumeSetPlugin: {e}", exc_info=True)
            return PluginResult(success=False, speech="No he podido completar la operación.")
```

### 3. Esqueleto de la Interfaz REST en `host-service` (Verificación de Contrato Existente)

El endpoint `POST /v1/audio/volume/set` en `host-service` responde al siguiente esquema JSON:

**Request Payload:**
```json
{
  "volume": 80
}
```

**Response Payload (`200 OK`):**
```json
{
  "volume": 80,
  "muted": false
}
```

---

## 5. Casos de Borde y Manejo de Errores

| Caso de Borde | Comportamiento Esperado | Implementación Técnica |
| :--- | :--- | :--- |
| **Instrucción incompleta sin parámetro ("Pon el volumen")** | Se detiene la ejecución previa a la llamada HTTP. Retorna `success=False` y `speech="Indica un nivel de volumen."`. | `Validation in VolumeSetPlugin.execute: if raw_val is None:` |
| **Parámetro fuera de rango ("Pon el volumen al 150")** | Se bloquea el envío de la petición a `host-service`. Retorna `success=False` y `speech="Indica un volumen entre 0 y 100."`. | `Range assertion: if not isinstance(raw_val, int) or raw_val < 0 or raw_val > 100:` |
| **Entrada numérica escrita en letras ("Pon el volumen a cincuenta")** | `IntegerResolver` procesa la palabra "cincuenta" convirtiéndola al entero `50`. El plugin procesa el ajuste a 50%. | `IntegerResolver lexicon map SPANISH_CARDINALS["cincuenta"] -> 50.` |
| **Fallo HTTP o caídas del servicio `host-service`** | Se captura `httpx.ConnectError` o `httpx.TimeoutException` devueltas por el cliente HTTP y se responde `speech="Servicio no disponible."`. | `Dedicated exception handler catching httpx transport errors in VolumeSetPlugin.execute.` |
| **Excepción inesperada en runtime** | Captura genérica de excepciones con log detallado de traza `logger.error(..., exc_info=True)` y mensaje genérico `speech="No he podido completar la operación."`. | `Generic Exception catch block returning standardized error speech per ADR-002 (Orchestrator).` |

---

## 6. Estrategia de Testing

### Pruebas Unitarias (`orchestrator/tests/test_volume_set_plugin.py`)
1. **Pruebas del método `HostServiceClient.set_volume`**:
   - Mockear `httpx.AsyncClient.post` y verificar la generación correcta de la URL `/v1/audio/volume/set` y el cuerpo JSON `{"volume": 50}`.
2. **Pruebas de la lógica del plugin `VolumeSetPlugin`**:
   - Inyectar `context.parameters = {"volume": 50}` y verificar retorno exitoso con `speech="Volumen al 50 por ciento."` y llamadas al cliente HTTP.
   - Inyectar `context.parameters = {"volume": 0}` y verificar `speech="Volumen al 0 por ciento."`.
   - Inyectar `context.parameters = {"volume": 100}` y verificar `speech="Volumen al 100 por ciento."`.
   - Inyectar `context.parameters = {}` y verificar respuesta hablada *"Indica un nivel de volumen."* sin llamadas a `host-service`.
   - Inyectar `context.parameters = {"volume": 150}` y `context.parameters = {"volume": -5}`, verificando el rechazo con respuesta hablada *"Indica un volumen entre 0 y 100."*.
   - Simular error de conexión `httpx.ConnectError` en el cliente y comprobar que se retorna `speech="Servicio no disponible."`.

### Pruebas de Integración (`orchestrator/tests/test_volume_set_integration.py`)
- Verificar el flujo completo del orquestador resolviendo la intención y parámetros para frases reales:
  - Input: *"Pon el volumen al 70"* -> `ExecutionPlanStep` contiene `plugin: "volume-set"` y `parameters: {"volume": 70}`.

---

## 7. Plan de Implementación (Checklist)

- [ ] **Fase 1: Extensión del Cliente HTTP en Orchestrator**
  - [ ] Añadir el método `async def set_volume(self, volume: int) -> AudioState` en `core/host_service_client.py` de `orchestrator`.

- [ ] **Fase 2: Implementación del Plugin VolumeSetPlugin**
  - [ ] Importar `ParameterDefinition` en `plugins/volume/main.py`.
  - [ ] Implementar la clase `VolumeSetPlugin` en `plugins/volume/main.py` con `id = "volume-set"`, `parameters` declarando `volume: Integer` obligatorio, validaciones de rango `0..100` y manejo de errores.

- [ ] **Fase 3: Pruebas Automatizadas**
  - [ ] Crear el archivo de test `tests/test_volume_set_plugin.py` en `orchestrator` cubriendo todos los escenarios unitarios y de manejo de errores de comunicación.
  - [ ] Crear/actualizar test de integración en `tests/test_volume_set_integration.py` validando la resolución de `volume-set` mediante `ExecutionPlanner`.
  - [ ] Ejecutar `pytest` en `orchestrator` y comprobar que la suite pase con 100% de éxito.

- [ ] **Fase 4: Documentación y Versionado**
  - [ ] Actualizar `docs/services.md` y `docs/architecture.md` en `home-assistant` documentando el plugin `volume-set`.
  - [ ] Actualizar `CHANGELOG.md` en `orchestrator` e incrementar la versión en `pyproject.toml` dentro del mismo commit (cumpliendo `development-workflow`).
  - [ ] Actualizar `CHANGELOG.md` en `home-assistant` bajo la sección `[Sin publicar]` (nota: `home-assistant` es un repositorio de documentación viva y no contiene `pyproject.toml`).

- [ ] **Fase 5: Despliegue Local**
  - [ ] Reconstruir y reiniciar el servicio `orchestrator` mediante `docker compose up --build orchestrator` y verificar la publicación de la capacidad `volume-set` en `system-service`.
