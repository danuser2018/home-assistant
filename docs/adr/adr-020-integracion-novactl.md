# ADR-020: Integración del CLI novactl y Publicación de Comandos Mediante nova-event-bus

- **Fecha**: 20-07-2026
- **Estado**: Aceptado
- **Contexto**:
  Actualmente, las interacciones desde el entorno de escritorio del sistema operativo Linux (tales como atajos de teclado, botones físicos o scripts de automatización) hacia Nova se realizan invocando scripts individuales en el host (p. ej., `mic-start`, `mic-stop`). Esta aproximación presenta limitaciones de mantenibilidad, dificulta el control de versiones y acopla la invocación de acciones a la ejecución local de binarios específicos.

  Con la llegada del message broker NATS y la librería unificada `nova-event-bus` (ADR-017 y ADR-018), se hace indispensable disponer de un punto de entrada CLI unificado y estándar (`novactl`) que abstraiga la tecnología de red subyacente y permita emitir comandos estructurados hacia cualquier servicio del ecosistema Nova.

- **Decisión**:
  1. Desarrollar `novactl` como la herramienta de línea de comandos oficial en Python para el ecosistema Nova.
  2. Implementar una arquitectura basada en plugins (`CommandPlugin`), donde cada subcomando (`start-capture`, `stop-capture`, `execute`, etc.) es un módulo aislado responsable únicamente de validar sus argumentos y construir el evento tipado correspondiente.
  3. `novactl` utilizará de forma exclusiva la API pública de `nova-event-bus` para la publicación de eventos, quedando prohibida la inclusión de código o dependencias directas a NATS en `novactl`.
  4. Los eventos emitidos por `novactl` seguirán el patrón de nomenclatura `novactl.command.<nombre_comando>` e incluirán un `correlation_id` aleatorio (UUIDv4) para asegurar la trazabilidad distribuida.
  5. Progresivamente, los gestores de atajos de teclado del sistema y componentes externos migrarán las invocaciones de scripts legacy hacia `novactl`.

- **Alternativas consideradas**:
  - **Invocación directa de endpoints REST**: Rechazada por acoplar el CLI a endpoints específicos de servicios concretos y requerir conocimiento de la topología de red.
  - **Scripts Bash independientes mantenidos en el host**: Rechazada por falta de homogeneidad, mayor dificultad para testing y duplicación de lógica de transporte.
  - **Uso directo del cliente `nats-py` en la CLI**: Rechazada por violar ADR-018 y generar vendor lock-in con NATS.

- **Consecuencias**:
  - **Desacoplamiento**: El sistema operativo interactúa únicamente con la CLI `novactl`, sin conocer la infraestructura ni la tecnología del bus de eventos.
  - **Extensibilidad**: Incorporar un nuevo comando solo requiere implementar un nuevo plugin derivado de `CommandPlugin` sin modificar el motor principal del CLI.
  - **Consistencia y Trazabilidad**: Todos los comandos del CLI generan eventos estructurados y validados tipadamente mediante `nova-event-bus` con `correlation_id`.
