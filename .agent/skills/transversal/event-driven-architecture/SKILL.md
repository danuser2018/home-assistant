---
name: event-driven-architecture
description: Reglas y directrices para el diseño, publicación y consumo de eventos consistentes y tipados en el ecosistema Nova-2.
---

# event-driven-architecture

## Objetivo
Garantizar el uso uniforme, consistente y fuertemente tipado de la comunicación asíncrona basada en eventos en el ecosistema Nova-2, protegiendo a los servicios de dependencias específicas de brokers y de esquemas de datos inconsistentes.

## Cuándo aplicar esta skill
- Al implementar flujos de publicación o suscripción a eventos en cualquier microservicio de dominio basado en Python.

## Responsabilidades
Integración de la librería `nova-event-bus`, definición de eventos que heredan de `Event`, tópicos en decorador `@event` e inyección de callbacks asíncronos tipados.

## Invariantes (Leyes — 🔴 Críticas — Hard Constraints)
- **Prohibición de importación directa de nats-py:** Ningún microservicio de dominio puede importar `nats` o `nats.aio.client` de forma directa en su código. Toda interacción con el broker debe realizarse a través de `nova-event-bus`.
- **Modelado obligatorio mediante Event tipados:** Todos los mensajes que se publiquen o consuman a través del bus deben ser instancias de subclases de `Event`. Se prohíbe explícitamente el envío de diccionarios arbitrarios o payloads no serializables en JSON estándar.
- **Asociación al ciclo de vida del servicio:** La conexión (`connect`) y desconexión (`disconnect`) del event bus deben vincularse de forma explícita al arranque y parada de la aplicación (por ejemplo, mediante los hooks de startup/shutdown en frameworks como FastAPI o sockets de daemons).

## Reglas (Procedimientos — 🟡 Recomendadas — Soft Constraints)
- **Nomenclatura estructurada de subjects:** Los subjects registrados mediante el decorador `@event` deben escribirse en inglés y seguir una estructura jerárquica de puntos: `service.domain.event` (ej. `identity.user.created` o `calendar.event.updated`).
- **Control y captura en callbacks:** Las funciones callback de suscripción deben ser asíncronas (`async def`) y manejar de forma interna cualquier excepción de negocio que ocurra durante el procesamiento para evitar interrumpir el bucle de eventos del EventBus.

## Buenas prácticas (Recomendaciones — 🟢 Opcionales)
- Ejemplo básico de uso en un servicio:
```python
from dataclasses import dataclass
from nova_event_bus import NatsEventBus, Event, event

# 1. Definición del evento tipado
@event("identity.user.created")
@dataclass
class UserCreatedEvent(Event):
    user_id: str
    username: str
    email: str

event_bus = NatsEventBus()

async def handle_user_created(evt: UserCreatedEvent):
    # El callback recibe una instancia tipada de la clase del evento
    print(f"New user created: {evt.username} ({evt.user_id})")

async def start_service():
    # Inicialización del bus al arrancar el servicio (carga configuración desde env)
    await event_bus.connect()
    
    # Registro de suscripción tipada
    await event_bus.subscribe(UserCreatedEvent, handle_user_created)

async def publish_sample_event():
    # Publicación de evento tipado
    new_user_evt = UserCreatedEvent(user_id="usr_123", username="jdoe", email="jdoe@example.com")
    await event_bus.publish(new_user_evt)

async def stop_service():
    await event_bus.disconnect()
```

## Antipatrones (Errores conocidos)
- ❌ Publicar diccionarios de datos planos directamente sin envolverlos en una clase `Event` decorada.
- ❌ Crear subjects de forma dinámica concatenando variables en la llamada a `publish` en lugar de declararlos estáticamente en el decorador `@event`.
- ❌ No capturar excepciones dentro del callback, delegando el control de flujo al bucle interno de mensajería.
