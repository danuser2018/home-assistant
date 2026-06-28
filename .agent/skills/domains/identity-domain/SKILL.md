---
name: identity-domain
description: Reglas de negocio para la gestión, privacidad y límites de la información personal del usuario.
---

# identity-domain

## Objetivo
Garantizar la confidencialidad, privacidad y el control centralizado de los datos privados del usuario.

## Cuándo aplicar esta skill
- Al modificar o añadir endpoints en `identity-service`.
- Al implementar nuevos plugins en `orchestrator` que requieran interactuar con información del usuario.

## Responsabilidades
Almacenamiento y suministro del nombre del usuario, correo electrónico primario y credenciales.

## Invariantes (Leyes — 🔴 Críticas — Hard Constraints)
- **Single Source of Truth:** El `identity-service` es el único propietario y origen de los datos privados de identidad. Ningún otro servicio debe duplicar su almacenamiento.
- **Privacidad absoluta (Zero-Leak):** Queda terminantemente prohibido imprimir datos privados del usuario (como correos o nombres reales) en consolas de logs públicos, depuradores de Docker o enviarlos en payloads sin cifrar.

## Reglas (Procedimientos — 🟡 Recomendadas — Soft Constraints)
- Los servicios que requieran notificar al usuario externo deben consultar su "dirección lógica" (correo electrónico) a través del microservicio de identidad; nunca deben resolverla de manera autónoma.

## Buenas prácticas (Recomendaciones — 🟢 Opcionales)
- Ocultar el mecanismo físico de almacenamiento de la identidad (como variables `.env` o bases de datos) al resto del sistema mediante interfaces REST.

## Antipatrones (Errores conocidos)
- ❌ Mapear o leer directamente la variable `USER_EMAIL` en servicios como `mail-watchdog` u `orchestrator` (violación de aislamiento de datos).
- ❌ Implementar lógica de envío SMTP o validación de red dentro de la API de identidad.

## Referencias
- [identity-service/README.md](file:///home/danuser2018/workspace/identity-service/README.md) (Especifica la implementación actual de almacenamiento por variables `.env` y endpoints REST de identidad).
