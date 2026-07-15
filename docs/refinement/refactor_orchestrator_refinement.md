# Refinamiento de la Feature: Refactorización de Orchestrator (Separación de Intent Resolver y Plugin Executor)

- **Archivo de origen**: [refactor_orchestrator.md](file:///home/danuser2018/workspace/home-assistant/docs/features/refactor_orchestrator.md)
- **Fecha**: 2026-07-15
- **Estado**: Refinado

---

## 1. Resumen y Contexto de Negocio

### Objetivo Principal
Refactorizar el microservicio `orchestrator` para desacoplar su motor interno en dos componentes diferenciados: **Intent Resolver** (responsable del procesamiento del lenguaje natural, cálculo de similitud mediante RapidFuzz y generación de un plan de ejecución) y **Plugin Executor** (responsable de la validación y ejecución secuencial del plan utilizando los plugins cargados). 

Esta separación permite aislar la lógica de comprensión de intenciones de la lógica de ejecución del ecosistema, facilitando la futura incorporación de parámetros, validaciones de seguridad (Security Manager), contexto conversacional (Context Service) y planes multi-acción. La refactorización se realizará de una sola vez para evitar duplicaciones y complejidad temporal en una base de código tan reducida (~300 líneas), asegurando compatibilidad del 100% con los clientes existentes (como `interaction-manager`).

### Actores y Flujo de Alto Nivel
1. **Interaction Manager (Consumidor)**: Envía una petición `POST /api/v1/execute` con el texto transcrito por voz.
2. **Orchestrator API Gateway / Controller (Proveedor)**:
   - Recibe la petición en el endpoint heredado `/api/v1/execute`.
   - Llama internamente a `IntentResolver` para obtener el `ExecutionPlan`.
   - Llama internamente a `PluginExecutor` con dicho plan para realizar la acción.
   - Retorna la respuesta unificada compatible con el formato actual.
3. **Intent Resolver (Componente Interno)**:
   - Recibe el texto y normaliza su formato.
   - Aplica el motor de similitud (RapidFuzz) sobre los ejemplos de los plugins activos.
   - Devuelve un `ExecutionPlan` estructurado.
4. **Plugin Executor (Componente Interno)**:
   - Recibe el `ExecutionPlan`.
   - Valida el plan.
   - Resuelve las instancias de los plugins mediante el `PluginManager`.
   - Ejecuta de manera asíncrona la acción de cada paso y devuelve un resultado unificado.

---

## 2. Análisis de Servicios e Impacto

| Servicio | Tipo de Cambio | Descripción del Impacto |
| :--- | :--- | :--- |
| `orchestrator` | Modificar | - Refactorización de `core/engine.py` para separar la lógica de enrutamiento en las clases `IntentResolver` y `PluginExecutor`.<br>- Actualización de `core/models.py` para introducir el modelo de datos formal `ExecutionPlan` y sus pasos (`ExecutionPlanStep`).<br>- Modificación de `core/api.py` para añadir los endpoints internos `POST /api/v1/resolve` y `POST /api/v1/execute-plan`, y refactorizar `/api/v1/execute` para secuenciar ambos pasos de forma interna sin romper la retrocompatibilidad.<br>- Actualización completa de la suite de pruebas automatizadas en `tests/` para probar ambos componentes aisladamente. |
| `interaction-manager` | Ninguno | Permanece 100% compatible sin cambios. Sigue consumiendo `POST /api/v1/execute` de forma transparente. |
| `home-assistant` | Modificar | - Actualización del catálogo de servicios (`docs/services.md`) para documentar los nuevos endpoints internos y el modelo `ExecutionPlan`.<br>- Actualización de la arquitectura del sistema (`docs/architecture.md`) para documentar la nueva separación Resolver/Executor y el registro de la decisión ADR-014.<br>- Creación del registro formal de arquitectura `docs/adr/adr-014-refactorizacion-orquestador.md`. |

---

## 3. Especificación de Comportamiento (Criterios de Aceptación)

### Escenario 1: Endpoint de Resolución de Intención (Resolve)
```gherkin
Dado que el servicio "orchestrator" está activo
Cuando se realiza una petición HTTP "POST /api/v1/resolve" con el cuerpo:
  """
  {
    "text": "qué tiempo hace hoy"
  }
  """
Entonces el servicio calcula la similitud con RapidFuzz
Y responde con código de estado 200 OK
Y el cuerpo de la respuesta contiene un "ExecutionPlan" con los pasos:
  """
  {
    "steps": [
      {
        "plugin": "WeatherPlugin",
        "confidence": 94.2,
        "parameters": {},
        "channel": "voice",
        "context": {
          "raw_text": "qué tiempo hace hoy",
          "normalized_text": "que tiempo hace hoy"
        },
        "security": {}
      }
    ]
  }
  """
```

### Escenario 2: Endpoint de Ejecución de Plan (Execute Plan)
```gherkin
Dado que el servicio "orchestrator" está activo y el plugin "WeatherPlugin" está cargado
Cuando se realiza una petición HTTP "POST /api/v1/execute-plan" con el cuerpo:
  """
  {
    "steps": [
      {
        "plugin": "WeatherPlugin",
        "parameters": {},
        "channel": "voice",
        "context": {
          "raw_text": "qué tiempo hace hoy",
          "normalized_text": "que tiempo hace hoy"
        },
        "security": {}
      }
    ]
  }
  """
Entonces el servicio ejecuta el plugin "WeatherPlugin"
Y responde con código de estado 200 OK
Y la respuesta es estructurada y exitosa:
  """
  {
    "success": true,
    "plugin_used": "WeatherPlugin",
    "speech": "Actualmente hace 22 grados.",
    "execution_time_ms": 15
  }
  """
```

### Escenario 3: Compatibilidad y comportamiento de /execute
```gherkin
Dado que el cliente envía una petición clásica "POST /api/v1/execute" con:
  """
  {
    "text": "pon el volumen en silencio"
  }
  """
Cuando el servidor procesa la petición
Entonces ejecuta secuencialmente y de forma transparente:
  1. resolve("pon el volumen en silencio") -> ExecutionPlan (MutePlugin)
  2. execute_plan(ExecutionPlan) -> AssistantResponse
Y responde con código de estado 200 OK
Y la estructura del JSON es idéntica a la anterior a la refactorización:
  """
  {
    "success": true,
    "plugin_used": "MutePlugin",
    "speech": "El sistema ha sido silenciado.",
    "execution_time_ms": 10
  }
  """
```



---

## 4. Diseño Técnico y Contratos

### Contratos de API (Inglés Obligatorio para payloads)

#### 1. POST `/api/v1/resolve`
- **Method**: POST
- **Payload de entrada (`UserRequest`)**:
```json
{
  "text": "qué tiempo hace hoy",
  "timestamp": 1782390123.45
}
```
- **Respuesta exitosa (`ExecutionPlan`)**:
```json
{
  "steps": [
    {
      "plugin": "WeatherPlugin",
      "confidence": 94.2,
      "parameters": {},
      "channel": "voice",
      "context": {
        "raw_text": "qué tiempo hace hoy",
        "normalized_text": "que tiempo hace hoy",
        "metadata": {}
      },
      "security": {}
    }
  ]
}
```
- **Respuesta de error** (esquema ADR-004):
```json
{
  "error": "ValidationError",
  "message": "El campo 'text' es obligatorio y no puede estar vacío.",
  "status": 422
}
```

#### 2. POST `/api/v1/execute-plan`
> **Nota de nomenclatura:** Se adopta `/api/v1/execute-plan` en lugar de `/api/v1/plans/execute` para mantener la coherencia semántica con el endpoint `/api/v1/execute` ya existente y facilitar la retrocompatibilidad terminológica.

- **Method**: POST
- **Payload de entrada (`ExecutionPlan`)**:
```json
{
  "steps": [
    {
      "plugin": "WeatherPlugin",
      "confidence": 94.2,
      "parameters": {},
      "channel": "voice",
      "context": {
        "raw_text": "qué tiempo hace hoy",
        "normalized_text": "que tiempo hace hoy",
        "metadata": {}
      },
      "security": {}
    }
  ]
}
```
- **Respuesta exitosa (`AssistantResponse`)**:
```json
{
  "success": true,
  "plugin_used": "WeatherPlugin",
  "speech": "Actualmente hace 22 grados.",
  "execution_time_ms": 12
}
```
- **Respuesta de error** (esquema ADR-004):
```json
{
  "error": "PluginNotFoundError",
  "message": "El plugin 'UnknownPlugin' no está registrado en el sistema.",
  "status": 400
}
```

#### 3. POST `/api/v1/execute` (Retrocompatible)
- **Method**: POST
- **Payload de entrada (`UserRequest`)**:
```json
{
  "text": "qué tiempo hace hoy",
  "timestamp": 1782390123.45
}
```
- **Respuesta (`AssistantResponse`)**:
```json
{
  "success": true,
  "plugin_used": "WeatherPlugin",
  "speech": "Actualmente hace 22 grados.",
  "execution_time_ms": 18
}
```

### Modelos en Python (`core/models.py`)
```python
from pydantic import BaseModel
from typing import Dict, Any, List, Optional

class UserRequest(BaseModel):
    text: str
    timestamp: Optional[float] = None

class PluginContext(BaseModel):
    raw_text: str
    normalized_text: str
    metadata: Dict[str, Any] = {}

class ExecutionPlanStep(BaseModel):
    plugin: str
    confidence: Optional[float] = None
    parameters: Dict[str, Any] = {}
    channel: Optional[str] = "voice"
    context: PluginContext
    security: Dict[str, Any] = {}

class ExecutionPlan(BaseModel):
    steps: List[ExecutionPlanStep]

class PluginResult(BaseModel):
    success: bool
    speech: str
    data: Optional[Dict[str, Any]] = None
    error_message: Optional[str] = None

class AssistantResponse(BaseModel):
    success: bool
    plugin_used: str
    speech: str
    execution_time_ms: int
```

---

## 5. Casos de Borde y Manejo de Errores

| Caso de Borde | Comportamiento Esperado | Implementación Técnica |
| :--- | :--- | :--- |
| **Texto de entrada vacío en resolve** | Resolver devuelve un plan con un único paso que apunta a `FallbackPlugin`. | El `IntentResolver` valida si el texto está vacío o sin caracteres válidos tras normalizar y devuelve el paso para `FallbackPlugin` con la confianza mínima requerida. |
| **Plugin de un paso del plan no existe en executor** | Retornar error HTTP 500 o fallar la ejecución del paso agregando log descriptivo. | En `PluginExecutor.execute_plan`, comprobar si `plugin_manager.get_plugin(step.plugin)` devuelve `None`. Si es así, lanzar `PluginNotFoundError` controlado mapeado a HTTP 400 o HTTP 500 según ADR-004. |
| **Fallo al ejecutar uno de los pasos del plan multi-acción** | Detener la ejecución del plan inmediatamente, marcando `success = False` y devolviendo el error del paso fallido. | Capturar excepciones en el bucle secuencial de ejecución. Detener el bucle en el primer error no controlado o en el primer paso con `success = False`. |
| **JSON mal formateado en el plan** | Retornar HTTP 422 con error estructurado de validación Pydantic. | El framework FastAPI validará automáticamente el payload del body mediante la clase `ExecutionPlan`. |

---

## 6. Estrategia de Testing

### Pruebas Unitarias (`orchestrator/tests/`)
1. **Intent Resolver (`tests/test_resolver.py`)**:
   - Probar que `IntentResolver.resolve` normaliza correctamente el texto (eliminación de acentos, minúsculas, caracteres especiales).
   - Validar que genera un objeto `ExecutionPlan` adecuado con estructura completa para entradas típicas.
   - Probar la resolución ante entradas vacías (comportamiento de fallback).
   - Validar la resolución del tie-breaker y umbrales de similitud.
2. **Plugin Executor (`tests/test_executor.py`)**:
   - Mockear plugins y verificar que `PluginExecutor.execute_plan` los invoca correctamente pasándoles el respectivo `PluginContext`.
   - Probar la gestión de errores en el executor cuando un plugin falla o no existe.
3. **Compatibilidad API (`tests/test_api.py`)**:
   - Verificar los códigos de estado `200` y `422` en los nuevos endpoints `/resolve` y `/execute-plan`.
   - Certificar que `/execute` sigue funcionando exactamente igual que antes con los mismos payloads y comportamiento.
   - Verificar que los payloads de error de los nuevos endpoints siguen el esquema ADR-004.
4. **Scaffolding de tests existentes**:
   - Actualizar `tests/conftest.py` para reemplazar la instancia de `Router` por `IntentResolver` y `PluginExecutor` separados.
   - Revisar y adaptar `tests/test_engine.py` a la nueva estructura de clases (`PluginMatcher` / `IntentResolver`).

---

## 7. Plan de Implementación (Checklist)

- [ ] **Fase 0: Modificación de Modelos y Contratos**
  - [ ] Actualizar `core/models.py` en `orchestrator` para añadir los esquemas `ExecutionPlanStep` y `ExecutionPlan` garantizando consistencia con Pydantic.
  - [ ] Modificar la clase de error del sistema si es necesario en caso de validación del plan.

- [ ] **Fase 1: Implementación de Intent Resolver y Plugin Executor**
  - [ ] Modificar `core/engine.py` para extraer la funcionalidad de búsqueda de similitud y enrutamiento en la clase `IntentResolver`.
  - [ ] Implementar la clase `PluginExecutor` en `core/engine.py` que reciba el `PluginManager` e implemente el método secuencial `execute_plan(plan: ExecutionPlan)`.
  - [ ] Eliminar por completo la dependencia de `Router` en `core/api.py` y `main.py`: los handlers del router de FastAPI deben recuperar `app.state.resolver` (instancia de `IntentResolver`) y `app.state.executor` (instancia de `PluginExecutor`) en lugar del antiguo `app.state.engine`.

- [ ] **Fase 2: Actualización de la API de Orchestrator**
  - [ ] Modificar `core/api.py` para importar los nuevos modelos.
  - [ ] Añadir el endpoint `POST /api/v1/resolve` inyectando `IntentResolver` desde el estado de la aplicación.
  - [ ] Añadir el endpoint `POST /api/v1/execute-plan` (o `/plans/execute`) inyectando `PluginExecutor`.
  - [ ] Actualizar el controlador del endpoint `POST /api/v1/execute` para que actúe como puente secuencial (`resolve` -> `execute_plan`) de manera interna.
  - [ ] Modificar `main.py` de `orchestrator` para registrar en el `app.state` las instancias globales de `IntentResolver` y `PluginExecutor` durante el ciclo de vida `lifespan`: **eliminar** el registro de `app.state.engine` y sustituirlo por `app.state.resolver` y `app.state.executor` como instancias independientes.

- [ ] **Fase 3: Actualización de Pruebas Automatizadas**
  - [ ] Escribir la suite de pruebas unitarias `tests/test_resolver.py` y `tests/test_executor.py`.
  - [ ] Actualizar las pruebas integradas existentes en `tests/test_api.py` y `tests/test_routing.py` para validar que no existan regresiones.
  - [ ] Actualizar `tests/conftest.py` para reemplazar la instancia de `Router` por instancias independientes de `IntentResolver` y `PluginExecutor`.
  - [ ] Revisar y adaptar `tests/test_engine.py` a la nueva estructura de clases (`PluginMatcher` / `IntentResolver`).

- [ ] **Fase 4: Actualización de Skills y Documentación**
  - [ ] Crear el registro formal de decisión arquitectónica `docs/adr/adr-014-refactorizacion-orquestador.md` en `home-assistant`.
  - [ ] Modificar la skill `service-responsibilities` en `home-assistant` para referenciar el nuevo ADR-014.
  - [ ] Modificar la skill `api-contracts` en `home-assistant` para referenciar el nuevo ADR-014.
  - [ ] Modificar el catálogo de servicios en `docs/services.md` de `home-assistant` para registrar los nuevos endpoints del orquestador.
  - [ ] Modificar el documento de arquitectura `docs/architecture.md` en `home-assistant` para detallar la separación de componentes en el orquestador y añadir el ADR-014.
  - [ ] Actualizar el `CHANGELOG.md` del `orchestrator` y `home-assistant` bajo `[Sin publicar]` detallando la refactorización arquitectónica.

- [ ] **Fase 5: Verificación de Regresiones E2E**
  - [ ] Levantar el entorno Docker local.
  - [ ] Ejecutar el pipeline completo de voz del sistema y certificar que la comunicación `interaction-manager` -> `orchestrator` funciona perfectamente y el asistente de voz responde sin errores ni demoras apreciables.

---

## Anexo: Borrador de Referencia para el ADR-014

```markdown
# ADR-014: Separación de Responsabilidades en el Orquestador (Intent Resolver y Plugin Executor)

## Fecha
15-07-2026

## Estado
Propuesto

## Contexto
El servicio `orchestrator` realizaba dos tareas diferenciadas en un único flujo acoplado dentro de la clase `Router`: la determinación de la intención semántica (comprensión del lenguaje natural mediante RapidFuzz) y la ejecución del plugin correspondiente.
Con la evolución de Nova-2 hacia capacidades más complejas (control de seguridad por acción, enriquecimiento de datos de contexto, resolución inteligente de parámetros y planes que combinan múltiples acciones en secuencia), el diseño monolítico del orquestador se convierte en una barrera de mantenibilidad.
Necesitamos desacoplar estas etapas del pipeline introduciendo un contrato intermedio claro y estable entre ellas.

## Decisión
Se decide aplicar una refactorización estructural profunda al orquestador bajo las siguientes directivas:
1. **Separación de Componentes**: Desacoplar el núcleo de enrutamiento en dos clases independientes:
   - `IntentResolver`: Se limita a calcular similitudes semánticas y construir un plan formal de pasos (`ExecutionPlan`).
   - `PluginExecutor`: Se limita a validar y ejecutar los pasos descritos en un `ExecutionPlan` usando las instancias de plugins correspondientes.
2. **Modelo ExecutionPlan Estructurado**: Establecer un modelo de datos formal en Pydantic que defina la secuencia de acciones a ejecutar, permitiendo soporte nativo para múltiples pasos, parámetros tipados, contexto específico de llamada y metadatos de seguridad.
3. **Nuevos Endpoints REST**: Exponer formalmente la API REST interna para ambos componentes:
   - `POST /api/v1/resolve`: Retorna el plan de ejecución `ExecutionPlan` correspondiente al texto del usuario.
   - `POST /api/v1/execute-plan`: Recibe y ejecuta el `ExecutionPlan` secuencialmente.
4. **Retrocompatibilidad y Aislamiento de Red**: Para evitar alterar la comunicación del coordinador `interaction-manager` (lo que duplicaría innecesariamente la latencia y requeriría actualizar el cliente), el endpoint público `POST /api/v1/execute` se mantendrá operativo ejecutando de forma interna y secuencial el resolver y el executor.

## Consecuencias
* **(+) Principio de Responsabilidad Única**: El procesamiento del lenguaje y la invocación de código de dominio quedan aislados y son testeables en total independencia.
* **(+) Extensibilidad**: Permite la futura inclusión sencilla de validadores de seguridad, enriquecedores de contexto y resolvedores de parámetros en el flujo del plan sin tocar los plugins existentes.
* **(+) Soporte Multi-acción**: El modelo del plan admite ejecutar múltiples plugins de forma coordinada en una sola llamada de voz.
* **(+) Sin penalización de red para el consumidor**: Al encapsular el flujo secuencial Resolver→Executor dentro del endpoint público `/api/v1/execute`, el consumidor `interaction-manager` no sufre ninguna latencia adicional por llamadas HTTP en cascada desde el exterior.
```
