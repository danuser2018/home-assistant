# Propuesta de Estructura de Skills para el Asistente de IA (Nova-2) — Formato de Constitución del Sistema

Esta propuesta final de **Skills** de agente para el ecosistema **Nova-2** adopta un formato de **Constitución del Sistema**. Las skills abandonan cualquier detalle de implementación temporal (que se delegan a los READMEs locales) y se estructuran como un conjunto jerárquico de principios de ingeniería que rigen el comportamiento de la IA y de los desarrolladores.

---

## Estructura Uniforme de la Skill

Cada skill sigue exactamente el siguiente esquema:

```markdown
# [Nombre de la Skill]

## Objetivo
[Qué pretende proteger esta skill.]

## Cuándo aplicar esta skill
[Criterios específicos de activación para la IA o el desarrollador.]

## Responsabilidades
[Qué pertenece a este dominio funcional/técnico.]

## Invariantes (Leyes — 🔴 Críticas)
[Reglas conceptuales de diseño que nunca deben romperse.]

## Reglas (Procedimientos — 🟡 Recomendadas)
[Acciones concretas y procedimientos de desarrollo que guían la evolución del código.]

## Buenas prácticas (Recomendaciones — 🟢 Opcionales)
[Consejos de diseño, mantenibilidad y optimización.]

## Antipatrones (Errores conocidos)
[Ejemplos negativos específicos para evitar regresiones de código.]

## Referencias
[ADRs vigentes (explican el "por qué") y archivos del workspace (explican el "qué" y la implementación actual).]
```

---

## Catálogo de Skills (Constitución Nova-2)

---

### 1. `development-workflow`

*   **Objetivo:** Proteger la coherencia histórica del código, su trazabilidad y la estabilidad de las interfaces de comunicación.
*   **Cuándo aplicar esta skill:**
    *   Al realizar cualquier commit o modificación de código en cualquier repositorio.
    *   Al preparar una Pull Request o preparar la versión de un release.
*   **Responsabilidades:** Ciclo de vida de Git, versionado, tipado, documentación e internacionalización.
*   **Invariantes (Leyes — 🔴 Críticas):**
    *   *Retrocompatibilidad obligatoria:* Queda prohibido romper una API pública existente de forma táctica. Toda rotura de contrato debe estar precedida de deprecación documentada.
    *   *Aislamiento lingüístico:* Todo elemento interno de desarrollo (código, variables, base de datos, logs y comentarios) se escribe en inglés. Toda interacción, documentación y ciclo Git (commits, PRs, changelogs) se realiza en español.
*   **Reglas (Procedimientos — 🟡 Recomendadas):**
    *   Registrar cronológicamente todo cambio funcional en el `CHANGELOG.md` del servicio correspondiente bajo la sección `[Sin publicar]`.
    *   Actualizar la documentación de OpenAPI (Swagger) tras modificar endpoints o parámetros HTTP.
*   **Buenas prácticas (Recomendaciones — 🟢 Opcionales):**
    *   Escribir pruebas unitarias que verifiquen el comportamiento y las condiciones de borde en lugar del flujo interno del código.
*   **Antipatrones (Errores conocidos):**
    *   ❌ Commitear cambios directamente sobre la rama `main`.
    *   ❌ Dejar firmas de API o parámetros públicos con tipado implícito o dinámico (`any`).
