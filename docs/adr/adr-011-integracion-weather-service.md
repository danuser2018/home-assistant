# ADR-011: Integración del Servicio Meteorológico (Weather Service) en el Ecosistema Nova

## Fecha
05-07-2026

## Estado
Aceptado

## Contexto
Para enriquecer la funcionalidad del asistente de voz Nova, es necesario responder a consultas sobre el estado meteorológico y el clima actual.

Tradicionalmente, en arquitecturas acopladas, los plugins de orquestación consultan directamente APIs externas de clima. Sin embargo, bajo la arquitectura modular de Nova (ADR-002) y la asignación de responsabilidades (`service-responsibilities`), los plugins de orquestación deben ser deterministas y carecer de lógica de negocio o llamadas a red directas a APIs de terceros.

Para evitar la fuga de lógica, el acoplamiento directo del orquestador a APIs externas de clima, y para gestionar correctamente los rate limits y timeouts del proveedor, necesitamos incorporar un microservicio de soporte dedicado que exponga una API REST local estándar y encapsule la comunicación con APIs externas.

## Decisión
Se decide integrar el nuevo microservicio `weather-service` en el ecosistema Nova bajo las siguientes pautas:
1. **Contenerización y Despliegue**: Desplegar el microservicio en un contenedor Docker independiente, expuesto internamente en la red `assistant-network` y externamente en el puerto `8006` del host.
2. **Abstracción del Proveedor**: El servicio encapsulará la integración con el proveedor meteorológico Open-Meteo mediante peticiones HTTP asíncronas utilizando `httpx.AsyncClient`.
3. **Caché en Memoria**: Implementar una caché en memoria basada en TTL (Time-To-Live) parametrizable para evitar bloqueos por rate limiting de Open-Meteo y optimizar latencia.
4. **Contrato REST**: Exponer endpoints siguiendo la directiva **ADR-004** (versionado explícito `/v1/weather/current` y endpoint de salud `/health` con estructura de error común).
5. **Aislamiento de Configuración**: Aplicar la política del **ADR-010**, creando un archivo de configuración separado `config/weather-service.env` para variables de usuario (`LATITUDE`, `LONGITUDE`, `REQUEST_TIMEOUT_SECONDS`, `CACHE_TTL_SECONDS`) y declarando de manera inline en `docker-compose.yml` las variables de infraestructura (`PORT` y `HOST`).

## Alternativas consideradas
- **Consulta directa desde el plugin de clima del Orquestador**: Rechazada porque violaría la directiva de responsabilidades del orquestador y causaría acoplamiento a red externa desde un servicio de flujo lógico determinista.
- **Mantener simulación local indefinidamente**: Rechazada porque no cumple el objetivo de dotar a Nova con capacidades reales de clima en producción.

## Consecuencias
+ **Modularidad y Desacoplamiento**: El orquestador y sus plugins solo consumen un contrato REST local unificado, sin conocer los detalles del proveedor Open-Meteo.
+ **Extensibilidad**: Si se decide cambiar el proveedor de datos de clima en el futuro, solo se requiere implementar una nueva clase bajo la interfaz `WeatherProvider` en el microservicio, manteniendo el contrato REST intacto.
+ **Rendimiento y Tolerancia a Fallos**: La caché mitiga el rate-limit externo y se manejan timeouts estrictos.
- **Consumo de recursos**: Ejecutar un contenedor adicional requiere recursos de RAM y CPU adicionales en el host.
