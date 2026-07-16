# ADR-016: Integración del Servicio Calendario (Calendar Service) en el Ecosistema Nova

## Fecha
16-07-2026

## Estado
Aceptado

## Contexto
El asistente de voz Nova requiere la capacidad de responder a consultas sobre el calendario civil, específicamente para identificar festivos oficiales nacionales, regionales o locales.

Para garantizar la privacidad y la fiabilidad de Nova en entornos sin conexión, todas las consultas deben resolverse de manera 100% local y offline, sin realizar llamadas a APIs externas. Los datos de festivos de cada año cambian periódicamente, por lo que requerimos un mecanismo flexible y desacoplado para cargar estos datos de forma dinámica en formato JSON por año.

Siguiendo los principios de separación de responsabilidades de Nova (ADR-002), el orquestador no debe mantener en memoria bases de datos pesadas ni procesar ficheros de calendario directamente. Por ello, es necesario un microservicio dedicado que cargue estos datos en memoria al arrancar y resuelva las peticiones de manera instantánea.

## Decisión
Se decide integrar el nuevo microservicio `calendar-service` en el ecosistema de Nova bajo las siguientes pautas:
1. **Contenerización y Red**: Desplegar el microservicio en un contenedor Docker independiente, integrado en la red `assistant-network` y expuesto en el puerto host `8008` (puerto interno `8000`) para depuración y comprobaciones de salud.
2. **Persistencia Dinámica de Festivos**: Usar un volumen de datos Docker (`./calendar-data:/app/data`) para leer los ficheros de festivos en formato JSON por año (`holidays/*.json`), asegurando que no se guarden datos específicos en el repositorio Git.
3. **Carga en Memoria**: Cargar dinámicamente toda la información de festivos en memoria al inicio para resolver las peticiones en menos de 50 ms.
4. **Contrato REST y Manejo de Errores**: Exponer endpoints versión `v1` (`/api/v1/health`, `/api/v1/holidays`, `/api/v1/holidays/next`) siguiendo la directiva **ADR-004**, devolviendo errores controlados y con estructura de JSON común (`DATA_NOT_FOUND`, `INVALID_DATE_FORMAT`, `INVALID_PARAMETERS`, `NO_NEXT_HOLIDAY_FOUND`).
5. **Configuración Aislada**: Crear un archivo de configuración separado `config/calendar-service.env` para variables de entorno (`LOG_LEVEL` y `DATA_DIR`), declarando inline los puertos y red en `docker-compose.yml`.

## Alternativas consideradas
- **Integrar base de datos SQLite persistente**: Rechazada porque añade complejidad innecesaria en la sincronización y almacenamiento de datos estáticos anuales. Los archivos JSON leídos en memoria son más que suficientes y de mantenimiento trivial.
- **Resolver consultas directamente en el Orquestador**: Rechazada porque violaría la separación de responsabilidades y aumentaría el consumo de RAM/complejidad del orquestador.

## Consecuencias
+ **Rendimiento e Inmediatez**: Las consultas se resuelven en microsegundos al estar cargadas en la memoria del microservicio.
+ **Privacidad y Aislamiento**: Operación 100% local y offline sin salida a red externa.
+ **Mantenibilidad**: Los datos de nuevos años pueden actualizarse simplemente subiendo un JSON al volumen local de datos y reiniciando el servicio.
- **Consumo de recursos**: Se añade la sobrecarga menor de un contenedor Python/FastAPI adicional.
