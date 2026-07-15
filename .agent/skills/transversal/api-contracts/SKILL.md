---
name: api-contracts
description: Reglas transversales para el diseño, versionado y consistencia de las APIs del ecosistema.
---

# api-contracts

## Objetivo
Garantizar la consistencia, estabilidad y compatibilidad de las interfaces públicas de comunicación en todo el ecosistema.

## Cuándo aplicar esta skill
- Al añadir, modificar o eliminar endpoints REST en cualquier microservicio.
- Al diseñar esquemas de datos de entrada/salida públicos.

## Responsabilidades
Versionado de APIs, nomenclatura de recursos, esquemas de error comunes y consistencia en cabeceras.

## Invariantes (Leyes — 🔴 Críticas — Hard Constraints)
- **Invariabilidad del formato de error:** Todas las respuestas de error en la API pública de cualquier servicio deben seguir el mismo esquema estructurado común (p. ej., RFC 7807 o similar).
- **Retrocompatibilidad obligatoria:** Queda prohibido realizar cambios en el nombre de campos o tipos en el JSON de salida de APIs que rompan consumidores existentes.

## Reglas (Procedimientos — 🟡 Recomendadas — Soft Constraints)
- Actualizar la especificación de OpenAPI de manera inmediata tras realizar cualquier cambio en endpoints.
- Mantener el versionado explícito en la ruta de las APIs (p. ej., `/api/v1/`).

## Buenas prácticas (Recomendaciones — 🟢 Opcionales)
- Usar paginación consistente en listados públicos para evitar sobrecargas de memoria en consultas grandes.

## Antipatrones (Errores conocidos)
- ❌ Retornar excepciones técnicas de base de datos o trazas de código en el payload de las respuestas HTTP.
- ❌ Mezclar estilos de nomenclatura en endpoints (ej. camelCase y snake_case combinados en la misma interfaz).

## Referencias
- [ADR-004: Estandarización de APIs REST en el Ecosistema](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-004.md) (Establece el protocolo HTTP unificado y la nomenclatura común).
- [ADR-001 (Orchestrator): Adición de campo timestamp opcional en UserRequest](file:///home/danuser2018/workspace/orchestrator/doc/adr/adr-001-adicion-timestamp-userrequest.md) (Define la adición del campo timestamp en UserRequest manteniendo retrocompatibilidad).
- [ADR-002 (Orchestrator): Alineación mensajes de error en los plugins](file:///home/danuser2018/workspace/orchestrator/doc/adr/adr-002-alineacion-mensajes-error-plugins.md) (Alinea los mensajes de error que devuelven los plugins).
- [ADR-014: Separación de Responsabilidades en el Orquestador](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-014-refactorizacion-orquestador.md).
- [ADR-015: Consolidación del Modelo ExecutionPlan y Eliminación del Endpoint Legado](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-015-consolidacion-execution-plan.md).
