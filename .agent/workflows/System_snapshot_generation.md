---
name: system_context_snapshot
description: Workflow para generar una fotografía arquitectónica actualizada del ecosistema Nova, consolidando la información distribuida de los distintos servicios en un único documento de contexto para asistentes de IA y revisiones técnicas.
---

# Workflow: Generación del System Context Snapshot

Este workflow guía al asistente de IA en la generación de un documento de contexto arquitectónico del ecosistema Nova a partir del estado actual de todos los servicios y su documentación.

## Objetivo

Generar una fotografía coherente y autocontenida del estado del ecosistema Nova, consolidando arquitectura, servicios, contratos, capacidades y decisiones arquitectónicas en un único documento que sirva como contexto para futuras conversaciones técnicas, revisiones de arquitectura y desarrollo de nuevas funcionalidades.

El workflow no modifica ningún archivo existente. Su única salida es un documento denominado **System Context Snapshot**.

## Parámetros de Entrada

- Workspace completo del ecosistema Nova.
- Opcionalmente, subconjunto de repositorios a incluir.
- Opcionalmente, versión o conjunto de versiones desplegadas.

---

# Pasos del Workflow

## Paso 1: Descubrimiento del Ecosistema

Identificar todos los servicios que forman parte del ecosistema.

Para cada uno obtener:

- Nombre.
- Responsabilidad.
- Estado de madurez.
- Versión (si existe).
- Repositorio correspondiente.

Identificar igualmente:

- Librerías compartidas.
- Componentes de infraestructura.
- Herramientas de línea de comandos.
- Plugins disponibles.

---

## Paso 2: Carga del Contexto Arquitectónico

Cargar toda la documentación relevante del ecosistema:

- `docs/architecture.md`
- `docs/services.md`
- Directorio `docs/adr/`
- Skills transversales relevantes.
- Skills de dominio.
- Documentación de contratos.
- README de cada servicio cuando aporte información arquitectónica.

El objetivo es reconstruir el estado arquitectónico real del sistema.

---

## Paso 3: Inventario de Servicios

Generar un inventario de todos los servicios indicando para cada uno:

- Responsabilidad.
- Interfaces públicas.
- Dependencias.
- Eventos publicados.
- Eventos consumidos.
- Estado de madurez.

El inventario debe describir responsabilidades, nunca detalles internos de implementación.

---

## Paso 4: Reconstrucción de la Topología

Reconstruir la arquitectura lógica del ecosistema identificando:

- Flujo principal de ejecución.
- Relaciones entre servicios.
- Dependencias síncronas.
- Comunicación mediante Event Bus.
- Componentes externos.

El objetivo es describir cómo coopera el conjunto del sistema.

---

## Paso 5: Inventario de Contratos

Documentar todos los contratos públicos utilizados por el ecosistema.

Incluir:

- APIs REST.
- Eventos.
- Modelos compartidos.
- Protocolos de comunicación.
- Versiones de contrato cuando existan.

No describir implementaciones internas.

---

## Paso 6: Estado Funcional del Sistema

Generar un inventario de capacidades disponibles.

Por ejemplo:

- Audio.
- Reconocimiento de voz.
- Síntesis de voz.
- Plugins.
- Host.
- Identidad.
- Clima.
- Inferencia.
- Conversación.

Para cada capacidad indicar:

- Estado.
- Servicio responsable.
- Limitaciones conocidas.

---

## Paso 7: Decisiones Arquitectónicas

Resumir las decisiones arquitectónicas actualmente vigentes obtenidas de los ADRs.

Para cada decisión indicar:

- Identificador.
- Resumen.
- Impacto sobre el diseño.

No reproducir completamente el contenido de los ADRs.

---

## Paso 8: Principios Arquitectónicos

Identificar las reglas fundamentales que gobiernan el ecosistema.

Por ejemplo:

- Separación de responsabilidades.
- Comunicación entre servicios.
- Uso de REST.
- Uso del Event Bus.
- Filosofía Plugin First.
- Local First.
- Independencia entre microservicios.

Estos principios representan los invariantes arquitectónicos del sistema.

---

## Paso 9: Estado del Ecosistema

Documentar el estado general del sistema indicando:

- Componentes estables.
- Componentes experimentales.
- Componentes en desarrollo.
- Funcionalidades previstas.
- Problemas arquitectónicos conocidos.
- Migraciones en curso.
- Deudas técnicas relevantes.

---

## Paso 10: Generación del System Context Snapshot

El workflow genera un documento con la siguiente estructura:

````markdown
# Nova System Context Snapshot

- Fecha de generación
- Servicios analizados
- Estado general del ecosistema

## 1. Resumen Ejecutivo

## 2. Arquitectura General

## 3. Topología del Sistema

## 4. Inventario de Servicios

## 5. Contratos Públicos

## 6. Capacidades Disponibles

## 7. Plugins

## 8. Decisiones Arquitectónicas

## 9. Principios Arquitectónicos

## 10. Estado del Ecosistema

## 11. Roadmap Técnico

## 12. Riesgos y Problemas Conocidos
