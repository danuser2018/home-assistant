# ADR-019: Integración de Context Service para la Gestión de Contexto Conversacional Basada en Eventos

- **Fecha**: 18-07-2026
- **Estado**: Aceptado
- **Contexto**:
  Para mejorar la inteligencia conversacional y personalización del asistente virtual Nova, es necesario almacenar el contexto conversacional. Sin embargo, acoplar de forma síncrona o directa los servicios para almacenar o recuperar el contexto añade dependencias en cascada y puede degradar la latencia. Además, se busca validar la arquitectura orientada a eventos establecida mediante ADR-017 y ADR-018 mediante un caso de uso real donde un servicio consume eventos asíncronos y expone su estado de forma aislada.

- **Decisión**:
  1. Crear un microservicio autónomo en Docker llamado `context-service`.
  2. Este servicio escuchará de forma asíncrona el evento `ResponseGeneratedEvent` (publicado por `orchestrator` en el subject `orchestrator.response.generated`) a través del bus de eventos NATS utilizando la librería común `nova-event-bus`.
  3. Almacenará en memoria (a través de la clase `ContextStore`) la última respuesta conversacional con su plugin generador y la marca de tiempo.
  4. Expondrá un endpoint REST público `GET /v1/context/last-response` para que otros componentes puedan consultar el último contexto conversacional de forma rápida e independiente.

- **Alternativas consideradas**:
  - **Almacenamiento persistente en base de datos**: Rechazado para esta fase ya que añade latencia y complejidad de almacenamiento innecesaria para el alcance inicial (que sólo requiere la última respuesta en memoria).
  - **Consultas síncronas en cascada**: Rechazado por acoplar fuertemente al orquestador con el almacenamiento y degradar los tiempos de respuesta.

- **Consecuencias**:
  - **Desacoplamiento**: El orquestador sigue publicando su evento normalmente sin preocuparse de quién lo consume o almacena.
  - **Eficiencia**: Consultas de latencia muy baja al recuperar el contexto directamente de la memoria del servicio REST.
  - **Modularidad**: El estado del contexto conversacional reside en un único servicio especializado, actuando como su Single Source of Truth en memoria.
