# Integración del Weather Service en el ecosistema Nova

## 1. Introducción

### 1.1 Objetivo

Integrar el nuevo microservicio **weather-service** dentro del ecosistema Nova para que pueda ser consumido por los plugins de dominio mediante el mecanismo habitual de comunicación entre servicios.

Esta fase no modifica el comportamiento del Weather Plugin. Su objetivo es únicamente dejar disponible el nuevo servicio dentro de la plataforma.

---

# 2. Alcance

## Incluido

- Incorporación del servicio al repositorio de Nova.
- Contenerización mediante Docker.
- Integración en docker-compose.
- Configuración mediante variables de entorno.
- Comunicación interna entre servicios.
- Verificación del correcto despliegue.

## No incluido

- Modificación del Weather Plugin.
- Consulta real desde el plugin.
- Enriquecimiento temporal.
- Gestión de ubicaciones.
- Nuevas capacidades conversacionales.

---

# 3. Requisitos funcionales

## RF-001 Registro del servicio

El Weather Service deberá incorporarse al ecosistema Nova como un nuevo microservicio.

---

## RF-002 Despliegue

El servicio deberá desplegarse automáticamente junto al resto de servicios mediante Docker Compose.

---

## RF-003 Descubrimiento

El servicio deberá ser accesible mediante el nombre de host definido en Docker Compose.

---

## RF-004 Configuración

Las variables de entorno necesarias para el funcionamiento del servicio deberán configurarse durante el despliegue.

---

## RF-005 Comunicación

El servicio deberá aceptar peticiones REST desde el resto de servicios internos del ecosistema.

---

## RF-006 Health Check

El servicio deberá exponer un endpoint de comprobación de estado para verificar su disponibilidad.

Ejemplo:

```
GET /health
```

---

## RF-007 Verificación

La integración deberá incluir una validación que confirme que el servicio responde correctamente una vez desplegado.

---

# 4. Requisitos no funcionales

## RNF-001 Consistencia arquitectónica

La integración deberá seguir las mismas convenciones utilizadas por el resto de microservicios de Nova.

---

## RNF-002 Aislamiento

El Weather Service deberá ejecutarse como un servicio independiente.

---

## RNF-003 Comunicación interna

Toda la comunicación se realizará mediante la red interna definida por Docker Compose.

El servicio no deberá depender de direcciones IP fijas.

---

## RNF-004 Configuración

La configuración deberá realizarse exclusivamente mediante variables de entorno.

---

## RNF-005 Observabilidad

El servicio deberá integrarse con el mecanismo estándar de logging utilizado por Nova.

---

## RNF-006 Arranque

El despliegue del servicio no deberá afectar al proceso de arranque del resto de componentes.

---

# 5. Cambios esperados

La integración afectará previsiblemente a:

- docker-compose.yml
- Variables de entorno del entorno de desarrollo
- Registro del nuevo servicio
- Documentación de despliegue

No se esperan cambios funcionales en ningún plugin existente.

---

# 6. Criterios de aceptación

La integración se considerará completada cuando:

- El ecosistema Nova despliegue correctamente el Weather Service.
- El servicio responda al endpoint `/health`.
- El endpoint `/v1/weather/current` responda correctamente desde la red interna.
- El resto de servicios puedan comunicarse con el Weather Service mediante su nombre de host.
- No se produzcan regresiones en el resto del ecosistema.