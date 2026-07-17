---
name: communication-patterns
description: Reglas de integración síncrona y asíncrona entre servicios utilizando el filesystem y APIs REST.
---

# communication-patterns

## Objetivo
Garantizar la fiabilidad en la entrega de mensajes y evitar dependencias de red frágiles.

## Cuándo aplicar esta skill
- Al definir la interacción de red o de archivos entre dos o más microservicios.
- Al implementar nuevos sockets o flujos de integración.

## Responsabilidades
Protocolos de red internos (síncronos) y paso de mensajes en el sistema de archivos (asíncronos).

## Invariantes (Leyes — 🔴 Críticas — Hard Constraints)
- **Reclamación exclusiva:** El servicio que procesa un mensaje asíncrono debe reclamar la propiedad del recurso de forma atómica antes de trabajar sobre él para evitar condiciones de carrera y procesamiento duplicado.
- **Ciclo de vida del mensaje:** El servicio consumidor de un mensaje en el filesystem es el único responsable de su destrucción o su traslado definitivo a carpetas de error en caso de fallo crítico.

## Reglas (Procedimientos — 🟡 Recomendadas — Soft Constraints)
- Utilizar HTTP/REST síncrono para operaciones en tiempo real donde la latencia sea crítica (STT, TTS, Orchestrator).
- Establecer timeouts estrictos en todas las solicitudes HTTP salientes para evitar congelar el pipeline de interacción por fallos de red.

## Buenas prácticas (Recomendaciones — 🟢 Opcionales)
- Utilizar formatos estandarizados de intercambio estructurado (como JSON) para mensajes asíncronos en disco.

## Antipatrones (Errores conocidos)
- ❌ Leer o escribir directamente en un directorio de datos interno propiedad de otro servicio (violación del aislamiento del bus).
- ❌ Mantener flujos de red persistentes entre el host y Docker para transferir bloques de datos.

## Referencias
- [services.md](file:///home/danuser2018/workspace/home-assistant/docs/services.md) (Sección: Comunicación entre Servicios).
- [ADR-001: Usar el Sistema de Ficheros como Bus de Mensajes entre Servicios](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-001.md)
- [ADR-006: Cola de Mensajería Asíncrona basada en Ficheros JSON](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-006.md)
- [ADR-017: Integración de NATS como Message Broker en el Ecosistema Nova](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-017-integracion-nats.md) (Define la integración del broker de mensajería NATS en el plano de procesamiento).
