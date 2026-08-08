# Especificación de Requisitos — Plugin `volume.set`

## 1. Identificación

**Plugin:** `volume.set`
**Dominio:** Audio
**Descripción:** Establece el volumen de audio del sistema a un valor absoluto entre 0 y 100.

El plugin se integra en el `orchestrator` y utiliza la infraestructura existente de resolución determinista de parámetros para obtener el valor de volumen a partir de la intención del usuario.

La ejecución del cambio de volumen se realizará exclusivamente mediante `host-service`, que actúa como HAL del sistema operativo y encapsula el acceso a PulseAudio/PipeWire.

---

## 2. Objetivo

Permitir que Nova interprete órdenes que indiquen explícitamente un **valor objetivo de volumen** y establezca dicho volumen en el sistema.

Ejemplos:

* «Pon el volumen al 50»
* «Establece el volumen en 30»
* «Fija el volumen al 75»
* «Pon el volumen al 100»
* «Volumen al 20»

El plugin representa una operación de **establecimiento absoluto**, no una operación incremental.

---

## 3. Alcance

### Incluido

* Identificación de la intención `volume.set`.
* Resolución de un parámetro `volume` de tipo `integer`.
* Validación del rango `0..100`.
* Ejecución del cambio de volumen mediante `host-service`.
* Gestión de errores de comunicación con `host-service`.
* Devolución del resultado de la operación al flujo de ejecución del `orchestrator`.

### No incluido

* Incrementar el volumen.
* Reducir el volumen.
* Silenciar el audio.
* Reactivar el audio.
* Alternar el estado de silencio.
* Consultar el volumen como operación independiente.
* Acceder directamente a `pactl`, PulseAudio o PipeWire.

Estas capacidades pertenecen a otros plugins o a la capa HAL correspondiente.

---

## 4. Identificación de intención

### Plugin ID

```text
volume.set
```

### Semántica

La intención se activa cuando el usuario expresa que quiere **establecer el volumen en un valor concreto**.

El número indicado representa un **valor absoluto**, no una variación respecto al volumen actual.

### Ejemplos válidos

| Expresión                    | Resultado      |
| ---------------------------- | -------------- |
| «Pon el volumen al 50»       | `volume = 50`  |
| «Establece el volumen en 30» | `volume = 30`  |
| «Fija el volumen al 75»      | `volume = 75`  |
| «Pon el volumen al 100»      | `volume = 100` |
| «Volumen al 20»              | `volume = 20`  |

### Expresiones fuera del alcance

Las expresiones que indiquen una variación relativa no pertenecen a `volume.set`.

| Expresión            | Plugin esperado |
| -------------------- | --------------- |
| «Sube el volumen»    | `volume.up`     |
| «Baja el volumen»    | `volume.down`   |
| «Aumenta el volumen» | `volume.up`     |
| «Reduce el volumen»  | `volume.down`   |

No se deben utilizar expresiones de incremento o decremento como ejemplos de entrenamiento del plugin `volume.set`.

---

## 5. Parámetros

El plugin requiere un único parámetro:

```yaml
volume:
  type: integer
  required: true
  minimum: 0
  maximum: 100
```

### `volume`

Representa el porcentaje absoluto de volumen deseado.

| Valor | Significado     |
| ----: | --------------- |
|   `0` | Volumen mínimo  |
|  `50` | Volumen al 50 % |
| `100` | Volumen máximo  |

El parámetro debe ser resuelto mediante el `ParameterResolverEngine`, utilizando el resolver entero existente. La arquitectura actual establece precisamente la ampliación de este mecanismo mediante convertidores deterministas.

---

## 6. Validación

El plugin debe aceptar exclusivamente valores enteros comprendidos entre `0` y `100`, ambos inclusive.

### Valores válidos

```text
0
1
25
50
75
99
100
```

### Valores inválidos

```text
-1
101
150
```

Los valores fuera de rango deben provocar un error de validación y **no deben generar ninguna llamada a `host-service`**.

