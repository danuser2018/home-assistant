# Especificación de Requisitos — Security Service: Autorización User → Service (MVP)

**Versión:** 1.0  
**Estado:** Borrador para implementación  
**Alcance:** Fase 1 — Definición del contrato

---

## 1. Objetivo

Definir el contrato funcional y técnico mínimo del **Security Service** para autorizar la ejecución de acciones de Nova.

Esta primera fase cubre exclusivamente la autorización **User → Service**.

El Security Service determinará si las acciones contenidas en un `ExecutionPlan` pueden ejecutarse en función de:

- la acción solicitada;
- su nivel de riesgo efectivo;
- el canal de interacción;
- la política de riesgo configurada para dicho canal.

El resultado de la autorización será siempre **ALLOW** o **DENY**.

No forman parte de este MVP los mecanismos de confirmación, verificación adicional ni la autorización Service → Service.

---

## 2. Principios

### 2.1. Fail closed

El Security Service debe aplicar una política de **fail closed**.

> Si no puede demostrar de forma positiva que una acción está autorizada, debe denegarla.

Cualquier dato inexistente, desconocido, inválido o inconsistente necesario para tomar la decisión debe producir `DENY`.

### 2.2. Seguridad independiente del mecanismo de ejecución

El Security Service no debe conocer cómo se ejecuta una acción.

No debe contener lógica específica para:

- comandos del sistema;
- aplicaciones;
- volumen;
- correo;
- GitHub;
- etc.

Debe trabajar con acciones y sus características de seguridad.

### 2.3. El riesgo pertenece a la acción

Cada acción debe declarar cómo se determina su nivel de riesgo.

El riesgo no debe ser proporcionado arbitrariamente por el `Interaction Manager` en el momento de solicitar la autorización.

### 2.4. El canal pertenece al contexto de seguridad

La política de riesgo aceptable de cada canal es propiedad del Security Service.

Ejemplo conceptual:

```text
voice → high
cli   → medium
api   → low
```

---

## 3. Alcance del MVP

### Incluido

- Registro de acciones y sus políticas de riesgo.
- Registro de capacidades/comandos procedentes de Host Service.
- Niveles de riesgo `low`, `medium`, `high`.
- Políticas de riesgo `fixed` y `lookup`.
- Configuración de riesgo máximo aceptable por canal.
- Evaluación de un `ExecutionPlan`.
- Decisión `ALLOW` / `DENY`.
- Generación de un token de autorización por acción.
- Rechazo de planes que contengan alguna acción no autorizada.

### Fuera de alcance

- `CONFIRM`.
- `VERIFY`.
- TOTP.
- Conversación de autorización.
- Autorización Service → Service.
- Acceso a credenciales o secretos.
- Acceso a datos personales.
- Gestión de identidades.
- Políticas de riesgo basadas en código ejecutable.
- Expresiones o reglas complejas más allá de `fixed` y `lookup`.

---

# 4. Modelo conceptual

## 4.1. Action

Una acción representa una capacidad ejecutable por Nova.

Conceptualmente:

```text
Action
├── id
├── plugin_id
└── risk_policy
```

El `Security Service` no debe depender del tipo concreto de plugin.

---

## 4.2. RiskLevel

Los niveles de riesgo del MVP son:

```text
low
medium
high
```

Son valores semánticos y ordenables:

```text
low < medium < high
```

El significado de estos niveles para cada canal es responsabilidad del Security Service.

---

## 4.3. RiskPolicy

Una acción declara una política que permite determinar su riesgo efectivo.

### Política `fixed`

El riesgo es constante.

```json
{
  "policy": "fixed",
  "value": "low"
}
```

### Política `lookup`

El riesgo se obtiene buscando el valor de un parámetro de la acción en una tabla registrada.

```json
{
  "policy": "lookup",
  "source": "command",
  "table": "host_commands"
}
```

`source` identifica el nombre del parámetro de entrada que se utilizará como clave de búsqueda.

`table` identifica el catálogo/tabla donde se obtiene el riesgo.

---

# 5. Registro de acciones

Los plugins deben publicar al arrancar las acciones que proporcionan.

El evento debe permitir al Security Service registrar como mínimo:

```text
plugin_id
action_id
risk_policy
```

Ejemplo:

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

