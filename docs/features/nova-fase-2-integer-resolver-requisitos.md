# Nova-2 — Especificación de requisitos
## Fase 2: IntegerResolver

**Componente:** Orchestrator  
**Fase:** 2 — Implementación del primer resolver de parámetros  
**Estado:** Propuesto

## 1. Contexto

La Fase 1 estableció las interfaces necesarias para declarar parámetros de plugins y resolverlos mediante resolvers especializados por tipo.

La Fase 2 implementa el primer resolver funcional: `IntegerResolver`.

El objetivo es validar el mecanismo completo con un tipo sencillo antes de incorporar tipos de dominio más complejos como `Date` o `Location`.

El primer consumidor será el plugin de generación de números aleatorios, que evolucionará para recibir un parámetro `max`.

Flujo objetivo:

```text
"Dime un número menor de ochenta"
             ↓
       IntentResolver
             ↓
       random-number
             ↓
     ParameterResolver
             ↓
       IntegerResolver
             ↓
             80
             ↓
       ExecutionPlan
             ↓
       random-number(max=80)
```

## 2. Objetivo

Implementar un `IntegerResolver` capaz de interpretar números enteros expresados en lenguaje natural en español y proporcionar el valor resultante al mecanismo de resolución de parámetros.

La fase deberá además adaptar el plugin de número aleatorio para declarar y consumir el parámetro `max`.

## 3. Requisitos funcionales

### RF-01 — Implementación de IntegerResolver

El sistema deberá disponer de un resolver especializado para parámetros de tipo entero:

```text
Integer → IntegerResolver
```

El resolver deberá implementar la interfaz definida en la Fase 1.

### RF-02 — Interpretación de dígitos

El resolver deberá interpretar números expresados mediante dígitos:

```text
"5"    → 5
"25"   → 25
"100"  → 100
"1500" → 1500
```

### RF-03 — Interpretación de números escritos

El resolver deberá interpretar números cardinales escritos en español.

Como mínimo:

```text
"uno"             → 1
"cinco"           → 5
"diez"            → 10
"veinte"          → 20
"veinticinco"     → 25
"cincuenta"       → 50
"ochenta"         → 80
"cien"            → 100
"ciento veinte"   → 120
"mil"             → 1000
```

La cobertura exacta deberá quedar respaldada por pruebas automatizadas.

### RF-04 — Extracción desde una instrucción

El resolver deberá poder encontrar el entero relevante dentro de una instrucción completa.

Ejemplo:

```text
"Dime un número menor de ochenta"
```

deberá permitir obtener:

```text
80
```

El resolver no deberá requerir que la entrada contenga únicamente el número.

### RF-05 — Ausencia de entero

Cuando no exista un entero interpretable en el texto, el resolver deberá indicar que no se ha podido resolver el parámetro.

No deberá inventar un valor.

El uso del valor por defecto será responsabilidad del mecanismo de resolución de parámetros definido en la Fase 1.

### RF-06 — Un único resultado

En esta fase el `IntegerResolver` devolverá un único entero.

No se implementará todavía soporte específico para expresiones que requieran interpretar relaciones entre varios números, rangos o restricciones semánticas.

Por ejemplo, queda fuera de esta fase:

```text
"Dime un número entre diez y veinte"
```

### RF-07 — Plugin random-number

El plugin de número aleatorio deberá declarar un parámetro:

```text
max: Integer
```

con valor por defecto:

```text
100
```

### RF-08 — Consumo del parámetro

El plugin deberá utilizar el valor resuelto de `max` para limitar el número generado.

Ejemplos:

```text
"Dime un número"
→ max = 100

"Dime un número menor de 50"
→ max = 50

"Dime un número menor de ochenta"
→ max = 80
```

La interpretación del número será responsabilidad de `IntegerResolver`; el plugin no deberá interpretar lenguaje natural.

### RF-09 — Integración con ExecutionPlan

Cuando se haya resuelto el parámetro, el `ExecutionPlan` deberá contenerlo:

```json
{
  "plugin_id": "random-number",
  "parameters": {
    "max": 80
  }
}
```

El executor recibirá el plan ya resuelto y no realizará interpretación lingüística.

### RF-10 — Registro

`IntegerResolver` deberá quedar registrado mediante el mecanismo definido en la Fase 1.

El `ParameterResolver` deberá poder localizarlo mediante el tipo lógico `Integer`.

No deberá existir lógica específica por tipo dentro del `ParameterResolver`.

## 4. Requisitos no funcionales

