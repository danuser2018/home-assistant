# Especificación de Requisitos – Ejecución Directa de Shortcuts desde CLI

## 1. Objetivo

Incorporar un nuevo caso de uso al `interaction-manager` que permita ejecutar directamente un plugin a partir de un `ExecuteShortcutCommand`, sin realizar resolución semántica mediante el Orchestrator.

Este mecanismo será utilizado inicialmente por `novactl execute`, permitiendo invocar capacidades de Nova desde la línea de comandos con una latencia inferior al flujo de voz.

---

# 2. Motivación

Actualmente existen dos formas de iniciar una interacción:

* Captura de voz mediante `SpeechCapturedEvent`.
* Ejecución directa desde `novactl`.

El flujo de voz requiere una fase de reconocimiento y resolución de intención:

```
Audio
    ↓
STT
    ↓
Resolve
    ↓
ExecutionPlan
    ↓
ExecutePlan
```

Sin embargo, en el caso de `novactl execute`, el usuario ya proporciona el identificador del plugin que desea ejecutar, por lo que la fase de resolución resulta innecesaria.

El nuevo caso de uso deberá construir directamente un `ExecutionPlan` y reutilizar el resto del pipeline de interacción.

---

# 3. Alcance

Esta funcionalidad afecta únicamente al `interaction-manager`.

No modifica:

* el mecanismo de resolución del Orchestrator;
* el contrato de `ExecutionPlan`;
* el mecanismo de ejecución de plugins.

---

# 4. Evento de entrada

El nuevo consumidor escuchará el subject:

```
command.interaction.execute-shortcut
```

Payload:

```json
{
  "type": "ExecuteShortcutCommand",
  "payload": {
    "correlation_id": "781870fc-80fe-4165-ae55-4ebdc36b1c60",
    "shortcut": "weather",
    "channel": "cli"
  }
}
```

---

# 5. Flujo funcional

Al recibir un `ExecuteShortcutCommand`, el sistema deberá:

1. Reproducir el sonido de espera.
2. Construir un `ExecutionPlan`.
3. Invocar el endpoint `execute-plan` del Orchestrator.
4. Sintetizar mediante TTS la respuesta obtenida.
5. Guardar el audio generado en el directorio de salida.

No deberá realizar reconocimiento de voz.

No deberá realizar resolución de intención.

---

# 6. Construcción del ExecutionPlan

El `ExecutionPlan` contendrá un único paso.

El identificador del plugin será exactamente el valor recibido en `shortcut`.

El valor de `confidence` será `100.0`.

El canal será el recibido en el comando.

El `correlation_id` deberá propagarse al contexto del plan.

---

# 7. Tratamiento del shortcut

El campo `shortcut` representa el identificador único del plugin.

No existe ninguna fase de traducción, búsqueda o resolución.

El `interaction-manager` deberá asumir que el valor recibido identifica directamente el plugin que debe ejecutarse.

---

# 8. Validación

El `interaction-manager` no deberá comprobar si el plugin existe.

Su única responsabilidad será construir correctamente el `ExecutionPlan`.

La validación corresponderá exclusivamente al Orchestrator durante la ejecución del plan.

---

# 9. Manejo de errores

Si el plugin solicitado no existe, el Orchestrator devolverá un error durante la ejecución del plan.

El `interaction-manager` deberá tratar esta situación como cualquier otro error producido durante la ejecución de una interacción.

No deberá implementar ninguna lógica específica de validación previa.

---

# 10. Reutilización del pipeline

El nuevo flujo reutilizará todos los componentes existentes posteriores a la generación del `ExecutionPlan`.

En particular:

* reproducción del sonido de espera;
* ejecución del plan;
* síntesis de voz;
* generación del archivo WAV;
* registro de logs;
* propagación del `correlation_id`;
* gestión de errores.

La única diferencia respecto al flujo iniciado por voz será el mecanismo utilizado para obtener el `ExecutionPlan`.

---

# 11. Flujo resultante

```
ExecuteShortcutCommand
            │
            ▼
   Reproducir sonido de espera
            │
            ▼
 Construcción de ExecutionPlan
            │
            ▼
POST /api/v1/execute-plan
            │
            ▼
      Respuesta del plugin
            │
            ▼
             TTS
            │
            ▼
     Audio de respuesta
```

---

# 12. Criterios de aceptación

## CA-01

Dado un `ExecuteShortcutCommand` válido, el `interaction-manager` deberá reproducir el sonido de espera antes de iniciar la ejecución.

---

## CA-02

El sistema deberá construir un `ExecutionPlan` con un único paso utilizando el valor de `shortcut` como identificador del plugin.

---

## CA-03

El `interaction-manager` deberá invocar el endpoint `execute-plan` del Orchestrator utilizando el plan generado.

---

## CA-04

La respuesta textual del Orchestrator deberá sintetizarse mediante TTS utilizando el pipeline habitual.

---

## CA-05

El audio generado deberá almacenarse en el directorio de salida siguiendo el comportamiento habitual del sistema.

---

## CA-06

El `correlation_id` recibido deberá mantenerse durante toda la interacción.

---

## CA-07

El `interaction-manager` no deberá realizar ninguna validación sobre la existencia del plugin.

---

## CA-08

Si el Orchestrator informa de que el plugin no existe, la interacción deberá finalizar mediante el flujo estándar de gestión de errores.
