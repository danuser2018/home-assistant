---
name: service-responsibilities
description: Reglas de delimitación de responsabilidades de cada componente para evitar acoplamiento y fuga de lógica.
---

# service-responsibilities

## Objetivo
Garantizar la modularidad de la plataforma mediante la asignación estricta de propiedad lícita (*ownership*) a cada componente.

## Cuándo aplicar esta skill
- Al añadir nuevas capacidades de procesamiento al sistema.
- Al decidir en qué repositorio o servicio implementar un nuevo requisito funcional.

## Responsabilidades
Definición de dependencias, fuentes de verdad (*sources of truth*) y propiedad de lógica de cada componente.

## Invariantes (Leyes — 🔴 Críticas — Hard Constraints)
- **Propiedad Única de Datos:** Cada dominio de datos (identidad, configuración del sistema, cola de correos) pertenece a un único servicio que actúa como su fuente de verdad. Ningún otro servicio debe duplicar su persistencia ni almacenar estados en la sombra (*shadow state*).
- **Aislamiento del host:** Los contenedores Docker son ciegos al hardware físico. La captura de micrófonos, la reproducción de altavoces, la lectura de eventos físicos de entrada (como teclado raw HID) y la gestión del volumen físico del sistema residen en exclusiva en el host. Toda interacción con el hardware físico desde contenedores Docker debe realizarse de forma indirecta consumiendo la API de `host-service` (HAL).
- **Orquestador único:** La secuencia temporal del pipeline de voz en tiempo real (STT -> Orchestrator -> TTS) es de propiedad exclusiva de `interaction-manager`. Ningún otro componente debe coordinar llamadas en cascada.
- **Plugins sin lógica:** Los plugins del orquestador no deben contener lógica. La lógica debe residir en los servicios del dominio.

## Reglas (Procedimientos — 🟡 Recomendadas — Soft Constraints)
- El orquestador debe limitarse a derivar intenciones mediante scoring determinista; nunca debe realizar almacenamiento de datos de usuario ni llamadas de red directas a APIs externas de dominio.

## Buenas prácticas (Recomendaciones — 🟢 Opcionales)
- Diseñar los servicios de traducción e inferencia de voz (`stt-capability` y `tts-capability`) de forma autónoma, sin conocimiento del dominio del asistente.

## Antipatrones (Errores conocidos)
- ❌ Añadir lógica de reproducción física de altavoces en `interaction-manager` u `orchestrator`.
- ❌ Duplicar persistencia de bases de datos o lógica de negocio en los daemons nativos del host (`mic-daemon`, `speaker-watchdog`, `hid-daemon`, `host-service`).

## Referencias
- [architecture.md](file:///home/danuser2018/workspace/home-assistant/docs/architecture.md) (Definición del plano de host y plano de procesamiento).
- [ADR-002: Modularización de Servicios](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-002.md) (Explica la decisión de aislar servicios de hardware del host de la lógica Docker).
- [ADR-009: Centralización del Destinatario de Correo y Consulta REST desde Mail Watchdog](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-009.md) (Define la obtención dinámica del destinatario desde Identity Service en Mail Watchdog).
- [ADR-012: Integración del Servicio HID Daemon (hid-daemon)](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-012-integracion-hid-daemon.md) (Define la captura y ejecución desacoplada de eventos HID en el host).
- [ADR-013: Integración del Servicio Host (host-service)](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-013-integracion-host-service.md).
- [ADR-014: Separación de Responsabilidades en el Orquestador](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-014-refactorizacion-orquestador.md).
- [ADR-015: Consolidación del Modelo ExecutionPlan y Eliminación del Endpoint Legado](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-015-consolidacion-execution-plan.md).
- [ADR-018: Creación de la Librería de Abstracción nova-event-bus](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-018-libreria-nova-event-bus.md).
- [ADR-019: Integración de Context Service](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-019-integracion-context-service.md).
- [ADR-020: Integración del CLI novactl](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-020-integracion-novactl.md).
- [ADR-021: Detección de Habla basada en Eventos en mic-daemon](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-021-deteccion-habla-eventos-mic-daemon.md).
- [event-driven-architecture](file:///home/danuser2018/workspace/home-assistant/.agent/skills/transversal/event-driven-architecture/SKILL.md).