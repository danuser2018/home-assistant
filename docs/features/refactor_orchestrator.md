# Especificación de Arquitectura
# Separación entre Intent Resolver y Plugin Executor

**Estado:** Propuesto

## 1. Introducción

El Orchestrator actual realiza dos funciones distintas:

1. Resolver la intención del usuario.
2. Ejecutar el plugin seleccionado.

Aunque ambas operaciones forman parte del mismo flujo, representan responsabilidades diferentes. Esta especificación propone desacoplarlas mediante dos componentes independientes: **Intent Resolver** y **Plugin Executor**.

El objetivo es preparar Nova para futuras capacidades como resolución de parámetros, canales, contexto conversacional, control de seguridad y planes de ejecución, manteniendo un comportamiento 100% compatible con la implementación actual.

---

# 2. Objetivos

- Aplicar el principio de responsabilidad única.
- Reducir el acoplamiento interno.
- Mejorar la observabilidad.
- Facilitar las pruebas unitarias.
- Mantener compatibilidad completa con los plugins existentes.
- No modificar el comportamiento percibido por el usuario.

## Objetivos no incluidos

- Cambiar RapidFuzz.
- Introducir LLMs.
- Modificar la API pública durante la migración.
- Reescribir los plugins existentes.

---

# 3. Arquitectura actual (As-Is)

```text
Interaction Manager
        │
        ▼
POST /api/v1/execute
        │
        ▼
Orchestrator
 ├─ Resolver intención
 ├─ Seleccionar plugin
 └─ Ejecutar plugin
        │
        ▼
Respuesta
```

Problemas:

- Resolución y ejecución están acopladas.
- No existe un modelo explícito de intención.
- No hay punto para insertar validaciones o enriquecimiento.

---

# 4. Arquitectura objetivo (To-Be)

```text
Interaction Manager
        │
        ▼
Intent Resolver
        │
        ▼
ExecutionPlan
        │
        ▼
Plugin Executor
        │
        ▼
Plugin
        │
        ▼
PluginResult
```

## Intent Resolver

Responsabilidades:

- Analizar el texto.
- Calcular similitud.
- Seleccionar plugin.
- Construir un ExecutionPlan.

Nunca ejecuta acciones.

## Plugin Executor

Responsabilidades:

- Validar el plan.
- Ejecutar el plugin.
- Devolver el resultado.

Nunca interpreta lenguaje natural.

---

# 5. Modelo ExecutionPlan

## Versión inicial

```json
{
  "plugin":"WeatherPlugin",
  "confidence":94.2,
  "text":"qué tiempo hace hoy"
}
```

## Modelo objetivo

```json
{
  "steps":[
    {
      "plugin":"WeatherPlugin",
      "parameters":{},
      "channel":"voice",
      "context":{},
      "security":{}
    }
  ]
}
```

El plan podrá contener múltiples pasos sin modificar el Executor.

---

# 6. APIs

## POST /api/v1/resolve

Entrada

```json
{"text":"qué tiempo hace"}
```

Salida

```json
{
  "plugin":"WeatherPlugin",
  "confidence":94.2
}
```

## POST /api/v1/execute

Entrada

```json
{
  "plugin":"WeatherPlugin",
  "text":"qué tiempo hace"
}
```

Durante la transición el endpoint público ejecutará:

```text
resolve()
↓
execute()
```

---

# 7. Compatibilidad

Se garantiza:

- mismos plugins
- mismas respuestas
- mismo algoritmo
- mismo endpoint público
- ningún cambio en Interaction Manager

---

# 8. Plan de migración

## Fase 1

Extraer Intent Resolver.

## Fase 2

Crear Plugin Executor.

## Fase 3

Eliminar implementación antigua.

## Fase 4

Pruebas de regresión completas.

---

# 9. Observabilidad

Registrar:

- texto original
- plugin seleccionado
- puntuación
- ExecutionPlan
- tiempo de resolución
- tiempo de ejecución
- resultado

---

# 10. Evolución futura

## Parámetros

```
Pon el volumen al 30%
```

↓

```
VolumePlugin(level=30)
```

## Canales

- voice
- screen
- mail

## Security Manager

```text
ExecutionPlan
    ↓
Security Manager
    ↓
Executor
```

## Context Service

Permitirá enriquecer el plan antes de ejecutarlo.

## Planes de múltiples acciones

```json
{
  "steps":[
    {"plugin":"LightsOffPlugin"},
    {"plugin":"VolumeDownPlugin"}
  ]
}
```

---

# 11. Riesgos

- Regresión funcional.
- Duplicación temporal de código.
- Necesidad de pruebas exhaustivas.

Mitigación:

- Migración incremental.
- Compatibilidad completa.
- Tests automatizados.

---

# 12. Criterios de aceptación

- Todos los plugins funcionan sin cambios.
- El usuario obtiene exactamente las mismas respuestas.
- Intent Resolver puede probarse de forma aislada.
- Plugin Executor puede probarse de forma aislada.
- ExecutionPlan queda definido como contrato estable.

---

# 13. Conclusión

Esta refactorización convierte el Orchestrator en un motor de planificación preparado para el crecimiento de Nova. La separación entre resolución y ejecución reduce el acoplamiento, mejora la mantenibilidad y proporciona una base sólida para incorporar capacidades avanzadas sin afectar a los plugins existentes.

