---
name: DoD_review
description: Workflow para realizar la revisión de Definition of Done (DoD) de una feature implementada, auditando calidad, trazabilidad, testing y consistencia.
---

# Workflow: Revisión de Definition of Done (DoD)

Este workflow guía al asistente de IA en la auditoría de calidad de una feature tras su implementación, asegurando que cumple con los estándares del ecosistema Nova-2 antes de considerarse finalizada.

## Objetivo
Actuar como un auditor de calidad independiente para verificar que la implementación se ajusta a la especificación de refinamiento aprobada y que el ecosistema permanece consistente y robusto tras los cambios, sin modificar código fuente, especificaciones ni documentación, y generando al final un informe formal de revisión (DoD Report).

## Parámetros de Entrada
- **Documento de Refinamiento**: Ruta al archivo de especificación/refinamiento (ej. `docs/refinements/refinement-mi-feature.md`).
- **Código Implementado**: Cambios realizados en el workspace o repositorio actual.
- **Opcional**: Lista de archivos modificados, commit específico o rama a auditar.

---

## Pasos del Workflow

### Paso 1: Lectura y Carga de Contexto
1. Leer el documento de refinamiento indicado en la entrada.
2. Cargar el código implementado (o el diff correspondiente a la rama/commit).
3. Cargar las skills transversales y de dominio relevantes, la documentación técnica del repositorio (`docs/services.md`, `docs/architecture.md`) y los ADRs vigentes en el directorio `docs/adr/`.

### Paso 2: Revisión de Trazabilidad
Comparar el diseño aprobado en el documento de refinamiento con la implementación realizada. Verificar:
- Que todos los criterios de aceptación y escenarios Gherkin del refinamiento hayan sido completamente implementados.
- Que no existan funcionalidades añadidas que no figuren en la especificación de refinamiento original.
- Que no hayan quedado requisitos o tareas definidas sin implementar.
- Que cualquier desviación funcional o técnica detectada respecto al refinamiento esté debidamente documentada y justificada.

### Paso 3: Code Review (Revisión Técnica)
Auditar la calidad técnica de los cambios utilizando las directrices de las skills transversales y de dominio:
- **Diseño Arquitectónico**: Validar la consistencia con la arquitectura del sistema y los ADRs vigentes.
- **Límites de Servicio**: Comprobar que no haya fugas de lógica entre microservicios o acoplamiento innecesario (`service-responsibilities`).
- **Calidad de Código**: Evaluar legibilidad, limpieza de variables, manejo de errores, code smells, complejidad ciclomática excesiva y mantenibilidad general.

### Paso 4: Revisión de Testing
Evaluar la suficiencia de la estrategia de pruebas implementada para acompañar la feature:
- Comprobar la existencia de tests unitarios y de integración adecuados.
- Verificar la cobertura de los criterios de aceptación de happy path descritos en el refinamiento, así como para casos de borde, entradas inválidas y escenarios de error.
- Detectar cualquier ausencia de pruebas o cobertura insuficiente para evitar regresiones.

### Paso 5: Revisión de Documentación y Consistencia
Validar que el ecosistema documental se mantenga coherente con la implementación:
- Confirmar que se han actualizado los contratos de comunicación y endpoints modificados (`api-contracts`).
- Evaluar la necesidad de crear nuevos ADRs si el cambio impacta a decisiones estructurales (`architecture-decisions`).
- Verificar la consistencia cruzada entre repositorios en caso de que la feature afecte a más de un servicio del ecosistema.

### Paso 6: Generación del DoD Report
**IMPORTANTE:** El workflow nunca debe modificar el código fuente, la documentación ni el refinamiento original. Su salida obligatoria es un reporte de revisión generado en formato de artefacto en la conversación con la siguiente estructura:

````markdown
# Reporte de Revisión DoD: [Nombre de la Feature]

- **Documento de Refinamiento**: [Nombre y ruta del archivo de refinamiento]
- **Fecha de Auditoría**: [AAAA-MM-DD]
- **Estado de la Feature**: [Aprobada / Requiere Correcciones]

## Resumen de la Auditoría
[Breve párrafo con el resultado de la revisión].

## Discrepancias Encontradas y Soluciones Propuestas

| ID | Categoría | Descripción de la Discrepancia | Solución Propuesta |
| :--- | :--- | :--- | :--- |
| D-01 | [Trazabilidad / Code Review / Testing / Documentación] | [Detalle de la discrepancia encontrada y qué directriz o criterio del DoD incumple] | [Acción correctora técnica propuesta] |
| D-02 | [Trazabilidad / Code Review / Testing / Documentación] | [Descripción] | [Propuesta] |

## Conclusión y Próximos Pasos
- Si hay discrepancias de tipo **Trazabilidad**, **Code Review** o **Testing** crítico, el estado debe ser "Requiere Correcciones" y se debe solicitar al desarrollador corregir la implementación antes de dar la feature por finalizada.
- Si no hay discrepancias críticas, el estado es "Aprobada" y se da por completada la feature.
````

---

## Referencias
- [development-workflow](file:///home/danuser2018/workspace/home-assistant/.agent/skills/transversal/development-workflow/SKILL.md)
- [service-responsibilities](file:///home/danuser2018/workspace/home-assistant/.agent/skills/transversal/service-responsibilities/SKILL.md)
- [api-contracts](file:///home/danuser2018/workspace/home-assistant/.agent/skills/transversal/api-contracts/SKILL.md)
- [architecture-decisions](file:///home/danuser2018/workspace/home-assistant/.agent/skills/transversal/architecture-decisions/SKILL.md)
