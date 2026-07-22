---
name: audio-subsystem
description: Invariantes para el control de hardware de audio en caliente, captura de micrófono y reproducción concurrente.
---

# audio-subsystem

## Objetivo
Garantizar la estabilidad de la reproducción y captura nativa de sonido en el sistema sin solapamientos ni fugas de recursos.

## Cuándo aplicar esta skill
- Al realizar cambios en los scripts de grabación o reproducción física en los daemons nativos del host (`mic-daemon` o `speaker-watchdog`).
- Al interactuar con los procesos de reproducción y captura de sonido del host Linux.

## Responsabilidades
Captura del micrófono, PipeWire/PulseAudio, encolamiento secuencial de audios de respuesta, suscripción a eventos de captura de habla via nova-event-bus y sincronización de hilos.

## Invariantes (Leyes — 🔴 Críticas — Hard Constraints)
- **Reproducción en cola única:** Las respuestas físicas de audio deben reproducirse secuencialmente una a una. Queda prohibido lanzar ejecuciones de audio concurrentes que provoquen solapamientos.
- **Liberación inmediata de recursos:** El sistema debe liberar el hardware de sonido y eliminar de forma segura los archivos temporales de audio del disco inmediatamente después de finalizar su reproducción.
- **Control de volumen centralizado:** El control de volumen físico del host y el estado de silencio deben gestionarse exclusivamente a través de los endpoints REST expuestos por `host-service` en `http://host.docker.internal:8007/v1/audio/volume`. Queda estrictamente prohibido ejecutar comandos directos `pactl` o scripts de manipulación del mezclador de audio desde dentro de contenedores Docker o plugins.

## Reglas (Procedimientos — 🟡 Recomendadas — Soft Constraints)
- Reaccionar a los comandos de control de grabación (`StartSpeechCaptureCommand` y `StopSpeechCaptureCommand`) recibidos a través del bus de eventos NATS via `nova-event-bus`, iniciando y deteniendo el buffer nativo de forma limpia y asíncrona.

## Buenas prácticas (Recomendaciones — 🟢 Opcionales)
- Mantener niveles de ganancia normalizados de forma global para los audios de realimentación acústica del sistema.

## Antipatrones (Errores conocidos)
- ❌ Mantener buffers de entrada de audio activos reteniendo RAM indefinidamente cuando no hay comando de grabación activo.

## Referencias
- [mic-daemon/README.md](file:///home/danuser2018/workspace/mic-daemon/README.md) (Control del micrófono impulsado por eventos NATS).
- [speaker-watchdog/README.md](file:///home/danuser2018/workspace/speaker-watchdog/README.md) (Uso del reproductor CLI con política de que el último sonido interrumpe al anterior sin solapamientos).
- [ADR-002: Modularización de Servicios](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-002.md) (Host para Hardware y Docker para Procesamiento).
- [ADR-008: Modelo de Reproducción de Audio Física en speaker-watchdog](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-008.md) (Consolidación de subprocesos efímeros con SIGKILL ante fallos de socket daemon).
- [ADR-013: Integración del Servicio Host (host-service)](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-013-integracion-host-service.md).
- [ADR-021: Detección de Habla basada en Eventos en mic-daemon](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-021-deteccion-habla-eventos-mic-daemon.md).
