---
name: plugin-domain
description: Reglas de calidad y estilo para la creación de plugins de intenciones y la generación de voz.
---

# plugin-domain

## Objetivo
Garantizar la resolución determinista de comandos de voz y mantener la coherencia de personalidad del asistente local.

## Cuándo aplicar esta skill
- Al añadir, modificar o registrar un plugin de intenciones en el servicio `orchestrator`.
- Al definir la cadena de respuesta de voz que se enviará al sintetizador.

## Responsabilidades
Scoring determinista de intenciones, coincidencia de keywords/regex, descripción de plugins e identidad verbal.

## Invariantes (Leyes — 🔴 Críticas — Hard Constraints)
- **Determinismo en intenciones:** Las derivaciones de voz se resuelven exclusivamente mediante scoring matemático determinista sobre keywords/regex. Queda prohibida la introducción de modelos de lenguaje probabilísticos (LLMs) para el enrutamiento.
- **Identidad verbal de Nova-2:** Las respuestas verbales generadas por cualquier plugin deben seguir obligatoriamente el principio de mínima información: ser directas, impersonales, en español y libres de diálogos conversacionales redundantes.

## Reglas (Procedimientos — 🟡 Recomendadas — Soft Constraints)
- Declarar siempre un campo de descripción conciso y obligatorio en la interfaz pública del plugin para cumplir el contrato del cargador dinámico.

## Buenas prácticas (Recomendaciones — 🟢 Opcionales)
- Diseñar expresiones regulares con pesos equilibrados para evitar conflictos de coincidencia múltiple entre plugins.

## Antipatrones (Errores conocidos)
- ❌ Escribir respuestas conversacionales amigables ("¡Hola!", "De nada, espero ayudarte", "¿Necesitas algo más?").
- ❌ Exponer mensajes con términos técnicos o excepciones de código HTTP en los textos salientes.

## Referencias
- [TONE_GUIDE.md](file:///home/danuser2018/workspace/orchestrator/TONE_GUIDE.md) (Reglas fundamentales de estilo, brevedad y respuestas por categoría).
- [ADR-003: Scoring Determinista de Plugins de Intenciones](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-003.md)
- [ADR-002 (Orchestrator): Alineación de mensajes de error genéricos en plugins](file:///home/danuser2018/workspace/orchestrator/doc/adr/adr-002-alineacion-mensajes-error-plugins.md)
