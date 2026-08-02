# Architectural Decision Records (ADRs)

Índice centralizado de Decisiones de Arquitectura del Ecosistema Nova-2:

| Nº | Título | Fecha | Estado | Fichero |
| :--- | :--- | :--- | :--- | :--- |
| ADR-001 | Usar el Sistema de Ficheros como Bus de Mensajes entre Servicios | 28-06-2026 | Aceptado | [adr-001.md](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-001.md) |
| ADR-002 | Modularización de Servicios (Host para Hardware y Docker para Procesamiento) | 28-06-2026 | Aceptado | [adr-002.md](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-002.md) |
| ADR-003 | Scoring Determinista de Plugins de Intenciones | 28-06-2026 | Aceptado | [adr-003.md](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-003.md) |
| ADR-004 | Estandarización de APIs REST en el Ecosistema | 28-06-2026 | Aceptado | [adr-004.md](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-004.md) |
| ADR-005 | Distribución mediante Imágenes Precompiladas en DockerHub | 28-06-2026 | Aceptado | [adr-005.md](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-005.md) |
| ADR-006 | Cola de Mensajería Asíncrona basada en Ficheros JSON | 28-06-2026 | Aceptado | [adr-006.md](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-006.md) |
| ADR-007 | Configuración de la Cuenta de Correo Destino en el MVP | 28-06-2026 | Aceptado | [adr-007.md](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-007.md) |
| ADR-008 | Modelo de Reproducción de Audio Física en speaker-watchdog | 30-06-2026 | Aceptado | [adr-008.md](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-008.md) |
| ADR-009 | Centralización del Destinatario de Correo y Consulta REST desde Mail Watchdog | 02-07-2026 | Aceptado | [adr-009.md](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-009.md) |
| ADR-010 | Aislamiento de Variables de Entorno por Servicio | 02-07-2026 | Aceptado | [adr-010.md](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-010.md) |
| ADR-011 | Integración del Servicio Meteorológico (Weather Service) | 05-07-2026 | Aceptado | [adr-011-integracion-weather-service.md](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-011-integracion-weather-service.md) |
| ADR-012 | Integración del Servicio HID Daemon (hid-daemon) | 05-07-2026 | Aceptado | [adr-012-integracion-hid-daemon.md](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-012-integracion-hid-daemon.md) |
| ADR-013 | Integración del Servicio Host (host-service) | 15-07-2026 | Aceptado | [adr-013-integracion-host-service.md](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-013-integracion-host-service.md) |
| ADR-014 | Separación de Responsabilidades en el Orquestador | 15-07-2026 | Aceptado | [adr-014-refactorizacion-orquestador.md](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-014-refactorizacion-orquestador.md) |
| ADR-015 | Consolidación del Modelo ExecutionPlan | 15-07-2026 | Aceptado | [adr-015-consolidacion-execution-plan.md](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-015-consolidacion-execution-plan.md) |
| ADR-016 | Integración del Servicio Calendario (Calendar Service) | 16-07-2026 | Aceptado | [adr-016-integracion-calendar-service.md](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-016-integracion-calendar-service.md) |
| ADR-017 | Integración de NATS como Message Broker | 17-07-2026 | Aceptado | [adr-017-integracion-nats.md](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-017-integracion-nats.md) |
| ADR-018 | Creación de la Librería de Abstracción nova-event-bus | 17-07-2026 | Aceptado | [adr-018-libreria-nova-event-bus.md](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-018-libreria-nova-event-bus.md) |
| ADR-019 | Integración de Context Service | 18-07-2026 | Aceptado | [adr-019-integracion-context-service.md](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-019-integracion-context-service.md) |
| ADR-020 | Integración del CLI novactl | 20-07-2026 | Aceptado | [adr-020-integracion-novactl.md](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-020-integracion-novactl.md) |
| ADR-021 | Detección de Habla basada en Eventos en mic-daemon | 22-07-2026 | Aceptado | [adr-021-deteccion-habla-eventos-mic-daemon.md](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-021-deteccion-habla-eventos-mic-daemon.md) |
| ADR-022 | Estandarización de Nomenclatura para Comunicaciones Asíncronas | 24-07-2026 | Aceptado | [adr-022-estandarizacion-nomenclatura-mensajeria-asincrona.md](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-022-estandarizacion-nomenclatura-mensajeria-asincrona.md) |
| ADR-023 | Estandarización del Identificador de Plugin en el Modelo ExecutionPlan | 02-08-2026 | Aceptado | [adr-023-estandarizacion-identificador-plugin-execution-plan.md](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-023-estandarizacion-identificador-plugin-execution-plan.md) |

