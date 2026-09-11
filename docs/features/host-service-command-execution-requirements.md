# Host Service — Command Execution
## Especificación de Requisitos

**Estado:** Propuesta  
**Componente:** `host-service`  
**Versión:** 1.0  
**Fecha:** 2026-09-11

---

## 1. Objetivo

Ampliar `host-service` para proporcionar una capacidad genérica y segura de ejecución de comandos/aplicaciones del sistema host.

La capacidad debe permitir que el resto de Nova solicite la ejecución de una aplicación mediante un **identificador lógico**, sin conocer ni enviar directamente el comando del sistema operativo.

El identificador será el elemento común entre:

- la resolución de la intención;
- el `ExecutionPlan`;
- la autorización de `security-service`;
- el catálogo de comandos del host;
- la ejecución efectiva en `host-service`.

La definición de cada comando se centralizará en un único fichero `config/host_commands.yaml`, que contendrá tanto la información necesaria para ejecutarlo como su nivel de riesgo.

---

## 2. Alcance

### Incluido

1. Definición declarativa de comandos/aplicaciones disponibles en el host.
2. Asociación de un identificador único con:
   - comando ejecutable;
   - argumentos estáticos, cuando sean necesarios;
   - nivel de riesgo.
3. Carga y validación del catálogo durante el arranque de `host-service`.
4. Registro interno de comandos (`CommandRegistry`).
5. Publicación del catálogo de comandos y riesgos hacia `security-service`.
6. Endpoint HTTP para solicitar la ejecución de un comando por identificador.
7. Ejecución mediante `subprocess` sin shell.
8. Respuesta inmediata para aplicaciones de larga duración, devolviendo al menos el estado de inicio y, cuando esté disponible, el PID.

### Fuera de alcance

- Ejecución arbitraria de comandos proporcionados por el usuario.
- Uso de `shell=True`.
- Interpretación de comandos de shell.
- Resolución lingüística de nombres de aplicaciones.
- Autorización de usuario dentro de `host-service`.
- Lógica de negocio específica de cada aplicación.
- Gestión de procesos después de su lanzamiento.
- Paso de argumentos arbitrarios desde el cliente.

---

## 3. Principios arquitectónicos

### 3.1 Identificador como contrato canónico

El identificador (`name`) representa la capacidad ejecutable del host.

Ejemplo:

```text
calculator
```

El identificador no representa el binario físico. Representa una capacidad conocida por Nova.

La resolución será:

```text
"abre la calculadora"
        ↓
ApplicationResolver
        ↓
calculator
        ↓
ExecutionPlan
        ↓
Security Service
        ↓
host-service
        ↓
CommandRegistry
        ↓
gnome-calculator
```

### 3.2 Una única fuente de verdad

`config/host_commands.yaml` sustituirá completamente a `config/host_commands_risk.yaml`.

No debe existir una segunda tabla independiente de riesgos que deba cruzarse con el catálogo de ejecución.

Cada entrada tendrá toda la información necesaria para identificar, autorizar y ejecutar el comando.

### 3.3 Seguridad por catálogo

El cliente del endpoint no proporciona un ejecutable.

El cliente proporciona únicamente un identificador registrado:

```json
{
  "command": "calculator"
}
```

`host-service` obtiene el comando real exclusivamente desde el catálogo cargado.

### 3.4 Sin shell

La ejecución debe utilizar una lista de argumentos y:

```python
subprocess.Popen(
    argv,
    shell=False,
    start_new_session=True,
)
```

No se utilizará `os.system`, `shell=True` ni concatenación de comandos.

### 3.5 Separación de responsabilidades

`host-service` es responsable de conocer y ejecutar comandos del host.

`security-service` es responsable de determinar si la ejecución está autorizada.

`host-service` no debe incorporar lógica de autorización ni política de usuario en este cambio.

---

# 4. Requisitos funcionales

## RF-001 — Catálogo de comandos

