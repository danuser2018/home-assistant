# ADR-015: Consolidación del Modelo ExecutionPlan y Eliminación del Endpoint Legado

## Fecha
15-07-2026

## Estado
Aceptado

## Contexto
En el `ADR-014` se decidió desacoplar las responsabilidades de resolución de intenciones y ejecución de plugins en dos fases independientes dentro del servicio `orchestrator`, exponiendo los endpoints `POST /api/v1/resolve` y `POST /api/v1/execute-plan`. Por razones de retrocompatibilidad, se mantuvo de forma temporal el endpoint original `POST /api/v1/execute`, que realizaba internamente ambas operaciones secuencialmente. 

Ahora que todos los clientes clave de la plataforma (como `interaction-manager`) han migrado al flujo desacoplado en dos pasos, es necesario limpiar las interfaces de compatibilidad obsoletas para evitar fragmentación en los contratos de la API, reducir la complejidad interna del orquestador y alinear la nomenclatura del código fuente.

## Decisión
Tomamos las siguientes medidas estructurales en el ecosistema NOVA-2:
1. **Eliminación del endpoint legado:** Retiramos definitivamente la ruta `POST /api/v1/execute` de la API pública del orquestador. Las llamadas a este endpoint devolverán a partir de ahora un código HTTP `404 Not Found`.
2. **Eliminación del enrutador obsoleto:** Eliminamos completamente la clase de compatibilidad interna `Router` y su método `route_request`.
3. **Renombrado del motor interno:** Modificamos la nomenclatura de las clases principales del motor de orquestación en el código fuente para reflejar con precisión su rol en el nuevo esquema:
   - `IntentResolver` pasa a llamarse `ExecutionPlanner`.
   - `PluginExecutor` pasa a llamarse `PlanExecutor`.
4. **Actualización del estado de la aplicación:** Las instancias expuestas en el contexto de FastAPI (`app.state`) pasan a llamarse `planner` y `executor`.

## Alternativas consideradas
- **Mantener el endpoint `/execute` de manera indefinida:** Rechazado porque dificulta la evolución del orquestador, manteniendo acopladas la fase semántica y la física de ejecución y duplicando la gestión de excepciones y respuestas en los endpoints.
- **Mantener las clases internas con los nombres anteriores (`IntentResolver` y `PluginExecutor`):** Rechazado porque no se corresponden exactamente con el diseño actual; no solo se resuelven intenciones aisladas sino que se planifica una secuencia estructurada (`ExecutionPlan`), y el ejecutor opera sobre planes (`PlanExecutor`).

## Consecuencias
+ **Alineación arquitectónica:** El motor de orquestación cuenta ahora con un único contrato y flujo de ejecución basado enteramente en `ExecutionPlan`.
+ **Simplicidad del código:** Se elimina código duplicado de compatibilidad, simplificando el mantenimiento del microservicio y reduciendo la suite de pruebas al remover casos de prueba de enrutamiento legacy redundantes.
+ **Breaking change:** Los clientes externos antiguos que no hagan uso del flujo resolve -> execute-plan dejarán de funcionar al invocar `/execute` directamente.
