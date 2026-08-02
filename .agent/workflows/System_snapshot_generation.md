---
name: ai_context_snapshot
description: Genera un contexto arquitectónico condensado del ecosistema Nova optimizado para asistentes de IA. Su objetivo es proporcionar el mínimo contexto necesario para comprender el estado actual del sistema y tomar decisiones técnicas coherentes, no sustituir la documentación del proyecto.
---

# Workflow: AI Context Snapshot

## Objetivo

Este workflow genera un **AI Context Snapshot**, un documento autocontenido y altamente sintetizado destinado exclusivamente a servir como contexto inicial para otro asistente de IA.

El documento debe permitir comprender rápidamente:

- la arquitectura del ecosistema;
- las responsabilidades de cada componente;
- las reglas arquitectónicas permanentes;
- el estado actual del sistema;
- las migraciones activas;
- la dirección de evolución del proyecto.

El resultado **no es documentación técnica**, sino un contexto optimizado para IA.

---

# Principios

El documento debe seguir siempre estas prioridades:

1. Arquitectura antes que implementación.
2. Responsabilidades antes que detalles internos.
3. Restricciones antes que ejemplos.
4. Contratos antes que endpoints.
5. Estado actual antes que historia.
6. Síntesis antes que exhaustividad.

---

# Restricciones

El documento generado deberá cumplir obligatoriamente:

- Longitud aproximada entre **2 y 4 páginas**.
- Lectura completa en menos de **cinco minutos**.
- Optimizado para minimizar consumo de tokens.
- Autocontenido.
- Sin ejemplos de código.
- Sin payloads JSON.
- Sin documentación REST detallada.
- Sin reproducir ADRs.
- Sin información histórica salvo cuando siga condicionando decisiones actuales.

---

# Regla Fundamental

Antes de incluir cualquier información, el asistente deberá responder mentalmente:

> **¿Este dato cambiaría una futura decisión técnica de otra IA?**

Si la respuesta es **NO**, deberá omitirse.

---

# Información que normalmente debe omitirse

- ejemplos de código;
- payloads completos;
- parámetros REST;
- formatos JSON;
- puertos;
- configuración Docker;
- variables de entorno;
- detalles internos de implementación;
- cronología histórica;
- información repetida.

---

# Información que debe priorizarse

- responsabilidades;
- contratos públicos;
- límites entre servicios;
- restricciones;
- invariantes;
- componentes deprecados;
- migraciones;
- riesgos;
- dirección arquitectónica.

---

# Parámetros de Entrada

- Workspace completo del ecosistema Nova.
- Repositorios disponibles.
- Documentación.
- ADRs.
- Skills.
- Contratos públicos.

---

# Pasos del Workflow

## Paso 1 — Descubrimiento del Ecosistema

Identificar automáticamente:

- servicios;
- daemons;
- herramientas CLI;
- librerías compartidas;
- plugins;
- infraestructura;
- componentes Host;
- componentes Docker.

Construir un inventario lógico del ecosistema.

---

## Paso 2 — Reconstrucción Arquitectónica

Cargar únicamente la documentación necesaria para reconstruir el estado actual del sistema.

Fuentes principales:

- `docs/architecture.md`
- `docs/services.md`
- `docs/adr/`
- documentación de contratos
- skills
- README con contenido arquitectónico

La documentación debe utilizarse para inferir el estado del sistema, nunca para reproducirla.

---

## Paso 3 — Validación de Consistencia

Detectar automáticamente:

- servicios no documentados;
- documentación obsoleta;
- contratos inconsistentes;
- eventos sin productor;
- eventos sin consumidor;
- ADRs obsoletos;
- referencias cruzadas rotas;
- discrepancias entre repositorios.

Las inconsistencias deberán aparecer resumidas en el documento final.

---

## Paso 4 — Extracción del Modelo Mental

Generar un resumen muy breve que permita comprender inmediatamente:

- qué es Nova;
- qué NO es Nova;
- cómo está organizado;
- cuál es su filosofía;
- qué principios condicionan todas las decisiones futuras.

Esta sección debe ocupar únicamente unas pocas líneas.

---

## Paso 5 — Invariantes Arquitectónicos

Extraer únicamente las reglas permanentes del ecosistema.

Ejemplos:

