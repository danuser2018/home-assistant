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

## Reglas (Procedimientos — 🟡 Recomendadas — Soft Constraints)
- Registrar cronológicamente todo cambio funcional en el `CHANGELOG.md` del servicio correspondiente bajo la sección `[Sin publicar]`.
- Acompañar cualquier cambio funcional de código con sus respectivos tests de comportamiento.

## Buenas prácticas (Recomendaciones — 🟢 Opcionales)
- Escribir pruebas unitarias que verifiquen el comportamiento y las condiciones de borde en lugar del flujo de ejecución del código.

## Antipatrones (Errores conocidos)
- ❌ Realizar commits directos sobre la rama `main` (violación de Trunk Based Development).
- ❌ Escribir changelogs o descripciones de PR en inglés.

## Referencias
- [CONTRIBUTING.md](file:///home/danuser2018/workspace/home-assistant/CONTRIBUTING.md) (Describe el flujo de Git y Conventional Commits).
