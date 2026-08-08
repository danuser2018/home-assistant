# Refinamiento de la Feature: Fase 2 — IntegerResolver

- **Archivo de origen**: [docs/features/nova-fase-2-integer-resolver-requisitos.md](file:///home/danuser2018/workspace/home-assistant/docs/features/nova-fase-2-integer-resolver-requisitos.md)
- **Fecha**: 2026-08-08
- **Estado**: Refinado

---

## 1. Resumen y Contexto de Negocio

### Objetivo Principal
Implementar en el microservicio `orchestrator` el extractor especializado `IntegerResolver` como el primer resolver concreto de tipo de dato del ecosistema Nova-2. Este resolver se integrará con la infraestructura de abstracción de parámetros introducida en la Fase 1 (`BaseParameterResolver`, `ParameterResolverRegistry` y `ParameterResolverEngine`).

Asimismo, se adaptará el plugin existente de generación de números aleatorios `RandomNumberPlugin` (`id`: `"random-number"`) para que declare formalmente el parámetro `max: Integer` con un valor por defecto de `100` y utilice la resolución del motor para limitar el valor generado.

### Actores y Flujo de Alto Nivel
1. **User Request**: La instrucción en lenguaje natural del usuario (ej. `"Dime un número menor de ochenta"`) ingresa al `orchestrator`.
2. **Intent Selection**: `SimilarityEngine` identifica y selecciona el plugin ganador `RandomNumberPlugin` (`id`: `"random-number"`).
3. **Parameter Resolution**: `ExecutionPlanner` invoca a `ParameterResolverEngine` pasando las definiciones de parámetros de `RandomNumberPlugin` (`max: Integer`).
4. **IntegerResolver Extraction**: `ParameterResolverEngine` consulta a `ParameterResolverRegistry`, obtiene la instancia registrada de `IntegerResolver` para el tipo `"Integer"`, y le solicita resolver el parámetro analizando el texto en español.
5. **Execution Plan Construction**: `IntegerResolver` extrae el valor `80`. `ExecutionPlanner` construye el `ExecutionPlanStep` incorporando `"parameters": {"max": 80}`.
6. **Plugin Execution**: `PlanExecutor` ejecuta `RandomNumberPlugin` inyectando el valor resuelto `80`, generando un número aleatorio entre 1 y 80 y devolviendo la respuesta verbal.

```text
"Dime un número menor de ochenta"
             ↓
       IntentResolver (SimilarityEngine)
             ↓
    RandomNumberPlugin (id: random-number)
             ↓
      ParameterResolverEngine
             ↓
        IntegerResolver -> 80
             ↓
  ExecutionPlanStep (parameters: {"max": 80})
             ↓
  RandomNumberPlugin.execute(max=80)
```

---

## 2. Análisis de Servicios e Impacto

| Servicio | Tipo de Cambio | Descripción del Impacto |
| :--- | :--- | :--- |
| `orchestrator` | Modificar | - Creación de `core/parameter_resolution/resolvers/integer.py` con la clase `IntegerResolver` implementando `BaseParameterResolver`.<br>- Registro automático de `IntegerResolver` en `ParameterResolverRegistry` en el ciclo `lifespan` de `main.py`.<br>- Actualización de `PluginContext` en `core/models.py` para incluir el atributo opcional `parameters: Dict[str, Any] = {}`, permitiendo propagar los parámetros resueltos al método `execute()` de los plugins.<br>- Modificación de `RandomNumberPlugin` en `plugins/random/main.py` para declarar `parameters = [ParameterDefinition(name="max", type="Integer", required=False, default=100)]` y consumir `context.parameters["max"]`, manteniendo el `plugin.id` canónico `"random-number"` conforme al [ADR-023](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-023-estandarizacion-identificador-plugin-execution-plan.md).<br>- Actualización de la suite de tests en `tests/` (`test_integer_resolver.py`, `test_random_number_plugin_parameters.py` y `test_execution_planner_integer.py`). |
| `interaction-manager` | Ninguno | Permanece 100% compatible sin cambios. Consume el `ExecutionPlan` generado con el campo `parameters` poblado. |
| `home-assistant` | Modificar | - Actualización del catálogo de servicios (`docs/services.md`) y arquitectura (`docs/architecture.md`) documentando la incorporación de `IntegerResolver`.<br>- Inclusión de referencias a [ADR-023](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-023-estandarizacion-identificador-plugin-execution-plan.md) y [ADR-024](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-024-interfaces-resolucion-parametros-orquestador.md). |

---

## 3. Especificación de Comportamiento (Criterios de Aceptación)

### Escenario 1: Interpretación de Enteros Expresados mediante Dígitos
```gherkin
Dado que el resolver "IntegerResolver" está registrado para el tipo lógico "Integer"
Cuando se solicita resolver el parámetro "max" para el texto "Dime un número menor de 50"
Entonces "IntegerResolver" retorna el estado "RESOLVED" con el valor numérico 50
Y el tipo de dato devuelto es un entero ("int")
```

### Escenario 2: Interpretación de Números Cardinales Escritos en Español
```gherkin
Dado que el resolver "IntegerResolver" está activo en el sistema
Cuando se procesan las siguientes expresiones escritas en español:
  | input_text                             | expected_value |
  | "Dime uno"                             | 1              |
  | "Dame cinco opciones"                  | 5              |
  | "Genera diez resultados"               | 10             |
  | "Límite en veinte"                     | 20             |
  | "Genera un número hasta veinticinco"   | 25             |
  | "Hasta cincuenta"                      | 50             |
  | "Dime un número menor de ochenta"     | 80             |
  | "Dame un valor menor de cien"          | 100            |
  | "Máximo ciento veinte"                 | 120            |
  | "Dame un número menor de mil"          | 1000           |
  | "Valor hasta treinta y cinco"          | 35             |
Entonces "IntegerResolver" extrae y retorna el valor entero numérico exacto indicado en "expected_value"
Y el estado de resolución del parámetro es "RESOLVED"
```

### Escenario 3: Instrucción en Lenguaje Natural Sin Entero Interpretable (Uso de Valor por Defecto)
```gherkin
Dado que el plugin "RandomNumberPlugin" declara el parámetro opcional "max" de tipo "Integer" con default 100
Cuando el usuario emite la instrucción "Dime un número" sin indicar ninguna cifra
Entonces "IntegerResolver" indica que no se ha encontrado ningún número en la instrucción
Y "ParameterResolverEngine" asigna el valor por defecto 100 al parámetro "max"
Y el estado de resolución del parámetro es "DEFAULT_VALUE_USED"
```

### Escenario 4: Unicidad del Resultado en Expresiones Complejas
```gherkin
Dado que "IntegerResolver" opera en la Fase 2 extrayendo un único valor entero determinista
Cuando se recibe una instrucción que contiene un único número dentro de una frase extensa
Entonces el resolver ignora las palabras de contexto semántico como "menor de" o "alrededor de"
Y devuelve únicamente la cifra entera encontrada sin evaluar operadores relacionales o rangos
```

### Escenario 5: Consumo del Parámetro "max" en RandomNumberPlugin
```gherkin
Dado que "ExecutionPlanner" resuelve la instrucción "Dime un número menor de ochenta"
Y el "ExecutionPlanStep" resultante asigna "parameters": {"max": 80} al plugin "random-number"
Cuando "PlanExecutor" ejecuta el método "execute" de "RandomNumberPlugin"
Entonces el plugin genera un número entero aleatorio comprendido en el rango entre 1 y 80 inclusive
Y la respuesta verbal estructurada en "speech" contiene el entero generado seguido de punto final (ej. "42.")
```

### Escenario 6: Preservación del Determinismo y Procesamiento 100% Offline
```gherkin
Dado cualquier proceso de resolución ejecutado por "IntegerResolver"
Cuando se realiza el parseo de números de la entrada de usuario
Entonces todo el cálculo se realiza en local mediante reglas léxico-sintácticas deterministas
Sin realizar llamadas a LLMs, servicios cloud o conexiones de red externas
```

---

## 4. Diseño Técnico y Contratos

### Módulos y Contratos en Python (`orchestrator/`)

#### 1. Ampliación del Modelo PluginContext (`core/models.py`)
Para permitir que los parámetros resueltos en `ExecutionPlanner` se encuentren inmediatamente disponibles en la ejecución de los plugins, se añade el campo `parameters` a `PluginContext`.

```python
class PluginContext(BaseModel):
    raw_text: str
    normalized_text: str
    correlation_id: Optional[str] = None
    channel: Optional[str] = "voice"
    parameters: Dict[str, Any] = {}
    metadata: Dict[str, Any] = {}
```

#### 2. Implementación de IntegerResolver (`core/parameter_resolution/resolvers/integer.py`)

```python
import re
from typing import Optional
from core.models import PluginContext
from core.parameter_resolution.base import BaseParameterResolver
from core.parameter_resolution.models import (
    ParameterDefinition,
    ParameterResolutionResult,
    ParameterResolutionStatus,
)

SPANISH_CARDINALS = {
    "cero": 0, "un": 1, "uno": 1, "una": 1, "dos": 2, "tres": 3, "cuatro": 4, "cinco": 5,
    "seis": 6, "siete": 7, "ocho": 8, "nueve": 9, "diez": 10, "once": 11, "doce": 12,
    "trece": 13, "catorce": 14, "quince": 15, "dieciséis": 16, "dieciseis": 16,
    "diecisiete": 17, "dieciocho": 18, "diecinueve": 19, "veinte": 20,
    "veintiuno": 21, "veintiún": 21, "veintiun": 21, "veintidós": 22, "veintidos": 22,
    "veintitrés": 23, "veintitres": 23, "veinticuatro": 24, "veinticinco": 25,
    "veintiséis": 26, "veintiseis": 26, "veintisiete": 27, "veintiocho": 28, "veintinueve": 29,
    "treinta": 30, "cuarenta": 40, "cincuenta": 50, "sesenta": 60, "setenta": 70,
    "ochenta": 80, "noventa": 90, "cien": 100, "ciento": 100, "doscientos": 200,
    "trescientos": 300, "cuatrocientos": 400, "quinientos": 500, "seiscientos": 600,
    "setecientos": 700, "ochocientos": 800, "novecientos": 900, "mil": 1000
}

class IntegerResolver(BaseParameterResolver):
    @property
    def target_type(self) -> str:
        return "Integer"

    async def resolve(
        self, 
        context: PluginContext, 
        definition: ParameterDefinition
    ) -> ParameterResolutionResult:
        text = context.normalized_text.lower()
        
        # 1. Search for digit patterns (e.g. "50", "100")
        digit_match = re.search(r'\b\d+\b', text)
        if digit_match:
            val = int(digit_match.group())
            return ParameterResolutionResult(
                parameter_name=definition.name,
                value=val,
                status=ParameterResolutionStatus.RESOLVED
            )

        # 2. Search for written Spanish cardinal numbers
        words = text.split()
        for i, word in enumerate(words):
            clean_word = re.sub(r'[^\w]', '', word)
            # Check compound numbers with 'y' (e.g., "treinta y cinco")
            if i + 2 < len(words) and words[i + 1] == "y":
                tens_word = clean_word
                units_word = re.sub(r'[^\w]', '', words[i + 2])
                if tens_word in SPANISH_CARDINALS and units_word in SPANISH_CARDINALS:
                    val = SPANISH_CARDINALS[tens_word] + SPANISH_CARDINALS[units_word]
                    return ParameterResolutionResult(
                        parameter_name=definition.name,
                        value=val,
                        status=ParameterResolutionStatus.RESOLVED
                    )

            if clean_word in SPANISH_CARDINALS:
                val = SPANISH_CARDINALS[clean_word]
                return ParameterResolutionResult(
                    parameter_name=definition.name,
                    value=val,
                    status=ParameterResolutionStatus.RESOLVED
                )

        # 3. No integer found
        return ParameterResolutionResult(
            parameter_name=definition.name,
            value=None,
            status=ParameterResolutionStatus.UNRESOLVED_OPTIONAL if not definition.required else ParameterResolutionStatus.UNRESOLVED_REQUIRED
        )
```

#### 3. Registro Centralizado en main.py (`main.py`)
```python
from core.parameter_resolution.resolvers.integer import IntegerResolver

# Inside lifespan startup:
parameter_registry.register(IntegerResolver())
```

#### 4. Adaptación del Plugin RandomNumberPlugin (`plugins/random/main.py`)
```python
from core.parameter_resolution.models import ParameterDefinition

class RandomNumberPlugin(Plugin):
    # ... existing properties ...

    @property
    def parameters(self) -> List[ParameterDefinition]:
        return [
            ParameterDefinition(
                name="max",
                type="Integer",
                required=False,
                default=100
            )
        ]

    async def execute(self, context: PluginContext) -> PluginResult:
        logger.info("Starting execution of RandomNumberPlugin")
        try:
            # Retrieve resolved parameter 'max', fallback to default 100 if omitted
            max_value = context.parameters.get("max", 100) if context.parameters else 100
            if not isinstance(max_value, int) or max_value < 1:
                max_value = 100

            result = self.random_service.random_int(1, max_value)
            speech = f"{result}."
            return PluginResult(
                success=True,
                speech=speech,
                data={
                    "result": result,
                    "max": max_value
                }
            )
        except Exception as e:
            logger.error(f"Error executing RandomNumberPlugin: {e}", exc_info=True)
            return PluginResult(
                success=False,
                speech="No he podido completar la operación."
            )
```

#### 5. Integración en ExecutionPlanner (`core/engine.py`)
```python
# In ExecutionPlanner.resolve:
resolved_params = {}
if self.parameter_engine and selected_plugin:
    plugin_params = getattr(selected_plugin, "parameters", [])
    if plugin_params:
        resolved_params, _ = await self.parameter_engine.resolve_parameters(context, plugin_params)

context.parameters = resolved_params

step = ExecutionPlanStep(
    plugin=selected_plugin.id,
    confidence=first["score"],
    parameters=resolved_params,
    channel=channel,
    context=context,
    security={}
)
```

---

## 5. Casos de Borde y Manejo de Errores

| Caso de Borde | Comportamiento Esperado | Implementación Técnica |
| :--- | :--- | :--- |
| **Instrucción con múltiples números (ej. "Dime un número entre 10 y 50")** | En la Fase 2, `IntegerResolver` extrae el primer entero que encuentra (ej. 10), respetando la restricción de resultado único (RF-06). | `Sequential regex and token evaluation processes input from left to right, returning immediately on first valid match.` |
| **Palabras ordinales o no reconocidas (ej. "primero", "décimo", "varios")** | Los términos ordinales o indefinitivos no se consideran enteros cardinales. El resolver devuelve `None`, forzando el uso del valor por defecto `100`. | `SPANISH_CARDINALS dictionary lookup excludes ordinal and non-numeric word tokens.` |
| **Valores numéricos negativos o decimales (ej. "-5", "3.14")** | `IntegerResolver` en esta fase procesa dígitos de números naturales. Los símbolos de puntuación ajenos se descartan mediante filtrado léxico `re.sub(r'[^\w]', '', word)`. | `Regex digit pattern \d+ matches positive integer digits.` |
| **Valor de `max` resuelto como entero <= 0 (ej. "0" o número negativo)** | `RandomNumberPlugin` valida que el límite superior sea un número natural positivo mayor o igual a 1, sustituyendo valores inválidos por 100. | `Defensive check in RandomNumberPlugin.execute: if not isinstance(max_value, int) or max_value < 1: max_value = 100.` |
| **Entrada sin ningún número (ej. "Dame un número aleatorio")** | `IntegerResolver` retorna `ParameterResolutionResult` con estado `UNRESOLVED_OPTIONAL` y valor `None`. `ParameterResolverEngine` aplica `default=100` y registra `DEFAULT_VALUE_USED`. | `ParameterResolverEngine detects value is None and applies default fallback logic declared in ParameterDefinition.` |

---

## 6. Estrategia de Testing

### Pruebas Unitarias (`orchestrator/tests/`)
1. **Pruebas del Resolver de Enteros (`tests/test_integer_resolver.py`)**:
   - Validar extracción de enteros expresados en dígitos (`"5"`, `"25"`, `"100"`, `"1500"`).
   - Validar números cardinales en español (`"uno"`, `"cinco"`, `"diez"`, `"veinte"`, `"veinticinco"`, `"cincuenta"`, `"ochenta"`, `"cien"`, `"ciento veinte"`, `"mil"`).
   - Validar la extracción dentro de instrucciones compuestas en lenguaje natural (`"Dime un número menor de ochenta"`, `"Genera una cifra hasta cincuenta"`).
   - Verificar retorno de ausencias (`value=None`) cuando el texto no contiene cifras.
2. **Pruebas del Plugin Adaptado (`tests/test_random_number_plugin_parameters.py`)**:
   - Verificar la propiedad `parameters` de `RandomNumberPlugin` comprobando que retorna `[ParameterDefinition(name="max", type="Integer", required=False, default=100)]`.
   - Ejecutar `RandomNumberPlugin.execute()` inyectando `context.parameters = {"max": 50}` y comprobar que la cifra generada está en el rango `[1, 50]`.
   - Ejecutar `RandomNumberPlugin.execute()` sin parámetros y comprobar que la cifra generada está en el rango `[1, 100]`.

### Pruebas de Integración (`orchestrator/tests/test_execution_planner_integer.py`)
- Instanciar `ExecutionPlanner` con `ParameterResolverRegistry` e `IntegerResolver` registrados.
- Invocar `resolve` con la entrada `"Dime un número menor de ochenta"` y verificar que:
  1. `ExecutionPlanStep.plugin` es `"random-number"`.
  2. `ExecutionPlanStep.parameters` contiene `{"max": 80}`.
  3. `ExecutionPlanStep.context.parameters` contiene `{"max": 80}`.
- Invocar `resolve` con la entrada `"Dime un número"` y verificar que `ExecutionPlanStep.parameters` contiene `{"max": 100}`.

---

## 7. Plan de Implementación (Checklist)

- [ ] **Fase 1: Implementación de IntegerResolver en Orchestrator**
  - [ ] Crear el archivo `core/parameter_resolution/resolvers/integer.py` con la clase `IntegerResolver`.
  - [ ] Implementar la lógica léxico-sintáctica determinista en español (`SPANISH_CARDINALS` y soporte para dígitos).
  - [ ] Crear `core/parameter_resolution/resolvers/__init__.py` exportando `IntegerResolver`.
  - [ ] Registrar `IntegerResolver` en `app.state.parameter_registry` dentro de `main.py`.

- [ ] **Fase 2: Adaptación de PluginContext y RandomNumberPlugin**
  - [ ] Añadir `parameters: Dict[str, Any] = {}` al modelo `PluginContext` en `core/models.py`.
  - [ ] Actualizar `ExecutionPlanner.resolve` en `core/engine.py` para inyectar `resolved_params` en `context.parameters`.
  - [ ] Modificar `RandomNumberPlugin` en `plugins/random/main.py` para declarar la propiedad `parameters` (`max: Integer`, default 100).
  - [ ] Actualizar `RandomNumberPlugin.execute()` para consumir `context.parameters.get("max", 100)`.

- [ ] **Fase 3: Pruebas Automatizadas**
  - [ ] Crear `tests/test_integer_resolver.py` cubriendo dígitos, palabras en español y casos vacíos.
  - [ ] Crear `tests/test_random_number_plugin_parameters.py` validando la ejecución del plugin con y sin parámetro `max`.
  - [ ] Crear `tests/test_execution_planner_integer.py` para verificar el flujo de integración de la Fase 2.
  - [ ] Ejecutar `pytest` en `orchestrator` y verificar 100% de éxito en la suite de pruebas sin regresiones.

- [ ] **Fase 4: Documentación y Versionado**
  - [ ] Actualizar `docs/services.md` y `docs/architecture.md` en `home-assistant` documentando el soporte para `IntegerResolver`.
  - [ ] Actualizar `CHANGELOG.md` en `orchestrator` bajo `[Sin publicar]` y actualizar el campo `version` en `pyproject.toml` en el mismo commit.
  - [ ] Actualizar `CHANGELOG.md` en `home-assistant` bajo `[Sin publicar]`.

- [ ] **Fase 5: Despliegue Local**
  - [ ] Reconstruir e iniciar el servicio `orchestrator` (`docker compose up --build orchestrator`) para instanciar el servidor con `IntegerResolver` cargado en `lifespan`.
