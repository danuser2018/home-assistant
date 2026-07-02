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
- **Aislamiento del host:** Los contenedores Docker son ciegos al hardware físico. La captura de micrófonos y la reproducción de altavoces residen en exclusiva en el host.
- **Orquestador único:** La secuencia temporal del pipeline de voz en tiempo real (STT -> Orchestrator -> TTS) es de propiedad exclusiva de `interaction-manager`. Ningún otro componente debe coordinar llamadas en cascada.
- **Plugins sin lógica:** Los plugins del orquestador no deben contener lógica. La lógica debe residir en los servicios del dominio.

## Reglas (Procedimientos — 🟡 Recomendadas — Soft Constraints)
- El orquestador debe limitarse a derivar intenciones mediante scoring determinista; nunca debe realizar almacenamiento de datos de usuario ni llamadas de red directas a APIs externas de dominio.

## Buenas prácticas (Recomendaciones — 🟢 Opcionales)
- Diseñar los servicios de traducción e inferencia de voz (`stt-capability` y `tts-capability`) de forma autónoma, sin conocimiento del dominio del asistente.

## Antipatrones (Errores conocidos)
- ❌ Añadir lógica de reproducción física de altavoces en `interaction-manager` u `orchestrator`.
- ❌ Duplicar persistencia de bases de datos o lógica de negocio en los daemons nativos del host (`mic-daemon`, `speaker-watchdog`).

## Referencias
- [architecture.md](file:///home/danuser2018/workspace/home-assistant/docs/architecture.md) (Definición del plano de host y plano de procesamiento).
- [ADR-002: Modularización de Servicios](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-002.md) (Explica la decisión de aislar servicios de hardware del host de la lógica Docker).
- [ADR-009: Centralización del Destinatario de Correo y Consulta REST desde Mail Watchdog](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-009.md) (Define la obtención dinámica del destinatario desde Identity Service en Mail Watchdog).