El Security Service debe rechazar o ignorar de forma segura una definición inválida y no debe autorizar posteriormente una acción cuya definición de riesgo no pueda determinar.

---

# 6. Registro de comandos de Host Service

Host Service publica un catálogo de comandos disponibles.

Este catálogo es consumido por:

1. `Command Resolver`, para resolver comandos solicitados por el usuario.
2. `Security Service`, para determinar el riesgo de comandos dinámicos.

Ejemplo:

```json
{
  "commands": [
    {
      "name": "calculadora",
      "risk": "low"
    },
    {
      "name": "github",
      "risk": "low"
    },
    {
      "name": "backup",
      "risk": "medium"
    },
    {
      "name": "formatear-disco",
      "risk": "high"
    }
  ]
}
```

Para `execute-command`, la política podrá ser:

```json
{
  "policy": "lookup",
  "source": "command",
  "table": "host_commands"
}
```

Por tanto, el riesgo efectivo se obtiene a partir del comando concreto resuelto.

---

# 7. Security Context

La solicitud de autorización debe incluir un contexto de seguridad.

En el MVP debe contener como mínimo:

```text
channel
```

Ejemplos:

```text
voice
cli
api
```

El modelo debe diseñarse para poder incorporar contexto adicional en el futuro sin romper el contrato.

---

# 8. Política de riesgo por canal

El Security Service mantiene la configuración de riesgo máximo aceptable por canal.

Ejemplo:

```json
{
  "channels": {
    "voice": {
      "max_risk": "high"
    },
    "cli": {
      "max_risk": "medium"
    },
    "api": {
      "max_risk": "low"
    }
  }
}
```

La configuración pertenece exclusivamente al Security Service.

Host Service y los plugins no deben definir el riesgo máximo aceptable de un canal.

---

# 9. Contrato de autorización

El Security Service debe exponer una operación que reciba:

```text
ExecutionPlan
SecurityContext
```

y evalúe todas las acciones del plan.

Conceptualmente:

```json
{
  "execution_plan": {
    "execution_id": "...",
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

---

# 10. Evaluación de riesgo

Para cada acción:

```text
ExecutionPlan action
        ↓
Action definition
        ↓
Risk Policy
        ↓
Effective Risk
        ↓
Channel Policy
        ↓
ALLOW / DENY
```

## 10.1. `fixed`

El riesgo efectivo es directamente el valor configurado.

```text
fixed(low)
    ↓
effective risk = low
```

## 10.2. `lookup`

El Security Service obtiene el valor indicado por `source` de los parámetros de la acción y realiza la búsqueda en `table`.

Ejemplo:

```text
action = execute-command
source = command
table = host_commands

command = "backup"
        ↓
host_commands["backup"]
        ↓
medium
```

Si el valor no existe, el resultado es `DENY`.

---

# 11. Decisión de autorización

Una acción está autorizada cuando:

1. la acción está registrada;
2. su política de riesgo es válida;
3. el riesgo efectivo puede determinarse;
4. el canal está registrado;
5. el canal tiene un nivel máximo definido;
6. el riesgo efectivo es igual o inferior al máximo permitido.

Conceptualmente:

```text
effective_risk <= channel.max_risk
```

Si todas las condiciones se cumplen:

```text
ALLOW
```

En cualquier otro caso:

```text
DENY
```

---

# 12. Autorización de un ExecutionPlan

El plan se considera autorizado únicamente si **todas sus acciones están autorizadas**.

Ejemplo:

```text
Action A → ALLOW
Action B → ALLOW
Action C → ALLOW
        ↓
ExecutionPlan → ALLOW
```

Pero:

```text
Action A → ALLOW
Action B → DENY
Action C → ALLOW
        ↓