*   **Referencias:**
    *   [CONTRIBUTING.md](file:///home/danuser2018/workspace/home-assistant/CONTRIBUTING.md) (Describe el flujo de Trunk Based Development y commits).

---

### 2. `service-boundaries`

*   **Objetivo:** Evitar el acoplamiento monolítico y la fuga de responsabilidades entre servicios del ecosistema.
*   **Cuándo aplicar esta skill:**
    *   Al añadir nuevas capacidades de procesamiento al sistema.
    *   Al decidir en qué repositorio o servicio implementar un nuevo requisito funcional.
*   **Responsabilidades:** Definición de los límites lógicos y del ámbito de ejecución de cada componente.
*   **Invariantes (Leyes — 🔴 Críticas):**
    *   *Aislamiento del host:* Los contenedores Docker de la red interna son ciegos al hardware físico. La captura de micrófonos y la reproducción física de altavoces residen en exclusiva en el host.
    *   *Orquestador único de tiempo:* La secuencia de ejecución temporal del pipeline (Captura -> STT -> Orchestrator -> TTS -> Speaker) es exclusiva de `interaction-manager`. Ningún otro componente debe coordinar llamadas en cascada.
*   **Reglas (Procedimientos — 🟡 Recomendadas):**
    *   El orquestador debe limitarse a derivar intenciones mediante scoring determinista; nunca debe realizar almacenamiento de datos de usuario ni llamadas de red directas a APIs externas de dominio.
*   **Buenas prácticas (Recomendaciones — 🟢 Opcionales):**
    *   Diseñar los servicios de traducción e inferencia de voz (`stt-capability` y `tts-capability`) de forma autónoma, sin conocimiento del dominio del asistente.
*   **Antipatrones (Errores conocidos):**
    *   ❌ Añadir lógica de reproducción física de altavoces en `interaction-manager` u `orchestrator`.
    *   ❌ Duplicar persistencia de bases de datos o lógica de negocio en los daemons nativos del host (`mic-daemon`, `speaker-watchdog`).
*   **Referencias:**
    *   [architecture.md](file:///home/danuser2018/workspace/home-assistant/docs/architecture.md) (Definición del plano de host y plano de procesamiento).
    *   [ADR-002: Modularización de Servicios] (Explica la decisión de aislar servicios de hardware del host de la lógica Docker).

---

### 3. `communication-patterns`

*   **Objetivo:** Garantizar la fiabilidad en la entrega de mensajes y evitar dependencias de red frágiles.
*   **Cuándo aplicar esta skill:**
    *   Al definir la interacción de red o de archivos entre dos o más microservicios.
    *   Al implementar nuevos sockets o flujos de integración.
*   **Responsabilidades:** Protocolos de red internos (síncronos) y paso de mensajes en el sistema de archivos (asíncronos).
*   **Invariantes (Leyes — 🔴 Críticas):**
    *   *Reclamación exclusiva:* El servicio que procesa un mensaje asíncrono debe reclamar la propiedad del recurso de forma atómica antes de trabajar sobre él para evitar condiciones de carrera.
    *   *Ciclo de vida del mensaje:* El servicio consumidor de un mensaje en el filesystem es el único responsable de su destrucción o su traslado definitivo a carpetas de error en caso de fallo crítico.
*   **Reglas (Procedimientos — 🟡 Recomendadas):**
    *   Utilizar HTTP/REST síncrono para operaciones en tiempo real donde la latencia sea crítica (STT, TTS, Orchestrator).
    *   Establecer timeouts estrictos en todas las solicitudes HTTP salientes para evitar congelar el pipeline de interacción por fallos de red.
*   **Buenas prácticas (Recomendaciones — 🟢 Opcionales):**
    *   Utilizar formatos estandarizados de intercambio estructurado (como JSON) para mensajes asíncronos en disco.
*   **Antipatrones (Errores conocidos):**
    *   ❌ Leer o escribir directamente en un directorio de datos interno propiedad de otro servicio (violación del aislamiento del bus).
    *   ❌ Mantener flujos de red persistentes entre el host y Docker para transferir bloques de datos.
*   **Referencias:**
    *   [services.md](file:///home/danuser2018/workspace/home-assistant/docs/services.md) (Sección: Comunicación entre Servicios; detalla el uso actual de inotify y APIs REST).

---

### 4. `system-deployment`

*   **Objetivo:** Garantizar la consistencia, portabilidad y repetibilidad de la instalación en entornos locales Linux.
*   **Cuándo aplicar esta skill:**
    *   Al modificar archivos de configuración de entornos (`.env.example`), orquestación de contenedores (`docker-compose.yml`) o servicios systemd.
    *   Al añadir dependencias del host o variables del sistema.
*   **Responsabilidades:** Despliegue, configuraciones de red, variables globales y montaje de recursos.
*   **Invariantes (Leyes — 🔴 Críticas):**
    *   *Seguridad en origen:* Queda estrictamente prohibida la inclusión de credenciales SMTP o API keys reales en archivos bajo control de versiones.
    *   *Servicio de usuario:* Los daemons de audio nativos deben ejecutarse en el espacio de usuario (`systemd --user`) para heredar los permisos de sonido del servidor (PulseAudio/PipeWire) de la sesión activa.
*   **Reglas (Procedimientos — 🟡 Recomendadas):**
    *   Validar la existencia de variables locales requeridas al iniciar cualquier módulo del sistema.
    *   Declarar todos los mapeos de directorios compartidos del host usando rutas relativas al directorio de instalación.
*   **Buenas prácticas (Recomendaciones — 🟢 Opcionales):**
    *   Utilizar redes privadas aisladas en Docker Compose (`assistant-network`) para ocultar los puertos internos de los servicios del exterior.
*   **Antipatrones (Errores conocidos):**
    *   ❌ Configurar dependencias absolutas a rutas de directorios específicas de un host concreto (`/home/usuario/...`).
    *   ❌ Levantar contenedores Docker que requieran acceso `privileged` para interactuar con la tarjeta de sonido.
*   **Referencias:**
    *   [installation.md](file:///home/danuser2018/workspace/home-assistant/docs/installation.md) (Guía de instalación rápida y dependencias nativas).
    *   [docker-compose.yml](file:///home/danuser2018/workspace/home-assistant/docker-compose.yml) (Configuración actual de redes y variables de entorno).

---

### 5. `architecture-decisions`

*   **Objetivo:** Proteger la coherencia arquitectónica a largo plazo impidiendo decisiones tácticas no justificadas que alteren el diseño general.
*   **Cuándo aplicar esta skill:**
    *   Al planificar una refactorización de gran envergadura.
    *   Al detectar cambios en las fronteras de servicios, protocolos o flujos.
*   **Responsabilidades:** Evaluar el impacto estructural de cambios e indicar la necesidad de documentarlos de manera formal.
*   **Invariantes (Leyes — 🔴 Críticas):**
    *   *Trazabilidad de diseño:* Toda decisión arquitectónica crítica que afecte a más de un repositorio debe documentarse en un Architectural Decision Record (ADR).
*   **Reglas (Procedimientos — 🟡 Recomendadas):**
    *   Proponer obligatoriamente al desarrollador la creación de un nuevo ADR si el cambio propuesto:
        *   Modifica responsabilidades o límites de los servicios (`service-boundaries`).
        *   Modifica contratos públicos o APIs de comunicación del sistema.
        *   Introduce un nuevo patrón de diseño o arquitectura estructural (p. ej., migrar de filesystem a Redis).
        *   Altera los patrones de comunicación física o red entre componentes (`communication-patterns`).
*   **Buenas prácticas (Recomendaciones — 🟢 Opcionales):**
    *   Indexar y almacenar los ADRs en formato Markdown en un directorio centralizado (`docs/adr/`) con nomenclatura secuencial.
*   **Antipatrones (Errores conocidos):**
    *   ❌ Crear ADRs para cambios de implementación local o refactorización interna de un único método que no impacte a la integración global.
    *   ❌ Implementar soluciones arquitectónicas alternativas sin consultar previamente los ADRs vigentes sobre esa decisión.
*   **Referencias:**
    *   [architecture.md](file:///home/danuser2018/workspace/home-assistant/docs/architecture.md) (Contiene las decisiones de diseño clave iniciales).

---

### 6. `identity-domain`

*   **Objetivo:** Garantizar la confidencialidad, privacidad y el control centralizado de los datos privados del usuario.
*   **Cuándo aplicar esta skill:**
    *   Al modificar o añadir endpoints en `identity-service`.
    *   Al implementar nuevos plugins en `orchestrator` que requieran interactuar con información del usuario.
*   **Responsabilidades:** Almacenamiento y suministro del nombre del usuario, correo electrónico primario y credenciales.
*   **Invariantes (Leyes — 🔴 Críticas):**
    *   *Single Source of Truth:* El `identity-service` es el único propietario y origen de los datos privados de identidad. Ningún otro servicio debe duplicar su almacenamiento.
    *   *Privacidad absoluta (Zero-Leak):* Queda terminantemente prohibido imprimir datos privados del usuario (como correos o nombres reales) en consolas de logs públicos, depuradores de Docker o enviarlos en payloads sin cifrar.
*   **Reglas (Procedimientos — 🟡 Recomendadas):**
    *   Los servicios que requieran notificar al usuario externo deben consultar su "dirección lógica" (correo electrónico) a través del microservicio de identidad; nunca deben resolverla de manera autónoma.
*   **Buenas prácticas (Recomendaciones — 🟢 Opcionales):**
    *   Ocultar el mecanismo físico de almacenamiento de la identidad (como variables `.env` o bases de datos) al resto del sistema mediante interfaces REST.
*   **Antipatrones (Errores conocidos):**
    *   ❌ Mapear o leer directamente la variable `USER_EMAIL` en servicios como `mail-watchdog` u `orchestrator` (violación de aislamiento de datos).
    *   ❌ Implementar lógica de envío SMTP o validación de red dentro de la API de identidad.
*   **Referencias:**
    *   [identity-service/README.md](file:///home/danuser2018/workspace/identity-service/README.md) (Especifica la implementación actual de almacenamiento por variables `.env` y endpoints REST de identidad).

---

### 7. `system-domain`

*   **Objetivo:** Proteger el registro y descubrimiento de capacidades y el control del estado y configuración global de Nova-2.
*   **Cuándo aplicar esta skill:**
    *   Al registrar nuevas capacidades, servicios o plugins en el sistema.
    *   Al alterar los metadatos de Nova-2 (versión, autor, capacidades del asistente).
*   **Responsabilidades:** Registro y estado de servicios, capacidades de intenciones del orquestador, metadatos y feature flags globales.
*   **Invariantes (Leyes — 🔴 Críticas):**
    *   *Consistencia de metadatos:* Toda la información sobre qué sabe Nova-2 de sí misma (nombre del asistente, versión activa, autor) reside centralmente en `system-service`.
    *   *Inmutabilidad del registro:* Ningún servicio debe asumir que una capacidad está disponible sin antes consultar su estado de registro en el servicio del sistema.
*   **Reglas (Procedimientos — 🟡 Recomendadas):**
    *   Enviar un payload de inicialización con el esquema de capacidades al endpoint de registro global (`POST /system/capabilities`) durante el arranque del servicio correspondiente.
*   **Buenas prácticas (Recomendaciones — 🟢 Opcionales):**
    *   Utilizar feature flags dinámicas en el payload de capacidades para controlar de manera remota qué intenciones puede resolver el orquestador en caliente.
*   **Antipatrones (Errores conocidos):**
    *   ❌ Escribir o asumir metadatos de autoría o versión fijos en servicios descentralizados de la plataforma.
    *   ❌ Registrar capacidades dinámicas ficticias que el servicio correspondiente no soporte de forma activa en el código.
*   **Referencias:**
    *   [system-service/README.md](file:///home/danuser2018/workspace/system-service/README.md) (Registros REST de información del sistema de metadatos de Nova).

---

### 8. `mail-domain`

*   **Objetivo:** Garantizar la fiabilidad y la entrega asíncrona de correos sin comprometer la latencia ni bloquear los flujos interactivos de voz.
*   **Cuándo aplicar esta skill:**
    *   Al realizar cambios en la lógica de procesamiento de colas en `mail-watchdog`.
    *   Al crear plugins de intenciones en el orquestador que requieran emitir correos o alertas asíncronas.
*   **Responsabilidades:** Desacoplamiento de la cola SMTP, encolado fiable de archivos JSON y reintentos automáticos.
*   **Invariantes (Leyes — 🔴 Críticas):**
    *   *Garantía anti-pérdida:* Un mensaje encolado nunca puede eliminarse de la bandeja hasta recibir una confirmación positiva de entrega SMTP o, alternativamente, hasta ser trasladado al repositorio de fallos definitivos para auditoría manual.
    *   *Idempotencia del receptor:* El procesamiento de la cola debe ser inmune a interrupciones físicas; si un envío falla a mitad de la transmisión, el reintento subsiguiente no debe duplicar el correo.
*   **Reglas (Procedimientos — 🟡 Recomendadas):**
    *   El encolado de correos debe realizarse exclusivamente escribiendo archivos de mensaje estructurados en el directorio de entrada asíncrono asignado en el bus de datos del sistema.
*   **Buenas prácticas (Recomendaciones — 🟢 Opcionales):**
    *   Implementar políticas de reintentos progresivos con esperas incrementales para proteger al servidor SMTP de sobrecargas.
*   **Antipatrones (Errores conocidos):**
    *   ❌ Conectarse a sockets SMTP externos o implementar lógica de transporte de red de correo en el orquestador o sus plugins.
    *   ❌ Conservar de forma indefinida en la cola activa archivos JSON de correo corruptos o con campos faltantes obligatorios.
*   **Referencias:**
    *   [mail-watchdog/README.md](file:///home/danuser2018/workspace/mail-watchdog/README.md) (Detalla la implementación actual de la cola de archivos JSON y las variables del servidor SMTP).

---

### 9. `orchestrator-plugin-rules`

*   **Objetivo:** Mantener el control determinista de la interpretación del lenguaje y proteger la consistencia de la personalidad del asistente.
*   **Cuándo aplicar esta skill:**
    *   Al añadir, modificar o registrar un plugin de intenciones en el servicio `orchestrator`.
    *   Al definir la cadena de respuesta de voz que se enviará al sintetizador.
*   **Responsabilidades:** Scoring determinista de intenciones, coincidencia de keywords/regex, descripción de plugins e identidad verbal.
*   **Invariantes (Leyes — 🔴 Críticas):**
    *   *Determinismo en intenciones:* Las derivaciones de voz se resuelven exclusivamente mediante scoring matemático determinista sobre keywords/regex. Queda prohibida la introducción de modelos de lenguaje probabilísticos (LLMs) para el enrutamiento.
    *   *Identidad verbal de Nova-2:* Las respuestas verbales generadas por cualquier plugin deben seguir obligatoriamente el principio de mínima información: ser directas, impersonales, en español y libres de diálogos conversacionales redundantes.
*   **Reglas (Procedimientos — 🟡 Recomendadas):**
    *   Declarar siempre un campo de descripción conciso y obligatorio en la interfaz pública del plugin para cumplir el contrato del cargador dinámico.
*   **Buenas prácticas (Recomendaciones — 🟢 Opcionales):**
    *   Diseñar expresiones regulares con pesos equilibrados para evitar conflictos de coincidencia múltiple entre plugins.
*   **Antipatrones (Errores conocidos):**
    *   ❌ Escribir respuestas conversacionales amigables ("¡Hola!", "De nada, espero ayudarte", "¿Necesitas algo más?").
    *   ❌ Exponer mensajes con términos técnicos o excepciones de código HTTP en los textos salientes.
*   **Referencias:**
    *   [TONE_GUIDE.md](file:///home/danuser2018/workspace/orchestrator/TONE_GUIDE.md) (Reglas fundamentales de estilo, brevedad y respuestas por categoría).

---

### 10. `audio-rules`

*   **Objetivo:** Garantizar la estabilidad de la reproducción y captura nativa de sonido en el sistema sin solapamientos ni fugas de recursos.
*   **Cuándo aplicar esta skill:**
    *   Al realizar cambios en los scripts de grabación o reproducción física en `mic-daemon` o `speaker-watchdog`.
    *   Al interactuar con los procesos CLI de reproducción y captura de sonido del host Linux.
*   **Responsabilidades:** Captura del micrófono en buffers WAV, encolamiento secuencial de respuestas de audio y borrado seguro de residuos de voz.
*   **Invariantes (Leyes — 🔴 Críticas):**
    *   *Reproducción en cola única:* Las respuestas físicas de audio deben reproducirse secuencialmente una a una. Queda prohibido lanzar ejecuciones de audio concurrentes que provoquen solapamientos.
    *   *Liberación inmediata de recursos:* El sistema debe liberar el hardware de sonido y eliminar de forma segura los archivos WAV del disco inmediatamente después de finalizar su reproducción.
*   **Reglas (Procedimientos — 🟡 Recomendadas):**
    *   Monitorear la señal física de grabación a través de la presencia del archivo bandera en el filesystem, deteniendo el buffer nativo de forma limpia si este desaparece.
*   **Buenas prácticas (Recomendaciones — 🟢 Opcionales):**
    *   Mantener niveles de ganancia normalizados de forma global para los audios de realimentación acústica del sistema.
*   **Antipatrones (Errores conocidos):**
    *   ❌ Abrir de manera concurrente múltiples instancias del reproductor físico `mpv`.
    *   ❌ Mantener buffers de entrada de audio activos reteniendo RAM indefinidamente cuando no hay comando de grabación activo.
*   **Referencias:**
    *   [mic-daemon/README.md](file:///home/danuser2018/workspace/mic-daemon/README.md) (Control del micrófono a través de hilos nativos).
    *   [speaker-watchdog/README.md](file:///home/danuser2018/workspace/speaker-watchdog/README.md) (Uso del reproductor CLI `mpv` y control de colas FIFO en Python).

---

### 11. `inference-rules`

*   **Objetivo:** Minimizar la latencia y garantizar la estabilidad en la conversión local del lenguaje en el asistente.
*   **Cuándo aplicar esta skill:**
    *   Al optimizar o actualizar el motor de inferencia neuronal en `stt-capability` o `tts-capability`.
    *   Al configurar parámetros del backend de procesamiento de modelos locales.
*   **Responsabilidades:** Carga inicial de pesos del modelo de IA, conversión de audio binario a texto y síntesis neuronal.
*   **Invariantes (Leyes — 🔴 Críticas):**
    *   *Carga inicial única:* El modelo neuronal de traducción y síntesis se carga exclusivamente en la inicialización del proceso. Queda prohibido realizar lecturas del disco para recargar el modelo durante el flujo de respuesta de una petición.
    *   *Invariabilidad del formato físico:* El formato de entrada y salida física de audio (p. ej., tasas de muestreo y codificación WAV) debe ser único e inmutable en todas las APIs del pipeline.
*   **Reglas (Procedimientos — 🟡 Recomendadas):**
    *   Exponer endpoints de verificación de salud independientes de las tareas costosas de inferencia.
*   **Buenas prácticas (Recomendaciones — 🟢 Opcionales):**
    *   Seleccionar la versión más liviana del modelo neuronal compatible con el rendimiento local para reducir la latencia general en CPU.
*   **Antipatrones (Errores conocidos):**
    *   ❌ Retornar excepciones HTTP 500 al recibir audios vacíos; se debe retornar una transcripción vacía controlada de manera síncrona.
    *   ❌ Guardar registros físicos o logs de los archivos binarios de audio procesados en el microservicio.
*   **Referencias:**
    *   [stt-capability/README.md](file:///home/danuser2018/workspace/stt-capability/README.md) (Configuraciones de Faster-Whisper locales).
    *   [tts-capability/README.md](file:///home/danuser2018/workspace/tts-capability/README.md) (Configuraciones y síntesis local Piper TTS).