El sistema deberá disponer de un fichero de configuración:

```text
config/host_commands.yaml
```

El fichero contendrá una colección de comandos identificados mediante un nombre único.

Ejemplo:

```yaml
commands:
  - name: calculator
    command:
      - gnome-calculator
    risk: low

  - name: github
    command:
      - github
    risk: low

  - name: backup
    command:
      - /usr/local/bin/nova-backup
    risk: medium

  - name: format-disk
    command:
      - /usr/local/bin/nova-format-disk
    risk: high
```

## RF-002 — Identificador único

Cada entrada deberá tener un `name` único dentro del catálogo.

El `name` será el identificador utilizado por las capas superiores de Nova.

Los nombres duplicados deberán provocar un error de configuración durante el arranque.

## RF-003 — Comando ejecutable

Cada entrada deberá definir un `command` no vacío.

`command` deberá representarse como una lista de argumentos (`argv`), no como una cadena de shell.

Ejemplo válido:

```yaml
command:
  - firefox
  - --new-window
```

Esto permitirá representar comandos con argumentos estáticos sin introducir interpretación de shell.

## RF-004 — Nivel de riesgo

Cada entrada deberá definir un nivel de riesgo.

Valores permitidos inicialmente:

```text
low
medium
high
```

El nivel de riesgo será utilizado por `host-service` al construir el catálogo que publica a `security-service`.

## RF-005 — Carga del catálogo

`host-service` deberá cargar `config/host_commands.yaml` durante el arranque.

Un error de sintaxis, una entrada inválida o una configuración inconsistente deberá provocar un fallo controlado de arranque.

No deberá iniciarse un `host-service` con un catálogo parcialmente válido.

## RF-006 — Registro interno

El catálogo cargado deberá estar disponible mediante un `CommandRegistry`.

Conceptualmente:

```python
@dataclass(frozen=True)
class HostCommand:
    name: str
    command: tuple[str, ...]
    risk: RiskLevel
```

El registro deberá permitir recuperar un comando mediante su identificador.

## RF-007 — Publicación del catálogo de seguridad

`host-service` deberá poder generar a partir del mismo `CommandRegistry` la representación destinada a `security-service`.

La publicación contendrá:

```json
{
  "commands": [
    {
      "name": "calculator",
      "risk": "low"
    }
  ]
}
```

El comando físico (`command`) no deberá formar parte del catálogo publicado a `security-service`.

## RF-008 — Ejecución por identificador

`host-service` deberá exponer un endpoint que reciba el identificador del comando.

Ejemplo:

```json
{
  "command": "calculator"
}
```

El servicio deberá:

1. buscar el identificador en `CommandRegistry`;
2. obtener el `argv` registrado;
3. ejecutar el proceso;
4. devolver el resultado del lanzamiento.

## RF-009 — Comando inexistente

Si el identificador solicitado no existe en el catálogo, el endpoint deberá devolver un error HTTP `404`.

No deberá intentarse ninguna ejecución.

## RF-010 — Ejecución asíncrona

Para aplicaciones de escritorio, `host-service` no deberá esperar a que el proceso termine.

El endpoint deberá devolver después de iniciar el proceso.

Ejemplo de respuesta:

```json
{
  "command": "calculator",
  "status": "started",
  "pid": 12345
}
```

## RF-011 — Error de lanzamiento

Si el proceso no puede iniciarse, el endpoint deberá devolver un error HTTP apropiado y controlado.

No deberá exponerse al cliente un traceback ni información interna innecesaria.

## RF-012 — Ejecución en contexto del usuario

Las aplicaciones gráficas deberán ejecutarse en el contexto del usuario de la sesión host.

Esto es necesario para conservar el entorno gráfico correspondiente (`DISPLAY`, `DBUS`, etc.).

La ejecución mediante el servicio `systemd --user` existente permite mantener este modelo.

---

# 5. Requisitos de seguridad

## RS-001 — No ejecución arbitraria