El propio `host-service` también dispone de validación del rango `0..100` mediante Pydantic.

Esta doble validación permite mantener el contrato del plugin y, al mismo tiempo, la defensa en profundidad de la HAL.

---

## 7. Integración con `host-service`

El plugin utilizará el endpoint existente:

```http
POST /v1/audio/volume/set
```

### Request

```json
{
  "volume": 80
}
```

El endpoint está específicamente definido para establecer un volumen absoluto.

### Response esperada

```json
{
  "volume": 80,
  "muted": false
}
```

`host-service` devuelve tanto el volumen efectivo como el estado de silencio.

El plugin no debe ejecutar directamente comandos `pactl` ni acceder a PulseAudio/PipeWire. El acceso a hardware/audio del host debe permanecer encapsulado en `host-service`, de acuerdo con la frontera Host/Docker de Nova.

---

## 8. Flujo de ejecución

```text
Usuario
   │
   ▼
STT
   │
   ▼
Orchestrator
   │
   ├── Identificación → volume.set
   │
   ├── ParameterResolverEngine
   │       └── IntegerResolver
   │             └── volume = N
   │
   ├── Validación 0..100
   │
   ▼
ExecutionPlan
   │
   ▼
PlanExecutor
   │
   ▼
host-service
   │
   └── POST /v1/audio/volume/set
            │
            ▼
       PulseAudio/PipeWire
```

La ejecución debe integrarse en el `ExecutionPlan` existente y respetar el modelo contractual del orquestador.

---

## 9. Requisitos funcionales

### RF-01 — Identificación de intención

El sistema deberá identificar la intención `volume.set` cuando el usuario solicite establecer el volumen en un valor absoluto.

### RF-02 — Parámetro obligatorio

La intención `volume.set` deberá requerir un parámetro `volume`.

### RF-03 — Tipo del parámetro

El parámetro `volume` deberá ser de tipo `integer`.

### RF-04 — Resolución del parámetro

El parámetro deberá resolverse mediante el `ParameterResolverEngine` y el mecanismo determinista de resolución de enteros.

### RF-05 — Rango válido

El plugin deberá aceptar únicamente valores comprendidos entre `0` y `100`, ambos inclusive.

### RF-06 — Rechazo de valores inválidos

El plugin deberá rechazar valores inferiores a `0` o superiores a `100`.

### RF-07 — Establecimiento absoluto

El valor recibido deberá interpretarse como el volumen objetivo absoluto.

### RF-08 — Invocación de HAL

Tras validar correctamente el parámetro, el plugin deberá invocar:

```http
POST /v1/audio/volume/set
```

### RF-09 — Propagación del resultado

El plugin deberá procesar la respuesta de `host-service` y devolver el resultado al mecanismo de ejecución del `orchestrator`.

### RF-10 — Separación de responsabilidades

El plugin no deberá implementar directamente la lógica de control del sistema de audio.

### RF-11 — No interferencia con `volume.up`

Las expresiones cuyo significado sea incrementar el volumen no deberán ser consideradas ejemplos válidos de `volume.set`.

### RF-12 — No interferencia con `volume.down`

Las expresiones cuyo significado sea reducir el volumen no deberán ser consideradas ejemplos válidos de `volume.set`.

---

## 10. Requisitos no funcionales

### RNF-01 — Determinismo

La resolución del parámetro deberá ser determinista y no depender de un LLM.

### RNF-02 — Aislamiento

La implementación deberá estar contenida en el plugin y no requerir modificaciones al núcleo del `orchestrator`, siguiendo el principio de extensión mediante plugins.

### RNF-03 — Respeto de la HAL

El plugin no deberá acceder directamente al sistema operativo ni a dispositivos de audio.

### RNF-04 — Validación

Los errores de parámetros deberán detectarse antes de ejecutar la operación remota.

### RNF-05 — Testabilidad

El plugin deberá poder probarse sin disponer de un sistema PulseAudio/PipeWire real, utilizando mocks del cliente HTTP hacia `host-service`.

