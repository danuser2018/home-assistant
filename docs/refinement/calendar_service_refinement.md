# Refinamiento de la Feature: Integración de Calendar Service en Nova

- **Archivo de origen**: [first_implementation.md](file:///home/danuser2018/workspace/calendar-service/doc/features/first_implementation.md)
- **Fecha**: 2026-07-16
- **Estado**: Refinado

---

## 1. Resumen y Contexto de Negocio

### Objetivo Principal
Integrar de manera oficial el nuevo microservicio `calendar-service` (calendario civil) en la infraestructura de contenedores y despliegue del ecosistema Nova. Este servicio se encargará de gestionar localmente la persistencia y consulta offline de festivos oficiales municipales mediante ficheros JSON estructurados por año. Al arrancar, cargará toda la información en memoria para resolver peticiones en un tiempo inferior al límite de 50 ms. En esta primera fase, se configura toda la infraestructura de contenedores, red, logs, comprobaciones automáticas y documentación general, preparando el servicio para su posterior explotación.

### Actores y Flujo de Alto Nivel
1. **Administrador/Desarrollador**: Coloca los archivos JSON anuales de festivos (por ejemplo, `2026.json`) en el volumen host `$PROJECT_DIR/calendar-data/holidays/`.
2. **Docker Compose**: Levanta el contenedor `calendar-service`, montando el volumen y mapeándolo a la red interna `assistant-network`.
3. **Healthcheck Script**: Consulta periódicamente el endpoint `/api/v1/health` en el puerto expuesto `8008` para verificar la disponibilidad.
4. **Orquestador (futuro)**: Consumirá los endpoints de consulta de festivos para contextualizar respuestas temporales al usuario.

---

## 2. Análisis de Servicios e Impacto

| Servicio | Tipo de Cambio | Descripción del Impacto |
| :--- | :--- | :--- |
| `calendar-service` | Nuevo | Creación del repositorio desde cero: código Python (FastAPI/Pydantic), pruebas unitarias e integración con pytest, configuración de CI (.github Actions) y `README.md`. |
| `home-assistant` | Modificar | Se añade la definición de `calendar-service` en `docker-compose.yml` mapeando el puerto `8008:8000`. Se actualiza `depends_on` y se añade la variable de red `CALENDAR_SERVICE_BASE_URL` en el servicio `orchestrator`. Se crea el archivo aislado de entorno `config/calendar-service.env`. Se actualizan los scripts de gestión `healthcheck.sh`, `install.sh`, `uninstall.sh`, el catálogo de servicios (`docs/services.md`), la arquitectura (`docs/architecture.md`), se redacta el nuevo `ADR-016` y se actualiza `CHANGELOG.md`. |

---

## 3. Especificación de Comportamiento (Criterios de Aceptación)

### Escenario 1: Despliegue exitoso del servicio de calendario
```gherkin
Dado que el ecosistema Nova se despliega utilizando Docker Compose
Cuando todos los contenedores se inician correctamente
Entonces el contenedor "calendar-service" debe reportar un estado "running"
Y el endpoint HTTP "GET http://localhost:8008/api/v1/health" debe responder con código 200 OK
Y el cuerpo de la respuesta debe ser exactamente {"status": "ok"}
```

### Escenario 2: Consulta exitosa de un día que es festivo
```gherkin
Dado que el servicio "calendar-service" está en ejecución con el archivo "2026.json" cargado
Cuando se realiza una petición HTTP "GET /api/v1/holidays?date=2026-11-09"
Entonces el servicio responde con código 200 OK
Y el cuerpo de la respuesta es un JSON con los campos:
  | Campo | Tipo | Valor |
  | isHoliday | boolean | true |
  | holiday.date | string | "2026-11-09" |
  | holiday.dayOfWeek | string | "MONDAY" |
  | holiday.name | string | "Nuestra Señora de la Soledad" |
  | holiday.scope | string | "local" |
```

### Escenario 3: Consulta de un día que no es festivo
```gherkin
Dado que el servicio "calendar-service" está en ejecución con el archivo "2026.json" cargado
Cuando se realiza una petición HTTP "GET /api/v1/holidays?date=2026-11-10"
Entonces el servicio responde con código 200 OK
Y el cuerpo de la respuesta es un JSON con el campo:
  | Campo | Tipo | Valor |
  | isHoliday | boolean | false |
```

### Escenario 4: Consulta del próximo festivo a partir de una fecha
```gherkin
Dado que el servicio "calendar-service" tiene cargados los festivos de 2026
Cuando se realiza una petición HTTP "GET /api/v1/holidays/next?from=2026-07-15"
Entonces el servicio responde con código 200 OK
Y el JSON devuelto contiene los campos:
  | Campo | Tipo | Valor |
  | date | string | "2026-10-12" |
  | dayOfWeek | string | "MONDAY" |
  | name | string | "Fiesta Nacional de España" |
  | scope | string | "national" |
  | daysUntil | integer | 89 |
```

### Escenario 5: Consulta de todos los festivos de un año
```gherkin
Dado que el servicio "calendar-service" tiene cargado el año "2026"
Cuando se realiza una petición HTTP "GET /api/v1/holidays?year=2026"
Entonces el servicio responde con código 200 OK
Y el cuerpo de la respuesta contiene el campo "year" con valor 2026
Y el campo "holidays" contiene la lista ordenada cronológicamente de todos los festivos cargados para ese año.
```

### Escenario 6: Intento de consulta de un año no cargado
```gherkin
Dado que el archivo "2025.json" no existe en el volumen de datos
Cuando se realiza una petición HTTP "GET /api/v1/holidays?year=2025"
Entonces el servicio responde con código 404 Not Found
Y la respuesta es un JSON con los campos:
  | Campo | Valor |
  | error | "DATA_NOT_FOUND" |
  | message | "No holiday data found for year 2025" |
  | status | 404 |
```

### Escenario 7: Consulta de próximo festivo cuando no hay festivos futuros en la base de datos
```gherkin
Dado que la fecha máxima registrada en los JSON es "2026-12-25"
Cuando se realiza una petición HTTP "GET /api/v1/holidays/next?from=2026-12-26"
Entonces el servicio responde con código 404 Not Found
Y la respuesta es un JSON con los campos:
  | Campo | Valor |
  | error | "NO_NEXT_HOLIDAY_FOUND" |
  | message | "No next holiday found from date 2026-12-26" |
  | status | 404 |
```

### Escenario 8: Consulta con fecha en formato inválido
```gherkin
Dado que el servicio "calendar-service" está en ejecución
Cuando se realiza una petición HTTP "GET /api/v1/holidays?date=not-a-date"
Entonces el servicio responde con código 400 Bad Request
Y la respuesta es un JSON con los campos:
  | Campo | Valor |
  | error | "INVALID_DATE_FORMAT" |
  | message | "Date format must be YYYY-MM-DD" |
  | status | 400 |
```

---

## 4. Diseño Técnico y Contratos

### Definición en Docker Compose (`home-assistant/docker-compose.yml`)
Se introduce el nuevo bloque de servicio, exponiendo el puerto host `8008` e integrándolo en `assistant-network`:

```yaml
  calendar-service:
    image: danuser2018/calendar-service:latest
    container_name: calendar-service
    env_file:
      - config/calendar-service.env
    environment:
      PORT: 8000
      HOST: 0.0.0.0
    ports:
      - "8008:8000"  # Expuesto para healthcheck y depuración local
    volumes:
      - ./calendar-data:/app/data
      - /etc/localtime:/etc/localtime:ro
      - /etc/timezone:/etc/timezone:ro
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/api/v1/health"]
      interval: 30s
      timeout: 5s
      retries: 3
    networks:
      - assistant-network
```

Se inyecta la URL de `calendar-service` en las variables de entorno del servicio `orchestrator`:

```yaml
  orchestrator:
    # ...
    environment:
      # ...
      CALENDAR_SERVICE_BASE_URL: http://calendar-service:8000
    # ...
    depends_on:
      system-service:
        condition: service_started
      weather-service:
        condition: service_healthy
```

### Configuración del Entorno (`home-assistant/config/calendar-service.env`)
Archivo aislado para variables del servicio de calendario:

```env
# =============================================================================
# Calendar Service Configuration (calendar-service)
# =============================================================================

# Logging configuration
LOG_LEVEL=INFO

# Local data path inside the container
DATA_DIR=/app/data
```

### Contrato API REST

#### 1. GET `/api/v1/health`
- **Method**: GET
- **Path**: `/api/v1/health`
- **Response HTTP status**: `200 OK`
- **Response Body**:
```json
{
  "status": "ok"
}
```

#### 2. GET `/api/v1/holidays` (Consulta de día o consulta de año)
- **Method**: GET
- **Path**: `/api/v1/holidays`
- **Query Parameters**:
  - `date`: string (formato `YYYY-MM-DD`, opcional)
  - `year`: integer (opcional)
- **Response HTTP status**: `200 OK`
- **Response Body (cuando se consulta una fecha y es festivo)**:
```json
{
  "isHoliday": true,
  "holiday": {
    "date": "2026-11-09",
    "dayOfWeek": "MONDAY",
    "name": "Nuestra Señora de la Soledad",
    "scope": "local"
  }
}
```
- **Response Body (cuando se consulta una fecha y NO es festivo)**:
```json
{
  "isHoliday": false
}
```
- **Response Body (cuando se consulta un año)**:
```json
{
  "year": 2026,
  "holidays": [
    {
      "date": "2026-01-01",
      "dayOfWeek": "THURSDAY",
      "name": "Año Nuevo",
      "scope": "national"
    },
    {
      "date": "2026-11-09",
      "dayOfWeek": "MONDAY",
      "name": "Nuestra Señora de la Soledad",
      "scope": "local"
    }
  ]
}
```

#### 3. GET `/api/v1/holidays/next`
- **Method**: GET
- **Path**: `/api/v1/holidays/next`
- **Query Parameters**:
  - `from`: string (formato `YYYY-MM-DD`, obligatorio)
- **Response HTTP status**: `200 OK`
- **Response Body**:
```json
{
  "date": "2026-10-12",
  "dayOfWeek": "MONDAY",
  "name": "Fiesta Nacional de España",
  "scope": "national",
  "daysUntil": 89
}
```

#### 4. Formato de Error Estándar (ADR-004)
Todas las respuestas de error (4xx/5xx) tendrán el siguiente formato JSON:
```json
{
  "error": "NombreDelError",
  "message": "Descripción detallada del error",
  "status": 404
}
```

---

## 5. Casos de Borde y Manejo de Errores

| Caso de Borde | Comportamiento Esperado | Implementación Técnica |
| :--- | :--- | :--- |
| **Directorio de datos vacío o corrupto** | Al arrancar, el servicio registrará advertencias en logs y se iniciará. Las consultas a fechas o años devolverán error estructurado HTTP 500 / 404. | Capturar excepciones `FileNotFoundError` o `json.JSONDecodeError` durante el arranque. Si no hay datos, levantar errores controlados en las llamadas. |
| **Fecha con formato inválido** | Responder HTTP 400 estructurado. | Usar validación automática de Pydantic o capturar excepciones en el parseo (`datetime.date.fromisoformat`) arrojando un error `INVALID_DATE_FORMAT`. |
| **Año no disponible** | Responder HTTP 404 estructurado indicando que no hay datos para el año. | Validar la existencia del año en el mapa en memoria de la base de datos local y propagar `DATA_NOT_FOUND`. |
| **Sin festivos futuros** | Responder HTTP 404 estructurado. | En `/holidays/next`, si tras buscar recursivamente en los años cargados no hay ningún festivo posterior o igual a la fecha especificada, lanzar `NO_NEXT_HOLIDAY_FOUND`. |

---

## 6. Estrategia de Testing

### Tests Unitarios e Integración (`calendar-service`)
1. **Configuración (`tests/test_config.py`)**:
   - Validar que la configuración de `Settings` carga adecuadamente variables de entorno y asigna defaults correctos.
2. **Base de Datos en Memoria (`tests/test_database.py`)**:
   - Validar que el cargador de ficheros JSON lee correctamente y parsea la estructura del base de datos.
   - Validar el cálculo de `dayOfWeek` (retornando nombres en inglés en mayúsculas como `MONDAY`, `TUESDAY`, etc.).
   - Validar el cálculo de `daysUntil` a partir de una fecha de referencia.
   - Proporcionar fixtures con datos simulados (ficheros JSON temporales) para aislar las pruebas.
3. **Controladores y Endpoints (`tests/test_api.py`)**:
   - Validar `/api/v1/health` (HTTP 200).
   - Validar `/api/v1/holidays` consultando festivos existentes, días ordinarios, años completos, y años que no existen (comprobando errores 404 con formato ADR-004).
   - Validar `/api/v1/holidays/next` comprobando el cálculo de días restantes y respuestas 404 estructuradas.

### Pruebas E2E (`home-assistant`)
1. Levantar el ecosistema completo con `docker compose up --build -d`.
2. Validar que todos los servicios y en especial `calendar-service` alcancen estado `running`.
3. Ejecutar `./scripts/healthcheck.sh` y certificar la salida correcta en verde con `Calendar Service /health` verificado en el puerto `8008`.
4. Comprobar llamadas desde el host usando comandos `curl`:
   - `curl -i http://localhost:8008/api/v1/health`
   - `curl -i "http://localhost:8008/api/v1/holidays?year=2026"`

---

## 7. Plan de Implementación (Checklist)

- [ ] **Fase 0: Repositorio y Entorno de Desarrollo (`calendar-service`)**
  - [ ] Crear la estructura de directorios: `app/` y `tests/`.
  - [ ] Crear `.gitignore` específico para Python.
  - [ ] Crear `requirements.txt` declarando `fastapi`, `uvicorn`, `pydantic`, `pydantic-settings`, `pytest` y `httpx`.
  - [ ] Crear `Dockerfile` basado en `python:3.11-slim` exponiendo el puerto `8000`.
  - [ ] Crear el workflow `.github/workflows/test.yml` para ejecutar automáticamente `pytest` en cada PR a la rama `main`.
  - [ ] Crear el archivo `.env.example` y el `.env` local (únicamente para desarrollo local, asegurando que `.env` está en `.gitignore`).
  - [ ] Crear `README.md` documentando la instalación, el formato JSON de los datos y los endpoints REST (el README debe incluir la especificación completa de todos los endpoints REST con sus parámetros de entrada, esquemas de respuesta y códigos de error, de acuerdo con el formato de error común de ADR-004).

- [ ] **Fase 1: Implementación del Código Fuente (`calendar-service`)**
  - [ ] Implementar la clase `Settings` en `app/config.py` manejando variables con `pydantic-settings`.
  - [ ] Implementar los modelos Pydantic de entrada y salida en `app/models.py` asegurando tipado e identificadores en inglés.
  - [ ] Implementar la base de datos en memoria en `app/database.py` que busque y cargue dinámicamente los ficheros `DATA_DIR/holidays/*.json` al iniciar, guardándolos en un mapa optimizado de festivos.
  - [ ] Implementar los endpoints y el enrutador en `app/main.py` controlando excepciones globales para formatear errores bajo la estructura común de ADR-004.
  - [ ] Escribir y validar la suite de pruebas unitarias y de integración en `tests/`.
  - [ ] Asegurar que `pytest` se ejecute localmente de forma satisfactoria.
  - [ ] Crear el archivo `CHANGELOG.md` del repositorio `calendar-service` con la entrada inicial bajo `[Sin publicar]` documentando la primera implementación del servicio.

- [ ] **Fase 2: Configuración de la Infraestructura en Home Assistant**
  - [ ] Crear el archivo de entorno `config/calendar-service.env` con parámetros por defecto.
  - [ ] Modificar `docker-compose.yml` para agregar el bloque de servicio `calendar-service` expuesto en puerto `8008`, enlazado a la red y montando el volumen de datos.
  - [ ] Actualizar el servicio `orchestrator` en `docker-compose.yml` inyectando `CALENDAR_SERVICE_BASE_URL` en su `environment` (se excluye la dependencia `depends_on` en esta fase al no haber interacción inmediata desde los plugins).

- [ ] **Fase 3: Observabilidad y Scripts de Sistema**
  - [ ] Actualizar `scripts/install.sh` para crear automáticamente la carpeta `$PROJECT_DIR/calendar-data/holidays` durante la instalación y actualizar trazas.
  - [ ] Actualizar `scripts/uninstall.sh` para indicar a través de la salida que los datos en `$PROJECT_DIR/calendar-data/` no se han eliminado y se preservan manualmente.
  - [ ] Modificar `scripts/healthcheck.sh` agregando `"calendar-service"` en la variable asociativa `CONTAINERS` y la validación HTTP `/api/v1/health` en el puerto `8008`.

- [ ] **Fase 4: Documentación de Sistema e Historial**
  - [ ] Crear el archivo [ADR-016: Integración del Servicio Calendario (calendar-service) en el Ecosistema Nova](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-016-integracion-calendar-service.md) con el contenido técnico y decisiones acordadas.
  - [ ] Insertar la referencia `[ADR-016: Integración del Servicio Calendario](file:///home-assistant/docs/adr/adr-016-integracion-calendar-service.md)` en la sección `Referencias` del archivo `home-assistant/.agent/skills/transversal/system-deployment/SKILL.md`.
  - [ ] Modificar `docs/services.md` actualizando el catálogo de servicios (tabla de resumen, total de microservicios de 12 a 13, diagrama ASCII y agregando sección para calendar-service).
  - [ ] Modificar `docs/architecture.md` agregando `calendar-service` al plano de procesamiento, listado de componentes y tabla de decisiones.
  - [ ] Registrar cronológicamente en el `CHANGELOG.md` del servicio y de `home-assistant` bajo `[Sin publicar]` todos los cambios integrados en este refinamiento.

- [ ] **Fase 5: Validación E2E del Sistema**
  - [ ] Crear un archivo JSON de prueba `calendar-data/holidays/2026.json` con algunos festivos oficiales.
  - [ ] Ejecutar `docker compose up --build -d` para levantar el ecosistema Nova.
  - [ ] Ejecutar `./scripts/healthcheck.sh` y certificar que todas las pruebas pasen en verde.
  - [ ] Realizar peticiones HTTP manuales a los endpoints del servicio mediante `curl` y verificar payloads.
