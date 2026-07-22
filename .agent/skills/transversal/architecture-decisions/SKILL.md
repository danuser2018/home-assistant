---
name: architecture-decisions
description: Reglas y condiciones para la documentación formal de decisiones arquitectónicas mediante ADRs.
---

# architecture-decisions

## Objetivo
Proteger la coherencia arquitectónica a largo plazo impidiendo decisiones tácticas no justificadas que alteren el diseño general.

## Cuándo aplicar esta skill
- Al planificar una refactorización de gran envergadura.
- Al detectar cambios en las responsabilidades de servicios, contratos o flujos.

## Responsabilidades
Evaluar el impacto estructural de cambios e indicar la necesidad de documentarlos de manera formal.

## Invariantes (Leyes — 🔴 Críticas — Hard Constraints)
- **Trazabilidad de diseño:** Toda decisión arquitectónica crítica que afecte a más de un repositorio debe documentarse en un Architectural Decision Record (ADR).
- **Resolución de conflictos de decisión:** Si dos ADRs entran en conflicto y ambos están en estado Aceptado, el que posea la fecha de registro posterior (especificada en el campo `Fecha` con formato `DD-MM-YYYY`) es el que prevalece y aplica.

## Reglas (Procedimientos — 🟡 Recomendadas — Soft Constraints)
- Proponer obligatoriamente al desarrollador la creación de un nuevo ADR si el cambio propuesto:
    - Modifica responsabilidades o límites de los servicios (`service-responsibilities`).
    - Modifica contratos públicos o APIs de comunicación del sistema (`api-contracts`).
    - Introduce un nuevo patrón de diseño o arquitectura estructural (p. ej., migrar de filesystem a Redis).
    - Altera los patrones de comunicación física o red entre componentes (`communication-patterns`).
- **Sincronización de referencias en Skills:** Al crear o actualizar un ADR:
    - Identificar todas las skills transversales o de dominio que se vean afectadas por la decisión e incluir una referencia explícita al nuevo ADR en su sección de `Referencias`.
    - Si el nuevo ADR entra en conflicto o reemplaza la validez de un ADR anterior (según la regla de resolución por fecha posterior), eliminar de manera segura la referencia al ADR antiguo de todas las skills afectadas y sustituirla por el nuevo registro.

## Buenas prácticas (Recomendaciones — 🟢 Opcionales)
- Indexar y almacenar los ADRs en formato Markdown en un directorio centralizado ([docs/adr/](file:///home/danuser2018/workspace/home-assistant/docs/adr/)) con nomenclatura secuencial.

## Antipatrones (Errores conocidos)
- ❌ Crear ADRs para cambios de implementación local o refactorización interna de un único método que no impacte a la integración global.
- ❌ Implementar soluciones arquitectónicas alternativas sin consultar previamente los ADRs vigentes sobre esa decisión.

## Referencias
- [architecture.md](file:///home/danuser2018/workspace/home-assistant/docs/architecture.md) (Contiene las decisiones de diseño clave iniciales).
- [Directorio de ADRs](file:///home/danuser2018/workspace/home-assistant/docs/adr/) (Contiene todos los Architectural Decision Records registrados, incluido [ADR-021](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-021-deteccion-habla-eventos-mic-daemon.md)).
