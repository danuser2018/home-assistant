# ADR-022: Estandarización de Nomenclatura para Comunicaciones Asíncronas y Publicación de Eventos de Dominio (Fase 4 Refactor de Entrada)

- **Fecha**: 24-07-2026
- **Estado**: Aceptado
- **Contexto**:
  Tras la consolidación del message broker NATS y la librería unificada `nova-event-bus` (ADR-017, ADR-018, ADR-020 y ADR-021), la arquitectura basada en eventos del ecosistema Nova-2 requiere una taxonomía clara y estandarizada para nombrar los subjects en NATS. Hasta ahora existían nomenclaturas heterogéneas (ej. `novactl.command.<nombre>`, `orchestrator.response.generated` o propuestas como `event.<nombre_evento>`), lo que dificultaba la distinción entre peticiones imperativas y notificaciones declarativas, así como el filtrado por comodines (*wildcards*).

  Esta decisión **sustituye y anula** explícitamente la nomenclatura de subjects de comandos definida en ADR-020 (punto 4) (`novactl.command.<nombre_comando>`) y ADR-021 (punto 3) (`novactl.command.start_speech_capture` y `novactl.command.stop_speech_capture`), unificándolas bajo la nueva taxonomía estandarizada.

  Asimismo, en el marco de la Fase 4 del refactor de entrada, `mic-daemon` (componente del host) debe publicar su primer evento de dominio (`SpeechCapturedEvent`) para notificar que una nueva locución se ha grabado y almacenado correctamente en el volumen compartido, iniciando la transición de la observación por filesystem hacia eventos.

- **Decisión**:
  1. **Taxonomía Binaria de Mensajería Asíncrona**: Todos los subjects registrados en `nova-event-bus` se clasifican strictly en una de las siguientes dos categorías:
     - **Comandos (`command.{dominio}.{petición}`)**: Representan una orden o petición directa dirigida a un componente del sistema para ejecutar una acción imperativa.
       - *Ejemplos*:
         - `command.speech.start-capture`: Iniciar captura de audio del micrófono.
         - `command.speech.stop-capture`: Detener captura de audio del micrófono.
     - **Eventos (`event.{dominio}.{notificación}`)**: Notifican de forma declarativa un hecho que ya ha ocurrido en el sistema.
       - *Ejemplos*:
         - `event.speech.captured`: Notifica la disponibilidad de una nueva locución grabada en disco.
         - `event.interaction.response-generated`: Notifica que el orquestador ha generado una respuesta para el usuario.

  2. **Canonización de `SpeechCapturedEvent`**:
     - `mic-daemon` publicará el evento `SpeechCapturedEvent` en el subject `event.speech.captured` tras guardar con éxito el fichero `.wav` en `MIC_OUTPUT_DIR`.
     - El payload contendrá: `correlation_id` (UUIDv4 generado autónomamente al iniciar la captura), `channel` (`voice`) y `audio_path` (ruta relativa al volumen compartido).

  3. **Migración Progresiva de Comandos y Eventos Existentes**:
     - Los comandos de captura (`StartSpeechCaptureCommand` y `StopSpeechCaptureCommand`) adoptan formalmente los subjects `command.speech.start-capture` y `command.speech.stop-capture`, sustituyendo el prefijo `novactl.command.*` de ADR-020 y ADR-021.
     - El evento `ResponseGeneratedEvent` en `orchestrator` (`core/events.py`) y `context-service` (`app/events.py`) adopta el subject `event.interaction.response-generated`, sustituyendo el subject heredado `orchestrator.response.generated`.

- **Alternativas consideradas**:
  - **Uso de nombres de clases de Python como subjects (`SpeechCapturedEvent`)**: Rechazado por acoplar la infraestructura de mensajería a detalles de implementación del lenguaje.
  - **Subjects planos sin prefijo de categoría (`speech.captured`)**: Rechazado por impedir el filtrado claro en NATS entre tráfico de comandos de control y tráfico de eventos de dominio.

- **Consecuencias**:
  - **Claridad Semántica**: Separación explícita entre intenciones imperativas (`command.*`) y notificaciones de hechos sucedidos (`event.*`).
  - **Filtrado Flexible**: Permite suscripciones por comodines NATS (ej. `command.speech.*` o `event.interaction.*`).
  - **Evolución del Refactor de Entrada**: `mic-daemon` se convierte en un publicador activo de eventos de dominio sobre `event.speech.captured`.
  - **Sustitución y Trazabilidad de ADRs**: Este ADR reemplaza formalmente la convención de naming de subjects definida en ADR-020 (punto 4) y ADR-021 (punto 3). Las referencias en las skills transversales (`event-driven-architecture`, `audio-subsystem`, `service-responsibilities`) se actualizarán en la Tarea 6 para referenciar ADR-022.