## Anexo A. Requisitos funcionales
RF-001. Separación de responsabilidades

El Orchestrator deberá separar el proceso de resolución de intención del proceso de ejecución del plugin.

RF-002. Intent Resolver

El sistema deberá incorporar un componente denominado Intent Resolver, responsable exclusivamente de determinar la intención del usuario.

El Intent Resolver no podrá ejecutar ningún plugin.

RF-003. Plugin Executor

El sistema deberá incorporar un componente denominado Plugin Executor, responsable exclusivamente de ejecutar un plan previamente resuelto.

El Plugin Executor no podrá interpretar lenguaje natural.

RF-004. Resolución determinista

El algoritmo de selección de plugins deberá permanecer idéntico al existente.

No deberán modificarse:

RapidFuzz
pesos
prioridades
tie breaker
umbrales
RF-005. Compatibilidad de plugins

Los plugins existentes deberán funcionar sin modificaciones.

No será necesario adaptar ninguna implementación de plugin.

RF-006. Contrato interno

El Intent Resolver deberá producir un objeto denominado ExecutionPlan.

El Plugin Executor únicamente aceptará dicho objeto como entrada.

RF-007. Endpoint de resolución

El sistema deberá exponer un endpoint interno capaz de resolver una intención sin ejecutarla.

RF-008. Endpoint de ejecución

El sistema deberá exponer un endpoint interno capaz de ejecutar un ExecutionPlan.

RF-009. Compatibilidad externa

Durante la migración deberá mantenerse operativo el endpoint existente:

POST /api/v1/execute

Su comportamiento será:

resolve()

↓

execute()
RF-010. Respuesta

Las respuestas generadas deberán ser exactamente iguales a las obtenidas antes de la refactorización.

RF-011. Registro

El sistema deberá registrar:

intención
plugin seleccionado
confianza
tiempo de resolución
tiempo de ejecución
RF-012. Evolución del contrato

El modelo ExecutionPlan deberá permitir incorporar en el futuro:

parámetros
canales
contexto
información de seguridad
múltiples acciones

sin romper compatibilidad.

## Anexo B. Requisitos no funcionales
RNF-001. Compatibilidad

La refactorización no deberá modificar el comportamiento observable por el usuario.

RNF-002. Rendimiento

La separación Resolver/Executor no deberá introducir una degradación apreciable del tiempo de respuesta.

RNF-003. Modularidad

Resolver y Executor deberán poder evolucionar de forma independiente.

RNF-004. Testabilidad

Será posible probar de forma independiente:

Intent Resolver
Plugin Executor
RNF-005. Mantenibilidad

La incorporación de nuevas etapas del pipeline no deberá requerir modificar los plugins existentes.

RNF-006. Extensibilidad

La arquitectura deberá permitir incorporar posteriormente:

Parameter Resolver
Channel Resolver
Security Manager
Context Service

sin modificar la interfaz pública.

RNF-007. Observabilidad

El sistema deberá generar información suficiente para reconstruir el flujo completo de ejecución.

RNF-008. Compatibilidad hacia atrás

Interaction Manager no deberá requerir modificaciones durante esta refactorización.

RNF-009. Escalabilidad funcional

El modelo deberá soportar la ejecución de múltiples acciones mediante un único ExecutionPlan.

RNF-010. Bajo acoplamiento

Resolver y Executor únicamente compartirán el contrato ExecutionPlan.

No compartirán lógica de negocio.

## Anexo C. Propuesta de API
Endpoint de resolución
POST /api/v1/resolve
Request
{
  "text": "qué tiempo hace hoy"
}
Response
{
  "plugin": "WeatherPlugin",
  "confidence": 94.1
}
Endpoint de ejecución
POST /api/v1/execute
Request
{
  "plugin": "WeatherPlugin",
  "text": "qué tiempo hace hoy"
}
Response
{
  "success": true,
  "plugin_used": "WeatherPlugin",
  "speech": "Actualmente hace 28 grados.",
  "execution_time_ms": 14
}
Evolución prevista
ExecutionPlan v2
{
  "steps": [
    {
      "plugin": "WeatherPlugin",
      "parameters": {},
      "channel": "voice",
      "context": {},
      "security": {}
    }
  ]
}
ExecutionPlan v3
{
  "steps": [
    {
      "plugin": "LightsOffPlugin",
      "parameters": {
        "room": "salón"
      }
    },
    {
      "plugin": "VolumePlugin",
      "parameters": {
        "level": 20
      }
    }
  ]
}

## Una sugerencia de diseño

Hay un punto que reconsideraría antes de empezar la implementación: el endpoint /api/v1/execute.

Si la idea es que el Executor reciba un ExecutionPlan, el endpoint podría llamarse mejor:

POST /api/v1/plans (crear un plan)
POST /api/v1/plans/execute (ejecutar un plan)

o incluso:

POST /api/v1/resolve
POST /api/v1/execute-plan

La razón es semántica: cuando el PluginExecutor ya no ejecuta un plugin directamente, sino un plan, el contrato refleja mejor la evolución futura hacia múltiples acciones, parámetros, contexto y validaciones. Aunque puedes mantener /execute por compatibilidad, internamente empezar a pensar en términos de ExecutionPlan desde el primer día hará que la siguiente evolución de Nova sea mucho más natural.