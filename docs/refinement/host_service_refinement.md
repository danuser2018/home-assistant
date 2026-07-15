# Refinamiento de la Feature: Primera Implementación del Servicio Host (host-service)

- **Archivo de origen**: [first_implementation.md](file:///home/danuser2018/workspace/host-service/doc/features/first_implementation.md)
- **Fecha**: 2026-07-15
- **Estado**: Refinado

---

## 1. Resumen y Contexto de Negocio

### Objetivo Principal
Implementar la primera versión del microservicio `host-service` y agregarlo formalmente al ecosistema de Nova (`home-assistant`). Este servicio actuará como una capa de abstracción del sistema operativo (Host Abstraction Layer - HAL), ofreciendo una API REST local estable. La primera versión se limitará al control del volumen y silenciado de audio del host utilizando la utilidad nativa de Linux `pactl`, compatible tanto con PulseAudio como con PipeWire.

La centralización de operaciones del sistema operativo en un servicio host nativo y aislado evita que los plugins de orquestación u otros servicios ejecuten comandos directamente en el host, protegiendo los límites de responsabilidades de los servicios y facilitando la modularidad y seguridad del sistema.

### Actores y Flujo de Alto Nivel
1. **Plugins / Clientes del Ecosistema (ej. VolumePlugin)**: Envían peticiones HTTP REST a `host-service` (en puerto host `8007`) para modificar o consultar el audio.
2. **Host Service (FastAPI app)**: Recibe y procesa las peticiones REST, validando los parámetros de entrada en inglés.
3. **pactl**: Utilidad CLI ejecutada en un subproceso del host por el `host-service` para interactuar con PipeWire/PulseAudio.
4. **systemd --user**: Gestor de servicios del host que administra el daemon de forma nativa en la sesión del usuario.

---

## 2. Análisis de Servicios e Impacto

| Servicio | Tipo de Cambio | Descripción del Impacto |
| :--- | :--- | :--- |
| `host-service` | Nuevo | Creación del microservicio completo utilizando FastAPI en Python. Estructura de código bajo el directorio `src/`, configuraciones con Pydantic Settings, controladores REST, servicios y modelos de datos. Implementación de una suite de pruebas automatizadas con `pytest` y configuración de un flujo de CI mediante GitHub Actions (`.github/workflows/test.yml`). Adición de un archivo `README.md` detallando el uso y pruebas. |
| `home-assistant` | Modificar | Integración del nuevo servicio nativo en los scripts de ciclo de vida (`install.sh`, `uninstall.sh`, `update.sh` y `healthcheck.sh`). Creación del archivo de configuración `config/host-service.env`. Actualización del catálogo de servicios (`docs/services.md`), descripción de la arquitectura (`docs/architecture.md`), del `CHANGELOG.md` general y de las guías de instalación (`docs/installation.md`) y resolución de problemas (`docs/troubleshooting.md`). |
| `orchestrator` | Modificar | Se requiere permitir que el contenedor de `orchestrator` se comunique con el servicio host nativo. Se añadirá `host.docker.internal` al mapeo de hosts locales (`extra_hosts`) en `docker-compose.yml` para posibilitar llamadas HTTP al puerto `8007` del host. |

---

## 3. Especificación de Comportamiento (Criterios de Aceptación)

### Escenario 1: Endpoint de Salud de host-service
```gherkin
Dado que el servicio "host-service" está en ejecución en el puerto 8007
Cuando se realiza una petición HTTP "GET http://localhost:8007/health"
Entonces el servicio responde con código de estado 200 OK
Y el cuerpo de la respuesta es exactamente {"status": "ok"}
```

### Escenario 2: Obtener volumen y mute actual
```gherkin
Dado que el servicio "host-service" está en ejecución
Cuando se realiza una petición HTTP "GET http://localhost:8007/v1/audio/volume"
Entonces el servicio ejecuta la consulta al sistema mediante "pactl"
Y responde con código de estado 200 OK
Y el cuerpo de la respuesta contiene "volume" (entero entre 0 y 100) y "muted" (booleano)
```

### Escenario 3: Modificar volumen absoluto con éxito
```gherkin
Dado que el volumen actual del sistema es de 50%
Cuando se realiza una petición HTTP "POST http://localhost:8007/v1/audio/volume/set" con el cuerpo {"volume": 80}
Entonces el servicio establece el volumen en 80% utilizando "pactl"
Y responde con código de estado 200 OK
Y el cuerpo de la respuesta confirma el nuevo estado {"volume": 80, "muted": false}
```

### Escenario 4: Intentar establecer volumen fuera de rango
```gherkin
Dado que el servicio "host-service" está en ejecución
Cuando se realiza una petición HTTP "POST http://localhost:8007/v1/audio/volume/set" con el cuerpo {"volume": 120}
Entonces el servicio rechaza la solicitud
Y responde con código de estado 422 Unprocessable Entity
Y el JSON de error sigue el estándar ADR-004 indicando error de validación
```

### Escenario 5: Subir volumen por pasos con éxito
```gherkin
Dado que el volumen actual del sistema es de 40%
Cuando se realiza una petición HTTP "POST http://localhost:8007/v1/audio/volume/up" con el cuerpo {"step": 5}
Entonces el servicio incrementa el volumen en un 5%
Y responde con código de estado 200 OK
Y el cuerpo de la respuesta es exactamente {"volume": 45, "muted": false}
```

### Escenario 6: Silenciar y reactivar sonido (Mute / Unmute)
```gherkin
Dado que el sistema no está silenciado
Cuando se realiza una petición HTTP "POST http://localhost:8007/v1/audio/mute"
Entonces el servicio silencia el sistema utilizando "pactl"
Y responde con código de estado 200 OK
Y el cuerpo de la respuesta confirma el estado {"volume": 45, "muted": true}
Y si luego se envía una petición HTTP "POST http://localhost:8007/v1/audio/unmute"
Entonces el servicio reactiva el sonido
Y responde con código de estado 200 OK
Y el cuerpo de la respuesta es {"volume": 45, "muted": false}
```

### Escenario 7: Alternar silenciado (Toggle mute)
```gherkin
Dado que el sistema no está silenciado
Cuando se realiza una petición HTTP "POST http://localhost:8007/v1/audio/toggle-mute"
Entonces el servicio cambia el silenciado a activado
Y responde con código de estado 200 OK
Y la respuesta es {"volume": 45, "muted": true}
```

### Escenario 8: Error asíncrono por fallo o ausencia de pactl
```gherkin
Dado que la utilidad "pactl" no está instalada en el sistema o la llamada devuelve un error
Cuando se realiza una petición HTTP "GET http://localhost:8007/v1/audio/volume"
Entonces el servicio captura el fallo de ejecución de comandos de forma segura
Y responde con código de estado 503 Service Unavailable
Y el JSON devuelto es estructurado bajo ADR-004:
"""
{
  "error": "HOST_AUDIO_SERVICE_UNAVAILABLE",
  "message": "The system audio control interface (pactl) is unavailable or failed to execute.",
  "status": 503
}
"""
```

---

## 4. Diseño Técnico y Contratos

### Variables de Entorno (`home-assistant/config/host-service.env`)
Se configurará el microservicio utilizando un archivo de entorno independiente en el directorio central de configuraciones de Nova:
```env
# =============================================================================
# Host Service Configuration (host-service)
# =============================================================================

# Server network bindings
HOST=0.0.0.0
PORT=8007

# Service logging
LOG_LEVEL=INFO
```

### Clase de Configuración (`src/config.py`)
Utiliza `pydantic-settings` para cargar y validar variables de entorno (sintaxis **Pydantic v2**):
```python
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env")

    HOST: str = "0.0.0.0"
    PORT: int = 8007
    LOG_LEVEL: str = "INFO"

settings = Settings()
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

#### 2. GET `/v1/audio/volume`
- **Method**: GET
- **Path**: `/v1/audio/volume`
- **Response HTTP status**: `200 OK`
- **Response Body**:
```json
{
  "volume": 50,
  "muted": false
}
```

#### 3. POST `/v1/audio/volume/up`
- **Method**: POST
- **Path**: `/v1/audio/volume/up`
- **Request Body**:
```json
{
  "step": 5
}
```
- **Response HTTP status**: `200 OK`
- **Response Body**:
```json
{
  "volume": 55,
  "muted": false
}
```

#### 4. POST `/v1/audio/volume/down`
- **Method**: POST
- **Path**: `/v1/audio/volume/down`
- **Request Body**:
```json
{
  "step": 5
}
```
- **Response HTTP status**: `200 OK`
- **Response Body**:
```json
{
  "volume": 50,
  "muted": false
}
```

#### 5. POST `/v1/audio/volume/set`
- **Method**: POST
- **Path**: `/v1/audio/volume/set`
- **Request Body**:
```json
{
  "volume": 80
}
```
- **Response HTTP status**: `200 OK`
- **Response Body**:
```json
{
  "volume": 80,
  "muted": false
}
```

#### 6. POST `/v1/audio/mute`
- **Method**: POST
- **Path**: `/v1/audio/mute`
- **Response HTTP status**: `200 OK`
- **Response Body**:
```json
{
  "volume": 80,
  "muted": true
}
```

#### 7. POST `/v1/audio/unmute`
- **Method**: POST
- **Path**: `/v1/audio/unmute`
- **Response HTTP status**: `200 OK`
- **Response Body**:
```json
{
  "volume": 80,
  "muted": false
}
```

#### 8. POST `/v1/audio/toggle-mute`
- **Method**: POST
- **Path**: `/v1/audio/toggle-mute`
- **Response HTTP status**: `200 OK`
- **Response Body**:
```json
{
  "volume": 80,
  "muted": true
}
```

#### 9. Error Respuestas (Estándar ADR-004)
Cualquier fallo de validación o del proveedor externo retornará un esquema común:

- **Error de Ejecución de pactl (HTTP 503)**:
```json
{
  "error": "HOST_AUDIO_SERVICE_UNAVAILABLE",
  "message": "The system audio control interface (pactl) is unavailable or failed to execute.",
  "status": 503
}
```

- **Error de Validación (HTTP 422)**:
```json
{
  "error": "VALIDATION_ERROR",
  "message": "Volume value must be between 0 and 100.",
  "status": 422
}
```

---

## 5. Casos de Borde y Manejo de Errores

| Caso de Borde | Comportamiento Esperado | Implementación Técnica |
| :--- | :--- | :--- |
| **Volumen mayor que 100 o menor que 0** | Lanzar error de validación REST y responder HTTP 422 formateado. | Usar restricciones Pydantic `Field(ge=0, le=100)` en el esquema del payload y mapear `RequestValidationError` en FastAPI a la respuesta estructurada de error. |
| **Múltiples canales con diferente volumen** | Devolver el volumen medio del canal izquierdo y derecho o el primer volumen encontrado. | El parser Regex en Python extraerá todos los porcentajes de volumen retornados por `pactl get-sink-volume` y tomará el primer valor coincidente, que es el predeterminado para el canal izquierdo/derecho en la mayoría de sistemas estéreo. |
| **pactl no disponible o sin privilegios de ejecución** | Retornar una excepción controlada HTTP 503 indicando que el audio del host no está disponible. | Atrapar `FileNotFoundError` o `PermissionError` al intentar invocar `subprocess.run(["pactl", ...])` en la capa de servicios e interceptarlo con un manejador de excepciones global en FastAPI. |
| **Concurrencia en cambios de volumen** | Ejecutar comandos del sistema de forma secuencial y retornar el estado final correcto. | Las llamadas de volumen son llamadas de ejecución rápida mediante subprocesos locales de corta duración. En caso de alto tráfico concurrente, las llamadas a `pactl` se ordenan naturalmente a nivel del sistema operativo. |

---

## 6. Estrategia de Testing

### Tests Unitarios y de Integración (`host-service`)
1. **Configuración (`tests/test_config.py`)**:
   - Validar que la inicialización de `Settings` utiliza los valores por defecto si no existen en el entorno.
2. **Servicio y Ejecutor de Comandos (`tests/test_audio_service.py`)**:
   - Mockear la salida de `subprocess.run` para simular diferentes respuestas de `pactl get-sink-volume` y `pactl get-sink-mute`.
   - Validar el algoritmo de parseo con expresiones regulares para salidas multicanal reales.
   - Simular errores (código de salida no cero, comando no disponible) y certificar que lanza una excepción de tipo `HostAudioServiceError` controlada.
3. **Endpoints de API (`tests/test_api.py`)**:
   - Utilizar FastAPI `TestClient` para simular peticiones REST a los endpoints de volumen.
   - Validar códigos de estado `200`, `422` y `503` con respuestas que coincidan estrictamente con el estándar ADR-004.
   - Probar condiciones límite (valores `0`, `100`, `-1`, `101`).

### Pruebas de Integración y Despliegue E2E (`home-assistant`)
1. Desplegar localmente el servicio de host ejecutando `./scripts/install.sh` y comprobar que el servicio `host-service` se arranca como un systemd user service.
2. Validar que la salida del script `./scripts/healthcheck.sh` registre el estado del nuevo microservicio systemd de forma satisfactoria.
3. Ejecutar peticiones de prueba desde el host usando `curl`:
   - `curl -i http://localhost:8007/health`
   - `curl -i http://localhost:8007/v1/audio/volume`
4. Validar la conectividad desde un contenedor Docker simulando una petición REST del orquestador:
   - `docker compose exec orchestrator curl -i http://host.docker.internal:8007/health`
5. Validar la desinstalación ejecutando `./scripts/uninstall.sh` y certificar que:
   - La unidad `host-service.service` queda detenida y deshabilitada (`systemctl --user is-active host-service` devuelve `inactive`).
   - El puerto `8007` queda liberado (ninguna petición `curl http://localhost:8007/health` responde).

---

## 7. Plan de Implementación (Checklist)

- [ ] **Fase 0: Implementación del Microservicio `host-service`**
  - [ ] Crear el archivo `.gitignore` configurado para ignorar entornos virtuales de Python (`venv/`), carpetas de caché (`__pycache__/`, `.pytest_cache/`, `.coverage`) y archivos `.env` locales.
  - [ ] Crear el archivo `requirements.txt` con las dependencias requeridas:
    ```text
    fastapi>=0.110.0
    uvicorn>=0.28.0
    pydantic>=2.6.0
    pydantic-settings>=2.2.0
    pytest>=8.0.0
    pytest-asyncio>=0.23.0
    ```
  - [ ] Crear la estructura de directorios bajo `src/`: `src/config.py`, `src/main.py`, `src/app.py`, `src/routes/`, `src/services/`, `src/models/`.
  - [ ] Implementar el servicio de audio en `src/services/audio.py` que ejecute comandos `pactl` mediante `subprocess.run` y parsee la salida del volumen y mute actual de forma robusta.
  - [ ] Implementar los modelos de Pydantic en `src/models/audio.py` y `src/models/error.py` que definan los contratos JSON y las firmas del error.
  - [ ] Implementar los endpoints en `src/routes/audio.py` y `src/routes/health.py` mapeados a los controladores del servicio.
  - [ ] Configurar el control global de excepciones en `src/app.py` para capturar fallos del sistema o de validación de volumen y devolver respuestas con formato ADR-004.
  - [ ] Escribir los tests automatizados en el directorio `tests/` para verificar el comportamiento de validación y de los endpoints REST mockeando la CLI `pactl`.
  - [ ] Crear el archivo `README.md` del proyecto que incluya:
    - Descripción del servicio host como Host Abstraction Layer (HAL).
    - Guía de instalación rápida local con variables y dependencias.
    - Documentación y catálogo interactivo de todos los endpoints REST expuestos.
    - Instrucciones para la ejecución local de las pruebas con `pytest`.
  - [ ] Configurar la GitHub Action en `.github/workflows/test.yml` para ejecutar automáticamente las pruebas con `pytest` y reportar la cobertura cuando se abra una Pull Request o se suban cambios a `main`.

- [ ] **Fase 1: Configuración de la Infraestructura en Home Assistant**
  - [ ] Crear el archivo de variables de entorno predeterminado en `config/host-service.env` con el binding `HOST=0.0.0.0` y `PORT=8007`.
  - [ ] Modificar `docker-compose.yml` en la sección del servicio `orchestrator` agregando la sección `extra_hosts` para mapear `host.docker.internal` al gateway del host:
    ```yaml
      orchestrator:
        ...
        extra_hosts:
          - "host.docker.internal:host-gateway"
    ```
  - [ ] Actualizar el instalador del sistema `scripts/install.sh`:
    - Definir variables `HOST_SERVICE_DIR` y `HOST_SERVICE_VENV`.
    - Añadir lógica para validar la existencia del repositorio `host-service`.
    - Crear el entorno virtual e instalar las dependencias de `requirements.txt`.
    - Generar el archivo de servicio de usuario de systemd `~/.config/systemd/user/host-service.service`.
    - Cargar e iniciar el servicio mediante comandos de usuario `systemctl`.
  - [ ] Actualizar el desinstalador `scripts/uninstall.sh` para detener, deshabilitar y eliminar el servicio `host-service.service`.
  - [ ] Actualizar el actualizador `scripts/update.sh` para instalar dependencias actualizadas en el entorno virtual de `host-service` y reiniciar su unidad systemd.
  - [ ] Actualizar el validador `scripts/healthcheck.sh` para verificar el estado de salud activo del servicio systemd `host-service` y realizar una llamada de prueba al endpoint `/health` en el puerto `8007`.

- [ ] **Fase 2: Actualización de Skills de Asistente**
  - [ ] Modificar la skill `system-deployment` (`home-assistant/.agent/skills/transversal/system-deployment/SKILL.md`) agregando la referencia al nuevo ADR-013 de integración de `host-service`.
  - [ ] Modificar la skill `audio-subsystem` (`home-assistant/.agent/skills/domains/audio-subsystem/SKILL.md`) agregando la referencia al nuevo ADR-013 por el control del volumen a nivel de host.
  - [ ] Modificar la skill `service-responsibilities` (`home-assistant/.agent/skills/transversal/service-responsibilities/SKILL.md`) agregando la referencia al nuevo ADR-013 justificando el aislamiento de la ejecución en el host.

- [ ] **Fase 3: Documentación del Sistema**
  - [ ] Modificar el catálogo de servicios en [docs/services.md](file:///home/danuser2018/workspace/home-assistant/docs/services.md):
    - Actualizar la cabecera del catálogo cambiando el conteo total de **11 a 12 microservicios (8 en Docker y 4 en el Host)**.
    - Agregar `host-service` como fila en la tabla resumen inicial de servicios.
    - Crear la sección detallada de `host-service` dentro de "Servicios del Host" con sus endpoints, variables de entorno y comandos de gestión `systemctl`.
    - Actualizar el **diagrama ASCII de comunicaciones** de la sección "Comunicación entre Servicios" añadiendo `host-service` en el bloque `HOST (Linux)` y la ruta de conexión `orchestrator → host.docker.internal:8007 → host-service`.
  - [ ] Modificar la descripción de la arquitectura en [docs/architecture.md](file:///home/danuser2018/workspace/home-assistant/docs/architecture.md):
    - Actualizar la **tabla de topología general** (sección "Topología General") añadiendo `host-service` en la fila del Plano Hardware (Systemd User Services).
    - Actualizar la sección **"Descripción de Componentes / Servicios del Host"** con una entrada para `host-service` detallando su rol, repositorio, lenguaje y API.
    - Actualizar el **diagrama de Red Interna de Docker** añadiendo la ruta de salida `orchestrator → host.docker.internal:8007` hacia el host físico.
    - Actualizar la **tabla de Decisiones de Diseño Clave (ADRs)** al final del documento añadiendo la entrada para ADR-013.
  - [ ] Crear el registro de decisión arquitectónica [ADR-013](docs/adr/adr-013-integracion-host-service.md) justificando formalmente la adición de este nuevo servicio en el ecosistema. *(Ver borrador de referencia al final de esta sección.)*
  - [ ] Modificar `CHANGELOG.md` en `home-assistant` bajo la sección `[Sin publicar]` para registrar la adición de `host-service`, su integración en los scripts del sistema, el nuevo ADR-013 y las actualizaciones documentales correspondientes.
  - [ ] Modificar la guía de instalación en [docs/installation.md](file:///home/danuser2018/workspace/home-assistant/docs/installation.md) para añadir el repositorio de `host-service` en la sección de clonado, añadir la descripción de `host-service` y sus variables de entorno en la sección de configuración de servicios del host, actualizar los comandos de verificación de estado y añadir el archivo de entorno en la estructura de directorios.
  - [ ] Modificar la guía de resolución de problemas en [docs/troubleshooting.md](file:///home/danuser2018/workspace/home-assistant/docs/troubleshooting.md) para añadir una nueva sección de solución de fallos relacionados con `host-service` (fallos de `pactl`, de comunicación de red entre Docker y host, y problemas del servicio systemd) y actualizar los comandos de diagnóstico rápido.

- [ ] **Fase 4: Verificación E2E y Pruebas**
  - [ ] Ejecutar `./scripts/install.sh` y certificar el correcto arranque local.
  - [ ] Ejecutar `./scripts/healthcheck.sh` y certificar que la salida final es `Sistema operativo — N/N comprobaciones OK` sin fallos.
  - [ ] Validar la API mediante comandos `curl` desde el host y desde dentro del contenedor `orchestrator` utilizando `host.docker.internal`.

---

### Borrador de Referencia: ADR-013

> **Nota**: El siguiente contenido es un borrador de referencia para facilitar la redacción del ADR formal. La creación del archivo `docs/adr/adr-013-integracion-host-service.md` es una tarea de la Fase 3.

**ADR-013: Integración del Servicio Host (host-service) en el Ecosistema Nova**

- **Fecha**: 2026-07-15
- **Estado**: Propuesto

**Contexto**

El asistente de voz local Nova-2 interactúa con aspectos físicos del host como volumen de audio, brillo de pantalla, bluetooth, estado de energía y control de aplicaciones.
Tradicionalmente, para realizar estas acciones, los plugins del orquestador ejecutaban comandos directamente sobre el sistema operativo. Sin embargo, bajo la arquitectura modular de Nova (ADR-002) y la asignación de responsabilidades (`service-responsibilities`), los plugins de orquestación (que residen en Docker) deben carecer de lógica de negocio del host y no deben tener acceso a shells de comandos arbitrarios por motivos de seguridad y aislamiento.

Además, los contenedores Docker son inherentemente ciegos al hardware físico y a las herramientas de control de la sesión del usuario del host (como `pactl` para audio). Para resolver esto, necesitamos una capa de abstracción estable expuesta en red local que encapsule el acceso a las operaciones del sistema del host.

**Decisión**

Se decide integrar el nuevo microservicio `host-service` en el ecosistema Nova bajo las siguientes directivas:
1. **Entorno de Ejecución**: Desplegar el microservicio directamente en el host como servicio de usuario systemd (`systemd --user`), asegurando que herede los privilegios del entorno del usuario de la sesión de sonido (PulseAudio/PipeWire) sin requerir privilegios de superusuario `root`.
2. **Puerto de API**: Exponer la API HTTP REST local del servicio en el puerto del host `8007`.
3. **Acceso desde Contenedores**: Configurar la sección `extra_hosts` en `docker-compose.yml` para mapear `host.docker.internal` al gateway del host (`host-gateway`) en el servicio `orchestrator`, permitiendo a los plugins REST invocar comandos en el host a través del endpoint `http://host.docker.internal:8007`.
4. **Seguridad e Idempotencia**: Clasificar las operaciones y encapsular las llamadas de comandos en una API estructurada basada en FastAPI. La primera iteración del servicio implementará exclusivamente operaciones idempotentes y controladas de volumen de audio usando `pactl`.

**Consecuencias**

* **(+) Aislamiento y Seguridad**: El orquestador y sus plugins no ejecutan comandos directamente ni requieren binarios instalados en su contenedor. Solo invocan endpoints estructurados sobre la API del host.
* **(+) Portabilidad de API**: Los plugins consumen un contrato REST unificado en inglés, ocultando la herramienta subyacente (`pactl`, `amixer`, etc.). Si cambia el backend de sonido, la API del Host Service sigue siendo la misma.
* **(+) Alineación con Estándares**: El servicio sigue el aislamiento de variables (ADR-010) y los esquemas comunes de versionado y errores (ADR-004).
* **(-) Complejidad de Red**: Requiere configurar la resolución de nombres de host locales (`extra_hosts`) para cruzar la frontera de red del contenedor Docker hacia el host físico.