El endpoint no deberá aceptar un ejecutable proporcionado por el cliente.

Incorrecto:

```json
{
  "command": "gnome-calculator"
}
```

cuando `command` se interprete como una orden libre.

Correcto:

```json
{
  "command": "calculator"
}
```

donde `calculator` es un identificador registrado.

## RS-002 — No shell

Queda prohibido utilizar:

```python
shell=True
```

y cualquier mecanismo equivalente.

## RS-003 — Catálogo cerrado

Solo podrán ejecutarse comandos presentes en `config/host_commands.yaml`.

## RS-004 — Fail closed

Ante una configuración inválida o un identificador desconocido, no se ejecutará ningún comando.

## RS-005 — Separación con Security Service

El riesgo definido en `config/host_commands.yaml` se utilizará para construir el catálogo de `security-service`.

La autorización seguirá siendo responsabilidad de `security-service`.

El endpoint de ejecución no deberá convertirse en una nueva implementación de la política de seguridad.

---

# 6. Flujo completo

```text
Usuario
   │
   │ "abre la calculadora"
   ▼
STT
   │
   ▼
ExecutionPlanner
   │
   │ command = calculator
   ▼
ExecutionPlan
   │
   ▼
Security Service
   │
   │ lookup host_commands["calculator"]
   │ risk = low
   │
   ▼
ALLOW + token
   │
   ▼
PlanExecutor
   │
   ▼
host-service
   │
   │ POST /v1/commands/execute
   │ {"command": "calculator"}
   ▼
CommandRegistry
   │
   │ calculator
   ▼
["gnome-calculator"]
   │
   ▼
CommandExecutor
   │
   ▼
Linux process
```

---

# 7. Validación del catálogo

Durante el arranque deberán comprobarse como mínimo:

- Existencia del fichero `config/host_commands.yaml`.
- YAML válido.
- `commands` presente.
- `commands` con formato correcto y lista no vacía (al menos un comando definido).
- `name` presente y no vacío.
- `name` único.
- `command` presente y no vacío.
- `command` representado como lista.
- Cada elemento de `command` debe ser una cadena no vacía.
- `risk` presente.
- `risk` pertenece a los valores soportados.

Cualquier error deberá impedir el arranque normal del servicio.

---

# 8. Requisitos no funcionales

## RNF-001 — Determinismo

La resolución de un identificador deberá ser determinista.

Un mismo identificador deberá producir siempre el mismo `argv` mientras no cambie la configuración.

## RNF-002 — Simplicidad

La ejecución de comandos deberá mantenerse como una capacidad genérica del HAL y no contener lógica específica de aplicaciones.

## RNF-003 — Trazabilidad

El identificador del comando deberá estar disponible en logs de ejecución.

Cuando exista PID, deberá registrarse también.

## RNF-004 — Compatibilidad

El cambio deberá mantener la arquitectura existente de `host-service`, incluyendo su API FastAPI y el puerto actual.

## RNF-005 — Gestión de procesos y prevención de zombies

Las aplicaciones lanzadas de forma asíncrona no deberán generar procesos zombie en el sistema operativo host tras su finalización. `host-service` deberá asegurar el desacoplamiento de los subprocesos y la gestión adecuada de señales (p. ej. ignorando `SIGCHLD` mediante `signal.signal(signal.SIGCHLD, signal.SIG_IGN)` o delegando en el gestor de sesión/init de `systemd --user`) para que los recursos y estados de terminación se liberen automáticamente.

---

# 9. Criterios de aceptación

### CA-001

Dado un catálogo válido:

```yaml
commands:
  - name: calculator
    command:
      - gnome-calculator
    risk: low
```

`host-service` arranca correctamente.

### CA-002

Al solicitar:

```http
POST /v1/commands/execute
```

con:

```json
{
  "command": "calculator"
}
```

se inicia `gnome-calculator`.

### CA-003

Al solicitar un identificador inexistente, se devuelve `404` y no se ejecuta ningún proceso.