### RNF-01 — Determinismo

La interpretación de enteros deberá ser determinista. Para una misma entrada y contexto deberá producir siempre el mismo resultado.

### RNF-02 — Funcionamiento offline

La resolución deberá funcionar completamente en local y sin:

- LLMs;
- APIs cloud;
- servicios externos;
- conexiones de red.

### RNF-03 — Independencia del plugin

`IntegerResolver` no deberá contener conocimiento específico de `random.number`.

Podrá utilizarse con cualquier plugin que declare un parámetro `Integer`.

### RNF-04 — Independencia del ParameterResolver

La lógica lingüística para interpretar enteros deberá permanecer dentro de `IntegerResolver`.

`ParameterResolver` deberá limitarse a coordinar la resolución.

### RNF-05 — Testabilidad

El resolver deberá poder probarse de forma aislada, sin levantar el orchestrator completo, executor, plugins ni servicios externos.

### RNF-06 — Extensibilidad

Ampliar la interpretación de enteros no deberá requerir modificar:

- `ParameterResolver`;
- `Plugin Executor`;
- plugins consumidores.

### RNF-07 — Dependencias

No se añadirá una dependencia externa para interpretar números salvo que resulte necesaria y esté justificada.

La implementación deberá priorizar una solución sencilla, local y mantenible.

### RNF-08 — Compatibilidad

Los plugins existentes que no utilicen parámetros deberán continuar funcionando sin cambios.

La incorporación de `IntegerResolver` no deberá modificar el comportamiento de resolución de intenciones que no requiera parámetros.

## 5. Fuera de alcance

Esta fase no incluye:

- `DateResolver`;
- `LocationResolver`;
- `DurationResolver`;
- composición entre resolvers;
- interpretación de rangos;
- interpretación de expresiones matemáticas;
- interpretación semántica de operadores como "menor que", "mayor que" o "entre";
- resolución de unidades;
- uso de LLM;
- servicios remotos;
- MCP;
- creación de `location-service`;
- cambios arquitectónicos adicionales en el orchestrator.

En particular, la frase:

```text
"Dime un número menor de ochenta"
```

se interpreta inicialmente como la extracción del valor `80`.

La semántica de la expresión "menor de" no forma parte todavía de `IntegerResolver`.

## 6. Criterios de aceptación

La fase se considerará completada cuando:

- [ ] Existe una implementación de `IntegerResolver`.
- [ ] Está registrada como resolver del tipo `Integer`.
- [ ] Interpreta correctamente números expresados mediante dígitos.
- [ ] Interpreta correctamente números cardinales habituales escritos en español.
- [ ] Puede extraer un entero desde una instrucción completa.
- [ ] Devuelve ausencia de resultado cuando no encuentra un entero interpretable.
- [ ] Dispone de pruebas unitarias.
- [ ] `random.number` declara `max` como parámetro `Integer`.
- [ ] `max` tiene valor por defecto `100`.
- [ ] Una instrucción sin número utiliza `100`.
- [ ] Una instrucción con un número proporciona dicho valor al plugin.
- [ ] El valor aparece en el `ExecutionPlan`.
- [ ] El plugin no contiene lógica de interpretación lingüística.
- [ ] Los plugins existentes continúan funcionando.
- [ ] No se introducen dependencias cloud ni llamadas de red.

## 7. Casos de prueba mínimos

| Entrada | Resultado esperado |
|---|---:|
| `"Dime un número"` | `100` mediante default |
| `"Dime un número menor de 50"` | `50` |
| `"Dime un número menor de 80"` | `80` |
| `"Dime un número menor de ochenta"` | `80` |
| `"Dime un número menor de cien"` | `100` |
| `"Dime un número menor de veinticinco"` | `25` |
| `"Dime un número menor de mil"` | `1000` |
| `"Dime un número aleatorio"` | `100` mediante default |

La batería definitiva deberá incluir casos adicionales de composición de números en español y casos negativos.

## 8. Resultado esperado

Al finalizar esta fase, Nova deberá haber demostrado el primer flujo completo de resolución de parámetros:

```text
Lenguaje natural
      ↓
IntentResolver
      ↓
Plugin seleccionado
      ↓
ParameterResolver
      ↓
IntegerResolver
      ↓
Parámetro tipado
      ↓
ExecutionPlan
      ↓
Plugin
```

`IntegerResolver` será el primer componente concreto que materialice la arquitectura definida en la Fase 1 y establecerá el patrón para futuros resolvers especializados.
