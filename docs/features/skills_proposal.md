# Propuesta de Estructura de Skills para el Asistente de IA (Nova-2) — Constitución y Modelo de Ejecución

Esta propuesta definitiva establece la **Constitución del Ecosistema Nova-2** y su **Modelo de Ejecución Lógica**. Define las reglas de interacción del asistente de IA (Antigravity) con el código, proporcionando una jerarquía clara, un mecanismo determinista de resolución de conflictos, y una separación estricta entre restricciones duras y heurísticas suaves para evitar la parálisis cognitiva del agente.

---

## 1. Modelo de Ejecución de Skills

Para que las skills de Nova-2 actúen como un sistema normativo ejecutable por el asistente de IA en runtime, se establece el siguiente ciclo de vida de evaluación y composición:

```text
[Inicio de la Tarea]
         │
         ▼
1. Carga de Skills Transversales (Políticas Globales de Calidad y Arquitectura)
         │
         ▼
2. Carga de Skills de Dominio (Reglas de Negocio del contexto de la tarea)
         │
         ▼
3. Carga de Skills de Subsistema (Reglas Técnicas e Integración de Hardware)
         │
         ▼
4. Composición e Identificación de Invariantes (Filtro de Restricciones Duras)
         │
         ▼
5. Resolución de Conflictos (Aplicación de Reglas de Prioridad y Overrides)
         │
         ▼
6. Aplicación de Heurísticas Suaves (Estilos, sugerencias y buenas prácticas)
         │
         ▼
[Ejecución de Código / Generación]
```

### Protocolo de Carga y Aplicación de Reglas

1.  **Carga Secuencial:** El agente de IA siempre inicia cargando las reglas transversales de calidad y arquitectura, seguidas por las del dominio de negocio que está modificando y, finalmente, las reglas técnicas del subsistema de hardware involucrado.
2.  **Filtro de Restricciones Duras (Hard Constraints):** Las restricciones de tipo 🔴 (Leyes) actúan como aserciones innegociables. El asistente debe abortar o refutar una propuesta de cambio si esta implica violar una sola Hard Constraint.
3.  **Evaluación de Heurísticas (Soft Constraints):** Las reglas 🟡 (Procedimientos) y las buenas prácticas 🟢 (Sugerencias) actúan como heurísticas de optimización; se aplican de forma flexible para guiar el diseño estético y la legibilidad.

---

## 2. Mecanismo de Resolución de Conflictos (Conflict Resolution)

Ante contradicciones lógicas entre dos o más directrices durante el desarrollo, el asistente aplicará las siguientes reglas de prioridad y anulación (*override*):

### Regla de Jerarquía de Prioridad
La precedencia de aplicación de normas ante cualquier conflicto es estrictamente lineal:
$$\text{Transversal} > \text{Domain Rules} > \text{Subsystem Rules} > \text{Plugin/Implementation Rules}$$

### Casos de Resolución de Conflictos Comunes en Nova-2

*   **Caso A: Feature Flags vs. Determinismo de Intenciones**
    *   *Conflicto:* `system-domain` permite alterar configuraciones del sistema en caliente mediante feature flags, mientras que `plugin-domain` exige un scoring determinista estricto del lenguaje.
    *   *Resolución:* `service-responsibilities` (Transversal) prevalece sobre `system-domain` y `plugin-domain`. La resolución del lenguaje siempre debe ser 100% determinista *para un estado dado* de la feature flag. El registro del flag es dinámico, pero la regla de mapeo lingüístico correspondiente al estado activo del flag no debe poseer aleatoriedad.
*   **Caso B: Idempotencia de API vs. Reintentos Físicos de Entrega**
    *   *Conflicto:* `api-contracts` exige idempotencia estricta en el registro de peticiones para evitar envíos duplicados, mientras que `mail-domain` requiere políticas de reintento físico de sockets de red SMTP que pueden generar re-envíos ante fallos de conexión parciales.
    *   *Resolución:* `api-contracts` (Transversal) prevalece sobre `mail-domain` (Dominio). La idempotencia se garantiza en la frontera de la API (mediante el identificador de mensaje único en `mail/pending/`). La lógica interna de reintentos del daemon de correo es transparente y nunca debe alterar el identificador único del mensaje ni duplicar su registro en la cola del bus de datos.

---

## 3. Clasificación de Restricciones (Hard vs. Soft Constraints)

