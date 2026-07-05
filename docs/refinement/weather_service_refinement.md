# Refinamiento de la Feature: Integración de Weather Service en Nova

- **Archivo de origen**: [weather_service.md](file:///home/danuser2018/workspace/home-assistant/docs/features/weather_service.md)
- **Fecha**: 2026-07-05
- **Estado**: Refinado

---

## 1. Resumen y Contexto de Negocio

### Objetivo Principal
Integrar de manera oficial el nuevo microservicio `weather-service` en la infraestructura de contenedores y despliegue del ecosistema Nova. Esta fase no altera el comportamiento del orquestador ni de los plugins de clima existentes (manteniendo las simulaciones actuales), sino que establece el microservicio de soporte en la red interna de Docker Compose, aislando sus variables de entorno de acuerdo con los estándares de seguridad vigentes (ADR-010).

### Actores y Flujo de Alto Nivel
1. **Administrador/Desarrollador**: Configura las coordenadas geográficas de la ubicación en el archivo local de variables de entorno y ejecuta la pila del ecosistema.
2. **Docker Compose**: Descarga y despliega automáticamente el contenedor `weather-service`.
3. **Healthcheck Script**: Consulta periódicamente el endpoint `/health` del servicio para garantizar su disponibilidad.
4. **Clientes Internos (futuro)**: Los plugins de dominio consumirán el endpoint `/v1/weather/current` para obtener información del clima en tiempo real de forma normalizada.

---

## 2. Análisis de Servicios e Impacto

| Servicio | Tipo de Cambio | Descripción del Impacto |
| :--- | :--- | :--- |
| `home-assistant` | Modificar | Se añade la definición de `weather-service` a `docker-compose.yml` mapeando el puerto `8006:8000`. Se añade `weather-service` a la directiva `depends_on` del servicio `orchestrator` con condición `service_healthy`. Se añade el archivo de configuración `config/weather-service.env`. Se actualizan los scripts de gestión `scripts/healthcheck.sh`, `CHANGELOG.md` y la documentación general (`docs/services.md` y `docs/architecture.md`). |
| `weather-service` | Modificar | Adaptar el endpoint `/health` para que devuelva `{"status": "ok"}` en lugar de `{"status": "UP"}`, alineando la respuesta con el estándar del ecosistema Nova. **La publicación de la imagen actualizada `danuser2018/weather-service:latest` en DockerHub es un paso manual, responsabilidad del desarrollador, y debe completarse antes de iniciar la Fase 1.** |

---

## 3. Especificación de Comportamiento (Criterios de Aceptación)

### Escenario 1: Despliegue exitoso del servicio de clima
```gherkin
Dado que el ecosistema Nova se despliega utilizando Docker Compose
Cuando todos los contenedores se inician correctamente
Entonces el contenedor "weather-service" debe reportar un estado "running"
Y el endpoint HTTP "GET http://localhost:8006/health" debe responder con código 200 OK
Y el cuerpo de la respuesta debe ser exactamente {"status": "ok"}
```

### Escenario 2: Consulta del clima actual en la red interna
```gherkin
Dado que el servicio "weather-service" está en ejecución en el ecosistema
Cuando se realiza una petición HTTP "GET /v1/weather/current" desde cualquier contenedor en la red "assistant-network" a "http://weather-service:8000/v1/weather/current"
Entonces el servicio responde con código 200 OK
Y el JSON devuelto contiene los campos "temperature" (float) y "precipitation_probability" (int)
```

### Escenario 3: Respuesta de error estructurada ante caída de Open-Meteo
```gherkin
Dado que el servicio "weather-service" está en ejecución pero la API de Open-Meteo no responde o tiene timeout
Cuando se consulta "GET http://localhost:8006/v1/weather/current"
Entonces el servicio responde con código 503 Service Unavailable
Y la respuesta es un JSON estructurado según ADR-004 con los campos "error": "WEATHER_PROVIDER_UNAVAILABLE", "message" y "status": 503
```

### Escenario 4: Respuesta de error por coordenadas ausentes en configuración
```gherkin
Dado que no se configuran las variables de entorno obligatorias "LATITUDE" y "LONGITUDE"
Cuando se realiza una petición HTTP "GET http://localhost:8006/v1/weather/current"
Entonces el servicio responde con código 500 Internal Server Error
Y la respuesta es un JSON estructurado según ADR-004 con los campos "error": "INTERNAL_ERROR", "message" y "status": 500
```

---

## 4. Diseño Técnico y Contratos

### Definición en Docker Compose (`home-assistant/docker-compose.yml`)
Se añadirá una nueva sección de servicio al archivo de Docker Compose principal, respetando los estándares de aislamiento de puertos y redes:

```yaml
  weather-service:
    image: danuser2018/weather-service:latest
    container_name: weather-service
    env_file:
      - config/weather-service.env
    environment:
      PORT: 8000
      HOST: 0.0.0.0
    ports:
      - "8006:8000"  # Exposed for healthcheck and local debugging
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 5s
      retries: 3
    networks:
      - assistant-network
```

### Actualización del Servicio `orchestrator` en Docker Compose (`home-assistant/docker-compose.yml`)
Se añade `weather-service` a la directiva `depends_on` del servicio `orchestrator` para garantizar que el microservicio de clima esté disponible y sano antes de que el orquestador arranque, dejando preparada la dependencia de infraestructura para la futura integración del `WeatherPlugin` con datos reales:

```yaml
  orchestrator:
    depends_on:
      system-service:
        condition: service_started
      weather-service:
        condition: service_healthy
```

### Configuración de Variables de Entorno (`home-assistant/config/weather-service.env`)
De acuerdo con la directiva **ADR-010**, se aísla la configuración del servicio de clima en su propio archivo:

```env
# =============================================================================
# Weather Service Configuration (weather-service)
# =============================================================================

# Coordinates for weather query (Madrid by default)
LATITUDE=40.4168
LONGITUDE=-3.7038

# Request configuration
REQUEST_TIMEOUT_SECONDS=5.0
CACHE_TTL_SECONDS=60
```

### Contrato API REST

#### 1. GET `/health`
- **Method**: GET
- **Path**: `/health`
- **Response HTTP status**: `200 OK`
- **Response Body**:
```json
{
  "status": "ok"
}
```

#### 2. GET `/v1/weather/current`
- **Method**: GET
- **Path**: `/v1/weather/current`
- **Response HTTP status**: `200 OK`
- **Response Body**:
```json
{
  "temperature": 28.3,
  "precipitation_probability": 20
}
```

#### 3. Error Respuestas (Estándar ADR-004)
Cualquier fallo de validación o del proveedor externo retornará un esquema común:

- **Error del Proveedor Externo (HTTP 503)**:
```json
{
  "error": "WEATHER_PROVIDER_UNAVAILABLE",
  "message": "Weather information is currently unavailable.",
  "status": 503
}
```

- **Error Interno o Falta de Configuración (HTTP 500)**:
```json
{
  "error": "INTERNAL_ERROR",
  "message": "Internal server error.",
  "status": 500
}
```

---

## 5. Casos de Borde y Manejo de Errores

| Caso de Borde | Comportamiento Esperado | Implementación Técnica |
| :--- | :--- | :--- |
| **Timeout en llamada a Open-Meteo** | Retornar HTTP 503 estructurado indicando indisponibilidad sin exponer trazas. | Capturar `httpx.TimeoutException` en `OpenMeteoProvider` y lanzar una excepción controlada que resuelva en el manejador global. |
| **Variables geográficas vacías o nulas** | Interrumpir la petición en runtime respondiendo HTTP 500 estructurado. | El método `Settings.validate_required()` lanzará un `ValueError` si `LATITUDE` o `LONGITUDE` son nulos. El interceptor de excepciones de FastAPI capturará esto y lo formateará según ADR-004. |
| **Límite de peticiones de la API de Open-Meteo (Rate Limit)** | Servir datos desde la caché local o retornar HTTP 503 si no hay caché. | Se implementa un TTL de caché configurable mediante `CACHE_TTL_SECONDS` en memoria. Al expirar o en caso de fallo sin datos en caché, se propaga el error de proveedor no disponible. |

---

## 6. Estrategia de Testing

### Tests Unitarios e Integración (`weather-service`)
1. **Configuración (`tests/test_config.py`)**:
   - Validar que la inicialización de `Settings` sin variables obligatorias (`LATITUDE`/`LONGITUDE`) arroja un error controlado.
2. **Servicio y Proveedor (`tests/test_service.py`)**:
   - Mockear las respuestas JSON de la API de Open-Meteo y validar el parseo correcto de la temperatura y precipitación.
   - Validar el mecanismo de almacenamiento en caché por TTL.
3. **Controlador y Endpoints (`tests/test_api.py`)**:
   - Validar que `/health` responde `200 OK` con el cuerpo `{"status": "ok"}`.
   - Validar que `/v1/weather/current` responde `200 OK` con la estructura correcta.
   - Validar que un fallo HTTP en el proveedor externo propaga una respuesta 503 con la estructura del estándar ADR-004.

### Pruebas de Integración y Despliegue E2E (`home-assistant`)
1. Desplegar localmente el conjunto de servicios del ecosistema ejecutando `docker compose up --build -d`.
2. Validar que no se generen errores durante el despliegue del nuevo contenedor.
3. Ejecutar el script actualizado `./scripts/healthcheck.sh` y comprobar que todos los servicios responden correctamente, prestando especial atención a que `weather-service` sea validado.
4. Ejecutar comandos manuales de comprobación desde el host:
   - `curl -i http://localhost:8006/health` (debe responder 200 OK con `"status": "ok"`).
   - `curl -i http://localhost:8006/v1/weather/current` (debe responder 200 OK con un JSON estructurado).

---

## 7. Plan de Implementación (Checklist)

- [ ] **Fase 0: Adaptación del Microservicio `weather-service`**
  - [ ] Modificar el endpoint `/health` del repositorio `weather-service` para que devuelva `{"status": "ok"}` en lugar de `{"status": "UP"}`, alineando la respuesta con el estándar del ecosistema Nova.
  - [ ] ⚠️ **[Paso manual — responsabilidad del desarrollador]** Publicar la imagen actualizada `danuser2018/weather-service:latest` en DockerHub antes de continuar con la Fase 1.

- [ ] **Fase 1: Configuración de la Infraestructura en Home Assistant**
  - [ ] Crear el archivo de variables de entorno `config/weather-service.env` con valores por defecto razonables (por ejemplo, coordenadas de Madrid, timeout de 5s y TTL de 60s).
  - [ ] Registrar la definición del contenedor de `weather-service` en `docker-compose.yml` utilizando la imagen `danuser2018/weather-service:latest` y exponiendo el puerto `8006:8000`.
  - [ ] Declarar de forma inline las variables de infraestructura `PORT=8000` y `HOST=0.0.0.0` bajo la sección `environment:` del servicio en `docker-compose.yml`.
  - [ ] Añadir `weather-service` a la red `assistant-network` en la definición del servicio.
  - [ ] Actualizar la definición del servicio `orchestrator` en `docker-compose.yml` añadiendo `weather-service` a su directiva `depends_on` con condición `service_healthy`.

- [ ] **Fase 2: Observabilidad y Gestión**
  - [ ] Añadir `weather-service` en la lista de contenedores verificados (`CONTAINERS`) dentro de `scripts/healthcheck.sh`.
  - [ ] Añadir la llamada de comprobación HTTP para `Weather Service /health` en el script `scripts/healthcheck.sh` en el puerto `8006`.

- [ ] **Fase 3: Actualización de la Documentación del Sistema**
  - [ ] Modificar el catálogo de servicios en [docs/services.md](file:///home/danuser2018/workspace/home-assistant/docs/services.md) para agregar `weather-service` en la tabla general, actualizar el conteo total de microservicios de 9 a 10, crear la sección detallada con sus endpoints/variables y actualizar el diagrama ASCII de comunicación.
  - [ ] Modificar la descripción de la arquitectura en [docs/architecture.md](file:///home/danuser2018/workspace/home-assistant/docs/architecture.md) para agregar `weather-service` a la lista de contenedores de procesamiento y documentar su rol.
  - [ ] Crear el registro de decisión arquitectónica [ADR-011](docs/adr/adr-011-integracion-weather-service.md) justificando formalmente la adición de este nuevo servicio en el ecosistema.
  - [ ] Añadir una referencia al ADR-011 en la sección `Referencias` de la skill `system-deployment` (`home-assistant/.agent/skills/transversal/system-deployment/SKILL.md`).
  - [ ] Modificar `CHANGELOG.md` bajo la sección `[Sin publicar]` para registrar la adición de `weather-service`, su archivo de configuración `weather-service.env`, el nuevo ADR-011, la integración con `healthcheck.sh` y las actualizaciones documentales realizadas.

- [ ] **Fase 4: Verificación E2E y Pruebas**
  - [ ] Ejecutar `docker compose up --build -d` para construir y levantar todo el ecosistema.
  - [ ] Ejecutar `./scripts/healthcheck.sh` y certificar que la salida final es `Sistema operativo — N/N comprobaciones OK` sin ningún fallo (❌), donde N es el número total de checks del script tras añadir `weather-service`.
  - [ ] Validar manualmente los endpoints expuestos mediante comandos `curl` desde el host.

---

## 8. Propuesta de Decisión Arquitectónica (ADR)

### ADR-011: Integración del Servicio Meteorológico (Weather Service) en el Ecosistema Nova

- **Fecha**: 2026-07-05
- **Estado**: Propuesto

#### Contexto
Para enriquecer la funcionalidad del asistente de voz Nova, es necesario responder a consultas sobre el estado meteorológico y el clima actual. 

Tradicionalmente, en arquitecturas acopladas, los plugins de orquestación consultan directamente APIs externas de clima. Sin embargo, bajo la arquitectura modular de Nova (ADR-002) y la asignación de responsabilidades (`service-responsibilities`), los plugins de orquestación deben ser deterministas y carecer de lógica de negocio o llamadas a red directas a APIs de terceros. 

Para evitar la fuga de lógica, el acoplamiento directo del orquestador a APIs externas de clima, y para gestionar correctamente los rate limits y timeouts del proveedor, necesitamos incorporar un microservicio de soporte dedicado que exponga una API REST local estándar y encapsule la comunicación con APIs externas.

#### Decisión
Se decide integrar el nuevo microservicio `weather-service` en el ecosistema Nova bajo las siguientes pautas:
1. **Contenerización y Despliegue**: Desplegar el microservicio en un contenedor Docker independiente, expuesto internamente en la red `assistant-network` y externamente en el puerto `8006` del host.
2. **Abstracción del Proveedor**: El servicio encapsulará la integración con el proveedor meteorológico Open-Meteo mediante peticiones HTTP asíncronas utilizando `httpx.AsyncClient`.
3. **Caché en Memoria**: Implementar una caché en memoria basada en TTL (Time-To-Live) parametrizable para evitar bloqueos por rate limiting de Open-Meteo y optimizar latencia.
4. **Contrato REST**: Exponer endpoints siguiendo la directiva **ADR-004** (versionado explícito `/v1/weather/current` y endpoint de salud `/health` con estructura de error común).
5. **Aislamiento de Configuración**: Aplicar la política del **ADR-010**, creando un archivo de configuración separado `config/weather-service.env` para variables de usuario (`LATITUDE`, `LONGITUDE`, `REQUEST_TIMEOUT_SECONDS`, `CACHE_TTL_SECONDS`) y declarando de manera inline en `docker-compose.yml` las variables de infraestructura (`PORT` y `HOST`).

#### Consecuencias
* **(+) Modularidad y Desacoplamiento**: El orquestador y sus plugins solo consumen un contrato REST local unificado, sin conocer los detalles de Open-Meteo.
* **(+) Extensibilidad**: Si se decide cambiar el proveedor de datos de clima en el futuro, solo se requiere implementar una nueva clase bajo la interfaz `WeatherProvider` en el microservicio, manteniendo el contrato REST intacto.
* **(+) Rendimiento y Tolerancia a Fallos**: La caché mitiga el rate-limit externo y se manejan timeouts estrictos.
* **(-) Consumo de recursos**: Ejecutar un contenedor adicional requiere recursos de RAM y CPU adicionales en el host.

