# Refinamiento de la Feature: Fase 1 — Interfaz de Resolución de Parámetros

- **Archivo de origen**: [docs/features/nova-fase-1-requisitos-resolucion-parametros.md](file:///home/danuser2018/workspace/home-assistant/docs/features/nova-fase-1-requisitos-resolucion-parametros.md)
- **Fecha**: 2026-08-08
- **Estado**: Refinado

---

## 1. Resumen y Contexto de Negocio

### Objetivo Principal
Establecer la infraestructura contractual y las interfaces desacopladas en el microservicio `orchestrator` de Nova-2 para permitir la declaración y resolución de parámetros en los plugins de intención. 

Esta primera fase únicamente introduce la capa contractual abstraccta (definición de modelos de parámetros, interfaz genérica de resolver, registro centralizado de tipos lógicos y motor de coordinación), dejando la implementación de extractores concretos por tipo de dato (`IntegerResolver`, `DateResolver`, `LocationResolver`, etc.) fuera de alcance para fases posteriores. La solución mantiene la compatibilidad total con los plugins existentes y respeta los invariantes del ecosistema: procesamiento local/offline, determinismo y separación estricta entre la resolución de intenciones y la ejecución de planes.

### Actores y Flujo de Alto Nivel
1. **Developer / Plugin Creator**: Declara en la definición de cada plugin los parámetros requeridos mediante objetos `ParameterDefinition` (indicando `name`, `type`, `required` y `default`).
2. **Parameter Resolver Registry (`ParameterResolverRegistry`)**: Mantiene la asociación entre tipos lógicos (ej. `Integer`, `Date`) y sus correspondientes clases o instancias `BaseParameterResolver`.
3. **Execution Planner (`ExecutionPlanner`)**:
   - Recibe la petición del usuario `UserRequest`.
   - Identifica el plugin ganador mediante `SimilarityEngine`.
   - Invoca al `ParameterResolverEngine` inyectándole las declaraciones de parámetros del plugin seleccionado.
   - Construye el `ExecutionPlan` incorporando en cada `ExecutionPlanStep` los parámetros resueltos en su mapa `parameters`.
4. **Plugin Executor (`PlanExecutor`)**: Recibe el `ExecutionPlan` enriquecido con los parámetros resueltos y ejecuta la acción del plugin.

---

## 2. Análisis de Servicios e Impacto

| Servicio | Tipo de Cambio | Descripción del Impacto |
| :--- | :--- | :--- |
| `orchestrator` | Modificar | - Extensión de `plugins/base.py` para añadir la propiedad `parameters` en la abstracción `Plugin` (con valor por defecto `[]` para retrocompatibilidad).<br>- Creación de `core/parameter_resolution/` conteniendo `models.py` (`ParameterDefinition`, `ParameterResolutionStatus`, `ParameterResolutionResult`), `base.py` (`BaseParameterResolver`), `registry.py` (`ParameterResolverRegistry`) y `engine.py` (`ParameterResolverEngine`).<br>- Modificación de `ExecutionPlanner` en `core/engine.py` para integrar la invocación al `ParameterResolverEngine`.<br>- Actualización de la suite de tests en `tests/` para validar el registro, interfaces, casos de borde y retrocompatibilidad de plugins existentes. |
| `interaction-manager` | Ninguno | Permanece 100% compatible sin cambios. Sigue consumiendo los endpoints existentes del orquestador. |
| `home-assistant` | Modificar | - Actualización del catálogo de servicios (`docs/services.md`) y arquitectura (`docs/architecture.md`) documentando la capa de resolución de parámetros.<br>- Creación del registro de decisión de arquitectura `docs/adr/adr-024-interfaces-resolucion-parametros-orquestador.md`. |

---

## 3. Especificación de Comportamiento (Criterios de Aceptación)

### Escenario 1: Declaración y Registro de Resolvers por Tipo Lógico
```gherkin
Dado que existe un registrador "ParameterResolverRegistry" en el sistema
Cuando se registra un resolver concreto para el tipo lógico "Integer"
Entonces el registro almacena la asociación "Integer" -> "IntegerResolver"
Y una consulta al registro solicitando el resolver para "Integer" devuelve la instancia de "IntegerResolver"
```

### Escenario 2: Resolución de Parámetros Opcionales con Valor por Defecto
```gherkin
Dado un plugin que declara un parámetro opcional:
  | name | type    | required | default |
  | max  | Integer | false    | 100     |
Y dado que no se registra ningún resolver para el tipo "Integer" o el resolver no encuentra valor en el texto "Dime un número"
Cuando "ParameterResolverEngine" resuelve los parámetros para la instrucción "Dime un número"
Entonces la resolución final del parámetro "max" asigna el valor por defecto 100
Y el estado de resolución del parámetro es "DEFAULT_VALUE_USED"
```

### Escenario 3: Parámetro Obligatorio No Resuelto
```gherkin
Dado un plugin que declara un parámetro obligatorio sin valor por defecto:
  | name   | type    | required | default |
  | target | Location| true     | null    |
Y dado que el texto "Pon la luz" no contiene una ubicación resoluble
Cuando "ParameterResolverEngine" procesa la resolución de parámetros
# Nota de Fase 1: no existe resolver registrado para "Location", por lo que el estado es TYPE_NOT_REGISTERED.
# El estado UNRESOLVED_REQUIRED se alcanzará en fases futuras cuando exista un resolver que no logre extraer el valor.
Entonces el parámetro "target" se marca con el estado "TYPE_NOT_REGISTERED"
Y el resultado global de la resolución indica que existen parámetros sin resolver sin romper la construcción del "ExecutionPlan"
```

### Escenario 4: Retrocompatibilidad con Plugins Sin Declaración de Parámetros
```gherkin
Dado un plugin legacy activo que no declara parámetros (propiedad "parameters" por defecto devuelve lista vacía)
Cuando el "ExecutionPlanner" evalúa y selecciona dicho plugin para una instrucción dada
Entonces el "ParameterResolverEngine" procesa la lista vacía de parámetros sin lanzar excepciones
Y el "ExecutionPlanStep" resultante contiene la clave "parameters" con un diccionario vacío "{}"
```

---

## 4. Diseño Técnico y Contratos

### Modelos y Contratos en Python (`orchestrator/core/parameter_resolution/`)

#### 1. Modelos de Datos (`core/parameter_resolution/models.py`)
```python
from enum import Enum
from typing import Any, Optional
from pydantic import BaseModel

class ParameterResolutionStatus(str, Enum):
    RESOLVED = "RESOLVED"
    UNRESOLVED_OPTIONAL = "UNRESOLVED_OPTIONAL"
    DEFAULT_VALUE_USED = "DEFAULT_VALUE_USED"
    UNRESOLVED_REQUIRED = "UNRESOLVED_REQUIRED"
    TYPE_NOT_REGISTERED = "TYPE_NOT_REGISTERED"

class ParameterDefinition(BaseModel):
    name: str
    type: str
    required: bool = False
    default: Optional[Any] = None

class ParameterResolutionResult(BaseModel):
    parameter_name: str
    value: Optional[Any] = None
    status: ParameterResolutionStatus
    error_message: Optional[str] = None
```

#### 2. Interfaz Base del Resolver (`core/parameter_resolution/base.py`)
```python
from abc import ABC, abstractmethod
from typing import Optional
from core.models import PluginContext
from .models import ParameterDefinition, ParameterResolutionResult

class BaseParameterResolver(ABC):
    @property
    @abstractmethod
    def target_type(self) -> str:
        """Return the logical type handled by this resolver (e.g. 'Integer', 'Date')."""
        pass

    @abstractmethod
    async def resolve(
        self, 
        context: PluginContext, 
        definition: ParameterDefinition
    ) -> ParameterResolutionResult:
        """Resolve a single parameter from the user text/context."""
        pass
```

#### 3. Registro Centralizado (`core/parameter_resolution/registry.py`)
```python
from typing import Dict, Optional
from .base import BaseParameterResolver

class ParameterResolverRegistry:
    def __init__(self):
        self._resolvers: Dict[str, BaseParameterResolver] = {}

    def register(self, resolver: BaseParameterResolver) -> None:
        type_key = resolver.target_type.lower()
        self._resolvers[type_key] = resolver

    def get(self, target_type: str) -> Optional[BaseParameterResolver]:
        return self._resolvers.get(target_type.lower())

    def unregister(self, target_type: str) -> None:
        self._resolvers.pop(target_type.lower(), None)
```

#### 4. Motor de Coordinación (`core/parameter_resolution/engine.py`)
```python
from typing import List, Dict, Any, Tuple
from core.models import PluginContext
from .models import ParameterDefinition, ParameterResolutionResult, ParameterResolutionStatus
from .registry import ParameterResolverRegistry

class ParameterResolverEngine:
    def __init__(self, registry: ParameterResolverRegistry):
        self.registry = registry

    async def resolve_parameters(
        self, 
        context: PluginContext, 
        definitions: List[ParameterDefinition]
    ) -> Tuple[Dict[str, Any], List[ParameterResolutionResult]]:
        resolved_params: Dict[str, Any] = {}
        detailed_results: List[ParameterResolutionResult] = []

        for definition in definitions:
            resolver = self.registry.get(definition.type)
            if not resolver:
                if definition.default is not None:
                    res = ParameterResolutionResult(
                        parameter_name=definition.name,
                        value=definition.default,
                        status=ParameterResolutionStatus.DEFAULT_VALUE_USED
                    )
                    resolved_params[definition.name] = definition.default
                elif not definition.required:
                    res = ParameterResolutionResult(
                        parameter_name=definition.name,
                        value=None,
                        status=ParameterResolutionStatus.UNRESOLVED_OPTIONAL
                    )
                else:
                    res = ParameterResolutionResult(
                        parameter_name=definition.name,
                        value=None,
                        status=ParameterResolutionStatus.TYPE_NOT_REGISTERED,
                        error_message=f"No parameter resolver registered for type '{definition.type}'"
                    )
                detailed_results.append(res)
                continue

            try:
                res = await resolver.resolve(context, definition)
                if res.status == ParameterResolutionStatus.RESOLVED:
                    resolved_params[definition.name] = res.value
                elif res.value is None and definition.default is not None:
                    res = ParameterResolutionResult(
                        parameter_name=definition.name,
                        value=definition.default,
                        status=ParameterResolutionStatus.DEFAULT_VALUE_USED
                    )
                    resolved_params[definition.name] = definition.default
            except Exception as e:
                if definition.default is not None:
                    res = ParameterResolutionResult(
                        parameter_name=definition.name,
                        value=definition.default,
                        status=ParameterResolutionStatus.DEFAULT_VALUE_USED,
                        error_message=str(e)
                    )
                    resolved_params[definition.name] = definition.default
                else:
                    res = ParameterResolutionResult(
                        parameter_name=definition.name,
                        value=None,
                        status=ParameterResolutionStatus.UNRESOLVED_REQUIRED if definition.required else ParameterResolutionStatus.UNRESOLVED_OPTIONAL,
                        error_message=str(e)
                    )
            detailed_results.append(res)

        return resolved_params, detailed_results
```

#### 5. Modificación en la Abstracción Plugin (`plugins/base.py`)
```python
# Add parameters property with empty list as default value
@property
def parameters(self) -> List[ParameterDefinition]:
    """Collection of parameters declared by the plugin. Default is empty list."""
    return []
```

---

## 5. Casos de Borde y Manejo de Errores

| Caso de Borde | Comportamiento Esperado | Implementación Técnica |
| :--- | :--- | :--- |
| **Tipo lógico no registrado en el registro** | Si tiene `default`, usar el valor por defecto (`DEFAULT_VALUE_USED`). Si es opcional sin defecto, marcar `UNRESOLVED_OPTIONAL`. Si es obligatorio sin defecto, marcar `TYPE_NOT_REGISTERED`. | El `ParameterResolverEngine` verifica `registry.get(definition.type)`. Si retorna `None`, asigna el estado adecuado sin lanzar excepción no controlada. |
| **Excepción durante la resolución en un resolver concreto** | Capturar la excepción, registrar log de error y aplicar valor por defecto si existe, o marcar el parámetro como no resuelto. | Bloque `try-except` envolviendo `resolver.resolve(context, definition)` dentro de `ParameterResolverEngine`. |
| **Parámetro obligatorio sin valor disponible ni resolver** | Incluir el estado `UNRESOLVED_REQUIRED` o `TYPE_NOT_REGISTERED` en el resultado detallado. En la Fase 1, no se detiene la construcción del `ExecutionPlanStep` (se deja `parameters` sin esa clave), delegando la interacción conversacional de aclaración a fases posteriores. | `ParameterResolverEngine` retorna la tupla con los parámetros resueltos y los resultados detallados. `ExecutionPlanner` incluye los parámetros resueltos en `step.parameters`. |
| **Plugin legacy sin propiedad `parameters`** | Mantener compatibilidad total sin requerir cambios en plugins legacy. | `Plugin.__getattribute__` o el valor por defecto del método `@property def parameters(self) -> List[ParameterDefinition]: return []` retorna `[]`. |
| **Texto de entrada totalmente vacío** | Cortocircuitar la búsqueda de candidatos y seleccionar el plugin `fallback` sin invocar resolución de parámetros. | Preservar el guard existente en `ExecutionPlanner.resolve`: `if not normalized_text: return ExecutionPlan(steps=[step_fallback])`. |

---

## 6. Estrategia de Testing

### Pruebas Unitarias (`orchestrator/tests/`)
1. **Modelos y Definición de Parámetros (`tests/test_parameter_models.py`)**:
   - Validar creación de `ParameterDefinition` con valores obligatorios y por defecto.
   - Verificar la deserialización y enums de `ParameterResolutionStatus`.
2. **Registro de Resolvers (`tests/test_parameter_registry.py`)**:
   - Probar registro, obtención e insensibilidad a mayúsculas/minúsculas de tipos lógicos (`Integer`, `integer`).
   - Verificar comportamiento al consultar tipos no registrados o desregistrar componentes.
3. **Motor de Resolución (`tests/test_parameter_engine.py`)**:
   - Testear resolución con un resolver mockeado que retorna un valor exitoso.
   - Probar fallback a `default` cuando el resolver no resuelve o falla.
   - Validar tratamiento de parámetros obligatorios no resueltos.
   - Verificar comportamiento ante tipos no registrados.
4. **Compatibilidad de Plugins (`tests/test_plugin_parameters.py`)**:
   - Certificar que plugins existentes sin propiedad `parameters` declarada devuelven `[]` y funcionan correctamente.

### Pruebas de Integración (`tests/test_execution_planner_parameters.py`)
- Integrar `ParameterResolverRegistry` y `ParameterResolverEngine` en `ExecutionPlanner`.
- Crear un plugin de prueba con parámetros declarados y verificar que al llamar a `ExecutionPlanner.resolve(request)` el `ExecutionPlanStep` resultante incluye los parámetros resueltos en su campo `parameters`.

---

## 7. Plan de Implementación (Checklist)

- [ ] **Fase 0: Definición Arquitectónica y ADR**
  - [ ] Crear el borrador formal del registro de decisión de arquitectura `docs/adr/adr-024-interfaces-resolucion-parametros-orquestador.md` en el repositorio `home-assistant`.

- [ ] **Fase 1: Creación de Módulos e Interfaces en Orchestrator**
  - [ ] Crear el paquete `core/parameter_resolution/` con `__init__.py`.
  - [ ] Implementar `core/parameter_resolution/models.py` con `ParameterDefinition`, `ParameterResolutionStatus` y `ParameterResolutionResult`.
  - [ ] Implementar `core/parameter_resolution/base.py` con la clase abstracta `BaseParameterResolver`.
  - [ ] Implementar `core/parameter_resolution/registry.py` con `ParameterResolverRegistry`.
  - [ ] Implementar `core/parameter_resolution/engine.py` con `ParameterResolverEngine`.
  - [ ] Modificar `plugins/base.py` para añadir la propiedad `parameters` en `Plugin`.

- [ ] **Fase 2: Integración en el Orquestador**
  - [ ] Instanciar `ParameterResolverRegistry` y `ParameterResolverEngine` en el ciclo `lifespan` de `main.py` y registrarlos en `app.state.parameter_registry` y `app.state.parameter_engine` (siguiendo el patrón de `PluginManager` y `SimilarityEngine`).
  - [ ] Inyectar `ParameterResolverEngine` en el constructor de `ExecutionPlanner` al construirlo en `main.py`, pasándolo como dependencia explícita.
  - [ ] Actualizar el constructor de `ExecutionPlanner` en `core/engine.py` para aceptar `ParameterResolverEngine` como parámetro opcional.
  - [ ] Actualizar el método `ExecutionPlanner.resolve` para invocar `resolve_parameters` tras seleccionar el plugin ganador.

- [ ] **Fase 3: Pruebas Automatizadas**
  - [ ] Crear `tests/test_parameter_models.py`, `tests/test_parameter_registry.py` y `tests/test_parameter_engine.py`.
  - [ ] Crear `tests/test_execution_planner_parameters.py` para verificar la integración.
  - [ ] Ejecutar la suite completa de pruebas de `orchestrator` (`pytest`) garantizando cero regresiones.

- [ ] **Fase 4: Documentación y Registros**
  - [ ] Actualizar `docs/services.md` y `docs/architecture.md` en `home-assistant`.
  - [ ] Actualizar `CHANGELOG.md` de `orchestrator` bajo `[Sin publicar]` y actualizar la versión en `pyproject.toml` del `orchestrator` en el mismo commit.
  - [ ] Actualizar `CHANGELOG.md` de `home-assistant` bajo `[Sin publicar]` y actualizar la versión en `pyproject.toml` de `home-assistant` en el mismo commit si aplica.

---

## Anexo: Borrador de Referencia para el ADR-024

```markdown
# ADR-024: Arquitectura e Interfaces de Resolución de Parámetros en Orchestrator

## Fecha
08-08-2026

## Estado
Propuesto

## Contexto
El servicio `orchestrator` de Nova-2 clasifica la intención del usuario y genera un `ExecutionPlanStep` que incluye un campo `parameters: Dict[str, Any]`. Sin embargo, hasta la fecha no existía un contrato formal para declarar qué parámetros espera cada plugin ni un mecanismo desacoplado para extraer dichos parámetros a partir del lenguaje natural.

Para permitir la evolución hacia tipos complejos (números, fechas, duraciones, ubicaciones) sin romper la modularidad ni acoplar el orquestador a lógica específica por plugin, se requiere una arquitectura extensible basada en registros e interfaces abstractas.

## Decisión
Se decide implementar en el servicio `orchestrator` la infraestructura contractual de resolución de parámetros bajo las siguientes directivas:

1. **Declaración de Parámetros en Plugins**: La abstracción `Plugin` en `plugins/base.py` expondrá una propiedad `parameters` que retorna una lista de `ParameterDefinition` (`name`, `type`, `required`, `default`).
2. **Interfaz Común Base**: Definir la clase abstracta `BaseParameterResolver` que establece el contrato que deben cumplir los extractores especializados por tipo lógico (`target_type`, `resolve()`).
3. **Registro por Tipo Lógico**: Crear la clase `ParameterResolverRegistry` encargada de asociar tipos lógicos (ej. `Integer`, `Date`) con sus implementaciones concretas de resolver.
4. **Motor Desacoplado**: Introducir `ParameterResolverEngine` para coordinar la resolución de parámetros durante la construcción del `ExecutionPlanStep` en `ExecutionPlanner`, abstrayendo la selección de resolvers y el manejo de valores por defecto.
5. **Separación de Fases**: En esta primera fase no se implementan extractores concretos (`IntegerResolver`, `DateResolver`, etc.), sentando únicamente las bases contractuales y garantizando retrocompatibilidad total con plugins existentes.

## Consecuencias
* **(+) Bajo Acoplamiento**: `ExecutionPlanner` no contiene sentencias condicionales (`if/else`) para cada tipo de parámetro.
* **(+) Extensibilidad**: Añadir un nuevo tipo de parámetro solo requiere definir el tipo, implementar su resolver derivado de `BaseParameterResolver` y registrarlo en `ParameterResolverRegistry`.
* **(+) Determinismo y Procesamiento Local**: Se preserva el invariante de resolución determinista y local sin dependencias externas ni servicios cloud.
* **(+) Retrocompatibilidad**: Los plugins existentes siguen funcionando sin modificaciones al heredar la lista vacía de parámetros por defecto.
```
