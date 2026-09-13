# Especificación de Requisitos: AppLauncherPlugin (Nova)

## 1. Introducción
El `AppLauncherPlugin` es un componente conectable (plugin) para el servicio `orchestrator` del ecosistema Nova. Su propósito es interpretar instrucciones en lenguaje natural para abrir aplicaciones en el entorno host (Linux), delegando la ejecución física al `host-service`.

## 2. Requisitos Funcionales (RF)

*   **RF-01 (Activación Semántica Dinámica):** El plugin debe activarse basándose en el motor de similitud determinista (RapidFuzz), comparando el texto del usuario con un corpus de frases gestionado dinámicamente.
*   **RF-02 (Extracción de Parámetros):** El plugin debe delegar la extracción de la aplicación objetivo al `ParameterResolverEngine`, declarando contractualmente un parámetro de tipo `Command`.
*   **RF-03 (Delegación de Ejecución - HAL):** El plugin invocará el endpoint `POST /v1/commands/execute` de `host-service` vía cliente HTTP (`HostServiceClient`), pasándole el identificador lógico resuelto (`command_id`).
*   **RF-04 (Cumplimiento de Tone Guide):**
    *   En caso de éxito, emitirá un `PluginResult` con el literal exacto: *"Aplicación abierta."*
    *   En caso de error de red/timeout, responderá: *"Servicio no disponible."*
    *   En caso de rechazo del host, responderá: *"No he podido abrir la aplicación."*
*   **RF-05 (Publicación de Capacidades):** El plugin debe declarar su `id` (`"open_app"`) y descripción para que el `PluginManager` lo publique automáticamente en el `system-service` durante el arranque.

## 3. Requisitos No Funcionales (RNF)

*   **RNF-01 (Seguridad Zero-Shell):** El plugin operará bajo el principio de aislamiento absoluto; no utilizará el módulo `subprocess`, `os.system` ni shells locales dentro del contenedor Docker.
*   **RNF-02 (Comunicación Inter-Servicio de Confianza):** La llamada REST hacia el `host-service` no requerirá inyección de tokens de seguridad (HMAC-SHA256), ya que la seguridad perimetral se resuelve antes de la ejecución del plan en el orquestador.
*   **RNF-03 (Performance y Latencia):** Las llamadas de red al `host-service` deben configurarse con un timeout estricto (ej. 5 segundos) para no bloquear el bucle asíncrono del orquestador.
*   **RNF-04 (Statelessness):** La clase del plugin no persistirá estado conversacional en memoria. Su única mutabilidad permitida será el caché de las frases de activación (ejemplos dinámicos).

## 4. Diseño: Gestión de Ejemplos Dinámicos (Dynamic Examples)

El sistema de plugins original requiere que la propiedad `examples` esté disponible al arrancar para compilar el árbol de decisión de `ExecutionPlanner`. Sin embargo, los comandos reales del host viven en `commands.yaml` y son transmitidos asíncronamente mediante el bus de mensajería NATS (`event.host.commands.available`).

Para reconciliar este ciclo de vida, se implementa la siguiente estrategia híbrida:

1.  **Arranque en Frío (Cold-Start Fallback):**
    El plugin inicializa su estado interno (`_dynamic_examples`) con una lista estática de frases de contingencia (ej. *"Abre una aplicación"*, *"Iniciar programa"*). Esto garantiza que el orquestador no falle al cargar el plugin y pueda resolver intenciones genéricas antes de que llegue el primer evento NATS.
2.  **Inyección Asíncrona (Listener Hook):**
    Se añade un método público `load_dynamic_phrases(new_phrases: List[str])` en el plugin. 
3.  **Suscripción NATS:**
    El manejador de eventos del orquestador, suscrito a `event.host.commands.available`, será el responsable de:
    *   Recibir el catálogo del `host-service`.
    *   Localizar la instancia activa del `AppLauncherPlugin` mediante el `PluginManager`.
    *   Llamar a `load_dynamic_phrases()` para inyectar todas las frases capturadas.
4.  **Actualización Continua:**
    Cada vez que el host emita una actualización de su catálogo, el plugin actualizará su corpus en memoria, asegurando que si el usuario añade una nueva aplicación (ej. *"Calculadora"*), el orquestador sepa enrutar esa intención sin necesidad de reiniciar el contenedor.
