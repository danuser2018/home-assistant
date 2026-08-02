# ADR-023: Estandarización del Identificador de Plugin en el Modelo ExecutionPlan

- **Fecha**: 02-08-2026
- **Estado**: Aceptado
- **Contexto**:
  En el marco de la refactorización de `orchestrator` y la consolidación del modelo `ExecutionPlan` (ADR-014 y ADR-015), la fase de planificación (`POST /api/v1/resolve`) poblaba el campo `plugin` dentro de los pasos (`ExecutionPlanStep`) utilizando el nombre de la clase Python del plugin (p. ej., `"WeatherPlugin"`, `"GreetingPlugin"`).

  Sin embargo, el resto de componentes del ecosistema —como el registro de capacidades en `system-service`, la trazabilidad de contexto en `context-service`, y los subcomandos del CLI `novactl` para la ejecución directa de shortcuts (`command.interaction.execute-shortcut`)— utilizan como identificador canónico el atributo `plugin.id` (p. ej., `"weather"`, `"greeting"`, `"time"`).

  Esta divergencia generaba una fragmentación en los contratos del sistema y producía fallos de resolución (errores HTTP `400 Bad Request`) cuando se enviaban planes construidos directamente con identificadores de shortcuts.

- **Decisión**:
  1. **Estandarización del Payload en `ExecutionPlan`**: Modificar el generador de planes (`ExecutionPlanner.resolve`) en `orchestrator` para que asigne siempre el identificador único del plugin (`plugin.id`, p. ej., `"weather"`, `"fallback"`, `"time"`) en el campo `plugin` de cada `ExecutionPlanStep`.
  2. **Indexación y Búsqueda Dual en `PluginManager`**: Actualizar `PluginManager` para que registre internamente las instancias por su `id` y por su `name`, permitiendo la resolución inmediata en O(1) mediante el método `get_plugin()` independientemente de si se consulta por identificador canónico o por nombre de clase.
  3. **Alineación del Ecosistema**: Todos los servicios de la plataforma (`orchestrator`, `interaction-manager`, `context-service`, `system-service` y `novactl`) operarán utilizando el `plugin.id` como clave principal de intercambio.

- **Alternativas consideradas**:
  - **Mantener nombres de clase en el `ExecutionPlan` de voz y requerir traducciones explícitas en `interaction-manager`**: Rechazado por incrementar la complejidad, duplicar tablas de mapeo y romper la homogeneidad del contrato `ExecutionPlan`.
  - **Requerir únicamente `plugin.name` en los comandos del CLI `novactl`**: Rechazado por acoplar la interfaz de usuario de la CLI a los nombres de clases internas de Python del orquestador.

- **Consecuencias**:
  - **Homogeneidad de APIs**: El modelo `ExecutionPlan` es exactamente idéntico y consistente tanto si proviene de la resolución de voz (`/api/v1/resolve`) como de comandos imperativos CLI (`command.interaction.execute-shortcut`).
  - **Coherencia con `context-service` y `system-service`**: Los eventos de dominio (`ResponseGeneratedEvent`) y registros de capacidades propagan de forma uniforme identificadores limpios como `"weather"` y `"time"`.
  - **Compatibilidad Total**: Gracias a la indexación dual en `PluginManager`, las peticiones heredadas o personalizadas siguen siendo resueltas en O(1) sin romper ningún consumidor.
