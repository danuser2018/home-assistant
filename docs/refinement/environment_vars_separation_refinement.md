# Refinamiento de la Feature: Aislamiento de Variables de Envío por Servicio

- **Archivo de origen**: [environment_vars_separation.md](file:///home/danuser2018/workspace/home-assistant/docs/features/environment_vars_separation.md)
- **Fecha**: 2026-07-02
- **Estado**: Refinado

---

## 1. Resumen y Contexto de Negocio

### Objetivo Principal
Reforzar el aislamiento de dominios y el principio de mínimo privilegio en el ecosistema Nova-2 mediante la eliminación del archivo de variables de entorno global compartido `config/assistant.env`. En su lugar, se creará un archivo de configuración `.env` independiente para cada microservicio gestionado por Docker, conteniendo exclusivamente los parámetros necesarios para sus responsabilidades.

### Actores y Flujo de Alto Nivel
1. **Docker Compose**: Durante el arranque de la plataforma, lee los archivos de configuración específicos desde la carpeta `config/` y pasa sus variables únicamente al contenedor correspondiente.
2. **Microservicios (STT, TTS, Orchestrator, System Service, Mail Watchdog, Identity Service)**: Inicializan sus procesos consumiendo de manera aislada sus respectivas variables de entorno sin visibilidad de las configuraciones de otros dominios.
3. **Instalador y Actualizador (`install.sh`, `update.sh`)**: Acceden de forma específica a las variables de descarga de modelos TTS (`TTS_MODEL_NAME`, `TTS_MODEL_URL`) en el archivo `config/tts-capability.env` en lugar de buscarlas en el antiguo archivo unificado.

---

## 2. Análisis de Servicios e Impacto

| Servicio | Tipo de Cambio | Descripción del Impacto |
| :--- | :--- | :--- |
| `stt-capability` | Modificar | Carga `config/stt-capability.env` en lugar de `config/assistant.env` en `docker-compose.yml`. |
| `tts-capability` | Modificar | Carga `config/tts-capability.env` en lugar de `config/assistant.env` en `docker-compose.yml`. |
| `orchestrator` | Modificar | Carga `config/orchestrator.env` en lugar de `config/assistant.env` en `docker-compose.yml`. |
| `system-service` | Modificar | Carga `config/system-service.env` en lugar de `config/assistant.env` en `docker-compose.yml`. |
| `mail-watchdog` | Modificar | Carga `config/mail-watchdog.env` en lugar de `config/assistant.env` en `docker-compose.yml`. |
| `identity-service` | Modificar | Carga `config/identity-service.env` en lugar de `config/assistant.env` en `docker-compose.yml`. |
| `interaction-manager`| Ninguno | No utiliza archivos `env_file`. Declara sus variables directamente inline en `docker-compose.yml`. |
| `mic-daemon` | Ninguno | Ya utiliza su archivo independiente `config/mic-daemon.env` de forma nativa. |
| `speaker-watchdog` | Ninguno | Ya utiliza su archivo independiente `config/speaker-watchdog.env` de forma nativa. |
| `home-assistant` | Modificar | Se elimina `config/assistant.env`. Se crean los 6 nuevos archivos `.env` independientes en `config/`. Se modifican `docker-compose.yml`, `scripts/install.sh`, `scripts/update.sh` y la documentación general. |

---

## 3. Especificación de Comportamiento (Criterios de Aceptación)

### Escenario 1: Aislamiento estricto de variables en contenedores
```gherkin
Dado que el microservicio "mail-watchdog" está configurado con "config/mail-watchdog.env"
Y el microservicio "identity-service" está configurado con "config/identity-service.env"
Cuando se inicia la plataforma mediante Docker Compose
Entonces el contenedor "mail-watchdog" dispone únicamente de las variables SMTP y sus políticas de reintentos
Y el contenedor "mail-watchdog" no tiene acceso a "USER_EMAIL" o "USER_NAME"
Y el contenedor "identity-service" dispone únicamente de las variables de identidad del usuario
Y el contenedor "identity-service" no tiene acceso a las credenciales "SMTP_PASSWORD"
```

### Escenario 2: Instalación de modelos TTS en el Host
```gherkin
Dado que el script "scripts/install.sh" está listo para su ejecución en el host
Y las variables "TTS_MODEL_NAME" y "TTS_MODEL_URL" se encuentran en "config/tts-capability.env"
Cuando el usuario ejecuta el script "scripts/install.sh"
Entonces el instalador lee con éxito "TTS_MODEL_NAME" y "TTS_MODEL_URL" desde "config/tts-capability.env"
Y descarga el modelo Piper TTS y su configuración JSON en la ruta "models/tts"
Y levanta los contenedores con sus respectivos archivos `.env` individuales
```

### Escenario 3: Actualización y reinicio de servicios
```gherkin
Dado que el script "scripts/update.sh" está listo para ejecutarse en el host
Y las variables "TTS_MODEL_NAME" y "TTS_MODEL_URL" se encuentran en "config/tts-capability.env"
Cuando el usuario ejecuta el script "scripts/update.sh"
Entonces el actualizador lee con éxito "TTS_MODEL_NAME" y "TTS_MODEL_URL" desde "config/tts-capability.env"
Y verifica la presencia del modelo descargando actualizaciones si fuesen necesarias
Y reinicia todos los contenedores Docker aplicando la separación de archivos de configuración
```

### Escenario 4: Verificación funcional del sistema
```gherkin
Dado que la plataforma se ha iniciado cargando exclusivamente los nuevos archivos `.env`
Cuando el usuario ejecuta la herramienta de diagnóstico "scripts/healthcheck.sh"
Entonces todos los contenedores pasan la comprobación de puerto y estado
Y todos los endpoints REST (/health o /ready) responden satisfactoriamente
Y el diagnóstico finaliza con un estado general OK
```

### Escenario 5: Verificación de la eliminación del archivo de configuración compartido
```gherkin
Dado que la plataforma se ha migrado a archivos de configuración individuales por servicio
Cuando se inspecciona el repositorio y el archivo "docker-compose.yml"
Entonces el archivo "config/assistant.env" no existe en el sistema de ficheros del repositorio
Y ningún servicio en "docker-compose.yml" referencia "config/assistant.env" en su directiva "env_file"
Y el comando "grep -r assistant.env ." no devuelve ningún resultado en los archivos de configuración activos
```

---

## 4. Diseño Técnico y Contratos

### Contratos de Configuración (Nuevos Archivos `.env`)

Todos los archivos se crearán en la carpeta `config/` del repositorio `home-assistant`.

#### 1. File: `config/stt-capability.env`
```env
# =============================================================================
# STT Capability Configuration (stt-capability)
# =============================================================================

# Faster-Whisper voice model to use.
# Options: tiny, base, small, medium
WHISPER_MODEL=base

# Device for inference processing: cpu or cuda
WHISPER_DEVICE=cpu

# Level of logging detail
LOG_LEVEL=INFO
```

#### 2. File: `config/tts-capability.env`
```env
# =============================================================================
# TTS Capability Configuration (tts-capability)
# =============================================================================

# Piper TTS voice model name.
TTS_MODEL_NAME=es_ES-carlfm-x_low

# Local directory where Piper models reside inside the container.
TTS_MODEL_DIR=/app/models

# URL for downloading the Piper TTS voice model (.onnx).
TTS_MODEL_URL=https://huggingface.co/rhasspy/piper-voices/resolve/main/es/es_ES/carlfm/x_low/es_ES-carlfm-x_low.onnx

# Level of logging detail
LOG_LEVEL=INFO
```

#### 3. File: `config/system-service.env`
```env
# =============================================================================
# System Service Configuration (system-service)
# =============================================================================

# Nova Assistant identity properties.
NOVA_NAME=Nova
NOVA_AUTHOR=Xeretre studios
NOVA_VERSION=2.0.0
NOVA_DESCRIPTION=Asistente personal de voz y automatización

# Level of logging detail
LOG_LEVEL=INFO
```

#### 4. File: `config/orchestrator.env`
```env
# =============================================================================
# Orchestrator Configuration (orchestrator)
# =============================================================================

# Level of logging detail
LOG_LEVEL=INFO
```

> **Nota arquitectónica**: Las variables `MAIL_PENDING_DIR` y `SYSTEM_SERVICE_BASE_URL` no se incluyen en este archivo `.env` porque no representan configuración del usuario, sino definiciones de arquitectura flexible del entorno Docker (análogas a las variables de URL base de los servicios del `interaction-manager`). Ambas se declaran como variables `environment` inline en `docker-compose.yml`, siguiendo el precedente establecido para la configuración de carpetas compartidas y URLs de servicios internos.

#### 5. File: `config/mail-watchdog.env`
```env
# =============================================================================
# Mail Watchdog Configuration (mail-watchdog)
# =============================================================================

# SMTP server credentials and connectivity.
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your_user@gmail.com
SMTP_PASSWORD=your_password
SMTP_FROM="Nova <your_user@gmail.com>"

# Retry and polling behavior settings.
MAIL_POLL_INTERVAL=2
MAIL_MAX_RETRIES=3
MAIL_BACKOFF_BASE=2

# Identity Service internal REST URL.
IDENTITY_SERVICE_BASE_URL=http://identity-service:8000

# Level of logging detail
LOG_LEVEL=INFO
```

#### 6. File: `config/identity-service.env`
```env
# =============================================================================
# Identity Service Configuration (identity-service)
# =============================================================================

# User identity information (Single Source of Truth).
USER_NAME=David
USER_EMAIL=david@example.com

# Level of logging detail
LOG_LEVEL=INFO
```

---

### Modificaciones en `docker-compose.yml`

Se reemplaza el archivo común `config/assistant.env` por cada archivo específico en la directiva `env_file`. Adicionalmente, se mueven las variables que antes se definían inline en `environment:` a sus respectivos archivos de configuración independientes para asegurar la consistencia.

```yaml
services:

  stt:
    image: danuser2018/stt-capability:latest
    container_name: stt-capability
    env_file:
      - config/stt-capability.env
    ports:
      - "8001:8000"
    restart: unless-stopped
    volumes:
      - ./models/stt:/root/.cache/huggingface
    networks:
      - assistant-network

  orchestrator:
    image: danuser2018/orchestrator:latest
    container_name: orchestrator
    env_file:
      - config/orchestrator.env
    environment:
      SYSTEM_SERVICE_BASE_URL: http://system-service:8000
      MAIL_PENDING_DIR: /shared/mail/pending
    volumes:
      - ./data/mail:/shared/mail
    ports:
      - "8002:8000"
    restart: unless-stopped
    depends_on:
      - system-service
    networks:
      - assistant-network

  system-service:
    image: danuser2018/system-service:latest
    container_name: system-service
    env_file:
      - config/system-service.env
    ports:
      - "8004:8000"
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 5s
      retries: 3
    networks:
      - assistant-network

  tts:
    image: danuser2018/tts-capability:latest
    container_name: tts-capability
    env_file:
      - config/tts-capability.env
    ports:
      - "8003:8000"
    volumes:
      - ./models/tts:/app/models
    restart: unless-stopped
    networks:
      - assistant-network

  mail-watchdog:
    image: danuser2018/mail-watchdog:latest
    container_name: mail-watchdog
    env_file:
      - config/mail-watchdog.env
    volumes:
      - ./data/mail:/shared/mail
    restart: unless-stopped
    depends_on:
      identity-service:
        condition: service_healthy
    networks:
      - assistant-network

  identity-service:
    image: danuser2018/identity-service:latest
    container_name: identity-service
    env_file:
      - config/identity-service.env
    ports:
      - "8005:8000"
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 5s
      retries: 3
    networks:
      - assistant-network
```

---

### Modificaciones en Scripts del Host

Se actualiza la lógica de los scripts de instalación y actualización para buscar las variables del modelo en `config/tts-capability.env`.

```bash
# Line change in scripts/install.sh (around line 118) and scripts/update.sh (around line 62)
get_env_var() {
    local var_name="$1"
    local env_file="$PROJECT_DIR/config/tts-capability.env"
    if [ -f "$env_file" ]; then
        grep -E "^${var_name}=" "$env_file" | head -n1 | cut -d'=' -f2- | tr -d '"' | tr -d "'"
    fi
}
```

---

## 5. Casos de Borde y Manejo de Errores

| Caso de Borde | Comportamiento Esperado | Implementación Técnico |
| :--- | :--- | :--- |
| **Falta un archivo `.env` al arrancar** | Docker Compose abortará el inicio con un mensaje descriptivo. | Docker Compose valida la presencia de los archivos definidos en `env_file`. Se mantendrán plantillas y documentación claras. |
| **Conflicto de variables duplicadas** | Prevalece la declaración del archivo específico. | Puesto que no se comparten archivos, el riesgo es nulo. Las variables inline residuales en `docker-compose.yml` se eliminan. |
| **Instalación/Actualización sin `config/tts-capability.env`** | El script usa valores por defecto (`es_ES-carlfm-x_low`). | Los scripts `install.sh` y `update.sh` disponen de variables de contingencia (`MODEL_NAME` y `MODEL_URL`) en caso de no poder leer el archivo. |

---

## 6. Estrategia de Testing

### Tests Unitarios
- No se requieren cambios en los tests unitarios de las imágenes de servicios individuales, ya que su lógica de lectura interna a través de `pydantic-settings` o `dotenv` sigue consumiendo las mismas variables sin cambios en sus identificadores.

### Tests de Integración E2E
1. **Validación de Inicio y Configuración**:
   - Detener el entorno actual: `docker compose down`.
   - Limpiar el entorno temporalmente y arrancar con los nuevos archivos: `docker compose up -d`.
   - Validar que cada servicio arranca correctamente.
2. **Auditoría de Entorno (Aislamiento)**:
   - Ejecutar un comando para comprobar que `mail-watchdog` no tiene cargadas variables de identidad y viceversa:
     ```bash
     docker exec mail-watchdog env | grep USER_EMAIL || true # Debe retornar vacío
     docker exec identity-service env | grep SMTP_PASSWORD || true # Debe retornar vacío
     ```
3. **Validación de Scripts**:
   - Eliminar localmente los modelos en `models/tts/`.
   - Ejecutar `./scripts/install.sh` para certificar que lee `config/tts-capability.env`, descarga los modelos correctamente y finaliza sin fallos.
4. **Verificación de Diagnóstico**:
   - Ejecutar `./scripts/healthcheck.sh` para verificar que la suite reporta un estado 100% verde (OK).

---

## 7. Plan de Implementación (Checklist)

- [ ] **Fase 1: Creación de los nuevos archivos de configuración**
  - [ ] Crear `config/stt-capability.env` con sus variables correspondientes.
  - [ ] Crear `config/tts-capability.env` con sus variables correspondientes.
  - [ ] Crear `config/system-service.env` con sus variables correspondientes.
  - [ ] Crear `config/orchestrator.env` con su variable `LOG_LEVEL`.
  - [ ] Crear `config/mail-watchdog.env` con sus variables correspondientes (incluyendo `IDENTITY_SERVICE_BASE_URL`).
  - [ ] Crear `config/identity-service.env` con sus variables correspondientes.

- [ ] **Fase 2: Actualización de Scripts y Definición de Contenedores**
  - [ ] Modificar `docker-compose.yml` para sustituir `config/assistant.env` por los respectivos archivos específicos y remover variables de entorno duplicadas.
  - [ ] Modificar la función `get_env_var` en `scripts/install.sh` para cargar las variables desde `config/tts-capability.env`.
  - [ ] Modificar la función `get_env_var` en `scripts/update.sh` para cargar las variables desde `config/tts-capability.env`.
  - [ ] Eliminar definitivamente el archivo obsoleto `config/assistant.env`.

- [ ] **Fase 3: Actualización de la Documentación del Sistema**
  - [ ] Modificar `docs/installation.md` para sustituir las referencias a `assistant.env` por las explicaciones de los nuevos archivos específicos de configuración.
  - [ ] Modificar `docs/services.md` para reflejar la tabla de variables por cada contenedor/archivo independiente.
    - [ ] Actualizar la cabecera de la tabla de variables de `identity-service` en `docs/services.md` sustituyendo el texto `"cargadas vía config/assistant.env"` por `"cargadas vía config/identity-service.env"`.
  - [ ] Modificar `docs/troubleshooting.md` para indicar al usuario qué archivo `.env` modificar en función de la naturaleza del problema (p. ej., problemas de SMTP -> `mail-watchdog.env`).
  - [ ] Crear `docs/adr/adr-010.md` documentando la decisión de separar `config/assistant.env` en archivos de configuración individuales por servicio como patrón estándar del ecosistema Nova-2.

- [ ] **Fase 4: Validación y Pruebas**
  - [ ] Ejecutar el ciclo de despliegue local mediante Docker Compose.
  - [ ] Auditar el aislamiento de variables dentro de los contenedores ejecutando comandos `env`.
  - [ ] Correr `./scripts/healthcheck.sh` para verificar que el sistema funciona correctamente.
  - [ ] Ejecutar `./scripts/install.sh` y `./scripts/update.sh` para validar su robustez.
