# ADR-014: Separación de Responsabilidades en el Orquestador (Intent Resolver y Plugin Executor)

## Fecha
15-07-2026

## Estado
Aceptado

## Contexto
El microservicio `orchestrator` de NOVA-2 realizaba la resolución semántica (cálculo de similitud mediante RapidFuzz) y la ejecución del plugin seleccionado en un único flujo acoplado a través del método `Router.route_request`. Esto dificultaba la validación previa de intenciones, la simulación de ejecuciones sin efectos secundarios y la ejecución de pipelines de múltiples pasos de forma secuencial y atómica.

## Decisión
Refactorizamos el motor interno del orquestador en dos responsabilidades claramente desacopladas:
1. **`IntentResolver`**: Recibe una consulta en texto legible (`UserRequest`), normaliza el texto, calcula las similitudes semánticas frente a los ejemplos de los plugins y genera un plan estructurado (`ExecutionPlan`).
2. **`PluginExecutor`**: Recibe un plan de ejecución (`ExecutionPlan`), valida la existencia de los plugins y los ejecuta de manera secuencial, deteniéndose en el primer error.

Exponemos dos nuevos endpoints en la API:
- `POST /api/v1/resolve`: Devuelve el `ExecutionPlan` calculado sin ejecutar ninguna acción.
- `POST /api/v1/execute-plan`: Recibe un `ExecutionPlan` y lo ejecuta secuencialmente.

El endpoint original `POST /api/v1/execute` se mantiene por retrocompatibilidad, orquestando de manera interna y secuencial la resolución y ejecución del plan (`resolve` -> `execute_plan`).

## Alternativas consideradas
- **Mantener el diseño acoplado original:** Descartado porque impide soportar de forma nativa flujos complejos de multi-acción controlados externamente o realizar análisis estáticos/validaciones previas en la interfaz de usuario.
- **Implementar la orquestación multi-acción en interaction-manager:** Descartado porque la traducción de similitud semántica y la granularidad fina de ejecución pertenecen inherentemente al motor del orquestador.

## Consecuencias
+ **Modularidad:** El pipeline semántico y el motor de ejecución física quedan completamente desacoplados.
+ **Extensibilidad:** Facilita la adición de etapas previas de seguridad, autorización o procesamiento de parámetros en el plan de ejecución antes de su consumo en el ejecutor.
+ **Consistencia:** Las llamadas con errores de validación de plugins no existentes o de esquema devuelven códigos HTTP adecuados (`400` y `422` respectivamente) formateados de acuerdo con la especificación global ADR-004.
