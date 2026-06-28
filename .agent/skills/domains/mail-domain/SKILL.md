---
name: mail-domain
description: Reglas para la gestión de colas de correo asíncronas y fiabilidad en la entrega de mensajes.
---

# mail-domain

## Objetivo
Garantizar la fiabilidad y la entrega asíncrona de correos sin comprometer la latencia ni bloquear los flujos interactivos de voz.

## Cuándo aplicar esta skill
- Al realizar cambios en la lógica de procesamiento de colas en `mail-watchdog`.
- Al crear plugins de intenciones en el orquestador que requieran emitir correos o alertas asíncronas.

## Responsabilidades
Conexión SMTP, procesamiento de cola de correos, transiciones de archivos JSON y reintentos ante fallos de conexión SMTP.

## Invariantes (Leyes — 🔴 Críticas — Hard Constraints)
- **Garantía anti-pérdida:** Un mensaje encolado nunca puede eliminarse de la bandeja hasta recibir una confirmación positiva de entrega SMTP o, alternativamente, hasta ser trasladado al repositorio de fallos definitivos para auditoría manual.
- **Idempotencia del receptor:** El procesamiento de la cola debe ser inmune a interrupciones físicas; si un envío falla a mitad de la transmisión, el reintento subsiguiente no debe duplicar el correo.

## Reglas (Procedimientos — 🟡 Recomendadas — Soft Constraints)
- El encolado de correos debe realizarse exclusivamente escribiendo archivos de mensaje estructurados en el directorio de entrada asíncrono asignado en el bus de datos del sistema.

## Buenas prácticas (Recomendaciones — 🟢 Opcionales)
- Implementar políticas de reintentos progresivos con esperas incrementales para proteger al servidor SMTP de sobrecargas.

## Antipatrones (Errores conocidos)
- ❌ Conectarse a sockets SMTP externos o implementar lógica de transporte de red de correo en el orquestador o sus plugins.
- ❌ Conservar de forma indefinida en la cola activa archivos JSON de correo corruptos o con campos faltantes obligatorios.

## Referencias
- [mail-watchdog/README.md](file:///home/danuser2018/workspace/mail-watchdog/README.md) (Detalla la implementación actual de la cola de archivos JSON y las variables del servidor SMTP).
- [ADR-006: Cola de Mensajería Asíncrona basada en Ficheros JSON](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-006.md)