Las directrices del sistema se dividen estrictamente en dos categorías funcionales para prevenir la parálisis por exceso de reglas:

1.  **Restricciones Duras (Hard Constraints — Invariantes 🔴):**
    Principios de obligado cumplimiento. Incluyen: seguridad del sistema, privacidad de identidad, exclusión de audio físico del entorno de contenedores, carga estática de modelos neuronales de inferencia y esquemas comunes de respuestas de error.
2.  **Restricciones Suaves (Soft Constraints — Reglas 🟡 y Heurísticas 🟢):**
    Directrices de optimización que guían el estilo de lenguaje del orquestador, los pesos específicos de keywords, las metodologías de tests unitarios y las tácticas de despliegue local de entornos de desarrollo.

---

## 4. Estructura de Directorios Unificada (Single Source of Truth)

Todas las skills se almacenan bajo el subdirectorio `.agent/skills/` del repositorio coordinador `home-assistant`. Esto garantiza que no haya duplicidad y que cualquier cambio de reglas se actualice en un único lugar.

```text
home-assistant/
└── .agent/
    └── skills/
        ├── transversal/
        │   ├── development-workflow/
        │   │   └── SKILL.md
        │   ├── service-responsibilities/
        │   │   └── SKILL.md
        │   ├── communication-patterns/
        │   │   └── SKILL.md
        │   ├── api-contracts/
        │   │   └── SKILL.md
        │   ├── system-deployment/
        │   │   └── SKILL.md
        │   └── architecture-decisions/
        │       └── SKILL.md
        │
        └── domains/
            ├── identity-domain/
            │   └── SKILL.md
            ├── system-domain/
            │   └── SKILL.md
            ├── mail-domain/
            │   └── SKILL.md
            ├── plugin-domain/
            │   └── SKILL.md
            ├── audio-subsystem/
            │   └── SKILL.md
            └── inference-subsystem/
                └── SKILL.md
```

---

## 5. Catálogo de Skills (Constitución Nova-2)

### A. Skills Transversales (Ciclo de Vida y Arquitectura Global)

#### 1. `development-workflow`
*   **Objetivo:** Proteger la coherencia histórica del código, su legibilidad y la estabilidad de las interfaces de comunicación.
*   **Cuándo aplicar esta skill:**
    *   Al realizar cualquier modificación de código en cualquier repositorio del ecosistema.
    *   Al preparar commits, Pull Requests o preparar la versión de un release.
*   **Responsabilidades:** Ciclo de vida de Git, versionado, tipado, documentación e internacionalización.
*   **Invariantes (Leyes — 🔴 Críticas — Hard Constraints):**
    *   *Aislamiento lingüístico:* Todo elemento de código (código fuente, variables, base de datos, nombres de endpoints, logs y comentarios) se escribe estrictamente en inglés. Toda interacción externa (documentación técnica, changelogs, commits y PRs) se redacta en español.
*   **Reglas (Procedimientos — 🟡 Recomendadas — Soft Constraints):**
    *   Registrar cronológicamente todo cambio funcional en el `CHANGELOG.md` del servicio correspondiente bajo la sección `[Sin publicar]`.
    *   Acompañar cualquier cambio funcional de código con sus respectivos tests de comportamiento.
*   **Buenas prácticas (Recomendaciones — 🟢 Opcionales):**
    *   Escribir pruebas unitarias que verifiquen el comportamiento y las condiciones de borde en lugar del flujo de ejecución del código.
*   **Antipatrones (Errores conocidos):**
    *   ❌ Realizar commits directos sobre la rama `main` (violación de Trunk Based Development).
    *   ❌ Escribir changelogs o descripciones de PR en inglés.
