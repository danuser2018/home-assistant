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
Captura del micrófono, PipeWire/PulseAudio, encolamiento secuencial de audios de respuesta, estado del archivo bandera de grabación y sincronización de hilos.

## Invariantes (Leyes — 🔴 Críticas — Hard Constraints)
- **Reproducción en cola única:** Las respuestas físicas de audio deben reproducirse secuencialmente una a una. Queda prohibido lanzar ejecuciones de audio concurrentes que provoquen solapamientos.
- **Liberación inmediata de recursos:** El sistema debe liberar el hardware de sonido y eliminar de forma segura los archivos temporales de audio del disco inmediatamente después de finalizar su reproducción.

## Reglas (Procedimientos — 🟡 Recomendadas — Soft Constraints)
- Monitorear la señal física de grabación a través de la presencia del archivo bandera en el filesystem, deteniendo el buffer nativo de forma limpia si este desaparece.

## Buenas prácticas (Recomendaciones — 🟢 Opcionales)
- Mantener niveles de ganancia normalizados de forma global para los audios de realimentación acústica del sistema.

## Antipatrones (Errores conocidos)
- ❌ Abrir de manera concurrente múltiples instancias del reproductor físico de comandos del host.
- ❌ Mantener buffers de entrada de audio activos reteniendo RAM indefinidamente cuando no hay comando de grabación activo.

## Referencias
- [mic-daemon/README.md](file:///home/danuser2018/workspace/mic-daemon/README.md) (Control del micrófono a través de hilos nativos).
- [speaker-watchdog/README.md](file:///home/danuser2018/workspace/speaker-watchdog/README.md) (Uso del reproductor CLI y control de colas FIFO en Python).
- [ADR-002: Modularización de Servicios](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-002.md) (Host para Hardware y Docker para Procesamiento).
