# Refinamiento de la Feature: Integración de NATS en el Ecosistema Nova (Fase 1)

- **Archivo de origen**: [nats.md](file:///home/danuser2018/workspace/home-assistant/docs/features/nats.md)
- **Fecha**: 2026-07-17
- **Estado**: Refinado

---

## 1. Resumen y Contexto de Negocio

### Objetivo Principal
Integrar el servidor oficial de mensajería **NATS** como un nuevo servicio Docker de infraestructura dentro de la red del ecosistema Nova. Esta fase (Fase 1) se enfoca exclusivamente en el despliegue del contenedor, su inclusión en la topología de red, la garantía de su salud operativa mediante healthchecks locales y su documentación formal. Su propósito es dejar la infraestructura totalmente preparada para soportar futuras comunicaciones asíncronas y eventos distribuidos sin alterar el funcionamiento síncrono actual del asistente.

### Actores y Flujo de Alto Nivel
1. **Docker Compose**: Arranca el contenedor de NATS utilizando la imagen oficial basada en Alpine.
2. **NATS Server**: Inicializa el broker en el puerto cliente estándar `4222` y levanta el servidor de monitoreo HTTP en el puerto interno `8222`.
3. **Healthcheck**: Utiliza `wget` dentro del propio contenedor para realizar peticiones periódicas a `http://localhost:8222/healthz`.
4. **Desarrollador / Administrador**: Puede conectarse al servidor NATS desde el host a través del puerto expuesto `4222` para tareas de depuración y pruebas.
5. **Microservicios (fases futuras)**: Podrán resolver el nombre de host `nats` y conectarse al puerto `4222` dentro de la red privada para publicar y consumir eventos.

---

## 2. Análisis de Servicios e Impacto

| Servicio | Tipo de Cambio | Descripción del Impacto |
| :--- | :--- | :--- |
| `home-assistant` | Modificar | - Modificar `docker-compose.yml` para añadir el servicio `nats`. <br>- Modificar `scripts/healthcheck.sh` para incorporar la comprobación de estado de `nats` (verificando que esté activo e inspeccionando su health status de Docker, además de probar el socket `4222` desde el host). <br>- Actualizar `docs/services.md` actualizando el total de microservicios a 14, agregando la descripción de `nats` y actualizando el diagrama ASCII de red. <br>- Actualizar `docs/architecture.md` incorporando `nats` en el plano de procesamiento, listado de componentes y diagrama de red. <br>- Crear el registro de decisión de arquitectura `docs/adr/adr-017-integracion-nats.md`. <br>- Actualizar `CHANGELOG.md` documentando los cambios de infraestructura. |
| `calendar-service` | Modificar | - Modificar la skill transversal `communication-patterns` y la skill transversal `system-deployment` en sus archivos maestros en `home-assistant/.agent/skills/...` para añadir la referencia al nuevo `ADR-017` en sus secciones de `Referencias` (los cambios se propagan a `calendar-service` mediante enlace simbólico). |

---

## 3. Especificación de Comportamiento (Criterios de Aceptación)

### Escenario 1: Despliegue exitoso del servicio NATS
```gherkin
Dado que el ecosistema Nova se despliega utilizando Docker Compose
Cuando todos los contenedores se inician correctamente
Entonces el contenedor "nats" debe reportar un estado "running"
Y el estado de salud (health status) del contenedor debe ser "healthy"
```

### Escenario 2: Disponibilidad del puerto de mensajería desde el Host
```gherkin
Dado que el servicio "nats" está en ejecución y saludable
Cuando se realiza una comprobación de socket TCP al puerto 4222 en "localhost"
Entonces el puerto debe aceptar conexiones entrantes
```

### Escenario 3: Resolución de DNS interno y conectividad en el ecosistema
```gherkin
Dado que los contenedores del ecosistema Nova están conectados a la red "assistant-network"
Cuando se ejecuta una resolución de nombre de host "nats" desde el contenedor "interaction-manager"
Entonces el nombre de host debe resolverse a la dirección IP interna del contenedor de NATS
Y el puerto 4222 de "nats" debe ser accesible a través de la red interna
```

### Escenario 4: Ausencia de regresiones en el funcionamiento actual del asistente
```gherkin
Dado que el servicio "nats" ha sido desplegado e incorporado a la red interna
Cuando se realizan llamadas a los endpoints de la API de Nova (por ejemplo, "GET http://localhost:8004/health" de system-service o "GET http://localhost:8008/api/v1/health" de calendar-service)
Entonces los servicios existentes deben responder con código HTTP 200 OK
Y el pipeline de voz debe funcionar sin alteraciones
```

---

## 4. Diseño Técnico y Contratos

### Definición en Docker Compose (`home-assistant/docker-compose.yml`)
Se añadirá la definición del servicio `nats` utilizando la imagen oficial basada en Alpine para permitir el uso de `wget` en el healthcheck. Se habilitará el puerto de monitoreo interno `8222` mediante el comando de inicio, pero no se expondrá al host.

```yaml
  nats:
    image: nats:2.10-alpine
    container_name: nats
    command: "-m 8222"  # Habilita el puerto de monitoreo interno para el healthcheck
    ports:
      - "4222:4222"     # Puerto de clientes expuesto al host para desarrollo y depuración
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8222/healthz"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s
    networks:
      - assistant-network
```

No se creará ningún archivo `.env` en la carpeta `config/` ya que el servicio no requiere parametrización de entorno para esta fase (RF-7).

---

## 5. Casos de Borde y Manejo de Errores

| Caso de Borde | Comportamiento Esperado | Implementación Técnica |
| :--- | :--- | :--- |
| **Puerto 4222 ocupado en el Host** | El contenedor fallará al arrancar debido a un conflicto de binding de puerto. El comando `docker compose ps` reportará el fallo. | El administrador del sistema debe liberar el puerto ocupado en el host o modificar localmente el mapeo de puertos externos si es necesario. |
| **Puerto de monitoreo deshabilitado** | El healthcheck del contenedor fallará permanentemente y su estado pasará a "unhealthy". | Garantizar que el parámetro `command: "-m 8222"` esté presente en el servicio de `docker-compose.yml`. |
| **Desconexión temporal de la red Docker** | Los servicios del ecosistema no podrán resolver el nombre de host `nats` y registrarán fallos de conexión (en fases futuras). | La política de reinicio `unless-stopped` y la resiliencia del driver bridge de Docker restaurarán la conectividad. |

---

## 6. Estrategia de Testing

### Pruebas de Despliegue e Integración (`home-assistant`)
1. **Verificación de Contenedor**:
   - Levantar el ecosistema completo: `docker compose up --build -d`.
   - Validar que el servicio `nats` se encuentre en estado `running` y `healthy` usando `docker compose ps`.
2. **Prueba de Conectividad Host-Container**:
   - Comprobar que el puerto cliente está disponible desde el host usando un verificador de sockets, por ejemplo: `nc -zv localhost 4222` o equivalentemente `bash -c "</dev/tcp/localhost/4222"`.
3. **Prueba de Conectividad Inter-Container**:
   - Ejecutar una prueba dentro de un contenedor en ejecución (por ejemplo, `interaction-manager`) para verificar que resuelve el host `nats` y alcanza el puerto:
     `docker compose exec interaction-manager nc -zv nats 4222`
4. **Verificación de Regresión**:
   - Ejecutar el script `./scripts/healthcheck.sh` en el host para certificar que todos los servicios anteriores siguen en verde y que la adición de NATS no interfiere.

---

## 7. Plan de Implementación (Checklist)

- [ ] **Fase 1: Registro de la Decisión de Arquitectura**
  - [ ] Crear el archivo [ADR-017: Integración de NATS como Message Broker en el Ecosistema Nova](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-017-integracion-nats.md), incluyendo una sección que justifique su coexistencia con el filesystem-bus actual (definido en ADR-001 y ADR-006).
  - [ ] Añadir la referencia a `ADR-017` en la sección de `Referencias` de la skill `system-deployment` en el archivo maestro de `home-assistant` (en [SKILL.md](file:///home/danuser2018/workspace/home-assistant/.agent/skills/transversal/system-deployment/SKILL.md)), corregir la referencia a `ADR-016` rota en ese archivo para que apunte a `home-assistant/docs/adr/`, y verificar su propagación automática.
  - [ ] Añadir la referencia a `ADR-017` en la sección de `Referencias` de la skill `communication-patterns` en el archivo maestro de `home-assistant` (en [SKILL.md](file:///home/danuser2018/workspace/home-assistant/.agent/skills/transversal/communication-patterns/SKILL.md)), y verificar su propagación automática.

- [ ] **Fase 2: Orquestación e Infraestructura en Docker**
  - [ ] Modificar `docker-compose.yml` para agregar la definición del servicio `nats` con imagen `nats:2.10-alpine`, comando `-m 8222`, mapeo de puertos `4222:4222`, healthcheck con `wget`, red y política de reinicio.

- [ ] **Fase 3: Observabilidad y Scripts de Sistema**
  - [ ] Modificar el bucle de validación de contenedores en `scripts/healthcheck.sh` para verificar tanto el estado `running` del contenedor como el Docker health status (`healthy`) para aquellos que tengan healthcheck, y añadir `"nats"="nats"` al mapa asociativo `CONTAINERS`.
  - [ ] Modificar `scripts/healthcheck.sh` añadiendo una prueba de conexión TCP a `localhost:4222` en la sección de "Endpoints" utilizando sockets bash para certificar que el broker responde.

- [ ] **Fase 4: Documentación del Sistema e Historial**
  - [ ] Modificar `docs/services.md` actualizando la introducción (14 microservicios), la tabla resumen de servicios (añadiendo `nats`), agregando una subsección detallando `nats` (repositorio oficial, puerto, healthcheck y propósitos futuros), y actualizando el diagrama de flujo de comunicación ASCII para incluir el nodo `nats`.
  - [ ] Modificar `docs/architecture.md` agregando `nats` en el plano de procesamiento de la tabla de Topología General, en la descripción de componentes bajo la sección de Docker, en el diagrama ASCII de red interna y agregando la fila correspondiente a `ADR-017` en la tabla de Decisiones de Diseño Clave.
  - [ ] Registrar cronológicamente los cambios en `CHANGELOG.md` del repositorio `home-assistant` bajo la sección `[Sin publicar]`.

- [ ] **Fase 5: Validación E2E del Sistema**
  - [ ] Ejecutar `docker compose up -d` para desplegar el sistema.
  - [ ] Validar el estado `healthy` del contenedor `nats` en `docker compose ps`.
  - [ ] Ejecutar `./scripts/healthcheck.sh` y certificar el estado OK de todo el sistema incluyendo la conexión a NATS.