*   **Referencias:**
    *   [CONTRIBUTING.md](file:///home/danuser2018/workspace/home-assistant/CONTRIBUTING.md) (Describe el flujo de Git y Conventional Commits).

---

#### 2. `service-responsibilities`
*   **Objetivo:** Garantizar la modularidad de la plataforma mediante la asignación estricta de propiedad lícita (*ownership*) a cada componente.
*   **Cuándo aplicar esta skill:**
    *   Al añadir nuevas capacidades de procesamiento al sistema.
    *   Al decidir en qué repositorio o servicio implementar un nuevo requisito funcional.
*   **Responsabilidades:** Definición de dependencias, fuentes de verdad (*sources of truth*) y propiedad de lógica de cada componente.
*   **Invariantes (Leyes — 🔴 Críticas — Hard Constraints):**
    *   *Propiedad Única de Datos:* Cada dominio de datos (identidad, configuración del sistema, cola de correos) pertenece a un único servicio que actúa como su fuente de verdad. Ningún otro servicio debe duplicar su persistencia ni almacenar estados en la sombra (*shadow state*).
    *   *Aislamiento del host:* Los contenedores Docker son ciegos al hardware físico. La captura de micrófonos y la reproducción de altavoces residen en exclusiva en el host.
    *   *Orquestador único:* La secuencia temporal del pipeline de voz en tiempo real (STT -> Orchestrator -> TTS) es de propiedad exclusiva de `interaction-manager`. Ningún otro componente debe coordinar llamadas en cascada.
*   **Reglas (Procedimientos — 🟡 Recomendadas — Soft Constraints):**
    *   El orquestador debe limitarse a derivar intenciones mediante scoring determinista; nunca debe realizar almacenamiento de datos de usuario ni llamadas de red directas a APIs externas de dominio.
*   **Buenas prácticas (Recomendaciones — 🟢 Opcionales):**
    *   Diseñar los servicios de traducción e inferencia de voz (`stt-capability` y `tts-capability`) de forma autónoma, sin conocimiento del dominio del asistente.
*   **Antipatrones (Errores conocidos):**
    *   ❌ Añadir lógica de reproducción física de altavoces en `interaction-manager` u `orchestrator`.
    *   ❌ Duplicar persistencia de bases de datos o lógica de negocio en los daemons nativos del host (`mic-daemon`, `speaker-watchdog`).
*   **Referencias:**
    *   [architecture.md](file:///home/danuser2018/workspace/home-assistant/docs/architecture.md) (Definición del plano de host y plano de procesamiento).
    *   [ADR-002: Modularización de Servicios](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-002.md) (Explica la decisión de aislar servicios de hardware del host de la lógica Docker).

---

#### 3. `communication-patterns`
*   **Objetivo:** Garantizar la fiabilidad en la entrega de mensajes y evitar dependencias de red frágiles.
*   **Cuándo aplicar esta skill:**
    *   Al definir la interacción de red o de archivos entre dos o más microservicios.
    *   Al implementar nuevos sockets o flujos de integración.
*   **Responsabilidades:** Protocolos de red internos (síncronos) y paso de mensajes en el sistema de archivos (asíncronos).
*   **Invariantes (Leyes — 🔴 Críticas — Hard Constraints):**
    *   *Reclamación exclusiva:* El servicio que procesa un mensaje asíncrono debe reclamar la propiedad del recurso de forma atómica antes de trabajar sobre él para evitar condiciones de carrera y procesamiento duplicado.
    *   *Ciclo de vida del mensaje:* El servicio consumidor de un mensaje en el filesystem es el único responsable de su destrucción o su traslado definitivo a carpetas de error en caso de fallo crítico.
*   **Reglas (Procedimientos — 🟡 Recomendadas — Soft Constraints):**
    *   Utilizar HTTP/REST síncrono para operaciones en tiempo real donde la latencia sea crítica (STT, TTS, Orchestrator).
    *   Establecer timeouts estrictos en todas las solicitudes HTTP salientes para evitar congelar el pipeline de interacción por fallos de red.
*   **Buenas prácticas (Recomendaciones — 🟢 Opcionales):**
    *   Utilizar formatos estandarizados de intercambio estructurado (como JSON) para mensajes asíncronos en disco.
*   **Antipatrones (Errores conocidos):**
    *   ❌ Leer o escribir directamente en un directorio de datos interno propiedad de otro servicio (violación del aislamiento del bus).
    *   ❌ Mantener flujos de red persistentes entre el host y Docker para transferir bloques de datos.
*   **Referencias:**
    *   [services.md](file:///home/danuser2018/workspace/home-assistant/docs/services.md) (Sección: Comunicación entre Servicios).

---

#### 4. `api-contracts`
*   **Objetivo:** Garantizar la consistencia, estabilidad y compatibilidad de las interfaces públicas de comunicación en todo el ecosistema.
*   **Cuándo aplicar esta skill:**
    *   Al añadir, modificar o eliminar endpoints REST en cualquier microservicio.
    *   Al diseñar esquemas de datos de entrada/salida públicos.
*   **Responsabilidades:** Versionado de APIs, nomenclatura de recursos, esquemas de error comunes y consistencia en cabeceras.
*   **Invariantes (Leyes — 🔴 Críticas — Hard Constraints):**
    *   *Invariabilidad del formato de error:* Todas las respuestas de error en la API pública de cualquier servicio deben seguir el mismo esquema estructurado común (p. ej., RFC 7807 o similar).
    *   *Retrocompatibilidad obligatoria:* Queda prohibido realizar cambios en el nombre de campos o tipos en el JSON de salida de APIs que rompan consumidores existentes.
*   **Reglas (Procedimientos — 🟡 Recomendadas — Soft Constraints):**
    *   Actualizar la especificación de OpenAPI de manera inmediata tras realizar cualquier cambio en endpoints.
    *   Mantener el versionado explícito en la ruta de las APIs (p. ej., `/api/v1/`).
*   **Buenas prácticas (Recomendaciones — 🟢 Opcionales):**
    *   Usar paginación consistente en listados públicos para evitar sobrecargas de memoria en consultas grandes.
*   **Antipatrones (Errores conocidos):**
    *   ❌ Retornar excepciones técnicas de base de datos o trazas de código en el payload de las respuestas HTTP.
    *   ❌ Mezclar estilos de nomenclatura en endpoints (ej. camelCase y snake_case combinados en la misma interfaz).
*   **Referencias:**
    *   [ADR-004: Estandarización de APIs REST en el Ecosistema](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-004.md) (Establece el protocolo HTTP unificado y la nomenclatura común).

---

#### 5. `system-deployment`
*   **Objetivo:** Garantizar la consistencia, portabilidad y repetibilidad de la instalación en entornos locales Linux.
*   **Cuándo aplicar esta skill:**
    *   Al modificar archivos de configuración de entornos (`.env.example`), orquestación de contenedores (`docker-compose.yml`) o servicios systemd.
    *   Al añadir dependencias del host o variables del sistema.
*   **Responsabilidades:** Despliegue, configuraciones de red, variables globales y montaje de recursos.
*   **Invariantes (Leyes — 🔴 Críticas — Hard Constraints):**
    *   *Seguridad en origen:* Queda estrictamente prohibida la inclusión de credenciales SMTP o API keys reales en archivos bajo control de versiones.
    *   *Servicio de usuario:* Los daemons de audio nativos deben ejecutarse en el espacio de usuario (`systemd --user`) para heredar los permisos de sonido de la sesión activa del usuario.
*   **Reglas (Procedimientos — 🟡 Recomendadas — Soft Constraints):**
    *   Validar la existencia de variables locales requeridas al iniciar cualquier módulo del sistema.
    *   Declarar todos los mapeos de directorios compartidos del host usando rutas relativas al directorio de instalación.
*   **Buenas prácticas (Recomendaciones — 🟢 Opcionales):**
    *   Utilizar redes privadas aisladas en Docker Compose (`assistant-network`) para ocultar los puertos internos de los servicios del exterior.
*   **Antipatrones (Errores conocidos):**
    *   ❌ Configurar dependencias absolutas a rutas de directorios específicas de un host concreto (`/home/usuario/...`).
    *   ❌ Ejecutar daemons de audio como servicio de sistema (`sudo systemctl`) en lugar de servicio de usuario.
*   **Referencias:**
    *   [installation.md](file:///home/danuser2018/workspace/home-assistant/docs/installation.md) (Guía de instalación rápida y dependencias nativas).
    *   [docker-compose.yml](file:///home/danuser2018/workspace/home-assistant/docker-compose.yml) (Configuración actual de redes y variables de entorno).

---

#### 6. `architecture-decisions`
*   **Objetivo:** Proteger la coherencia arquitectónica a largo plazo impidiendo decisiones tácticas no justificadas que alteren el diseño general.
*   **Cuándo aplicar esta skill:**
    *   Al planificar una refactorización de gran envergadura.
    *   Al detectar cambios en las responsabilidades de servicios, contratos o flujos.
*   **Responsabilidades:** Evaluar el impacto estructural de cambios e indicar la necesidad de documentarlos de manera formal.
*   **Invariantes (Leyes — 🔴 Críticas — Hard Constraints):**
    *   *Trazabilidad de diseño:* Toda decisión arquitectónica crítica que afecte a más de un repositorio debe documentarse en un Architectural Decision Record (ADR).
*   **Reglas (Procedimientos — 🟡 Recomendadas — Soft Constraints):**
    *   Proponer obligatoriamente al desarrollador la creación de un nuevo ADR si el cambio propuesto:
        *   Modifica responsabilidades o límites de los servicios (`service-responsibilities`).
        *   Modifica contratos públicos o APIs de comunicación del sistema (`api-contracts`).
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

### B. Skills Locales (Reglas de Negocio por Dominios)

#### 7. `identity-domain` (Dominio de Identidad del Usuario)
*   **Objetivo:** Garantizar la confidencialidad, privacidad y el control centralizado de los datos privados del usuario.
*   **Cuándo aplicar esta skill:**
    *   Al modificar o añadir endpoints en `identity-service`.
    *   Al implementar nuevos plugins en `orchestrator` que requieran interactuar con información del usuario.
*   **Responsabilidades:** Almacenamiento y suministro del nombre del usuario, correo electrónico primario y credenciales.
*   **Invariantes (Leyes — 🔴 Críticas — Hard Constraints):**
    *   *Single Source of Truth:* El `identity-service` es el único propietario y origen de los datos privados de identidad. Ningún otro servicio debe duplicar su almacenamiento.
    *   *Privacidad absoluta (Zero-Leak):* Queda terminantemente prohibido imprimir datos privados del usuario (como correos o nombres reales) en consolas de logs públicos, depuradores de Docker o enviarlos en payloads sin cifrar.
*   **Reglas (Procedimientos — 🟡 Recomendadas — Soft Constraints):**
    *   Los servicios que requieran notificar al usuario externo deben consultar su "dirección lógica" (correo electrónico) a través del microservicio de identidad; nunca deben resolverla de manera autónoma.
*   **Buenas prácticas (Recomendaciones — 🟢 Opcionales):**
    *   Ocultar el mecanismo físico de almacenamiento de la identidad (como variables `.env` o bases de datos) al resto del sistema mediante interfaces REST.
*   **Antipatrones (Errores conocidos):**
    *   ❌ Mapear o leer directamente la variable `USER_EMAIL` en servicios como `mail-watchdog` u `orchestrator` (violación de aislamiento de datos).
    *   ❌ Implementar lógica de envío SMTP o validación de red dentro de la API de identidad.
*   **Referencias:**
    *   [identity-service/README.md](file:///home/danuser2018/workspace/identity-service/README.md) (Especifica la implementación actual de almacenamiento por variables `.env` y endpoints REST de identidad).

---

#### 8. `system-domain` (Dominio de Configuración del Asistente)
*   **Objetivo:** Proteger el registro y descubrimiento de capacidades y el control del estado y configuración global de Nova-2.
*   **Cuándo aplicar esta skill:**
    *   Al registrar nuevas capacidades, servicios o plugins en el sistema.
    *   Al alterar los metadatos de Nova-2 (versión, autor, capacidades del asistente).
*   **Responsabilidades:** Registro y estado de servicios, capacidades de intenciones del orquestador, metadatos y feature flags globales.
*   **Invariantes (Leyes — 🔴 Críticas — Hard Constraints):**
    *   *Consistencia de metadatos:* Toda la información sobre qué sabe Nova-2 de sí misma (nombre del asistente, versión activa, autor) reside centralmente en `system-service`.
    *   *Inmutabilidad del registro:* Ningún servicio debe asumir que una capacidad está disponible sin antes consultar su estado de registro en el servicio del sistema.
*   **Reglas (Procedimientos — 🟡 Recomendadas — Soft Constraints):**
    *   Enviar un payload de inicialización con el esquema de capacidades al endpoint de registro global (`POST /system/capabilities`) durante el arranque del servicio correspondiente.
*   **Buenas prácticas (Recomendaciones — 🟢 Opcionales):**
    *   Utilizar feature flags dinámicas en el payload de capacidades para controlar de manera remota qué intenciones puede resolver el orquestador en caliente.
*   **Antipatrones (Errores conocidos):**
    *   ❌ Permitir que el `orchestrator` asuma las capacidades disponibles de forma estática en el código sin consultarlas al `system-service`.
    *   ❌ Modificar los datos de autoría o versión de Nova en archivos locales distribuidos.
*   **Referencias:**
    *   [system-service/README.md](file:///home/danuser2018/workspace/system-service/README.md) (Registros REST de información del sistema de metadatos de Nova).

---

#### 9. `mail-domain` (Dominio de Mensajería Asíncrona)
*   **Objetivo:** Garantizar la fiabilidad y la entrega asíncrona de correos sin comprometer la latencia ni bloquear los flujos interactivos de voz.
*   **Cuándo aplicar esta skill:**
    *   Al realizar cambios en la lógica de procesamiento de colas en `mail-watchdog`.
    *   Al crear plugins de intenciones en el orquestador que requieran emitir correos o alertas asíncronas.
*   **Responsabilidades:** Conexión SMTP, procesamiento de cola de correos, transiciones de archivos JSON y reintentos ante fallos de conexión SMTP.
*   **Invariantes (Leyes — 🔴 Críticas — Hard Constraints):**
    *   *Garantía anti-pérdida:* Un mensaje encolado nunca puede eliminarse de la bandeja hasta recibir una confirmación positiva de entrega SMTP o, alternativamente, hasta ser trasladado al repositorio de fallos definitivos para auditoría manual.
*   **Reglas (Procedimientos — 🟡 Recomendadas — Soft Constraints):**
    *   El encolado de correos debe realizarse exclusivamente escribiendo archivos de mensaje estructurados en el directorio de entrada asíncrono asignado en el bus de datos del sistema.
*   **Buenas prácticas (Recomendaciones — 🟢 Opcionales):**
    *   Implementar políticas de reintentos progresivos con esperas incrementales para proteger al servidor SMTP de sobrecargas.
*   **Antipatrones (Errores conocidos):**
    *   ❌ Conectarse a sockets SMTP externos o implementar lógica de transporte de red de correo en el orquestador o sus plugins.
    *   ❌ Conservar de forma indefinida en la cola activa archivos JSON de correo corruptos o con campos faltantes obligatorios.
*   **Referencias:**
    *   [mail-watchdog/README.md](file:///home/danuser2018/workspace/mail-watchdog/README.md) (Detalla la implementación actual de la cola de archivos JSON y las variables del servidor SMTP).

---

#### 10. `plugin-domain` (Dominio de Intenciones e Identidad de Voz)
*   **Objetivo:** Garantizar la resolución determinista de comandos de voz y mantener la coherencia de personalidad del asistente local.
*   **Cuándo aplicar esta skill:**
    *   Al añadir, modificar o registrar un plugin de intenciones en el servicio `orchestrator`.
    *   Al definir la cadena de respuesta de voz que se enviará al sintetizador.
*   **Responsabilidades:** Scoring determinista de intenciones, coincidencia de keywords/regex, descripción de plugins e identidad verbal.
*   **Invariantes (Leyes — 🔴 Críticas — Hard Constraints):**
    *   *Determinismo en intenciones:* Las derivaciones de voz se resuelven exclusivamente mediante scoring matemático determinista sobre keywords/regex. Queda prohibida la introducción de modelos de lenguaje probabilísticos (LLMs) para el enrutamiento.
    *   *Identidad verbal de Nova-2:* Las respuestas verbales generadas por cualquier plugin deben seguir obligatoriamente el principio de mínima información: ser directas, impersonales, en español y libres de diálogos conversacionales redundantes.
*   **Reglas (Procedimientos — 🟡 Recomendadas — Soft Constraints):**
    *   Declarar siempre un campo de descripción conciso y obligatorio en la interfaz pública del plugin para cumplir el contrato del cargador dinámico.
*   **Buenas prácticas (Recomendaciones — 🟢 Opcionales):**
    *   Diseñar expresiones regulares con pesos equilibrados para evitar conflictos de coincidencia múltiple entre plugins.
*   **Antipatrones (Errores conocidos):**
    *   ❌ Escribir respuestas conversacionales amigables ("¡Hola!", "De nada, espero ayudarte", "¿Necesitas algo más?").
    *   ❌ Exponer mensajes con términos técnicos o excepciones de código HTTP en los textos salientes.
*   **Referencias:**
    *   [TONE_GUIDE.md](file:///home/danuser2018/workspace/orchestrator/TONE_GUIDE.md) (Reglas fundamentales de estilo, brevedad y respuestas por categoría).

---

#### 11. `audio-subsystem` (Dominio de Captura y Reproducción Física)
*   **Objetivo:** Garantizar la estabilidad de la reproducción y captura nativa de sonido en el sistema sin solapamientos ni fugas de recursos.
*   **Cuándo aplicar esta skill:**
    *   Al realizar cambios en los scripts de grabación o reproducción física en los daemons nativos del host (`mic-daemon` o `speaker-watchdog`).
    *   Al interactuar con los procesos de reproducción y captura de sonido del host Linux.
*   **Responsabilidades:** Captura del micrófono, PipeWire/PulseAudio, encolamiento secuencial de audios de respuesta, estado del archivo bandera de grabación y sincronización de hilos.
*   **Invariantes (Leyes — 🔴 Críticas — Hard Constraints):**
    *   *Reproducción en cola única:* Las respuestas físicas de audio deben reproducirse secuencialmente una a una. Queda prohibido lanzar ejecuciones de audio concurrentes que provoquen solapamientos.
    *   *Liberación inmediata de recursos:* El sistema debe liberar el hardware de sonido y eliminar de forma segura los archivos temporales de audio del disco inmediatamente después de finalizar su reproducción.
*   **Reglas (Procedimientos — 🟡 Recomendadas — Soft Constraints):**
    *   Monitorear la señal física de grabación a través de la presencia del archivo bandera en el filesystem, deteniendo el buffer nativo de forma limpia si este desaparece.
*   **Buenas prácticas (Recomendaciones — 🟢 Opcionales):**
    *   Mantener niveles de ganancia normalizados de forma global para los audios de realimentación acústica del sistema.
*   **Antipatrones (Errores conocidos):**
    *   ❌ Abrir de manera concurrente múltiples instancias del reproductor físico de comandos del host.
    *   ❌ Mantener buffers de entrada de audio activos reteniendo RAM indefinidamente cuando no hay comando de grabación activo.
*   **Referencias:**
    *   [mic-daemon/README.md](file:///home/danuser2018/workspace/mic-daemon/README.md) (Control del micrófono a través de hilos nativos).
    *   [speaker-watchdog/README.md](file:///home/danuser2018/workspace/speaker-watchdog/README.md) (Uso del reproductor CLI y control de colas FIFO en Python).

---

#### 12. `inference-subsystem` (Dominio de Inferencia y Modelos Locales)
*   **Objetivo:** Minimizar la latencia y garantizar la estabilidad en la conversión local del lenguaje en el asistente.
*   **Cuándo aplicar esta skill:**
    *   Al optimizar o actualizar los motores de inferencia neuronal de Speech-to-Text (STT) o Text-to-Speech (TTS).
    *   Al configurar parámetros del backend de procesamiento de modelos locales.
*   **Responsabilidades:** Carga inicial de pesos del modelo de IA, conversión de audio binario a texto, síntesis neuronal y formatos de codificación.
*   **Invariantes (Leyes — 🔴 Críticas — Hard Constraints):**
    *   *Carga inicial única:* El modelo neuronal de traducción y síntesis se carga exclusivamente en la inicialización del proceso. Queda prohibido realizar lecturas del disco para recargar el modelo durante el flujo de respuesta de una petición.
    *   *Consistencia del formato de audio:* El formato físico de audio intercambiado entre las APIs del pipeline (tasas de muestreo, canales) debe ser único e inmutable en todas las firmas.
*   **Reglas (Procedimientos — 🟡 Recomendadas — Soft Constraints):**
    *   Exponer endpoints de verificación de salud independientes de las tareas costosas de inferencia.
*   **Buenas prácticas (Recomendaciones — 🟢 Opcionales):**
    *   Seleccionar la versión más liviana del modelo neuronal compatible con el rendimiento local para reducir la latencia general en CPU.
*   **Antipatrones (Errores conocidos):**
    *   ❌ Retornar excepciones HTTP 500 al recibir audios vacíos; se debe retornar una transcripción vacía controlada de manera síncrona.
    *   ❌ Guardar registros físicos o logs de los archivos binarios de audio procesados en el microservicio.
*   **Referencias:**
    *   [stt-capability/README.md](file:///home/danuser2018/workspace/stt-capability/README.md) (Configuraciones de Faster-Whisper locales).
    *   [tts-capability/README.md](file:///home/danuser2018/workspace/tts-capability/README.md) (Configuraciones y síntesis local Piper TTS).
