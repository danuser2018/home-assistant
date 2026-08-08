# Requisitos — Fase 1: Interfaz de resolución de parámetros

**Proyecto:** Nova-2  
**Componente:** Orchestrator  
**Fase:** 1 — Creación de interfaces  
**Estado:** Propuesto

## 1. Contexto

El `Intent Resolver` de Nova selecciona el plugin que mejor representa la intención del usuario y genera un `ExecutionPlan`. La arquitectura existente ya contempla la evolución del plan para incorporar parámetros, por ejemplo:

```text
"Pon el volumen al 30%"
        ↓
VolumePlugin
        ↓
{ "level": 30 }
```

Esta fase introduce la base contractual necesaria para resolver parámetros sin implementar todavía extractores concretos ni modificar el comportamiento funcional de los plugins.

La resolución de parámetros forma parte de la resolución de intenciones y, por tanto, permanece inicialmente dentro del `orchestrator`. No se introduce un servicio independiente para esta capacidad.

La solución debe mantener los principios arquitectónicos existentes de Nova: procesamiento local/offline, resolución determinista y separación entre resolución y ejecución. La documentación existente define `ExecutionPlan` como el contrato entre el resolver y el executor y contempla `parameters` como parte de su evolución. 

## 2. Objetivo

Definir las interfaces mínimas que permitan:

1. Declarar los parámetros que necesita un plugin.
2. Identificar el tipo lógico de cada parámetro.
3. Resolver un parámetro mediante un resolver especializado por tipo.
4. Registrar y localizar resolvers por tipo.
5. Mantener desacoplados el `ParameterResolver` y los resolvers concretos.
6. Preparar la incorporación posterior de `IntegerResolver`, `DateResolver`, `LocationResolver`, etc.

Esta fase **no implementa todavía la interpretación de números, fechas, ubicaciones ni otros tipos**.

---

# 3. Requisitos funcionales

## RF-01 — Declaración de parámetros

El sistema deberá disponer de una abstracción para declarar un parámetro de plugin.

Cada definición de parámetro deberá contemplar, como mínimo:

- nombre del parámetro;
- tipo lógico del parámetro;
- si es obligatorio;
- valor por defecto, cuando exista.

Ejemplo conceptual:

```text
max:
  type: Integer
  required: false
  default: 100
```

## RF-02 — Identificación por tipo

Cada parámetro deberá estar asociado a un tipo lógico que permita seleccionar el resolver adecuado.

El sistema no deberá asociar directamente un parámetro con una implementación concreta de resolver.

Ejemplo:

```text
max → Integer
```

y no:

```text
max → IntegerResolver
```

La relación entre tipo y resolver deberá mantenerse en un registro.

## RF-03 — Interfaz de resolver

Deberá existir una interfaz común para los resolvers de parámetros.

La interfaz deberá permitir recibir el texto de la instrucción y devolver un resultado del tipo solicitado o indicar que no se ha podido resolver.

Conceptualmente:

```python
class ParameterResolver:
    def resolve(text, parameter_definition) -> ...
```

La forma concreta de la interfaz queda pendiente de la implementación.

## RF-04 — Resolver especializado por tipo

El diseño deberá permitir implementar resolvers especializados por tipo sin modificar el `ParameterResolver`.

Ejemplos previstos:

```text
IntegerResolver
DateResolver
LocationResolver
DurationResolver
```

La implementación de cada resolver deberá estar encapsulada en su propio componente.

## RF-05 — Registro de resolvers

Deberá existir un mecanismo de registro que permita asociar un tipo lógico con su resolver.

Conceptualmente:

```text
Integer → IntegerResolver
Date    → DateResolver
Location → LocationResolver
```

El `ParameterResolver` deberá consultar este registro en lugar de contener lógica condicional específica para cada tipo.

## RF-06 — Resolución independiente del plugin

El `ParameterResolver` no deberá contener lógica específica de ningún plugin.

Su responsabilidad será coordinar:

```text
texto
  +
plugin descriptor
  ↓
resolución de parámetros
```

El conocimiento específico del dominio deberá residir en el resolver correspondiente o, cuando la complejidad lo requiera, en un servicio especializado.

## RF-07 — Parámetros opcionales

La definición deberá permitir parámetros opcionales.

Cuando un parámetro opcional no pueda resolverse, el sistema podrá utilizar su valor por defecto.

Ejemplo:

```text
random.number
  max: Integer
  default: 100
```

Una instrucción como:

```text
"Dime un número"
```

podrá generar:

```json
{
  "max": 100
}
```

## RF-08 — Parámetros obligatorios no resueltos

La interfaz deberá permitir distinguir entre:

- parámetro resuelto;
- parámetro no resuelto;
- parámetro opcional con valor por defecto;
- parámetro obligatorio sin valor disponible.

El comportamiento conversacional ante un parámetro obligatorio no resuelto se definirá en una fase posterior.

## RF-09 — Resultado de resolución

El diseño deberá permitir representar el resultado de una resolución sin obligar al resolver a devolver directamente un `ExecutionPlan`.

La resolución de parámetros deberá producir datos que posteriormente puedan incorporarse al `ExecutionPlan`.

## RF-10 — Evolución del ExecutionPlan

La solución deberá ser compatible con la evolución prevista del `ExecutionPlan` para incorporar parámetros.

