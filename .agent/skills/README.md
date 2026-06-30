# Constitución de Nova-2: Modelo de Ejecución de Skills y Resolución de Conflictos

Este directorio contiene las **Skills** de agente para el ecosistema **Nova-2**. Estas skills no son documentación del proyecto, sino un conjunto estructurado de reglas de experto, principios e invariantes lógicos que regulan cómo el asistente de IA (Antigravity u otros agentes de desarrollo) debe modificar el código.

Cualquier agente que trabaje en esta suite debe leer este archivo en primer lugar para comprender las prioridades y la jerarquía normativa del sistema.

---

## 1. Modelo de Ejecución de Skills (Ciclo de Vida)

Cuando un agente de IA inicia una tarea, debe evaluar las skills siguiendo estrictamente este flujo secuencial:

```text
[Inicio de la Tarea]
         │
         ▼
1. Cargar Skills Transversales (Políticas Globales de Calidad y Arquitectura)
         │
         ▼
2. Cargar Skills de Dominio (Reglas de Negocio del contexto de la tarea)
         │
         ▼
3. Cargar Skills de Subsistema (Reglas Técnicas e Integración de Hardware)
         │
         ▼
4. Composición e Identificación de Invariantes (Filtro de Restricciones Duras)
         │
         ▼
5. Resolución de Conflictos (Aplicación de Reglas de Prioridad y Overrides)
         │
         ▼
6. Aplicación de Heurísticas Suaves (Estilos, sugerencias y buenas prácticas)
         │
         ▼
[Ejecución de Código / Generación]
```

### Protocolo de Carga y Aplicación de Reglas

1.  **Carga Secuencial:** El agente debe cargar primero las políticas transversales (calidad y arquitectura global), luego las del dominio de negocio específico y finalmente las de hardware/subsistema que esté modificando.
2.  **Filtro de Restricciones Duras (Hard Constraints):** Las restricciones de tipo 🔴 (Leyes) son innegociables. El asistente debe abortar o rechazar un cambio antes de violar una sola Hard Constraint.
3.  **Evaluación de Heurísticas (Soft Constraints):** Las reglas 🟡 (Procedimientos) y las buenas prácticas 🟢 (Sugerencias) guían el estilo y la mantenibilidad; se aplican de forma flexible.

---

## 2. Mecanismo de Resolución de Conflictos (Conflict Resolution)

Si dos directrices de diferentes niveles entran en contradicción durante el desarrollo, el agente de IA aplicará la siguiente jerarquía de precedencia lineal:

$$\text{Transversal} > \text{Domain Rules} > \text{Subsystem Rules} > \text{Plugin/Implementation Rules}$$

### Casos de Resolución Comunes en Nova-2

*   **Feature Flags vs. Determinismo de Intenciones:**
    *   *Resolución:* `service-responsibilities` (Transversal) prevalece sobre `system-domain` y `plugin-domain`. La resolución del lenguaje del orquestador siempre debe ser 100% determinista *para un estado dado* de una feature flag. La feature flag cambia la configuración, pero el motor de scoring no debe tener aleatoriedad interna.
*   **Idempotencia de API vs. Reintentos de Cola de Correo:**
    *   *Resolución:* `api-contracts` (Transversal) prevalece sobre `mail-domain` (Dominio). La idempotencia de un correo se garantiza en la frontera de entrada (evitando duplicar archivos en `mail/pending/`). El daemon de correo puede realizar reintentos SMTP de red transparentes, pero sin duplicar el identificador único del mensaje en la cola global.

---

## 3. Clasificación de Restricciones

*   **Restricciones Duras (Hard Constraints — Invariantes 🔴):** Innegociables. Incluyen: seguridad global, privacidad de identidad (Zero-Leak), aislamiento físico de audio de contenedores Docker, carga estática de modelos locales y esquemas unificados de errores de API.
*   **Restricciones Suaves (Soft Constraints — Reglas 🟡 y Heurísticas 🟢):** Flexibles y evolutivas. Incluyen: estilo de lenguaje del orquestador (concisión Nova-2), pesos de keywords, cobertura de tests unitarios y tácticas de despliegue en entornos locales.

---

## 4. Mapa del Catálogo de Skills

### Skills Transversales (Políticas Globales)
*   [`development-workflow`](file:///home/danuser2018/workspace/home-assistant/.agent/skills/transversal/development-workflow/SKILL.md): Calidad de Git,Conventional Commits, CHANGELOG e internacionalización (código en EN, docs en ES).
*   [`service-responsibilities`](file:///home/danuser2018/workspace/home-assistant/.agent/skills/transversal/service-responsibilities/SKILL.md): Responsabilidades explícitas, fuentes de verdad únicas de datos y límites entre host y Docker.
*   [`communication-patterns`](file:///home/danuser2018/workspace/home-assistant/.agent/skills/transversal/communication-patterns/SKILL.md): Buses de datos de archivos e interfaces síncronas/asíncronas.
*   [`api-contracts`](file:///home/danuser2018/workspace/home-assistant/.agent/skills/transversal/api-contracts/SKILL.md): Estandarización de endpoints REST, versionado y esquemas comunes de error.
*   [`system-deployment`](file:///home/danuser2018/workspace/home-assistant/.agent/skills/transversal/system-deployment/SKILL.md): Variables de entorno, docker-compose local y systemd de usuario.
*   [`architecture-decisions`](file:///home/danuser2018/workspace/home-assistant/.agent/skills/transversal/architecture-decisions/SKILL.md): Triggers para redactar y sugerir Architectural Decision Records (ADRs).
*   [`feature-refinement`](file:///home/danuser2018/workspace/home-assistant/.agent/skills/transversal/feature-refinement/SKILL.md): Reglas y plantilla para el refinamiento técnico y de negocio de nuevas features.


### Skills de Dominio (Reglas de Negocio)
*   [`identity-domain`](file:///home/danuser2018/workspace/home-assistant/.agent/skills/domains/identity-domain/SKILL.md): Privacidad de datos del usuario, propiedad y correo primario.
*   [`system-domain`](file:///home/danuser2018/workspace/home-assistant/.agent/skills/domains/system-domain/SKILL.md): Registro global de metadatos, capacidades de servicios y feature flags.
*   [`mail-domain`](file:///home/danuser2018/workspace/home-assistant/.agent/skills/domains/mail-domain/SKILL.md): Transiciones y fiabilidad anti-pérdida de la cola física de correo.
*   [`plugin-domain`](file:///home/danuser2018/workspace/home-assistant/.agent/skills/domains/plugin-domain/SKILL.md): Contrato de plugins de intenciones y estilo de respuestas de voz Nova-2.
*   [`audio-subsystem`](file:///home/danuser2018/workspace/home-assistant/.agent/skills/domains/audio-subsystem/SKILL.md): PipeWire/PulseAudio en el host, secuenciación en cola única de audios y archivo bandera.
*   [`inference-subsystem`](file:///home/danuser2018/workspace/home-assistant/.agent/skills/domains/inference-subsystem/SKILL.md): Latencia local, carga inicial estática de modelos de IA y formatos WAV.