### RNF-06 — Compatibilidad

La implementación deberá utilizar los contratos y estructuras existentes del `orchestrator`, `ExecutionPlan` y `ParameterResolverEngine`.

### RNF-07 — Observabilidad

Los errores de comunicación con `host-service` deberán quedar registrados mediante el mecanismo de logging existente, sin incluir información sensible.

---

## 11. Gestión de errores

### Parámetro ausente

Entrada:

```text
«Pon el volumen»
```

Resultado:

```text
Error de parámetro requerido.
```

No se ejecutará ninguna llamada a `host-service`.

### Valor fuera de rango

Entrada:

```text
«Pon el volumen al 120»
```

Resultado:

```text
Error de validación: volume debe estar entre 0 y 100.
```

No se ejecutará ninguna llamada a `host-service`.

### Error de `host-service`

Si `host-service` no está disponible o devuelve un error, el plugin deberá devolver un resultado de ejecución fallida y registrar el error correspondiente.

El plugin no deberá intentar ejecutar `pactl` como mecanismo alternativo.

---

## 12. Criterios de aceptación

### CA-01 — Volumen mínimo

Dado:

```text
«Pon el volumen al 0»
```

Cuando se ejecute la intención `volume.set`.

Entonces:

```json
POST /v1/audio/volume/set
{
  "volume": 0
}
```

deberá ser invocado correctamente.

### CA-02 — Volumen intermedio

Dado:

```text
«Pon el volumen al 50»
```

Entonces el plugin deberá ejecutar:

```json
{
  "volume": 50
}
```

### CA-03 — Volumen máximo

Dado:

```text
«Pon el volumen al 100»
```

Entonces el plugin deberá ejecutar:

```json
{
  "volume": 100
}
```

### CA-04 — Valor inferior al mínimo

Dado:

```text
volume = -1
```

Entonces la ejecución deberá rechazarse y no deberá invocarse `host-service`.

### CA-05 — Valor superior al máximo

Dado:

```text
volume = 101
```

Entonces la ejecución deberá rechazarse y no deberá invocarse `host-service`.

### CA-06 — Parámetro ausente

Dada una intención `volume.set` sin parámetro `volume`, la ejecución deberá fallar indicando que el parámetro es obligatorio.

### CA-07 — Separación con incremento

Una expresión equivalente a «sube el volumen» deberá resolverse mediante el plugin de incremento y no mediante `volume.set`.

### CA-08 — Separación con decremento

Una expresión equivalente a «baja el volumen» deberá resolverse mediante el plugin de decremento y no mediante `volume.set`.

### CA-09 — Uso exclusivo de HAL

El plugin no deberá ejecutar comandos `pactl` ni acceder directamente a PulseAudio/PipeWire.

### CA-10 — Propagación del resultado

Ante una respuesta correcta de `host-service`, el resultado del cambio deberá quedar disponible para el flujo de ejecución del `orchestrator`.

---

## 13. Contrato resumido

```yaml
plugin:
  id: volume.set
  description: Establece el volumen absoluto del sistema

parameters:
  volume:
    type: integer
    required: true
    minimum: 0
    maximum: 100

execution:
  service: host-service
  method: POST
  endpoint: /v1/audio/volume/set

request:
  volume: integer
```

## 14. Dependencias

El plugin depende de:

* `orchestrator`
* `ParameterResolverEngine`
* `IntegerResolver`
* `host-service`
* API `POST /v1/audio/volume/set`

No requiere acceso directo a hardware ni a las herramientas de audio del sistema.

---

## 15. Fuera de alcance para esta fase

No se contempla en esta implementación:

* Resolución de expresiones relativas como «un poco más».
* Conversión de palabras numéricas si el `IntegerResolver` no la soporta todavía.
* Control del volumen por pasos.
* Control de mute.
* Consulta independiente del volumen actual.
* Persistencia del volumen.
* Control de dispositivos de audio individuales.
