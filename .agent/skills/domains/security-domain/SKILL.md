---
name: security-domain
description: Reglas de arquitectura, gobernanza y seguridad para la autorización User -> Service en el ecosistema Nova.
---

# security-domain

## Objetivo
Garantizar la evaluación determinista del riesgo de las acciones de los usuarios y la emisión/verificación de tokens de autorización criptográficos antes de ejecutar cualquier plan de acción.

## Cuándo aplicar esta skill
- Al implementar o modificar endpoints y motores de riesgo en `security-service`.
- Al registrar acciones y políticas de riesgo desde plugins en `orchestrator` o catálogos en `host-service`.
- Al coordinar la autorización de planes de ejecución en `interaction-manager`.
- Al verificar tokens de autorización antes de ejecutar acciones en `orchestrator`.

## Responsabilidades
Registro de acciones y catálogos de comandos host, gestión de políticas por canal (`voice`, `cli`, `api`), evaluación atómica de riesgo y generación/validación de tokens criptográficos HMAC-SHA256 de único uso.

## Invariantes (Leyes — 🔴 Críticas — Hard Constraints)
- **Fail Closed Absoluto:** Ante la falta o invalidez de datos de autorización, canal no registrado o política no calculable, la decisión por defecto es siempre `DENY`.
- **Autorización Atómica por Plan:** Un `ExecutionPlan` no admite ejecuciones parciales; si falla un solo paso, todo el plan se deniega y se emiten cero tokens.
- **Aislamiento del Mecanismo de Ejecución:** La seguridad opera sobre abstracciones de riesgo y canales, sin acoplarse al hardware ni al código ejecutable del plugin.
- **Single-Use Tokens:** Los tokens de autorización están acotados a `execution_id` y `action_id` y vencen tras un tiempo límite (`expires_at`).

## Reglas (Procedimientos — 🟡 Recomendadas — Soft Constraints)
- Registrar todas las acciones de plugins al iniciar el `orchestrator` mediante `POST /v1/security/actions/register`.
- Publicar el catálogo de comandos host al iniciar el `host-service` mediante `POST /v1/security/tables/host_commands`.
- Requerir y validar tokens de autorización en `Orchestrator` devolviendo HTTP 403 Forbidden en caso de token ausente, alterado o expirado.

## Antipatrones (Errores conocidos)
- ❌ Permitir ejecuciones parciales de planes de acción cuando una de las acciones es denegada.
- ❌ Ignorar fallos de red al comunicarse con `security-service` (si `security-service` no responde, la acción debe abortarse inmediatamente).
- ❌ Reutilizar tokens de autorización para múltiples ejecuciones o acciones distintas.

## Referencias
- [ADR-025: Autorización User → Service (Security Service MVP)](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-025-security-service-user-authorization.md)
- [security_service_user_authorization_refinement.md](file:///home/danuser2018/workspace/home-assistant/docs/refinement/security_service_user_authorization_refinement.md)
