# ADR-018: Creación de la Librería de Abstracción nova-event-bus para Comunicaciones Asíncronas Basadas en Eventos Tipados

- **Fecha**: 17-07-2026
- **Estado**: Aceptado
- **Contexto**:
  Tras la aceptación de ADR-017, el message broker NATS se ha integrado en la infraestructura de contenedores de Docker. Diversos servicios requerirán intercambiar eventos de forma asíncrona de manera eficiente. Sin embargo, acoplar directamente el código fuente de los microservicios de dominio (como `calendar-service`, `identity-service`, etc.) a la API de la librería `nats-py` introduce una dependencia muy rígida. Si en el futuro se requiriera escalar la infraestructura a un broker de mensajería diferente, el esfuerzo de reescritura de los servicios sería muy elevado. Además, permitir el envío de payloads arbitrarios (e.g. diccionarios genéricos) y la construcción manual de subjects por parte de los desarrolladores debilita la consistencia y la seguridad del contrato de mensajería del ecosistema.

- **Decisión**:
  1. Desarrollar una librería cliente unificada en Python llamada `nova-event-bus`.
  2. Todos los microservicios de dominio desarrollados en Python que requieran comunicarse asíncronamente a través del message broker deberán importar esta librería de manera exclusiva, prohibiendo la importación directa y el uso directo de `nats-py`.
  3. La librería definirá una interfaz abstracta (`EventBusInterface`), una clase base de eventos (`Event`) y un decorador de registro (`@event`).
  4. Los consumidores interactuarán estrictamente mediante clases tipadas que heredan de `Event` e instancias de las mismas. La librería resolverá de forma opaca el subject (utilizando el metadato del decorador) y la serialización JSON structured.
  5. En el futuro, si se decide migrar de message broker, se desarrollará una nueva clase concreta (ej: `KafkaEventBus`) dentro de esta misma librería, requiriendo únicamente cambiar la inyección o inicialización en el punto de entrada de los servicios, sin alterar la lógica de negocio ni las llamadas a `publish` y `subscribe`.
  6. Coexistencia: El filesystem-bus basado en archivos JSON (ADR-001/006) seguirá operando en exclusiva para la comunicación con los daemons nativos instalados directamente en el host (como `mic-daemon` y `speaker-watchdog`), asegurando el aislamiento del hardware.

- **Alternativas consideradas**:
  - **Uso directo de nats-py**: Enfoque rechazado, ya que provocaría vendor lock-in a NATS y dificultaría futuras migraciones.
  - **Uso de diccionarios planos y subjects manuales**: Rechazado, ya que debilita el contrato de diseño, aumenta la probabilidad de bugs y no garantiza la consistencia de esquemas de datos del dominio entre servicios.

- **Consecuencias**:
  - **Desacoplamiento**: Mayor portabilidad de la lógica de negocio frente a cambios de infraestructura.
  - **Robustez y consistencia**: Se impone un contrato tipado fuerte que impide el envío de esquemas aleatorios o incorrectos en el bus.
  - **Estandarización**: Un único punto donde gestionar reconexiones automáticas, logs de fallos de mensajería, carga de variables de entorno y serialización JSON.
