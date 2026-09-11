# ADR-026: Ejecución Segura de Comandos de Host mediante Identificador Lógico y Catálogo Cerrado en Host Service

## Fecha
11-09-2026

## Estado
Aceptado

## Contexto
El asistente local Nova-2 y sus clientes (como el orquestador o la CLI `novactl`) requieren la capacidad de lanzar aplicaciones y utilidades locales del sistema operativo host (por ejemplo, calculadora gráfica, navegadores o scripts de backup) en respuesta a intenciones del usuario.

Sin embargo:
1. Siguiendo el [ADR-002](adr/adr-002.md) y [ADR-013](adr/adr-013-integracion-host-service.md), los contenedores Docker del plano de procesamiento están aislados del sistema host y carecen de acceso a la sesión gráfica del usuario (`DISPLAY`, `WAYLAND_DISPLAY`, `DBUS_SESSION_BUS_ADDRESS`).
2. Permitir que los clientes HTTP o contenedores envíen binarios, rutas absolutas o argumentos arbitrarios introduciría graves riesgos de inyección de comandos o escalada de privilegios en el host.
3. Existía un archivo `config/host_commands_risk.yaml` en `host-service` que solo publicaba nombres y niveles de riesgo hacia `security-service`, pero sin ninguna capacidad de ejecución asociada, lo que propiciaba desincronizaciones si la ejecución se definía en otro lugar.

## Decisión
Se decide ampliar las capacidades del microservicio nativo `host-service` (Capa de Abstracción de Host / HAL) para gestionar la ejecución controlada y segura de comandos del host bajo los siguientes principios:

1. **Identificador Lógico como Contrato Único**:
   Los clientes solo conocen y envían un identificador lógico canónico (`name`, ej. `"calculator"`) al endpoint `POST /v1/commands/execute`. En ningún caso se aceptan binarios, rutas ni argumentos desde el exterior.

2. **Fuente Única de Verdad Declarativa (`config/host_commands.yaml`)**:
   Se sustituye por completo `config/host_commands_risk.yaml` por `config/host_commands.yaml`. Este archivo define unificadamente el identificador lógico, el vector físico de argumentos (`command` / `argv`) y el nivel de riesgo (`risk`).

3. **Ejecución Segura por Catálogo Cerrado y sin Shell**:
   La ejecución se realiza únicamente sobre comandos registrados previamente. Se invoca directamente el subproceso con `subprocess.Popen(argv, shell=False, start_new_session=True)` y streams redirigidos a `subprocess.DEVNULL`, eliminando cualquier vulnerabilidad de inyección mediante caracteres especiales de shell (`;`, `|`, `&&`, `$()`).

4. **Política Fail-Closed en el Arranque**:
   El componente `CommandRegistry` valida de forma estricta durante el `lifespan` de FastAPI el archivo `config/host_commands.yaml`: existencia del archivo, sintaxis YAML, formato de lista no vacía, unicidad de identificadores `name` y niveles de riesgo válidos (`low`, `medium`, `high`). Si falla cualquiera de estas comprobaciones, el servicio aborta inmediatamente su inicio.

5. **Separación Estricta de Responsabilidades**:
   `host-service` no toma decisiones sobre si un usuario tiene permisos para invocar un comando (autorización delegada en `security-service` según [ADR-025](adr/adr-025-security-service-user-authorization.md)). `host-service` se limita a ejecutar comandos del catálogo y publicar en el arranque el listado filtrado (`name` + `risk`) a `security-service`, omitiendo por completo los argumentos físicos de ejecución.

6. **Ejecución Asíncrona y Prevención de Zombies**:
   Al ejecutarse como servicio `systemd --user`, los subprocesos heredan la sesión del usuario activo. Con `start_new_session=True` (`os.setsid()`), los procesos gráficos se desacoplan del ciclo de vida del servicio. El servidor responde de forma inmediata con el estado `started` y el `pid` generado. Se configura `signal.signal(signal.SIGCHLD, signal.SIG_IGN)` para asegurar que el kernel recoja los procesos terminados sin generar zombies.

7. **Estandarización de Errores según ADR-004**:
   Las respuestas ante comandos desconocidos retornan HTTP 404 (`COMMAND_NOT_FOUND`), las cargas inválidas retornan HTTP 422 (`VALIDATION_ERROR`) y los fallos de invocación del sistema operativo retornan HTTP 500 (`COMMAND_EXECUTION_FAILED`), sin exponer tracebacks internos.

## Consecuencias
* **(+) Seguridad Zero Trust y Protección contra Inyecciones**: Imposible inyectar comandos o argumentos arbitrarios desde clientes o la red.
* **(+) Unificación y Coherencia**: Un único archivo de configuración (`host_commands.yaml`) garantiza que el catálogo ejecutado y el catálogo de riesgos publicado sean exactamente el mismo.
* **(+) Desacoplamiento y Respuesta Rápida**: Las aplicaciones de escritorio se lanzan de forma no bloqueante y continúan vivas independientemente de reinicios de `host-service`.
* **(+) Resiliencia ante la Red**: Si `security-service` no está disponible durante el arranque, `host-service` advierte en logs pero mantiene su disponibilidad operativa local.
* **(-) Gestión de Catálogo Estático**: Cualquier nueva aplicación o script a ejecutar en el host debe declararse previamente en `config/host_commands.yaml` y reiniciar el servicio `host-service`.
