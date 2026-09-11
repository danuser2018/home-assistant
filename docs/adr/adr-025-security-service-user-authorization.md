# ADR-025: Incorporación del Microservicio Security Service para Autorización User → Service (MVP)

## Fecha
30-08-2026

## Estado
Aceptado

## Contexto
El ecosistema Nova requiere un mecanismo centralizado y determinista para evaluar el riesgo de las acciones solicitadas por los usuarios a través de distintos canales de interacción (voz, CLI, API) antes de su ejecución.

Previamente, los planes de ejecución (`ExecutionPlan`) se ejecutaban directamente sin evaluar la adecuación entre el riesgo de la acción y los permisos del canal de entrada. Para aplicar el principio de menor privilegio y evitar la ejecución no autorizada o parcial de comandos peligrosos en el sistema host, se requiere una autoridad de seguridad centralizada.

## Decisión
Se decide crear e integrar el nuevo microservicio **Security Service** (`security-service`) en el ecosistema Nova bajo los siguientes principios:

1. **Autoridad Centralizada de Autorización**: El `security-service` es la única entidad responsable de registrar las acciones de los plugins, catalogar el riesgo de comandos host, gestionar las políticas por canal y evaluar las solicitudes de autorización.
2. **Principio de Fail Closed Absoluto**: Ante cualquier incoherencia, ausencia de datos, canal no registrado o política no calculable, el `security-service` devuelve un `DENY` inmediato impidiendo la ejecución.
3. **Evaluación Atómica del Plan**: El `ExecutionPlan` no admite ejecuciones parciales; si un solo paso resulta en `DENY`, se rechaza el plan completo sin generar tokens de autorización.
4. **Tokens Cryptográficos de Único Uso**: En caso de evaluación exitosa (`ALLOW`), el servicio emite tokens firmados con HMAC-SHA256 vinculados estrictamente al `execution_id` y `action_id`, con tiempo de expiración acotado (`expires_at`).
5. **Verificación Estricta en Orquestador**: El `PlanExecutor` del `orchestrator` valida la firma, vigencia y coherencia del token antes de ejecutar cada plugin, rechazando con HTTP 403 Forbidden cualquier intento no autorizado.
6. **Interceptación en Pipeline**: El `interaction-manager` intercepta las respuestas `DENY`, aborta la llamada a `execute-plan` y notifica al usuario mediante audio de denegación.
7. **Publicación Síncrona vía HTTP REST en el Arranque**: La publicación de acciones y sus niveles de riesgo desde `orchestrator` y `host-service` se realiza mediante peticiones HTTP síncronas (`POST /v1/security/actions/register` y `POST /v1/security/tables/host_commands`) en lugar de comandos o eventos asíncronos sobre NATS. Esta decisión se fundamenta en:
   - **Garantía determinista y principio Fail Closed**: Asegura confirmación inmediata (HTTP 200) de que el catálogo de seguridad está cargado antes de que los emisores comiencen a procesar peticiones, eliminando ventanas de inconsistencia temporal (*eventual consistency*) donde un comando de usuario pudiera ser denegado por un retraso en la entrega de eventos.
   - **Alineación con el orden de arranque de Docker**: Apoyado en `depends_on` con condición `service_healthy` sobre `security-service`, garantiza que `orchestrator` solo arranca cuando `security-service` ya está listo para responder, haciendo innecesaria una infraestructura compleja de reintentos o colas persistentes.
   - **Simplicidad arquitectónica en el MVP**: Evita acoplar `security-service` al broker de mensajería (NATS) o a la librería `nova-event-bus`, manteniéndolo como un microservicio REST ligero, autónomo y sin dependencias de colas asíncronas.

## Consecuencias
* **(+) Seguridad Robustecida**: Garantiza que comandos de alto riesgo no puedan ejecutarse desde canales restrictivos.
* **(+) Fail Closed & Zero Trust Execution**: Imposibilita la ejecución arbitraria de plugins sin token válido firmado criptográficamente.
* **(+) Arquitectura Desacoplada**: El motor de riesgo evalúa políticas sin acoplarse al código interno del plugin o hardware.
* **(+) Simplicidad y Verificabilidad Inmediata**: La publicación HTTP proporciona respuesta síncrona inmediata en el arranque sin dependencias de mensajería en `security-service`.
* **(-) Estado Volátil en MVP**: En caso de reinicio de `security-service`, se requiere que `orchestrator` y `host-service` completen su re-registro durante el arranque.
