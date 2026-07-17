# Integración de NATS en el ecosistema Nova (Fase 1)

## Objetivo

Integrar un servidor **NATS** como un nuevo servicio Docker dentro del ecosistema Nova, dejándolo disponible para futuras comunicaciones asíncronas entre servicios.

Esta fase tiene un alcance exclusivamente de infraestructura:

* desplegar el contenedor;
* incorporarlo a la red Docker del sistema;
* garantizar su disponibilidad mediante health checks;
* documentar su existencia.

No forma parte de esta fase:

* modificar ningún servicio existente;
* publicar o consumir eventos;
* desarrollar la librería de comunicación;
* definir eventos, subjects o contratos de mensajería.

---

# Motivación

La arquitectura actual utiliza principalmente dos mecanismos de comunicación:

* llamadas REST síncronas;
* filesystem compartido para determinados procesos asíncronos.

Este modelo ha resultado suficiente para Nova 2, pero aparecen nuevos casos de uso donde un bus de eventos resulta más adecuado:

* notificaciones entre servicios;
* eventos del sistema;
* sensores;
* workflows reactivos;
* múltiples consumidores de un mismo evento;
* desacoplamiento temporal entre productores y consumidores.

La incorporación de NATS permitirá evolucionar progresivamente hacia una arquitectura orientada a eventos sin romper el funcionamiento actual. 

---

# Alcance

Esta fase incluye únicamente:

* incorporación del servicio `nats` al `docker-compose.yml`;
* conexión a la red `assistant-network`;
* configuración básica del servidor;
* healthcheck;
* documentación.

No incluye cambios funcionales en el ecosistema.

---

# Requisitos funcionales

## RF-1. Nuevo servicio Docker

El ecosistema deberá incorporar un nuevo servicio denominado:

```
nats
```

---

## RF-2. Imagen oficial

Se utilizará la imagen oficial de NATS.

No se construirán imágenes propias.

---

## RF-3. Red interna

El servicio deberá pertenecer a la red Docker existente:

```
assistant-network
```

de forma que cualquier servicio del ecosistema pueda acceder posteriormente mediante:

```
nats:4222
```

---

## RF-4. Puerto interno

El servidor escuchará en el puerto estándar:

```
4222
```

No será necesario modificarlo.

---

## RF-5. Exposición al host

Para facilitar pruebas y depuración, el puerto deberá exponerse al host.

```
4222:4222
```

---

## RF-6. Persistencia

No se requiere persistencia.

El contenedor será completamente stateless.

---

## RF-7. Configuración

No será necesario proporcionar archivos de configuración.

Se utilizará la configuración por defecto del servidor NATS.

---

## RF-8. Healthcheck

El contenedor deberá disponer de un mecanismo que permita comprobar su disponibilidad.

El resto del ecosistema podrá utilizar posteriormente este estado para declarar dependencias mediante:

```
condition: service_healthy
```

---

## RF-9. Reinicio

El servicio seguirá la misma política de reinicio utilizada por el resto de contenedores Docker del ecosistema.

---

# Requisitos no funcionales

## RNF-1. Sin impacto funcional

Tras integrar NATS:

* Nova continuará funcionando exactamente igual.
* Ningún servicio deberá modificar su comportamiento.

---

## RNF-2. Compatibilidad

La incorporación de NATS no alterará:

* APIs REST existentes;
* contratos actuales;
* estructura de plugins;
* flujo de interacción.

La integración será completamente transparente para el usuario.

---

## RNF-3. Preparación para futuras fases

La infraestructura deberá permitir que futuras versiones puedan incorporar:

* publicación de eventos;
* suscripción a eventos;
* comandos asíncronos;
* sensores;
* workflows;
* temporizadores;
* ejecución distribuida.

Sin modificar el despliegue realizado en esta fase.

---

# Cambios esperados

## docker-compose.yml

Se añadirá un nuevo servicio:

```
nats
```

con:

* imagen oficial;
* puerto 4222;
* healthcheck;
* conexión a `assistant-network`.

---

## Arquitectura

El diagrama de red Docker deberá incluir un nuevo nodo:

```
assistant-network

interaction-manager
orchestrator
tts-capability
stt-capability
system-service
identity-service
calendar-service
weather-service
mail-watchdog

nats
```

Este cambio amplía la topología actual del ecosistema Docker sin modificar las comunicaciones existentes. 

---

# Criterios de aceptación

Se considerará completada la fase cuando:

* el contenedor `nats` arranque correctamente;
* aparezca en `docker compose ps`;
* el healthcheck sea satisfactorio;
* el puerto 4222 esté disponible;
* cualquier contenedor del ecosistema pueda resolver el hostname:

```
nats
```

* no exista ninguna regresión en el funcionamiento actual de Nova.

---

# Fuera de alcance

Quedan explícitamente fuera de esta fase:

* librería Python de comunicación con NATS;
* publicación de eventos;
* consumo de eventos;
* definición de subjects;
* autenticación;
* JetStream;
* persistencia;
* colas de trabajo;
* modificación de cualquier servicio existente.
