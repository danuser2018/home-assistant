# ADR-027: Catálogo Centralizado de Comandos, Distribución Asíncrona NATS y Resolución Determinista Ponderada por Riesgo

## Fecha
12-09-2026

## Estado
Aceptado

## Contexto
En el ecosistema Nova-2, la ejecución de órdenes en el host físico (`host-service`, [ADR-026](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-026-host-service-command-execution.md)) requiere traducir frases en lenguaje natural pronunciadas por el usuario (ej. *"Abre la calculadora"*) a identificadores lógicos de comando (`name`, ej. `"calculator"`), preservando la seguridad, la baja latencia y el desacoplamiento entre componentes.

Anteriormente:
1. El catálogo de comandos residía como un recurso interno y privado de `host-service` (`config/host_commands.yaml`), lo que dificultaba que el orquestador conociera las frases de activación sin violar la encapsulación del ejecutable físico.
2. La sincronización hacia `security-service` se realizaba mediante llamadas HTTP síncronas REST (`POST /v1/security/tables/host_commands`) acopladas temporalmente en el arranque.
3. No existía un mecanismo determinista y sin LLMs en `orchestrator` para mapear de manera segura y tolerante a errores léxicos o fonéticos las intenciones de usuario a identificadores de comando del host.

## Decisión
Se establece una arquitectura desacoplada y orientada a eventos para el ciclo de vida, distribución y resolución de comandos de host:

1. **Catálogo Central como Recurso Global (`config/commands.yaml`)**:
   Se extrae la configuración de comandos y se eleva a la raíz global de configuración de Nova (`config/commands.yaml`) como única fuente de verdad (*Single Source of Truth*). Define para cada comando: `name`, `command` (argv físico), `risk` (`low`, `medium`, `high`) y `phrases` (lista de frases naturales de activación).

2. **Aislamiento Absoluto del Ejecutable Físico**:
   El array físico `command` permanece estrictamente privado y encapsulado en `host-service`. Ningún otro componente del sistema (`orchestrator`, `security-service`, `interaction-manager`) tiene visibilidad sobre el ejecutable físico ni sus argumentos de bajo nivel.

3. **Distribución Asíncrona Eventual vía NATS (`event.host.commands.available`)**:
   `host-service` carga y valida `config/commands.yaml` en su arranque. Publica en el broker NATS una proyección pública en el subject `event.host.commands.available` (versión contractual 1) que contiene únicamente `name`, `risk` y `phrases`. Esta publicación se realiza en el arranque y de forma periódica cada 60 segundos (configurable mediante `CATALOG_PUBLISH_INTERVAL_SECONDS`), garantizando que consumidores que arranquen posteriormente o tras un reinicio reconstruyan su catálogo en memoria sin coordinación temporal manual ni peticiones HTTP.

4. **Sincronización Reactiva en `security-service`**:
   `security-service` se conecta a NATS en su `lifespan`, se suscribe a `HostCommandsAvailableEvent` y actualiza atómicamente la tabla en memoria `"host_commands"` en `LookupTableRegistry`. El endpoint REST `POST /v1/security/tables/{table_name}` se preserva sin cambios de código como fallback para tests unitarios aislados.

5. **Resolución Determinista en `orchestrator` (`CommandResolver`)**:
   Se implementa `CommandResolver` (`target_type = "Command"`) en `ParameterResolverEngine` ([ADR-024](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-024-interfaces-resolucion-parametros-orquestador.md)), alimentado por `CommandCatalogProjection`:
   - **Normalización Léxica Idéntica**: Unicode NFKD, eliminación de diacríticos y acentos, minúsculas, eliminación de signos de puntuación y colapso de espacios en blanco redundantes.
   - **Prioridad a Coincidencia Exacta**: Búsqueda inmediata de igualdad estricta con las frases normalizadas del catálogo.
   - **Similitud Difusa Ponderada por Riesgo**: Uso de `fuzz.ratio` (RapidFuzz) sobre la frase completa (*Full Phrase Matching*), descartando similitudes parciales de subcadenas. Los umbrales de aceptación varían según el riesgo: `low: 60.0`, `medium: 65.0`, `high: 70.0` (configurables en `Settings`).
   - **Detección y Rechazo por Ambigüedad**: Si la diferencia de puntuación entre los dos mejores candidatos es menor o igual al delta de ambigüedad (`AMBIGUITY_DELTA = 5.0`), la resolución se declara ambigua y se descarta (`UNRESOLVED_REQUIRED` / `UNRESOLVED_OPTIONAL`).
   - **Exclusión de LLMs e Inferencia Semántica**: No se emplean modelos de lenguaje, embeddings ni sinónimos automáticos para la resolución, preservando predictibilidad determinista, privacidad y latencia sub-milisegundo.
   - **Política Fail-Closed**: Si el catálogo en memoria está vacío o no se ha recibido aún de NATS, o ante cualquier ambigüedad, el resolver retorna inmediatamente `value=None` con estado no resuelto.

## Consecuencias
* **(+) Desacoplamiento Completo**: Eliminadas las dependencias REST en tiempo de arranque entre `host-service` y `security-service`.
* **(+) Resiliencia y Convergencia Eventual**: Los servicios convergen automáticamente a un estado consistente tras caídas o arranques en cualquier orden.
* **(+) Seguridad Adaptativa por Riesgo**: Mayor exigencia fonética/textual para comandos potencialmente peligrosos (`high`) y mayor flexibilidad para utilidades cotidianas (`low`).
* **(+) Cero Exposición de Detalles del SO**: Los clientes y orquestador solo manejan abstracciones lógicas (`name`).
* **(-) Latencia de Propagación de Nuevos Comandos**: La actualización en caliente de `config/commands.yaml` requiere reiniciar `host-service` o esperar al siguiente ciclo de publicación.
