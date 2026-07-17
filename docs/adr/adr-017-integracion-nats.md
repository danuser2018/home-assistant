# ADR-017: Integración de NATS como Message Broker en el Ecosistema Nova

## Fecha
17-07-2026

## Estado
Aceptado

## Contexto
El ecosistema Nova ha crecido hasta alcanzar 13 microservicios. A medida que el sistema evoluciona hacia una arquitectura de microservicios distribuidos, surge la necesidad de soportar una comunicación orientada a eventos, publicación/suscripción (pub/sub) de alto rendimiento y comunicaciones asíncronas fiables entre contenedores Docker de forma local y offline.

Hasta ahora, la comunicación asíncrona se ha resuelto mediante el filesystem-bus (ADR-001) y colas de ficheros JSON (ADR-006). Si bien este enfoque es robusto y excelente para desacoplar los servicios del host Linux (como `mic-daemon` y `speaker-watchdog`) de los contenedores Docker, no escala eficientemente para flujos de mensajería complejos de alta frecuencia o comunicación directa inter-container debido a la sobrecarga de I/O de disco. Por tanto, se requiere un broker de mensajería ligero, rápido y de bajo consumo para soportar la futura evolución del sistema.

## Decisión
Se decide integrar el servidor oficial de mensajería **NATS** como un nuevo servicio Docker de infraestructura dentro de la red privada del ecosistema Nova. Las pautas de la Fase 1 de esta integración son:

1. **Contenerización y Red**: Desplegar NATS mediante la imagen oficial `nats:2.10-alpine` bajo el nombre de contenedor `nats`, conectado únicamente a la red privada `assistant-network`.
2. **Puertos y Acceso**: Exponer el puerto de clientes `4222` al host únicamente para desarrollo, depuración y administración. El puerto de monitoreo interno `8222` se habilitará para uso exclusivo del healthcheck local del contenedor, pero no se expondrá fuera de la red de Docker.
3. **Mecanismo de Healthcheck**: Configurar un healthcheck nativo en el contenedor utilizando `wget` para realizar consultas periódicas a `http://localhost:8222/healthz`.
4. **Política de Reinicio**: Configurar `restart: unless-stopped` para garantizar la alta disponibilidad del broker ante caídas accidentales.
5. **Aislamiento de Configuración**: Al ser un servicio de infraestructura pura sin personalización requerida en esta fase, no se asociará ningún archivo `.env` en la carpeta `config/`.

### Coexistencia con el Filesystem-Bus (ADR-001 y ADR-006)
NATS y el bus basado en el sistema de archivos coexistirán en el ecosistema bajo las siguientes reglas de diseño:
- **Filesystem-Bus**: Se mantiene de forma indefinida y prioritaria para la interacción con daemons nativos del host (entrada/salida de audio y watchdog de emails). Esto garantiza que los daemons del host (que corren como servicios de usuario en systemd) no se vean afectados por reinicios o caídas temporales de la red de contenedores de Docker, manteniendo intacto el aislamiento físico y de hardware.
- **NATS Broker**: Se introduce exclusivamente para el plano de procesamiento en Docker, facilitando la futura migración de flujos internos inter-container hacia patrones pub/sub y mensajería distribuida de baja latencia sin sobrecargar el I/O del disco físico.

## Alternativas consideradas
- **Migrar completamente el pipeline de voz y daemons a NATS de forma inmediata**: Rechazada para evitar regresiones de estabilidad y el impacto de reescribir y redesplegar todos los componentes del host nativo en la primera fase.
- **Usar RabbitMQ o Redis**: Rechazada. RabbitMQ tiene una huella de memoria y de CPU muy elevada (~100-200 MB de RAM mínima), requiriendo de la máquina virtual de Erlang. Redis, aunque ligero, está optimizado para almacenamiento en caché estructurada y requiere configuraciones adicionales para actuar como un bus robusto de mensajería (Streams/PubSub). NATS es un broker nativo en Go, con una huella de memoria ínfima (< 10 MB de RAM en reposo), latencia de microsegundos y diseñado específicamente para topologías de microservicios locales y de nube.

## Consecuencias
+ **Preparación para el Futuro**: El ecosistema queda listo para soportar mensajería distribuida asíncrona de alto rendimiento.
+ **Cero Regresiones**: La Fase 1 mantiene el 100% de la funcionalidad actual de Nova, asegurando que los servicios síncronos y basados en archivos sigan operando normalmente.
+ **Observabilidad Local**: La activación de la interfaz de monitoreo en el puerto `8222` interno permite asegurar el estado de salud del broker mediante Docker.
- **Consumo Adicional**: Se añade un contenedor adicional, aunque su impacto en recursos de CPU y memoria es despreciable.
