---
name: development-workflow
description: Reglas transversales de calidad de código, documentación y ciclo de vida de cambios en el ecosistema Nova-2.
---

# development-workflow

## Objetivo
Proteger la coherencia histórica del código, su legibilidad y la estabilidad de las interfaces de comunicación en el ecosistema.

## Cuándo aplicar esta skill
- Al realizar cualquier modificación de código en cualquier repositorio del ecosistema.
- Al preparar commits, Pull Requests o preparar la versión de un release.

## Responsabilidades
Ciclo de vida de Git, versionado, tipado, documentación e internacionalización.

## Invariantes (Leyes — 🔴 Críticas — Hard Constraints)
- **Aislamiento lingüístico:** Todo elemento de código (código fuente, variables, base de datos, nombres de endpoints, logs y comentarios) se escribe estrictamente en inglés. Toda interacción externa (documentación técnica, changelogs, commits y PRs) se redacta en español.
- **Sincronización de versión:** La versión declarada en `pyproject.toml` (campo `version`) debe estar siempre sincronizada con la última versión publicada en `CHANGELOG.md`. Cualquier bump de versión en el CHANGELOG exige el bump correspondiente en `pyproject.toml` en el mismo commit.

## Reglas (Procedimientos — 🟡 Recomendadas — Soft Constraints)
- Registrar cronológicamente todo cambio funcional en el `CHANGELOG.md` del servicio correspondiente bajo la sección `[Sin publicar]`.
- Acompañar cualquier cambio funcional de código con sus respectivos tests de comportamiento.

## Buenas prácticas (Recomendaciones — 🟢 Opcionales)
- Escribir pruebas unitarias que verifiquen el comportamiento y las condiciones de borde en lugar del flujo de ejecución del código.

## Antipatrones (Errores conocidos)
- ❌ Realizar commits directos sobre la rama `main` (violación de Trunk Based Development).
- ❌ Escribir changelogs o descripciones de PR en inglés.
- ❌ Actualizar el `CHANGELOG.md` con una nueva versión sin actualizar el campo `version` en `pyproject.toml` al mismo tiempo — produce una desincronización que confunde a los consumidores de la librería sobre qué API corresponde a cada versión instalada.

## Referencias
- [CONTRIBUTING.md](file:///home/danuser2018/workspace/home-assistant/CONTRIBUTING.md) (Describe el flujo de Git y Conventional Commits).
- [ADR-018: Creación de la Librería de Abstracción nova-event-bus](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-018-libreria-nova-event-bus.md).
- [event-driven-architecture](file:///home/danuser2018/workspace/home-assistant/.agent/skills/transversal/event-driven-architecture/SKILL.md).
