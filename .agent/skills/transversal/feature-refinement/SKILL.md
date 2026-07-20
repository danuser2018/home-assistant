---
name: feature-refinement
description: Reglas y condiciones para el refinamiento estructurado de características a partir de documentos descriptivos en el ecosistema Nova-2.
---

# feature-refinement

## Objetivo
Garantizar la transición ordenada y sin fricciones de requisitos de alto nivel (prosa descriptiva) a especificaciones técnicas implementables, alineadas con las responsabilidades de los servicios y la arquitectura del ecosistema.

## Cuándo aplicar esta skill
- Al recibir una solicitud para refinar una nueva funcionalidad a partir de un archivo Markdown (`.md`) descriptivo o una especificación de producto (PRD).

## Responsabilidades
Traducir la intención del usuario a un diseño técnico de componentes, contratos de comunicación, casos de prueba y un plan secuencial de tareas de desarrollo.

## Invariantes (Leyes — 🔴 Críticas — Hard Constraints)
- **Solo planificación:** No modificar código, configuraciones o documentación 
en esta fase, aparte de la generación del documento obligatorio de refinamiento. Todas las modificaciones detectadas en código, configuración o documentación (incluida la generación de nuevos ADRs se deben añadir como tareas a realizar dentro del documento de refinamiento).
- **Aislamiento lingüístico en especificaciones:** El documento de refinamiento se redacta en español. No obstante, todos los identificadores técnicos (nombres de endpoints, campos JSON, variables, nombres de eventos y código de ejemplo) dentro de la especificación deben escribirse estrictamente en inglés.
- **Trazabilidad de origen:** Todo refinamiento debe enlazar explícitamente al archivo Markdown descriptivo original que le dio origen.
- **Validación de fronteras:** Queda estrictamente prohibido refinar una feature acoplando lógica de negocio directa entre servicios de distintas responsabilidades (ej. lógica de base de datos de identidad expuesta en el orquestador). Cada cambio de contrato debe respetar `service-responsibilities`.

## Reglas (Procedimientos — 🟡 Recomendadas — Soft Constraints)
- **Documento de Refinamiento Obligatorio:** Se debe generar un documento de refinamiento con las siguientes secciones obligatorias:
  1.  **Resumen y Contexto de Negocio:** Objetivo principal y actores.
  2.  **Análisis de Servicios e Impacto:** Tabla detallando qué servicios del ecosistema se ven afectados y tipo de cambio (Modificar/Nuevo/Ninguno).
  3.  **Especificación de Comportamiento:** Criterios de Aceptación estructurados en formato Gherkin (`Dado / Cuando / Entonces`).
  4.  **Diseño Técnico y Contratos:** Definición de payloads, esquemas e interfaces en inglés.
  5.  **Casos de Borde y Manejo de Errores:** Comportamiento ante fallos comunes (timeouts, entradas vacías, desconexión).
  6.  **Estrategia de Testing:** Clasificación de tests requeridos (unitarios, integración, E2E).
  7.  **Plan de Implementación:** Checklist detallado con tareas atómicas e incrementales.
- **Trigger de ADR:** Si el análisis de impacto muestra cambios en contratos públicos (`api-contracts`) o patrones de comunicación (`communication-patterns`), se debe disparar la skill `architecture-decisions` para evaluar la necesidad de crear un nuevo ADR.

## Buenas prácticas (Recomendaciones — 🟢 Opcionales)
- Almacenar los documentos de refinamiento bajo el directorio `docs/refinement/` del repositorio afectado para mantener un histórico de evolución de features.
- Si se trata de un cambio que afecta a más de un repositorio almacenar en `home-assistant/docs/refinement`.
- Asegurar que el checklist de implementación desglose tareas con un esfuerzo estimado inferior a media jornada de trabajo para facilitar commits atómicos.
- Ver [first_implementation_refinement.md](file:///home/danuser2018/workspace/hid-daemon/doc/refinements/first_implementation_refinement.md) como referencia ejemplar de especificación para nuevos daemons de hardware.

## Antipatrones (Errores conocidos)
- ❌ Definir criterios de aceptación ambiguos o no verificables (ej. "el sistema debe responder de forma rápida").
- ❌ Ignorar el impacto colateral en otros servicios del ecosistema durante la fase de análisis inicial.

## Referencias
- [development-workflow](file:///home/danuser2018/workspace/home-assistant/.agent/skills/transversal/development-workflow/SKILL.md) (Define el flujo de Git, Conventional Commits y la política lingüística general).
- [service-responsibilities](file:///home/danuser2018/workspace/home-assistant/.agent/skills/transversal/service-responsibilities/SKILL.md) (Define los límites de responsabilidad de cada servicio del ecosistema).
- [architecture-decisions](file:///home/danuser2018/workspace/home-assistant/.agent/skills/transversal/architecture-decisions/SKILL.md) (Condiciones para la creación de ADRs).
- [ADR-020: Integración del CLI novactl](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-020-integracion-novactl.md).
