---
name: inference-subsystem
description: Invariantes para servicios de traducción de voz (STT) y síntesis (TTS) optimizados para latencia local.
---

# inference-subsystem

## Objetivo
Minimizar la latencia y garantizar la estabilidad en la conversión local del lenguaje en el asistente.

## Cuándo aplicar esta skill
- Al optimizar o actualizar los motores de inferencia neuronal de Speech-to-Text (STT) o Text-to-Speech (TTS).
- Al configurar parámetros del backend de procesamiento de modelos locales.

## Responsabilidades
Carga inicial de pesos del modelo de IA, conversión de audio binario a texto, síntesis neuronal y formatos de codificación.

## Invariantes (Leyes — 🔴 Críticas — Hard Constraints)
- **Carga inicial única:** El modelo neuronal de traducción y síntesis se carga exclusivamente en la inicialización del proceso. Queda prohibido realizar lecturas del disco para recargar el modelo durante el flujo de respuesta de una petición.
- **Consistencia del formato de audio:** El formato físico de audio intercambiado entre las APIs del pipeline (tasas de muestreo, canales) debe ser único e inmutable en todas las firmas.

## Reglas (Procedimientos — 🟡 Recomendadas — Soft Constraints)
- Exponer endpoints de verificación de salud independientes de las tareas costosas de inferencia.

## Buenas prácticas (Recomendaciones — 🟢 Opcionales)
- Seleccionar la versión más liviana del modelo neuronal compatible con el rendimiento local para reducir la latencia general en CPU.

## Antipatrones (Errores conocidos)
- ❌ Retornar excepciones HTTP 500 al recibir audios vacíos; se debe retornar una transcripción vacía controlada de manera síncrona.
- ❌ Guardar registros físicos o logs de los archivos binarios de audio procesados en el microservicio.

## Referencias
- [stt-capability/README.md](file:///home/danuser2018/workspace/stt-capability/README.md) (Configuraciones de Faster-Whisper locales).
- [tts-capability/README.md](file:///home/danuser2018/workspace/tts-capability/README.md) (Configuraciones y síntesis local Piper TTS).
