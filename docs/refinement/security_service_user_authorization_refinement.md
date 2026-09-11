# Refinamiento de Feature: Security Service — Autorización User → Service (MVP)

- **Documento de Origen**: [security-service-user-authorization-requirements.md](file:///home/danuser2018/workspace/home-assistant/docs/features/security-service-user-authorization-requirements.md)
- **Fecha**: 2026-08-17
- **Estado**: Refinado / Listo para Desarrollo

---

## 1. Resumen y Contexto de Negocio

### Objetivo Principal
Establecer el diseño técnico, la arquitectura de contratos y el plan de implementación para el nuevo microservicio **Security Service** en su MVP de autorización **User → Service**. 

El `Security Service` actuará como la única autoridad centralizada del ecosistema Nova encargada de determinar si un plan de ejecución (`ExecutionPlan`) solicitado por un usuario a través de cualquier canal de interacción (voz, CLI, API) puede ejecutarse de forma segura. La evaluación del riesgo se basa en:
1. Las acciones contenidas en el plan y su política de riesgo declarada (`fixed` o `lookup`).
2. El canal de entrada de la solicitud y el nivel de riesgo máximo aceptable configurado para dicho canal.

El resultado de la autorización es estrictamente binario (**ALLOW** o **DENY**). Bajo el principio fundamental de **Fail Closed**, cualquier incoherencia, ausencia de datos, canal no registrado o política no calculable producirá un `DENY` inmediato para todo el plan de ejecución, impidiendo cualquier ejecución parcial. Cuando el plan es autorizado (`ALLOW`), el servicio genera un token de autorización criptográfico de único uso por cada acción.

Además, como parte integral de la incorporación de la seguridad en el ecosistema, se incluye la especificación y creación de una nueva skill oficial del dominio de seguridad: `security-domain` ([.agent/skills/domains/security-domain/SKILL.md](file:///home/danuser2018/workspace/home-assistant/.agent/skills/domains/security-domain/SKILL.md)).

### Actores e Interacciones
- **Security Service (`security-service`)**: Microservicio central que mantiene el registro de acciones y políticas de riesgo, cataloga comandos del host, almacena las políticas por canal, evalúa solicitudes de autorización y emite tokens firmados criptográficamente.
- **Interaction Manager (`interaction-manager`)**: Coordinador del pipeline de usuario que, tras obtener un `ExecutionPlan` desde el `orchestrator`, solicita la autorización a `security-service` incluyendo el `SecurityContext`. Si es autorizado, adjunta los tokens al plan y procede con la ejecución; si es denegado, detiene la ejecución y maneja la respuesta de error.
- **Orquestador (`orchestrator`)**: Registra al arrancar las acciones de sus plugins en `security-service`. Al recibir un `ExecutionPlan` para su ejecución (`POST /api/v1/execute-plan`), valida que cada acción contenga un token de autorización válido y no expirado expedido por `security-service`.
- **Host Service (`host-service`)**: Publica en `security-service` su catálogo de comandos del sistema (`host_commands`) indicando el nivel de riesgo asociado a cada comando dinámico.

---

## 2. Análisis de Servicios e Impacto

| Servicio | Nivel de Impacto | Componentes / Archivos Afectados | Tipo de Cambio | Descripción del Cambio |
| :--- | :--- | :--- | :--- | :--- |
| `security-service` | **Alto (Nuevo)** | `app/main.py`<br>`app/config.py`<br>`app/models/`<br>`app/services/`<br>`app/api/`<br>`Dockerfile`<br>`tests/` | **Nuevo Servicio** | Creación completa del microservicio Python/FastAPI. Implementa el registro de acciones, catálogo de comandos host, gestión de políticas por canal, motor de evaluación de riesgos determinista (`RiskEvaluator`) y generador/verificador de tokens de autorización HMAC-SHA256 (`AuthorizationTokenManager`). |
| `interaction-manager` | **Alto** | `app/config.py`<br>`app/services/interaction_pipeline.py`<br>`app/clients/security_client.py`<br>`tests/test_interaction_pipeline.py` | **Modificar** | Incorporar `SecurityClient` para invocar `POST /v1/security/authorize` tras la resolución del plan. Interceptar respuestas `DENY` para abortar la ejecución. Inyectar `authorization_token` en `step.security` antes de enviar el plan a `orchestrator`. |
| `orchestrator` | **Alto** | `app/main.py`<br>`app/services/plan_executor.py`<br>`app/clients/security_client.py`<br>`plugins/*/plugin.py`<br>`tests/test_plan_executor.py` | **Modificar** | Publicar en el arranque del servicio todas las acciones y políticas de riesgo de los plugins a `security-service` (`POST /v1/security/actions/register`). En `PlanExecutor`, verificar la validez y firma del `authorization_token` de cada acción antes de ejecutar el plugin. |
| `host-service` | **Medio** | `app/main.py`<br>`app/services/command_catalog.py`<br>`config/host_commands_risk.yaml` | **Modificar** | Publicar el catálogo de comandos `host_commands` con sus niveles de riesgo asociados en `security-service` (`POST /v1/security/tables/host_commands`) al arrancar. |
| `home-assistant` | **Medio** | `docker-compose.yml`<br>`config/security-service.env`<br>`docs/services.md`<br>`docs/architecture.md`<br>`docs/adr/adr-025-security-service-user-authorization.md`<br>`.agent/skills/domains/security-domain/SKILL.md` | **Modificar / Añadir** | Añadir el contenedor `security-service` a `docker-compose.yml` en la red `assistant-network` (puerto interno 8000, host 8010). Crear `config/security-service.env`. Documentar el servicio, registrar el ADR-025 y crear la nueva skill del dominio de seguridad (`security-domain`). |

> **⚠️ Prerequisito de Fase 3 — ADR-025:** El ADR-025 (`docs/adr/adr-025-security-service-user-authorization.md`) debe ser **redactado y aprobado antes de iniciar la Fase 3** de implementación, dado que en esa fase se modifican contratos públicos existentes (`POST /api/v1/execute-plan` del `orchestrator` pasa a requerir `step.security.authorization_token`). La Tarea 4.3 de la Fase 4 puede adelantarse a cualquier punto previo a la Fase 3.

---

## 3. Especificación de Comportamiento (Criterios de Aceptación)

### Scenario 1: Plugin action registration on startup
```gherkin
Given that security-service is running and accessible at "http://security-service:8000"
When orchestrator starts up and registers plugin actions via "POST /v1/security/actions/register"
  | plugin_id   | action_id   | policy_type | policy_value |
  | set-volume  | set-volume  | fixed       | low          |
  | weather     | weather     | fixed       | low          |
Then security-service stores the action definitions in the internal action registry
And returns HTTP status 200 OK with success status true
```

### Scenario 2: Host Service command catalog registration
```gherkin
Given that security-service is running
When host-service publishes its command catalog via "POST /v1/security/tables/host_commands"
  | name            | risk_level |
  | calculator      | low        |
  | backup          | medium     |
  | format-disk     | high       |
Then security-service registers the lookup table "host_commands" with the provided command risk mappings
And returns HTTP status 200 OK
```

### Scenario 3: Authorization of low-risk action via voice channel (ALLOW)
```gherkin
Given a registered action "set-volume" with fixed risk policy "low"
And a registered channel "voice" with max_risk policy "high"
When interaction-manager submits an ExecutionPlan to "POST /v1/security/authorize"
  | execution_id                         | action_id   | channel |
  | a1b2c3d4-e5f6-7a8b-9c0d-e1f2a3b4c5d6 | set-volume  | voice   |
Then security-service evaluates effective risk as "low"
And compares effective risk "low" <= channel max_risk "high"
And returns decision "ALLOW"
And generates a signed authorization_token for action "set-volume" bound to execution_id "a1b2c3d4-e5f6-7a8b-9c0d-e1f2a3b4c5d6"
```

### Scenario 4: Authorization of dynamic lookup action (ALLOW)
```gherkin
Given a registered action "execute-command" with lookup policy: source="command", table="host_commands"
And registered host_command "backup" with risk level "medium"
And a registered channel "cli" with max_risk policy "medium"
When interaction-manager submits an ExecutionPlan step for action "execute-command" with parameter "command"="backup" via channel "cli"
Then security-service resolves lookup value "backup" in table "host_commands" to risk level "medium"
And evaluates "medium" <= "medium" as authorized
And returns decision "ALLOW" with a generated authorization_token
```

### Scenario 5: Action risk exceeds channel max risk (DENY)
```gherkin
Given a registered action "execute-command" with lookup policy: source="command", table="host_commands"
And registered host_command "format-disk" with risk level "high"
And a registered channel "cli" with max_risk policy "medium"
When interaction-manager submits an ExecutionPlan step for action "execute-command" with parameter "command"="format-disk" via channel "cli"
Then security-service evaluates effective risk as "high"
And determines "high" > channel max_risk "medium"
And returns decision "DENY"
And does not return any authorization tokens
```

### Scenario 6: Atomic plan evaluation fail closed (DENY whole plan)
```gherkin
Given an ExecutionPlan containing two steps:
  | step | action_id        | parameter          | effective_risk |
  | 1    | set-volume       | volume=50          | low            |
  | 2    | execute-command  | command=format-disk| high           |
And channel "cli" with max_risk "medium"
When interaction-manager requests authorization for the ExecutionPlan via "POST /v1/security/authorize"
Then security-service evaluates Step 1 as ALLOW and Step 2 as DENY
And rejects partial plan execution by returning global decision "DENY"
And returns zero authorization tokens
```

### Scenario 7: Fail closed on missing parameters or unregistered components (DENY)
```gherkin
Given an ExecutionPlan with action "execute-command" using lookup policy on source "command"
When the step parameters omit the required "command" parameter
Then security-service cannot determine effective risk
And applies fail closed policy returning decision "DENY"
```

### Scenario 8: Orchestrator token validation enforcement
```gherkin
Given an ExecutionPlan submitted to Orchestrator "POST /api/v1/execute-plan"
When a step lacks a valid, signed authorization_token from security-service
Then Orchestrator refuses to execute the step
And returns HTTP status 403 Forbidden with error code "UNAUTHORIZED_ACTION"
```

---

## 4. Diseño Técnico y Contratos

### 4.1 Modelos de Datos (`app/models/security.py`)

#### Niveles de Riesgo (`RiskLevel`)
```python
from enum import Enum

class RiskLevel(str, Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"

    def __le__(self, other: "RiskLevel") -> bool:
        order = {RiskLevel.LOW: 1, RiskLevel.MEDIUM: 2, RiskLevel.HIGH: 3}
        return order[self] <= order[other]

    def __lt__(self, other: "RiskLevel") -> bool:
        order = {RiskLevel.LOW: 1, RiskLevel.MEDIUM: 2, RiskLevel.HIGH: 3}
        return order[self] < order[other]
```

#### Políticas de Riesgo (`RiskPolicy`)
```python
from typing import Literal, Optional
from pydantic import BaseModel

class FixedRiskPolicy(BaseModel):
    policy: Literal["fixed"] = "fixed"
    value: RiskLevel

class LookupRiskPolicy(BaseModel):
    policy: Literal["lookup"] = "lookup"
    source: str
    table: str

RiskPolicy = FixedRiskPolicy | LookupRiskPolicy
```

#### Registro de Acciones y Canales
```python
from typing import List, Dict, Any
from pydantic import BaseModel

class ActionDefinition(BaseModel):
    id: str
    risk: RiskPolicy

class RegisterActionsRequest(BaseModel):
    plugin_id: str
    actions: List[ActionDefinition]

class ChannelPolicy(BaseModel):
    max_risk: RiskLevel

class ChannelPolicyConfig(BaseModel):
    channels: Dict[str, ChannelPolicy]
```

#### Solicitud y Respuesta de Autorización
```python
from typing import List, Dict, Any, Optional
from pydantic import BaseModel

class ExecutionPlanActionStep(BaseModel):
    action_id: str
    parameters: Dict[str, Any] = {}

class ExecutionPlanPayload(BaseModel):
    execution_id: str
    actions: List[ExecutionPlanActionStep]

class SecurityContextPayload(BaseModel):
    channel: str

class AuthorizationRequest(BaseModel):
    execution_plan: ExecutionPlanPayload
    security_context: SecurityContextPayload

class AuthorizationTokenItem(BaseModel):
    action_id: str
    token: str

class AuthorizationResponse(BaseModel):
    decision: Literal["ALLOW", "DENY"]
    authorization_tokens: Optional[List[AuthorizationTokenItem]] = None
    reason: Optional[str] = None
```

---

### 4.2 Especificación de Endpoints REST (`security-service`)

#### 1. Registrar Acciones de Plugins
- **Endpoint:** `POST /v1/security/actions/register`
- **Request Body:**
```json
{
  "plugin_id": "set-volume",
  "actions": [
    {
      "id": "set-volume",
      "risk": {
        "policy": "fixed",
        "value": "low"
      }
    }
  ]
}
```
- **Response (200 OK):**
```json
{
  "success": true,
  "registered_actions": 1
}
```

#### 2. Registrar Catálogo de Comandos Host
- **Endpoint:** `POST /v1/security/tables/{table_name}`
- **Ejemplo Path:** `POST /v1/security/tables/host_commands`
- **Request Body:**
```json
{
  "commands": [
    {"name": "calculator", "risk": "low"},
    {"name": "github", "risk": "low"},
    {"name": "backup", "risk": "medium"},
    {"name": "format-disk", "risk": "high"}
  ]
}
```
- **Response (200 OK):**
```json
{
  "success": true,
  "table": "host_commands",
  "entries_registered": 4
}
```

#### 3. Autorizar ExecutionPlan
- **Endpoint:** `POST /v1/security/authorize`
- **Request Body:**
```json
{
  "execution_plan": {
    "execution_id": "781870fc-80fe-4165-ae55-4ebdc36b1c60",
    "actions": [
      {
        "action_id": "set-volume",
        "parameters": {
          "volume": 50
        }
      }
    ]
  },
  "security_context": {
    "channel": "voice"
  }
}
```
- **Response ALLOW (200 OK):**
```json
{
  "decision": "ALLOW",
  "authorization_tokens": [
    {
      "action_id": "set-volume",
      "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleGVjdXRpb25faWQiOiI3ODE4NzBmYy04MGZlLTQxNjUtYWU1NS00ZWJkYzM2YjFjNjAiLCJhY3Rpb25faWQiOiJzZXQtdm9sdW1lIiwiYXVkaWVuY2UiOiJub3ZhLW9yY2hlc3RyYXRvciIsImlhdCI6MTc4Njk2MDAwMCwiZXhwIjoxNzg2OTYwMzAwLCJub25jZSI6ImY0N2FjMTA1LTAzMDQtNDcwYi05ZGM0LWMxNGRjMzkwOTM1YiJ9.signature"
    }
  ]
}
```
- **Response DENY (200 OK):**
```json
{
  "decision": "DENY",
  "authorization_tokens": null,
  "reason": "Action 'execute-command' effective risk 'high' exceeds channel 'cli' max risk 'medium'"
}
```

#### 4. Gestión de Políticas por Canal
- **GET /v1/security/channels**
- **Response (200 OK):**
```json
{
  "channels": {
    "voice": {"max_risk": "high"},
    "cli": {"max_risk": "medium"},
    "api": {"max_risk": "low"}
  }
}
```
- **PUT /v1/security/channels/{channel_id}**
- **Request Body:** `{"max_risk": "high"}`
- **Response (200 OK):** `{"success": true, "channel": "cli", "max_risk": "high"}`

#### 5. Health Check
- **GET /health**
- **Response (200 OK):** `{"status": "ok"}`

---

### 4.3 Estructura del Token de Autorización

Cada token de autorización es emitido como un JWT o un payload JSON firmado mediante HMAC-SHA256 utilizando la clave secreta `SECURITY_HMAC_SECRET`:

```json
{
  "header": {
    "alg": "HS256",
    "typ": "JWT"
  },
  "payload": {
    "execution_id": "781870fc-80fe-4165-ae55-4ebdc36b1c60",
    "action_id": "set-volume",
    "audience": "nova-orchestrator",
    "issued_at": 1786960000,
    "expires_at": 1786960300,
    "nonce": "f47ac105-0304-470b-9dc4-c14dc390935b"
  },
  "signature": "c3ab8ff13720e8ad9047dd39466b3c8974e592c2fa383d4a3960714caef0c4f2"
}
```

#### Reglas de Validación de Token en `Orchestrator`:
1. Firma válida calculada con `SECURITY_HMAC_SECRET`.
2. `execution_id` del token coincide exactamente con el `correlation_id` del `ExecutionPlanStep` en ejecución. **Nota de contrato**: el campo `execution_id` usado internamente por `security-service` en su modelo `ExecutionPlanPayload` corresponde al `correlation_id` del modelo `ExecutionPlanStep` del `orchestrator` (campo `context.correlation_id`). El `interaction-manager` es responsable de mapear `context.correlation_id` → `execution_plan.execution_id` al construir la `AuthorizationRequest`. No se modifica el modelo `ExecutionPlanStep` existente del `orchestrator`; la traducción reside exclusivamente en la capa cliente `SecurityClient` del `interaction-manager`.
3. `action_id` coincide con la acción del paso en ejecución (campo `step.plugin`).
4. `audience` == `"nova-orchestrator"`.
5. Timestamp actual < `expires_at`.

---

### 4.4 Diagrama de Secuencia del Pipeline Integrado

```text
User          interaction-manager           orchestrator           security-service
 |                    |                          |                        |
 |-- Execute Command->|                          |                        |
 |                    |-- POST /api/v1/resolve ->|                        |
 |                    |<-- ExecutionPlan --------|                        |
 |                    |                                                   |
 |                    |-- POST /v1/security/authorize ------------------->|
 |                    |   (ExecutionPlan + SecurityContext)               |
 |                    |                                                   |-- Evaluate Risk (fixed/lookup)
 |                    |                                                   |-- Compare with Channel Policy
 |                    |<-- Decision: ALLOW + Tokens ----------------------|
 |                    |                                                   |
 |                    |-- POST /api/v1/execute-plan --------------------->|
 |                    |   (Plan with step.security.token)                 |-- Validate Token
 |                    |                                                   |-- Execute Plugin
 |                    |<-- Speech Result ---------------------------------|
 |<-- Audio Speech ---|
```

---

### 4.5 Especificación de la Nueva Skill del Dominio de Seguridad (`security-domain`)

Se define la nueva skill [.agent/skills/domains/security-domain/SKILL.md](file:///home/danuser2018/workspace/home-assistant/.agent/skills/domains/security-domain/SKILL.md) para gobernar las reglas y mejores prácticas de seguridad en el ecosistema:

- **Nombre**: `security-domain`
- **Ubicación**: `.agent/skills/domains/security-domain/SKILL.md`
- **Invariantes del Dominio**:
  1. **Fail Closed Absoluto**: Ante la falta o invalidez de datos de autorización, la decisión por defecto es siempre `DENY`.
  2. **Autorización Atómica por Plan**: Un `ExecutionPlan` no admite ejecuciones parciales; si falla un solo paso, todo el plan se deniega.
  3. **Aislamiento del Mecanismo de Ejecución**: La seguridad opera sobre abstracciones de riesgo y canales, sin acoplarse al hardware ni al código ejecutable del plugin.
  4. **Single-Use Tokens**: Los tokens de autorización están acotados a `execution_id` y `action_id` y vencen tras un tiempo límite (`expires_at`).

---

## 5. Casos de Borde y Manejo de Errores

| Código de Error | Causa Raíz | Comportamiento del Sistema | Principio Aplicado |
| :--- | :--- | :--- | :--- |
| `UNREGISTERED_ACTION` | La acción del `ExecutionPlan` no ha sido registrada por ningún plugin. | `security-service` responde `DENY` inmediatamente. `interaction-manager` cancela la ejecución y reproduce audio de error. | **Fail Closed** |
| `INVALID_RISK_POLICY` | La acción tiene una estructura de política sintácticamente inválida o incompleta. | `security-service` responde `DENY`. | **Fail Closed** |
| `LOOKUP_TABLE_NOT_FOUND` | La política `lookup` referencia a una tabla inexistente (ej. `"host_commands"` no registrada). | `security-service` responde `DENY`. | **Fail Closed** |
| `LOOKUP_VALUE_NOT_FOUND` | El parámetro extraído de la acción no se encuentra en la tabla de búsqueda (ej. comando no listado en catálogo). | `security-service` responde `DENY`. | **Fail Closed** |
| `MISSING_SOURCE_PARAMETER` | La política `lookup` requiere la clave `source="command"`, pero los parámetros de la acción no la contienen. | `security-service` responde `DENY`. | **Fail Closed** |
| `UNREGISTERED_CHANNEL` | El `SecurityContext` especifica un canal sin política de riesgo definida en `security-service`. | `security-service` responde `DENY`. | **Fail Closed** |
| `EXCEEDS_CHANNEL_MAX_RISK` | El riesgo efectivo de alguna acción supera el riesgo máximo configurado para el canal. | `security-service` responde `DENY`. | **Fail Closed** |
| `INVALID_AUTHORIZATION_TOKEN` | `orchestrator` recibe un token con firma alterada, expirado o correspondiente a otro `execution_id`. | `orchestrator` rechaza la ejecución respondiendo HTTP 403 Forbidden. | **Zero Trust Execution** |
| `SECURITY_SERVICE_UNAVAILABLE` | Timeout o fallo de red en la comunicación HTTP entre `interaction-manager` y `security-service`. | `interaction-manager` asume fallo de seguridad y aborta la ejecución (`DENY` por defecto). | **Fail Closed** |

---

## 6. Estrategia de Testing

### 6.1 Unit Testing (`security-service`)
- **`test_risk_level.py`**: Comprobar ordenación estricta y comparaciones (`low < medium < high`).
- **`test_fixed_policy_evaluator.py`**: Validar evaluación de políticas fijas.
- **`test_lookup_policy_evaluator.py`**: Validar búsqueda en tablas dinámicas, manejo de claves ausentes y valores desconocidos.
- **`test_channel_policy_manager.py`**: Verificar obtención y actualización de políticas por canal.
- **`test_token_manager.py`**: Comprobar generación de JWT/HMAC, validación de firma, verificación de expiración y manipulación de payload.
- **`test_authorization_engine.py`**: Pruebas unitarias completas del motor de decisión combinando múltiples acciones, evaluación atómica de planes (un solo `DENY` invalida el plan completo).

### 6.2 Integration Testing (`security-service` & Clients)
- **`test_actions_api.py`**: Verificar `POST /v1/security/actions/register`.
- **`test_tables_api.py`**: Verificar `POST /v1/security/tables/{table_name}`.
- **`test_authorize_api.py`**: Validar contrato REST de `POST /v1/security/authorize` respondiendo `ALLOW` con tokens o `DENY` según combinación de canal y riesgo.
- **`test_orchestrator_token_enforcement.py`**: Test de integración en `orchestrator` verificando el rechazo HTTP 403 al enviar planes sin token o con token alterado.
- **`test_interaction_manager_security_flow.py`**: Test de integración en `interaction-manager` simulando respuestas `ALLOW` y `DENY` desde `security-service`.

### 6.3 End-to-End Testing (E2E)
- **`test_e2e_authorized_execution.py`**: Ejecución de comando de voz con riesgo `low` verificando paso por `security-service` y reproducción exitosa.
- **`test_e2e_denied_execution.py`**: Intentar ejecutar un comando de alto riesgo desde un canal restringido comprobando la interceptación y emisión de audionotificación de denegación.

---

## 7. Plan de Implementación

### Fase 1: Creación del Microservicio `security-service`
- [ ] **Tarea 1.1**: Crear repositorio/directorio del servicio `security-service` con la estructura estándar Python/FastAPI (`app/main.py`, `app/config.py`, `app/models/`, `app/services/`, `app/api/`, `Dockerfile`, `requirements.txt`).
- [ ] **Tarea 1.2**: Implementar el modelo de datos `RiskLevel` y la lógica de ordenación de riesgos (`LOW < MEDIUM < HIGH`).
- [ ] **Tarea 1.3**: Implementar los modelos Pydantic para `RiskPolicy` (`fixed` y `lookup`), `ActionDefinition`, `ChannelPolicy`, `AuthorizationRequest` y `AuthorizationResponse`.
- [ ] **Tarea 1.4**: Implementar los registros in-memory `ActionRegistry` (para acciones publicadas por plugins) y `LookupTableRegistry` (para catálogos como `host_commands`). **Decisión de diseño MVP**: el estado es volátil por diseño; si `security-service` se reinicia, devolverá `DENY` a todas las solicitudes hasta que `orchestrator` y `host-service` completen su re-registro en el arranque. El `docker-compose.yml` debe configurar `depends_on` con healthcheck para garantizar el orden de inicio correcto (ver Tarea 4.1).
- [ ] **Tarea 1.5**: Implementar `ChannelPolicyManager` con soporte de almacenamiento in-memory y carga de configuración por defecto (`voice` -> `high`, `cli` -> `medium`, `api` -> `low`).
- [ ] **Tarea 1.6**: Implementar `RiskEvaluator` para resolver el riesgo efectivo de acciones fijas y por búsqueda de parámetros.
- [ ] **Tarea 1.7**: Implementar `AuthorizationTokenManager` para la generación y verificación criptográfica de tokens mediante HMAC-SHA256.
- [ ] **Tarea 1.8**: Implementar los endpoints de FastAPI (`POST /v1/security/actions/register`, `POST /v1/security/tables/{table_name}`, `POST /v1/security/authorize`, `GET/PUT /v1/security/channels`, `GET /health`).
- [ ] **Tarea 1.9a**: Implementar `test_risk_level.py` (ordenación y comparaciones `LOW < MEDIUM < HIGH`) y `test_fixed_policy_evaluator.py` (evaluación de políticas fijas). Ejecutar tras Tarea 1.2 y 1.6.
- [ ] **Tarea 1.9b**: Implementar `test_lookup_policy_evaluator.py` (búsqueda en tablas, claves ausentes, valores desconocidos) y `test_channel_policy_manager.py` (obtención y actualización de políticas por canal). Ejecutar tras Tarea 1.5 y 1.6.
- [ ] **Tarea 1.9c**: Implementar `test_token_manager.py` (generación HMAC-SHA256, validación de firma, expiración y manipulación de payload). Ejecutar tras Tarea 1.7.
- [ ] **Tarea 1.9d**: Implementar `test_authorization_engine.py` (motor de decisión completo: múltiples acciones, evaluación atómica del plan). Ejecutar tras Tarea 1.8.
- [ ] **Tarea 1.9e**: Implementar tests de integración REST (`test_actions_api.py`, `test_tables_api.py`, `test_authorize_api.py`). Verificar cobertura global > 90% sobre el microservicio. Ejecutar tras Tarea 1.8.

### Fase 2: Registro de Capacidades en Servicios Emisores
- [ ] **Tarea 2.1**: Crear el cliente `SecurityClient` en `orchestrator` para comunicarse con `security-service`.
- [ ] **Tarea 2.2**: Modificar la secuencia de arranque de `orchestrator` para registrar automáticamente las acciones y políticas de riesgo de todos los plugins cargados en `security-service` (`POST /v1/security/actions/register`).
- [ ] **Tarea 2.3**: Modificar `host-service` para publicar su catálogo de comandos `host_commands` y niveles de riesgo en `security-service` (`POST /v1/security/tables/host_commands`) al iniciar.

### Fase 3: Integración en Pipeline y Verificación de Tokens
- [ ] **Tarea 3.1**: Crear el cliente `SecurityClient` en `interaction-manager`.
- [ ] **Tarea 3.2**: Modificar `interaction-manager` (`interaction_pipeline.py`) para invocar a `security-service` (`POST /v1/security/authorize`) tras obtener el `ExecutionPlan` de `resolve`.
- [ ] **Tarea 3.3**: En `interaction-manager`, implementar la interceptación de respuestas `DENY`: abortar la ejecución, evitar invocar `execute-plan` y notificar al usuario mediante audio de denegación.
- [ ] **Tarea 3.4**: En `interaction-manager`, al recibir `ALLOW`, adjuntar los `authorization_token` correspondientes a cada paso en `step.security` antes de invocar `POST /api/v1/execute-plan` en `orchestrator`.
- [ ] **Tarea 3.5**: Modificar `orchestrator` (`PlanExecutor`) para validar la presencia, firma, vigencia y coherencia del `authorization_token` en cada paso antes de ejecutar el plugin. Devolver HTTP 403 Forbidden si el token no es válido.

### Fase 4: Despliegue, Documentación, ADR y Skill de Dominio
- [ ] **Tarea 4.1**: Añadir la definición del contenedor `security-service` en `docker-compose.yml` conectado a `assistant-network` (puerto 8010:8000) con healthcheck en `/health`. Configurar `depends_on` con condición `service_healthy` en los servicios `orchestrator` e `interaction-manager` respecto a `security-service`, de forma que no arranquen hasta que `security-service` haya superado el healthcheck. Esto garantiza que el registro de acciones en el arranque nunca llegue a un servicio no disponible.
- [ ] **Tarea 4.2**: Crear el archivo de configuración `config/security-service.env` con las variables de entorno necesarias (`SECURITY_HMAC_SECRET`, `LOG_LEVEL`, etc.).
- [ ] **Tarea 4.3**: Redactar y registrar la decisión de arquitectura `docs/adr/adr-025-security-service-user-authorization.md`.
- [ ] **Tarea 4.4**: Actualizar el catálogo de servicios (`docs/services.md`) y el documento de arquitectura global (`docs/architecture.md`) para documentar `security-service`.
- [ ] **Tarea 4.5**: Crear y registrar la nueva skill de dominio de seguridad en [.agent/skills/domains/security-domain/SKILL.md](file:///home/danuser2018/workspace/home-assistant/.agent/skills/domains/security-domain/SKILL.md).
