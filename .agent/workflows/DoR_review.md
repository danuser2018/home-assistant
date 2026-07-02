---
name: DoR_review
description: Workflow para realizar la revisión de preparación para el desarrollo (DoR) de un refinamiento de feature, detectando discrepancias de formato y de arquitectura.
---

# Workflow: Revisión de Refinamiento (DoR)

Este workflow guía al asistente de IA en la auditoría exhaustiva de un documento de refinamiento de feature frente a los estándares del ecosistema Nova-2 antes de proceder con el desarrollo.

## Objetivo
Detectar discrepancias en la estructura de la especificación o inconsistencias arquitectónicas con respecto a la documentación actual y los ADRs vigentes, sin alterar el archivo original, generando un informe formal de discrepancias en formato de artefacto.

## Parámetros de Entrada
- **Documento descriptivo inicial de la feature:** Documento inicial en formato markdown que explica a alto nivel la funcionalidad o cambio que se quiere implementar.
- **Documento de refinamiento a auditar**: Ruta del archivo Markdown del refinamiento (ej. `docs/refinements/refinement-mi-feature.md`).

---

## Pasos del Workflow

### Paso 1: Lectura y Carga de Contexto
1. Leer el documento de refinamiento indicado en la entrada.
2. Cargar las skills y documentación técnica de referencia del repositorio:
   - Skill `feature-refinement` (para validar el formato de las 7 secciones obligatorias).
   - Skill `service-responsibilities` (para validar fronteras e interacciones de servicios).
   - Skill `development-workflow` (para validar decisiones de implementación).
   - Skill `api-contracts` (para validar decisiones referentes a contratos de API).
   - Skill `architecture-decisions` (para validar decisiones de arquitectura).
   - Skill `system-deployment` (para validar todo lo relacionado con la configuración y puesta en producción del cambio).	
   - Skills de dominio que sean relevantes para el cambio.
   - Catálogo de servicios (`docs/services.md`), arquitectura (`docs/architecture.md`) y el directorio de ADRs (`docs/adr/`).

### Paso 2: Auditoría de Formato (Discrepancias de Estructura)
Evaluar el contenido del documento buscando:
- Ausencia de cualquiera de las 7 secciones obligatorias descritas en la skill `feature-refinement`.
- Campos vacíos, marcadores de posición (`TODO`, `[Completar]`) o explicaciones vagas.
- Incumplimiento de la regla de **Aislamiento Lingüístico**: el documento en español, pero los identificadores técnicos, endpoints, variables y código de ejemplo estrictamente en inglés.

### Paso 3: Auditoría de Coherencia Arquitectónica
Contrastar la especificación técnica propuesta con el estado real del ecosistema buscando:
- Fuga de lógica de negocio o acoplamiento no permitido entre microservicios (por ejemplo, base de datos expuesta, llamadas circulares).
- Alteraciones de interfaces de comunicación y contratos (`api-contracts`) que no hayan sido previstos o justificados.
- Incompatibilidades con la arquitectura o con las decisiones documentadas en los ADRs vigentes en el directorio `docs/adr/`.
- Falta de triggers o recomendaciones de creación de un nuevo ADR si la feature introduce patrones arquitectónicos o cambios en contratos de comunicación globales.
- Discrepancia entre los criterios de aceptación definidos y el objetivo descrito en el documento inicial de la feature. 
- Ausencia de algún criterio de aceptación necesario para definir el objetivo descrito en el documento inicial de la feature.
- Dudas o preguntas abiertas que queden pendientes de resolver.
- Discrepancias entre la solución técnica propuesta y los criterios de aceptación.
- Solución técnica coherente y autocontenida: Las tareas no se contradicen unas a otras. No hay dudas abiertas.
- Tareas técnicas demasiado complejas como para ser abordadas en un solo commit.
- Cambios no justificados en APIs o contratos.
- Falta de mecanismos de despliegue adecuados para poner en producción el cambio.
- Cambios en documentación necesarios no identificados.
- Violaciones explícitas de los invariantes/leyes, reglas/procedimientos o buenas prácticas/recomendaciones expresadas en las skills.

### Paso 4: Generación del Reporte de Discrepancias (DoR Report)
**IMPORTANTE:** El workflow nunca debe modificar el documento de refinamiento original.
El asistente debe generar un artefacto de reporte en la conversación con la siguiente estructura:

````markdown
# Reporte de Revisión de Refinamiento (DoR): [Nombre de la Feature]

- **Documento Auditado**: [Nombre y ruta del archivo de refinamiento]
- **Fecha de Auditoría**: [AAAA-MM-DD]
- **Estado de Preparación**: [Listo para Desarrollo / Requiere Correcciones]

## Resumen de la Auditoría
[Breve párrafo con el resultado de la revisión].

## Discrepancias Encontradas y Soluciones Propuestas

| ID | Categoría | Descripción de la Discrepancia | Solución Propuesta |
| :--- | :--- | :--- | :--- |
| D-01 | [Formato / Arquitectura] | [Explicación detallada del hallazgo y qué regla o skill incumple] | [Propuesta de cambio técnico o aclaración requerida] |
| D-02 | [Formato / Arquitectura] | [Descripción] | [Propuesta] |

## Conclusión y Próximos Pasos
- Si hay discrepancias de tipo **Arquitectura** o de **Formato crítico**, el estado debe ser "Requiere Correcciones" y se debe solicitar al desarrollador corregir el archivo antes de continuar.
- Si no hay discrepancias críticas, el estado es "Listo para Desarrollo".
````