ExecutionPlan → DENY
```

No debe permitirse la ejecución parcial del plan.

---

# 13. Authorization Token

Cuando el plan es autorizado, Security Service debe generar un token de autorización para cada acción.

El token debe estar vinculado, como mínimo, a:

```text
execution_id
action_id
audience
issued_at
expires_at
nonce
firma
```

El token representa:

> La autorización para ejecutar una acción concreta dentro de una ejecución concreta.

No representa una autorización genérica para ejecutar el plugin.

No debe reutilizarse como mecanismo de autorización Service → Service.

---

# 14. Resultado

### Resultado ALLOW

Debe devolver:

```text
decision = ALLOW
authorization_tokens = [
    token_action_1,
    token_action_2,
    ...
]
```

Debe existir un token para cada acción autorizada.

### Resultado DENY

Debe devolver:

```text
decision = DENY
```

No debe devolver tokens utilizables para ejecutar acciones del plan.

La información de diagnóstico podrá existir para logs/observabilidad, pero no debe convertirse en una autorización.

---

# 15. Casos de DENY obligatorio

El Security Service debe devolver `DENY` cuando:

- una acción del `ExecutionPlan` no está registrada;
- el plugin no ha publicado la acción;
- la política de riesgo no existe;
- la política de riesgo es inválida;
- un `lookup` no encuentra la tabla;
- un `lookup` no encuentra el valor;
- falta el parámetro requerido por `source`;
- el riesgo efectivo no puede determinarse;
- el canal no está registrado;
- el canal no tiene nivel máximo definido;
- el nivel de riesgo es desconocido;
- el `ExecutionPlan` es inválido;
- existen inconsistencias entre el plan y las capacidades registradas;
- no puede generarse correctamente la autorización.

Regla general:

> **La ausencia de información necesaria para autorizar equivale a DENY.**

---

# 16. Requisitos funcionales

### RF-01 — Registrar acciones

Security Service deberá poder registrar las acciones publicadas por los plugins.

### RF-02 — Registrar riesgo

Security Service deberá registrar la política de riesgo asociada a cada acción.

### RF-03 — Registrar capacidades de Host Service

Security Service deberá consumir el catálogo de comandos publicado por Host Service.

### RF-04 — Evaluar riesgo fijo

Security Service deberá soportar la política `fixed`.

### RF-05 — Evaluar riesgo mediante lookup

Security Service deberá soportar la política `lookup`.

### RF-06 — Gestionar políticas por canal

Security Service deberá mantener el nivel máximo de riesgo permitido para cada canal.

### RF-07 — Autorizar ExecutionPlan

Security Service deberá evaluar todas las acciones de un `ExecutionPlan`.

### RF-08 — Aplicar fail closed

Security Service deberá devolver `DENY` ante cualquier condición que impida demostrar que la acción está autorizada.

### RF-09 — Autorización atómica

Security Service deberá devolver `DENY` para el plan completo si una sola acción no está autorizada.

### RF-10 — Generar tokens

Security Service deberá generar un token de autorización por acción cuando el plan sea autorizado.

### RF-11 — Vincular tokens

Cada token deberá estar vinculado a su `execution_id` y `action_id`.

### RF-12 — No autorizar ejecución genérica

Un token de una acción no deberá poder utilizarse para autorizar otra acción.

---

# 17. Requisitos no funcionales

### RNF-01 — Determinismo

Dado el mismo catálogo, configuración, `ExecutionPlan` y `SecurityContext`, la decisión debe ser determinista.

### RNF-02 — Seguridad por defecto

La ausencia o invalidez de configuración nunca debe ampliar permisos.

### RNF-03 — Separación de responsabilidades

Security Service será propietario de la decisión de autorización User → Service.

### RNF-04 — Independencia del mecanismo de ejecución

Security Service no deberá contener lógica específica de ejecución de comandos o de otros plugins.

### RNF-05 — Extensibilidad

El contrato deberá permitir añadir nuevas políticas de riesgo y nuevos atributos de `SecurityContext` en futuras fases.

---

# 18. Fuera del contrato de esta fase

No se define todavía:

- cómo se implementará criptográficamente el token;
- mecanismo concreto de firma;
- almacenamiento de nonces;
- mecanismo de identidad del usuario;
- confirmaciones;
- verificaciones adicionales;
- autenticación Service → Service;
- credenciales;
- secretos;
- acceso a datos personales.

Estos aspectos se definirán en fases posteriores cuando sean necesarios.

---

# 19. Criterio de aceptación de la fase

La fase se considera completada cuando exista un contrato acordado que permita implementar:

```text
Plugin
  ↓
publicación de acciones + riesgo

Host Service
  ↓
publicación de comandos + riesgo

Security Service
  ↓
ExecutionPlan + SecurityContext
  ↓
effective risk
  ↓
channel policy
  ↓
ALLOW / DENY
  ↓
token por acción
```

y quede explícitamente garantizado el comportamiento **fail closed**.
