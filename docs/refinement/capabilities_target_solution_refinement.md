# Refinamiento de la Feature: Centralización del destinatario de correo en Identity Service

- **Archivo de origen**: [capabilities_target_solution.md](file:///home/danuser2018/workspace/orchestrator/doc/features/capabilities_target_solution.md)
- **Fecha**: 2026-07-02
- **Estado**: Refinado

---

## 1. Resumen y Contexto de Negocio

### Objetivo Principal
Centralizar la gestión del correo electrónico del usuario final en el microservicio `identity-service`, que actúa como la única fuente de verdad (Single Source of Truth) para la información personal en el ecosistema Nova. Esto desacopla completamente al `orchestrator` de tener que conocer o propagar esta información privada del usuario.

### Actores y Flujo de Alto Nivel
1. **User**: Inicia la petición de voz ("¿Qué sabes hacer?").
2. **Orchestrator**: Identifica la intención, recopila las capacidades y deposita un archivo JSON en la carpeta compartida `pending/` (buzón de salida). Este archivo ya no contiene la clave `to` con la dirección del destinatario.
3. **Mail Watchdog**: Detecta el archivo JSON en `pending/`, realiza una petición síncrona HTTP GET a la API REST de `identity-service` para resolver la dirección de correo actual, y despacha el correo mediante SMTP a dicho destinatario.
4. **Identity Service**: Expone la API REST que sirve la información personal del usuario, incluyendo el email de destino.

---

## 2. Análisis de Servicios e Impacto

| Servicio | Tipo de Cambio | Descripción del Impacto |
| :--- | :--- | :--- |
| `identity-service` | Ninguno | Ya implementa y expone el endpoint necesario `GET /v1/identity/email` que devuelve el correo electrónico del usuario. |
| `orchestrator` | Modificar | Se elimina la variable de configuración `user_email` de `core/config.py`. En `plugins/capabilities/main.py`, se elimina la propiedad `"to"` del payload JSON del archivo generado en `MAIL_PENDING_DIR`. |
| `mail-watchdog` | Modificar | Se modifica el modelo `MailMessage` en `src/models.py` para eliminar el campo obligatorio `to`. Se añade la variable de entorno `IDENTITY_SERVICE_BASE_URL` en `src/config.py`. En `src/processor.py`, se implementa una llamada HTTP GET a `http://identity-service:8000/v1/identity/email` para obtener el destinatario de forma dinámica en cada envío. |

---

## 3. Especificación de Comportamiento (Criterios de Aceptación)

### Escenario 1: Envío exitoso del correo de capacidades
```gherkin
Dado que el Orchestrator ha procesado la petición "¿Qué sabes hacer?"
Y ha depositado un archivo JSON de correo sin el campo "to" en la carpeta pending
Cuando el Mail Watchdog escanea y procesa dicho archivo
Y consulta exitosamente a Identity Service en GET /v1/identity/email obteniendo "david@example.com"
Entonces el Mail Watchdog envía el correo SMTP a "david@example.com"
Y elimina el archivo de la carpeta de procesamiento
```

### Escenario 2: Reintento por caída temporal de Identity Service
```gherkin
Dado que un archivo de correo sin el campo "to" está listo para ser procesado
Cuando el Mail Watchdog intenta procesarlo
Y la petición HTTP GET a Identity Service falla debido a un error de red o timeout
Entonces el Mail Watchdog registra una advertencia en los logs
Y no realiza el envío SMTP
Y programa un reintento utilizando la política de backoff exponencial incrementando el contador de intentos
Y mantiene el archivo en el filesystem
```

### Escenario 3: Fallo permanente por caída persistente de Identity Service
```gherkin
Dado que un archivo de correo ha fallado reiteradamente al consultar a Identity Service
Cuando el número de intentos fallidos alcanza el límite de MAIL_MAX_RETRIES (por defecto 3)
Entonces el Mail Watchdog registra un error definitivo
Y mueve el archivo JSON a la carpeta failed/ para auditoría manual
```

### Escenario 4: Reintento por respuesta bien formada pero con email inválido
```gherkin
Dado que un archivo de correo está listo para ser procesado
Cuando el Mail Watchdog consulta a Identity Service en GET /v1/identity/email
Y la respuesta HTTP es 200 OK pero el campo "email" está ausente o es una cadena vacía
Entonces el Mail Watchdog trata el evento como un fallo temporal
Y registra una advertencia en los logs indicando que el email recibido es inválido
Y programa un reintento utilizando la política de backoff exponencial incrementando el contador de intentos
Y mantiene el archivo en el filesystem
```

---

## 4. Diseño Técnico y Contratos

### Contrato del Archivo JSON en `pending/`
El esquema de datos JSON consumido por `mail-watchdog` ya no incluirá el campo `"to"`.

```json
{
  "id": "mail-12345",
  "subject": "Capacidades disponibles en Nova",
  "body": "Hola.\n\nActualmente puedo realizar 3 funciones...",
  "content_type": "text/plain"
}
```

### Modelo Pydantic Actualizado (`mail-watchdog/src/models.py`)
```python
class MailMessage(BaseModel):
    id: str = Field(..., min_length=1, description="Unique identifier for the email message")
    subject: str = Field(..., min_length=1, description="Email subject line")
    body: str = Field(..., min_length=1, description="Email content body")
    content_type: str = Field(default="text/plain", description="Content-Type format: 'text/plain' or 'text/html'")
    
    # Internal state tracking fields
    attempts: int = Field(default=0, description="Number of dispatch attempts executed")
    next_retry_at: Optional[float] = Field(default=None, description="Unix timestamp for when the next retry is scheduled")
```

### Contrato API REST con `identity-service`
`mail-watchdog` llamará a:
- **HTTP Method**: GET
- **Path**: `/v1/identity/email`
- **Headers**: `Accept: application/json`
- **Response Status**: `200 OK`
- **Response Payload**:
```json
{
  "email": "david@example.com"
}
```

### Nueva firma de `SMTPClient.send()` (`mail-watchdog/src/smtp_client.py`)
El cliente SMTP modifica su firma para recibir el destinatario de forma explícita, desacoplándose del campo `to` del modelo `MailMessage`:

```python
def send(self, message: MailMessage, recipient: str) -> None:
    """
    Builds the MIME message and transmits it via SMTP.
    recipient: resolved email address obtained from identity-service by the caller (processor.py).
    """
```

El valor de `recipient` es obtenido previamente por `processor.py` mediante la llamada REST a `identity-service` y se pasa como argumento explícito. El método ya no lee `message.to`.

### Configuración de `mail-watchdog`
Se añadirá a `mail-watchdog/src/config.py`:
- `identity_service_base_url`: Cadena de texto cargada desde la variable de entorno `IDENTITY_SERVICE_BASE_URL`, por defecto `http://identity-service:8000`.

Y se agregará en `config/assistant.env`:
```env
IDENTITY_SERVICE_BASE_URL=http://identity-service:8000
```

---

## 5. Casos de Borde y Manejo de Errores

| Caso de Borde | Comportamiento Esperado | Implementación Técnico |
| :--- | :--- | :--- |
| **Timeout en Identity Service** | Tratar como fallo de red temporal y reintentar. | Establecer un timeout estricto de `5.0` segundos en la petición REST interna. |
| **Payload corrupto o vacío en Identity Service** | Tratar como fallo temporal y reintentar. | Validar que el campo `email` esté presente en el JSON recibido y que no sea una cadena vacía. |
| **El archivo JSON entrante conserva el campo "to"** | El campo debe ser ignorado por completo. | Pydantic ignorará de forma nativa los campos adicionales no declarados en el modelo `MailMessage`. |

---

## 6. Estrategia de Testing

### Tests Unitarios
1. **Orchestrator (`tests/test_capabilities_plugin.py`)**:
   - Eliminar mocks de `settings.user_email`.
   - Modificar la aserción sobre el archivo JSON generado para verificar que el campo `"to"` **no** está presente en el payload.
2. **Mail Watchdog (`tests/test_processor.py`)**:
   - Mockear la llamada HTTP GET a `/v1/identity/email` para que devuelva un email simulado (`testuser@example.com`).
   - Verificar que `SMTPClient` recibe el email correcto resuelto de forma dinámica.
   - Verificar la respuesta ante fallos HTTP (500, timeouts) simulando reintentos e incrementando `attempts`.

### Tests de Integración E2E
1. Levantar los servicios `identity-service`, `mail-watchdog` y `orchestrator` utilizando Docker Compose localmente.
2. Encolar un archivo de prueba en `data/mail/pending/` sin el campo `"to"`.
3. Validar a través de los logs de `mail-watchdog` que se consulta con éxito el email en `identity-service` y que el correo se entrega a la dirección configurada.

---

## 7. Plan de Implementación (Checklist)

- [ ] **Fase 1: Modificaciones en Orchestrator**
  - [ ] Eliminar `user_email` en `core/config.py`.
  - [ ] Eliminar el campo `to` en el diccionario `email_payload` dentro de `plugins/capabilities/main.py`.
  - [ ] Actualizar los tests en `tests/test_capabilities_plugin.py` para eliminar aserciones de `to` y mocks de `settings.user_email`.
  - [ ] Ejecutar tests de orchestrator (`pytest tests/`) para verificar que no hay regresiones.

- [ ] **Fase 2: Modificaciones en Mail Watchdog**
  - [ ] Añadir `IDENTITY_SERVICE_BASE_URL` a `src/config.py` con su valor por defecto.
  - [ ] Eliminar el campo `to` en el modelo `MailMessage` de `src/models.py`.
  - [ ] Modificar la interfaz del cliente SMTP `SMTPClient.send()` en `src/smtp_client.py` para aceptar el parámetro `recipient` de forma explícita.
  - [ ] Implementar la consulta HTTP REST a `identity-service` en `src/processor.py` (usando `urllib.request` estándar de Python para evitar dependencias de red externas adicionales) antes de invocar a `SMTPClient.send()`.
  - [ ] Actualizar los tests unitarios en `tests/test_processor.py` y `tests/test_smtp.py` aplicando mocks a la consulta REST del servicio de identidad.
  - [ ] Ejecutar tests de mail-watchdog (`pytest tests/`) para validar el funcionamiento.

- [ ] **Fase 3: Configuración y Despliegue**
  - [ ] Añadir `IDENTITY_SERVICE_BASE_URL=http://identity-service:8000` en `config/assistant.env`.
  - [ ] Añadir `depends_on: [identity-service]` al servicio `mail-watchdog` en `docker-compose.yml`, usando `condition: service_healthy` para aprovechar el healthcheck ya existente en `identity-service`.
  - [ ] Actualizar `docs/services.md`: eliminar el campo `to` del contrato de entrada de `mail-watchdog`; añadir `IDENTITY_SERVICE_BASE_URL` a su tabla de variables; eliminar `USER_EMAIL` de la sección de variables del `orchestrator`; actualizar el diagrama de comunicación añadiendo la flecha `mail-watchdog → identity-service`.
  - [ ] Actualizar `docs/architecture.md`: añadir la relación `mail-watchdog → identity-service:8000` en el diagrama de red interna; ampliar la descripción del componente `mail-watchdog` para mencionar la resolución dinámica del destinatario vía REST.
  - [ ] Tras la validación e integración del PR, cambiar el estado del ADR-009 de `Propuesto` a `Aceptado` y añadir en el ADR-007 una nota de superación con referencia al ADR-009.
