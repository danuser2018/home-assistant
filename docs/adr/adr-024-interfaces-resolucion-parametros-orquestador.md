# ADR-024: Arquitectura e Interfaces de Resolución de Parámetros en Orchestrator

## Fecha
08-08-2026

## Estado
Aceptado

## Contexto
El servicio `orchestrator` de Nova-2 clasifica la intención del usuario y genera un `ExecutionPlanStep` que incluye un campo `parameters: Dict[str, Any]`. Sin embargo, hasta la fecha no existía un contrato formal para declarar qué parámetros espera cada plugin ni un mecanismo desacoplado para extraer dichos parámetros a partir del lenguaje natural.

Para permitir la evolución hacia tipos complejos (números, fechas, duraciones, ubicaciones) sin romper la modularidad ni acoplar el orquestador a lógica específica por plugin, se requiere una arquitectura extensible basada en registros e interfaces abstractas.

## Decisión
Se decide implementar en el servicio `orchestrator` la infraestructura contractual de resolución de parámetros bajo las siguientes directivas:

1. **Declaración de Parámetros en Plugins**: La abstracción `Plugin` en `plugins/base.py` expondrá una propiedad `parameters` que retorna una lista de `ParameterDefinition` (`name`, `type`, `required`, `default`).
2. **Interfaz Común Base**: Definir la clase abstracta `BaseParameterResolver` que establece el contrato que deben cumplir los extractores especializados por tipo lógico (`target_type`, `resolve()`).
3. **Registro por Tipo Lógico**: Crear la clase `ParameterResolverRegistry` encargada de asociar tipos lógicos (ej. `Integer`, `Date`) con sus implementaciones concretas de resolver.
4. **Motor Desacoplado**: Introducir `ParameterResolverEngine` para coordinar la resolución de parámetros durante la construcción del `ExecutionPlanStep` en `ExecutionPlanner`, abstrayendo la selección de resolvers y el manejo de valores por defecto.
5. **Separación de Fases**: En esta primera fase no se implementan extractores concretos (`IntegerResolver`, `DateResolver`, etc.), sentando únicamente las bases contractuales y garantizando retrocompatibilidad total con plugins existentes.

## Consecuencias
* **(+) Bajo Acoplamiento**: `ExecutionPlanner` no contiene sentencias condicionales (`if/else`) para cada tipo de parámetro.
* **(+) Extensibilidad**: Añadir un nuevo tipo de parámetro solo requiere definir el tipo, implementar su resolver derivado de `BaseParameterResolver` y registrarlo en `ParameterResolverRegistry`.
* **(+) Determinismo y Procesamiento Local**: Se preserva el invariante de resolución determinista y local sin dependencias externas ni servicios cloud.
* **(+) Retrocompatibilidad**: Los plugins existentes siguen funcionando sin modificaciones al heredar la lista vacía de parámetros por defecto.