El resultado final esperado será conceptualmente:

```json
{
  "plugin": "random.number",
  "parameters": {
    "max": 100
  }
}
```

La documentación arquitectónica existente ya contempla `parameters` como parte del modelo objetivo del plan. 

---

# 4. Requisitos no funcionales

## RNF-01 — Determinismo

La interfaz deberá permitir implementaciones deterministas.

La resolución de parámetros del core de Nova no deberá requerir LLMs ni servicios cloud. La arquitectura de Nova establece como invariante la resolución local y determinista de intenciones. 

## RNF-02 — Local-first

La implementación inicial deberá funcionar completamente en local y offline.

No deberá introducir dependencias de servicios externos para la infraestructura básica de resolución.

## RNF-03 — Bajo acoplamiento

El `ParameterResolver` no deberá conocer:

- la implementación concreta de los plugins;
- la lógica interna de los resolvers;
- los detalles de los servicios de dominio externos.

Deberá depender únicamente de interfaces/contratos.

## RNF-04 — Extensibilidad

Añadir un nuevo tipo de parámetro deberá requerir únicamente:

1. definir el tipo;
2. implementar su resolver;
3. registrarlo.

No deberá ser necesario modificar el `ParameterResolver`.

## RNF-05 — Testabilidad

Cada componente deberá poder probarse de forma aislada:

- definición de parámetros;
- registro de resolvers;
- `ParameterResolver`;
- resolvers concretos.

Esto es coherente con la separación existente entre resolución y ejecución, cuyo objetivo incluye facilitar pruebas unitarias independientes. 

## RNF-06 — Compatibilidad

La introducción de las interfaces no deberá alterar el comportamiento actual de Nova.

Los plugins existentes que todavía no declaren parámetros deberán continuar funcionando.

La documentación de arquitectura establece como requisito mantener compatibilidad funcional durante la evolución de la separación entre resolver y executor. 

## RNF-07 — Rendimiento

La nueva capa no deberá introducir una penalización significativa en la resolución de intenciones.

Deberá mantenerse el objetivo arquitectónico actual de baja latencia para la resolución local de intenciones.

## RNF-08 — Simplicidad

La primera implementación deberá evitar abstracciones innecesarias.

No se introducirán en esta fase:

- composición entre resolvers;
- NLP generalista;
- LLMs;
- servicios externos para tipos simples;
- resolución distribuida;
- persistencia específica para parámetros.

## RNF-09 — Separación de responsabilidades

La arquitectura deberá conservar la separación:

```text
Intent Resolver
      ↓
Parameter Resolver
      ↓
ExecutionPlan
      ↓
Plugin Executor
      ↓
Plugin
```

El executor no deberá interpretar lenguaje natural. La documentación existente define explícitamente esta frontera: el resolver determina qué quiere hacer el usuario y el executor ejecuta el plan recibido. 

## RNF-10 — Evolución a servicios especializados

El diseño deberá permitir que, en fases posteriores, un resolver pueda delegar la resolución compleja de un dominio a un servicio especializado.

Ejemplo futuro:

```text
LocationResolver
      ↓
location-service
      ↓
coordenadas
```

Esta posibilidad no forma parte de la implementación de la fase 1, pero la interfaz no deberá impedirla.

---

# 5. Fuera de alcance

Esta fase no incluye:

- implementación de `IntegerResolver`;
- interpretación de números escritos en español;
- implementación de `DateResolver`;
- implementación de `LocationResolver`;
- creación de `location-service`;
- modificación funcional del plugin `random-number`;
- modificación de `ExecutionPlan` más allá de lo estrictamente necesario para mantener compatibilidad;
- cambios en `Plugin Executor`;
- incorporación de LLMs;
- composición entre resolvers.

---

# 6. Criterios de aceptación

La fase se considerará completada cuando:

- [ ] Existe una interfaz/contrato para definir parámetros de plugin.
- [ ] Un parámetro puede declarar nombre, tipo, obligatoriedad y valor por defecto.
- [ ] Existe una interfaz común para resolvers.
- [ ] Existe un registro tipo → resolver.
- [ ] `ParameterResolver` utiliza el registro y no contiene lógica específica por tipo.
- [ ] Es posible registrar un nuevo tipo sin modificar `ParameterResolver`.
- [ ] Los componentes principales tienen pruebas unitarias.
- [ ] Los plugins existentes siguen funcionando sin declarar parámetros.
- [ ] No se introduce ninguna dependencia cloud.
- [ ] No se introduce lógica de composición entre resolvers.
- [ ] La arquitectura queda preparada para implementar posteriormente `IntegerResolver`.

---

# 7. Resultado esperado de la fase

Al finalizar esta fase Nova deberá disponer únicamente de la **infraestructura contractual**.

Todavía no será capaz de interpretar:

```text
"Dime un número menor de cien"
```

pero deberá estar preparada para que la siguiente fase incorpore:

```text
IntegerResolver
        ↓
"cien"
        ↓
100
```

y posteriormente:

```text
ParameterResolver
        ↓
random.number
        ↓
max = 100
        ↓
ExecutionPlan
```

La primera implementación funcional de resolución de parámetros será el siguiente paso, utilizando el plugin de número aleatorio como caso de validación.