### CA-004

El catálogo publicado a `security-service` contiene `calculator` con riesgo `low`.

### CA-005

El catálogo publicado a `security-service` no contiene el comando físico `gnome-calculator`.

### CA-006

Una entrada con un `name` duplicado impide el arranque de `host-service`.

### CA-007

Una entrada sin `risk` impide el arranque de `host-service`.

### CA-008

Una entrada con `command` vacío impide el arranque de `host-service`.

### CA-009

La ejecución no utiliza shell.

### CA-010

La ejecución de una aplicación gráfica devuelve el control al cliente sin esperar al cierre de la aplicación.

---

# Anexo A — API propuesta

## A.1 Ejecutar comando

### Endpoint

```http
POST /v1/commands/execute
```

### Request

```json
{
  "command": "calculator"
}
```

### Respuesta — éxito

```http
HTTP/1.1 200 OK
```

```json
{
  "command": "calculator",
  "status": "started",
  "pid": 12345
}
```

### Respuesta — identificador desconocido

```http
HTTP/1.1 404 Not Found
```

```json
{
  "detail": "Unknown command: calculator"
}
```

### Respuesta — error de ejecución

```http
HTTP/1.1 500 Internal Server Error
```

El detalle concreto deberá evitar revelar información interna innecesaria.

---

# Anexo B — Configuración propuesta

## B.1 Nuevo `config/host_commands.yaml`

```yaml
commands:
  - name: calculator
    command:
      - gnome-calculator
    risk: low

  - name: github
    command:
      - github
    risk: low

  - name: backup
    command:
      - /usr/local/bin/nova-backup
    risk: medium

  - name: format-disk
    command:
      - /usr/local/bin/nova-format-disk
    risk: high
```

El campo `name` es el identificador lógico.

El campo `command` es el `argv` que ejecutará `host-service`.

El campo `risk` es la clasificación utilizada para autorización.

---

# Anexo C — Reorganización de archivos

## C.1 Situación actual

Se elimina:

```text
host_commands_risk.yaml
```

La información de riesgo deja de mantenerse separadamente.

## C.2 Situación propuesta

```text
host-service/
├── app/
│   ├── api/
│   │   └── commands.py
│   ├── commands/
│   │   ├── models.py
│   │   ├── registry.py
│   │   └── executor.py
│   ├── config/
│   │   └── loader.py
│   └── ...
├── config/
│   └── host_commands.yaml
└── ...
```

La organización exacta podrá adaptarse a la estructura actual del repositorio, pero conceptualmente deben existir estas responsabilidades:

### `host_commands.yaml`

Fuente declarativa de comandos:

```text
identifier
    +
execution argv
    +
risk
```

### `commands/models.py`

Modelo interno de un comando registrado.

### `commands/registry.py`

Carga, validación y consulta del catálogo.

Responsabilidades principales:

```text
load()
validate()
get(name)
list()
security_catalog()
```

### `commands/executor.py`

Responsable exclusivamente de ejecutar un `HostCommand` ya resuelto.

No debe resolver nombres ni aplicar lógica de seguridad.

### `api/commands.py`

Adaptador HTTP.

Responsabilidades:

```text
HTTP request
    ↓
validate request
    ↓
registry.get()
    ↓
executor.execute()
    ↓
HTTP response
```

---

# Anexo D — Modelo conceptual final

```text
                 host_commands.yaml
                         │
                         ▼
                 ┌───────────────┐
                 │ CommandRegistry│
                 └───────┬───────┘
                         │
              ┌──────────┴──────────┐
              │                     │
              ▼                     ▼
     Security Catalog        CommandExecutor
       name + risk                 │
              │                    │
              ▼                    ▼
     security-service        subprocess.Popen
                                    │
                                    ▼
                               Host process
```

Este diseño mantiene el identificador como contrato común y evita duplicar la definición del comando y su riesgo en diferentes fuentes de configuración.