- Local First
- Plugin First
- Servicios independientes
- Host/Docker Boundary
- HAL obligatorio
- REST síncrono
- Event Bus asíncrono
- Contratos estables

No incluir reglas temporales.

---

## Paso 6 — Fronteras de Servicio

Para cada servicio generar únicamente:

- responsabilidad principal;
- qué NO hace;
- dependencias relevantes.

No describir implementación interna.

---

## Paso 7 — Estado del Ecosistema

Resumir:

- componentes estables;
- componentes experimentales;
- migraciones activas;
- componentes deprecados;
- deuda técnica;
- riesgos.

No incluir historia del proyecto.

---

## Paso 8 — Dirección del Desarrollo

Identificar automáticamente:

- iniciativas activas;
- roadmap inmediato;
- refactorizaciones;
- componentes que evolucionarán próximamente.

Esta información debe ayudar a orientar futuras propuestas.

---

## Paso 9 — Guías de Diseño

Generar una pequeña colección de reglas prácticas para futuras implementaciones.

Por ejemplo:

- Preferir nuevos plugins antes que ampliar el orquestador.
- Reutilizar contratos existentes.
- Evitar nuevas dependencias síncronas.
- Priorizar eventos frente a llamadas REST cuando sea posible.
- Mantener servicios stateless.
- Nunca acceder al hardware desde Docker.
- Nunca bypassar HAL.

Estas reglas deben representar la forma recomendada de extender el ecosistema.

---

## Paso 10 — Generación del AI Context Snapshot

El documento generado deberá seguir exactamente esta estructura:

````markdown
# Nova AI Context Snapshot

## Current Snapshot

Resumen ejecutivo del estado actual.

Debe incluir únicamente:

- arquitectura;
- número aproximado de servicios;
- backend del Event Bus;
- migraciones activas;
- componentes deprecados;
- foco actual;
- restricciones principales.

---

## Mental Model

Qué es Nova.

Qué NO es Nova.

Cómo debe entenderlo una IA.

---

## Architectural Invariants

Reglas permanentes del sistema.

---

## System Topology

Topología simplificada.

Máximo un diagrama.

---

## Vocabulary

Glosario de los conceptos fundamentales del proyecto.

---

## Service Boundaries

Tabla resumida:

- servicio;
- responsabilidad;
- qué NO hace;
- dependencias.

---

## Public Contracts

Resumen de:

- APIs relevantes;
- eventos;
- modelos compartidos.

No incluir payloads ni endpoints completos.

---

## Migration Status

- migraciones;
- elementos deprecados;
- compatibilidad.

---

## Current Development Focus

Qué partes están evolucionando actualmente.

---

## Design Guidelines

Buenas prácticas para añadir nuevas capacidades al ecosistema.

---

## Expected Architectural Evolution

Descripción muy breve (máximo 5-10 líneas) de la dirección prevista para la arquitectura.

Debe responder preguntas como:

- ¿Qué componentes tenderán a desaparecer?
- ¿Qué mecanismos se convertirán en el estándar?
- ¿Qué principios seguirán reforzándose?

Esta sección debe describir únicamente la evolución esperada, nunca el roadmap funcional.

---

## Known Constraints

Restricciones que cualquier cambio futuro debe respetar.

---

## Known Inconsistencies

Discrepancias detectadas entre documentación y estado del ecosistema.

---

## Architectural Decisions

Resumen de los ADRs vigentes.

Una única línea por ADR.

No reproducir el contenido de los documentos.

---

## Criterios de Calidad

El AI Context Snapshot solo se considerará correcto si cumple todos los siguientes criterios:

- Puede utilizarse directamente como contexto inicial para otra IA.
- Permite comprender Nova en menos de cinco minutos.
- No supera aproximadamente cuatro páginas.
- No contiene información redundante.
- No reproduce documentación existente.
- No describe implementaciones salvo cuando constituyan invariantes arquitectónicos.
- Todo el contenido influye en futuras decisiones técnicas.
- Una IA puede responder correctamente a la mayoría de preguntas sobre arquitectura utilizando únicamente este documento.
- El documento transmite tanto el estado actual como la dirección arquitectónica del ecosistema.

---

## Referencias

- `docs/architecture.md`
- `docs/services.md`
- `docs/adr/`
- Documentación de contratos
- Skills transversales
- Skills de dominio
