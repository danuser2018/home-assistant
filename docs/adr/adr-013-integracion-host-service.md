# ADR-013: Integración del Servicio Host (host-service)

## Fecha
15-07-2026

## Estado
Aceptado

## Contexto
El asistente de voz local Nova-2 requiere la capacidad de interactuar con el mezclador de audio del host (por ejemplo, PipeWire o PulseAudio) para leer y modificar el volumen físico y el estado de silencio (mute) del sistema en respuesta a las intenciones del usuario ("sube el volumen", "silencia el asistente").

Sin embargo:
1. Siguiendo el [ADR-002: Modularización de Servicios](adr/adr-002.md), los contenedores Docker que componen el plano de procesamiento (como el `orchestrator`) son independientes del sistema operativo host, ciegos al hardware físico y carecen de privilegios para ejecutar utilidades como `pactl` directamente sobre la sesión activa de audio del usuario.
2. Permitir que los contenedores Docker accedan directamente a los sockets del host (`/run/user/UID/pulse/native`) o ejecuten herramientas del host mediante montajes inseguros introduce riesgos de seguridad y rompe la portabilidad del entorno Docker.
3. Se requiere una interfaz centralizada y desacoplada que actúe como una **Capa de Abstracción del Host** (Host Abstraction Layer - HAL) y exponga endpoints REST seguros e idempotentes para la manipulación física del sistema.

## Decisión
Se creará y se integrará el microservicio `host-service` en el **Plano de Hardware (Host Nativo)** como un servicio de usuario de systemd (`systemd --user`).

Este servicio tendrá las siguientes características:
- Estará implementado en Python utilizando **FastAPI** y **Uvicorn**, escuchando localmente en el puerto `8007`.
- Servirá como la única Capa de Abstracción de Host (HAL) autorizada para el control de audio del sistema.
- Se comunicará con PipeWire/PulseAudio mediante subprocesos efímeros invocando la utilidad nativa de sistema `pactl` con los privilegios mínimos del usuario actual.
- Realizará el parseo de la salida estructurada de los comandos `pactl get-sink-volume` y `pactl get-sink-mute` mediante expresiones regulares para garantizar respuestas estructuradas y robustas.
- Validará de manera estricta los parámetros numéricos de entrada (volumen y pasos restringidos al rango `0-100`) mediante **Pydantic** antes de ejecutar cualquier comando.
- Se registrará en la infraestructura local mediante modificaciones en los scripts de instalación, actualización, desinstalación y comprobación de salud (`healthcheck.sh`) del proyecto `home-assistant`.
- Será consumido desde el contenedor Docker del `orchestrator` haciendo uso de la puerta de enlace interna del puente de red de Docker Compose (`host.docker.internal`).

## Alternativas consideradas
- **Mapear sockets y ejecutar pactl desde el contenedor del Orchestrator:** Descartado porque requiere instalar dependencias del servidor de sonido dentro de la imagen de Docker de procesamiento y configurar variables de entorno complejas, degradando la portabilidad y aumentando la superficie de ataque del contenedor.
- **Crear un plugin del orquestador que escriba un archivo de control en el filesystem compartido:** Descartado porque introduce latencia indeseada, requiere implementar un script observador (watcher) síncrono adicional en el host, y no permite proporcionar respuestas HTTP síncronas del estado del volumen final tras aplicar un cambio.

## Consecuencias
+ **Aislamiento de hardware robusto:** Los contenedores de Docker no tienen contacto directo con las herramientas del host ni con PipeWire/PulseAudio.
+ **API estructurada y estable:** Se proporciona una interfaz REST limpia que valida las entradas mediante Pydantic y maneja de forma unificada los errores del subsistema de audio.
+ **Independencia de entorno de pruebas:** La API REST y el servicio se prueban unitariamente mediante mocks de subprocesos (`subprocess.run`), lo que permite validar la integración en entornos de CI headless sin servidor de audio activo.
+ **Compatibilidad modular:** Facilita la ampliación futura para controlar otros recursos físicos del host (apagado de pantalla, temperatura, brillo, etc.) bajo la misma API REST unificada de la HAL.
- **Puerto local expuesto:** Se consume el puerto `8007` en la interfaz de red local del host, el cual debe mantenerse seguro.
- **Administración adicional:** Incrementa ligeramente los procesos a supervisar en el host en comparación con un sistema puramente dockerizado.
