---
name: system-domain
description: Reglas sobre el registro de capacidades dinámicas del asistente, metadatos y estado global del sistema.
---

# system-domain

## Objetivo
Proteger el registro y descubrimiento de capacidades y el control del estado y configuración global de Nova-2.

## Cuándo aplicar esta skill
- Al registrar nuevas capacidades, servicios o plugins en el sistema.
- Al alterar los metadatos de Nova-2 (versión, autor, capacidades del asistente).

## Responsabilidades
Registro y estado de servicios, capacidades de intenciones del orquestador, metadatos y feature flags globales.

## Invariantes (Leyes — 🔴 Críticas — Hard Constraints)
- **Consistencia de metadatos:** Toda la información sobre qué sabe Nova-2 de sí misma (nombre del asistente, versión activa, autor) reside centralmente en `system-service`.
- **Inmutabilidad del registro:** Ningún servicio debe asumir que una capacidad está disponible sin antes consultar su estado de registro en el servicio del sistema.

## Reglas (Procedimientos — 🟡 Recomendadas — Soft Constraints)
- Enviar un payload de inicialización con el esquema de capacidades al endpoint de registro global (`POST /system/capabilities`) durante el arranque del servicio correspondiente.

## Buenas prácticas (Recomendaciones — 🟢 Opcionales)
- Utilizar feature flags dinámicas en el payload de capacidades para controlar de manera remota qué intenciones puede resolver el orquestador en caliente.

## Antipatrones (Errores conocidos)
- ❌ Permitir que el `orchestrator` asuma las capacidades disponibles de forma estática en el código sin consultarlas al `system-service`.
- ❌ Modificar los datos de autoría o versión de Nova en archivos locales distribuidos.

## Referencias
- [system-service/README.md](file:///home/danuser2018/workspace/system-service/README.md) (Registros REST de información del sistema de metadatos de Nova).
- [ADR-003 (Orchestrator): Exclusión de FallbackPlugin del registro automático de capacidades](file:///home/danuser2018/workspace/orchestrator/doc/adr/adr-003-exclusion-fallbackplugin-registro-capacidades.md)
- [ADR-019: Integración de Context Service](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-019-integracion-context-service.md).

