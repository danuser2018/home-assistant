# Requirements Definition

## CommandResolver, Command Catalog & NATS Command Catalog Distribution

**Project:** NOVA
**Component:** `CommandResolver` / `ParameterResolverEngine` / `host-service` / `security-service` / `orchestrator`
**Status:** Requirements Definition
**Version:** 1.0

---

# 1. Purpose

This document defines the requirements for introducing and integrating the `CommandResolver` into NOVA, together with the refactoring required to make the command catalog a NOVA-level configuration resource and the normalization of command-related communication between:

* `host-service`
* `orchestrator`
* `security-service`
* `ParameterResolverEngine`

The objective is to provide a deterministic and secure mechanism to transform a natural-language command produced by the NOVA planning/interaction pipeline into a **logical command identifier**, while keeping the physical execution details private to `host-service`.

The feature also establishes a single command catalog as the source of truth and distributes the relevant catalog projection through NATS.

---

# 2. Scope

This feature includes:

1. Creation/integration of `CommandResolver`.
2. Integration with the existing `ParameterResolverEngine`.
3. Definition of the NOVA-level `config/commands.yaml`.
4. Migration of command catalog configuration out of `host-service` internal configuration.
5. Definition of the public command catalog NATS event.
6. Periodic publication of the catalog by `host-service`.
7. Consumption and in-memory projection by `orchestrator` and `security-service`.
8. Command phrase normalization.
9. Exact and fuzzy command matching.
10. Risk-dependent fuzzy matching thresholds.
11. Ambiguity detection.
12. Normalization of command-related NATS communication.
13. Preservation of `host-service` as the sole owner of physical command execution.
14. Security integration and fail-closed behavior.
15. Testing and acceptance criteria.

This feature does **not** include:

* Semantic NLP.
* LLM-based command interpretation.
* Automatic synonym generation.
* Stemming or lemmatization.
* Embedding-based matching.
* Dynamic/hot reload of `commands.yaml`.
* Changes to the global `ParameterResolutionStatus` contract.
* Dynamic command catalog modification through REST.
* Distribution of physical command execution definitions to other services.

---

# 3. Architectural Principles

The implementation MUST preserve the existing NOVA architectural principles:

* Privacy First.
* Service boundaries.
* HAL where applicable.
* Plugin-first architecture.
* Typed inter-service messaging.
* Per-service configuration.
* REST for synchronous communication.
* NATS for asynchronous communication.
* `identity-service` as identity source of truth.
* Security default deny.
* Logical identifiers across service boundaries.
* Physical implementation details isolated within the owning service.

The command catalog introduces a deliberate distinction between:

**Logical command**

```text
calculator
```

and:

**Physical command**

```text
gnome-calculator
```

Only the logical identifier may cross the public command-resolution boundary.

---

# 4. Command Catalog

## 4.1 Location

The command catalog MUST be located at:

```text
config/commands.yaml
```

It is NOVA-level configuration and MUST NOT be considered private/internal configuration belonging to `host-service`.

---

## 4.2 Structure

The initial schema is:

```yaml
commands:
  - name: calculator
    command:
      - gnome-calculator
    risk: low
    phrases:
      - calculadora
      - máquina de calcular
      - el programa de cuentas
```

Each command MUST contain:

| Field     | Purpose                                                        |
| --------- | -------------------------------------------------------------- |
| `name`    | Stable logical command identifier                              |
| `command` | Physical command definition used exclusively by `host-service` |
| `risk`    | User-defined risk classification                               |
| `phrases` | Natural-language phrases accepted by `CommandResolver`         |

---

## 4.3 Logical command name

`name` MUST be:

* unique within the catalog;
* stable;
* the identifier used by `CommandResolver`;
* the identifier used by Security authorization;
* the identifier represented in execution plans.

Other services MUST NOT need to know how the command is physically executed.

---

## 4.4 Physical command

The `command` field describes the physical execution command.

This information is private to `host-service`.

It MUST NOT be included in:

```text
event.host.commands.available
```

It MUST NOT be consumed by `orchestrator` or `CommandResolver`.

This guarantees that the physical implementation may change without requiring changes to the rest of NOVA.

For example:

```yaml
command:
  - gnome-calculator
```

may later become:

```yaml
command:
  - kcalc
```

without changing the logical command:

```text
calculator
```

---

# 5. Risk Classification

`risk` MUST be part of the command catalog.

Example:

```yaml
risk: low
```

Supported initial levels:

```text
low
medium
high
```

Risk is intentionally **user-configurable**.

NOVA MUST NOT assume that a particular command has a universally correct risk classification.

The user may classify a command according to:

* their environment;
* their trust model;
* their own perception of consequences;
* their desired security posture.

The same physical action may therefore legitimately receive different risk classifications in different NOVA installations.

---

# 6. Command Catalog as Source of Truth

`commands.yaml` MUST be the single source of truth for command metadata.

The catalog contains information required by different consumers:

```text
                    commands.yaml
                         │
                         ▼
                   host-service
                         │
              ┌──────────┴──────────┐
              │                     │
        physical execution     public projection
              │                     │
              │                     ▼
              │                    NATS
              │               ┌─────┴─────┐
              │               ▼           ▼
              │          orchestrator  security
              │
              ▼
       physical command
```

Consumers MUST maintain projections containing only the information they require.

---

# 7. NATS Command Catalog Event

## 7.1 Subject

The public command catalog event MUST use:

```text
event.host.commands.available
```

---

## 7.2 Purpose

The event communicates the complete currently available command catalog to interested services.

It represents:

> The command catalog currently available to NOVA.

It is not a delta/update event.

---

## 7.3 Payload

The public event MUST contain:

```json
{
  "version": 1,
  "commands": [
    {
      "name": "calculator",
      "risk": "low",
      "phrases": [
        "calculadora",
        "máquina de calcular",
        "el programa de cuentas"
      ]
    }
  ]
}
```

The event MUST NOT expose:

```json
{
  "command": [
    "gnome-calculator"
  ]
}
```

---

## 7.4 Event contract version

`version` identifies the **event contract version**.

It is not an incrementing catalog revision.

The initial value is:

```text
version: 1
```

---

# 8. Catalog Publication

`host-service` MUST publish the complete command catalog:

1. immediately after successfully loading and validating `commands.yaml`;
2. subsequently once every 60 seconds.

Therefore the expected lifecycle is:

```text
host-service startup
        │
        ▼
publish catalog
        │
        ▼
wait 60 seconds
        │
        ▼
publish catalog
        │
        ▼
repeat
```

The periodic publication is intentional.

It provides a simple recovery mechanism for consumers that:

* start after the initial publication;
* restart;
* temporarily lose the event;
* become temporarily unavailable.

No additional catalog synchronization protocol is required.

---

# 9. Consumer Behavior

## 9.1 Orchestrator

`orchestrator` MUST subscribe to:

```text
event.host.commands.available
```

Upon receiving the event, it MUST update its in-memory command catalog.

The catalog MUST contain at least:

```text
name
risk
phrases
```

The physical `command` MUST NOT be required.

If `orchestrator` has no catalog available, `CommandResolver` MUST NOT resolve a command.

It MUST NOT:

* infer a command from its own knowledge;
* query `host-service` directly;
* use stale assumptions;
* invent a command identifier.

---

## 9.2 Security Service

`security-service` MUST subscribe to:

```text
event.host.commands.available
```

Upon receiving the event, it MUST update its in-memory command catalog.

Security requires at least:

```text
name
risk
```

If a requested command is not present in the Security catalog, authorization MUST fail closed:

```text
DENY
```

---

# 10. Startup and Resilience

The architecture MUST NOT require consumers to restart `host-service` in order to reconstruct their command catalog.

Example:

```text
host-service ────────────────┐
                             │
                         NATS event
                             │
              ┌──────────────┴──────────────┐
              ▼                             ▼
        orchestrator                  security-service
```

If `orchestrator` restarts:

```text
restart
   │
   ▼
wait for catalog
   │
   ▼
next publication ≤ approximately 60 s
   │
   ▼
reconstruct in-memory catalog
```

The same applies to `security-service`.

If a consumer receives no catalog yet:

* `CommandResolver` cannot resolve;
* Security cannot authorize an unknown command.

This preserves fail-closed behavior.

---

# 11. CommandResolver Integration

`CommandResolver` MUST integrate with the existing `ParameterResolver` architecture.

It MUST implement the existing resolver contract based on:

```text
BaseParameterResolver.target_type
async resolve(context, definition)
```

It MUST be registered through the existing resolver mechanism and integrated into:

```text
ParameterResolverEngine
```

No parallel or incompatible resolver contract may be introduced.

The resolver MUST produce the logical command identifier rather than the physical execution command.

Example:

```text
Input:
"abre la calculadora"

Output:
calculator
```

It MUST NOT produce:

```text
gnome-calculator
```

---

# 12. Command Resolution Pipeline

The intended resolution flow is:

```text
STT
 │
 ▼
Planner / interaction pipeline
 │
 ▼
CommandResolver
 │
 ├── normalize
 │
 ├── exact match
 │
 └── fuzzy match if required
 │
 ▼
logical command
 │
 ▼
ExecutionPlan
 │
 ▼
Security
 │
 ▼
Host Service
 │
 ▼
physical execution
```

The physical execution command becomes relevant only at the final `host-service` boundary.

---

# 13. Phrase Normalization

Both:

* incoming STT text;
* configured `phrases`;

MUST be normalized before matching.

Normalization MUST include:

1. Unicode normalization.
2. Conversion to lowercase.
3. Removal of irrelevant punctuation.
4. Whitespace normalization.
5. Removal of diacritics.

Example:

```text
"  ¡Máquina   de CALCULAR!  "
```

MUST normalize to:

```text
"maquina de calcular"
```

Therefore:

```text
"máquina de calcular"
```

and:

```text
"maquina de calcular"
```

MUST be treated as equivalent for matching.

---

# 14. Matching Strategy

The resolver MUST use the following order:

```text
1. Normalize input and phrases
2. Attempt exact match
3. If exact match fails, use RapidFuzz
4. Apply risk-dependent threshold
5. Return resolved / unresolved result
```

Exact matching MUST take precedence over fuzzy matching.

The resolver MUST NOT use:

* semantic NLP;
* stemming;
* lemmatization;
* automatic synonyms;
* embeddings;
* LLM interpretation;
* translation.

The first implementation intentionally remains deterministic and bounded.

---

# 15. Full Phrase Matching

Matching MUST initially operate on the complete normalized phrase.

The resolver MUST NOT attempt arbitrary substring extraction.

For example, if the configured phrase is:

```text
abre la calculadora
```

the resolver should match that phrase against the complete normalized resolver input.

The first implementation does not need to interpret arbitrary surrounding language such as:

```text
oye nova, cuando puedas, por favor abre la calculadora
```

unless the upstream component produces the expected command phrase.

This keeps the resolver predictable and prevents it from becoming a general-purpose NLP component.

The expected command definitions are intentionally simple, for example:

```text
abre la calculadora
ejecuta la calculadora
```

---

# 16. RapidFuzz

RapidFuzz MUST be used as the fuzzy matching implementation after exact matching fails.

The purpose is primarily to tolerate minor recognition differences introduced by STT, such as:

* character substitutions;
* omissions;
* duplicated characters;
* small transcription errors.

Fuzzy matching MUST NOT be used to infer arbitrary semantic equivalence.

For example:

```text
"abre la calculadoraa"
```

may reasonably match:

```text
"abre la calculadora"
```

while:

```text
"quiero hacer una cuenta"
```

should not become a calculator command merely because both are semantically related.

---

# 17. Risk-Dependent Fuzzy Matching

The fuzzy matching threshold MUST NOT be configured individually inside `commands.yaml`.

Instead, `CommandResolver` MUST use an internal matching policy based on command risk.

Conceptually:

```text
LOW
  → more tolerant

MEDIUM
  → more restrictive

HIGH
  → most restrictive
```

The rationale is that false-positive resolution has different consequences depending on command risk.

A false positive involving a low-risk command is generally less consequential than a false positive involving a high-risk command.

Therefore:

> The higher the command risk, the stronger the textual evidence required before accepting a fuzzy match.

Exact matches remain valid independently of the risk threshold.

---

# 18. Initial Threshold Policy

The implementation SHOULD start with reasonable internal threshold values for:

```text
low
medium
high
```

The precise values are an implementation-level decision and MUST NOT become part of the command catalog.

The initial values MAY be adjusted based on observed NOVA behavior and real STT errors.

The project deliberately follows an iterative tuning approach:

```text
initial values
      ↓
real usage
      ↓
observe false positives / false negatives
      ↓
adjust policy
      ↓
repeat
```

This approach avoids premature over-engineering and allows the policy to be tuned using actual NOVA interaction behavior.

---

# 19. Ambiguity

The resolver MUST NOT arbitrarily select the highest-scoring fuzzy candidate when multiple candidates are sufficiently plausible.

Example:

```text
calculator → 89
calendar   → 87
```

If both candidates satisfy the relevant matching criteria and the difference is insufficient to establish a reliable winner, the result MUST be treated as unresolved/ambiguous.

The existing `ParameterResolutionStatus` contract MUST be reused.

A new:

```text
AMBIGUOUS
```

status MUST NOT be introduced as part of this feature.

The resolver MAY expose the reason for the failed resolution through diagnostics/logging, for example:

```text
reason=ambiguous
```

but the public resolution contract remains unchanged.

An ambiguous resolution MUST NEVER result in an executable command.

---

# 20. No Catalog Behavior

## 20.1 CommandResolver

If `orchestrator` has not received a command catalog:

```text
CommandResolver → no resolution
```

The resolver MUST NOT attempt fallback resolution.

---

## 20.2 Security

If `security-service` has not received a catalog, or the requested logical command does not exist in its current catalog:

```text
Security → DENY
```

This is mandatory.

Security remains **default deny**.

---

# 21. Host Service Responsibilities

After the refactor, `host-service` MUST:

1. Load `config/commands.yaml`.
2. Validate the command catalog.
3. Keep the complete catalog required for local execution.
4. Publish the public catalog through NATS.
5. Republish it every 60 seconds.
6. Execute physical commands.
7. Keep physical command definitions private.

`host-service` MUST NOT delegate physical command execution to another service.

---

# 22. Configuration Validation

`host-service` MUST validate the catalog before publishing it.

At minimum, validation MUST ensure:

* command names are unique;
* required fields are present;
* risk values are valid;
* phrases are valid;
* commands are structurally valid.

An invalid catalog MUST NOT result in a partially published catalog.

The service MUST report configuration failure according to existing NOVA service error conventions.

---

# 23. Security Integration

The security flow MUST continue to operate independently from command resolution.

Conceptually:

```text
CommandResolver
      │
      ▼
logical command
      │
      ▼
ExecutionPlan
      │
      ▼
Security
      │
      ├── command exists?
      ├── risk known?
      └── policy allows?
             │
          ALLOW/DENY
             │
             ▼
        Host Service
```

`CommandResolver` MUST NOT authorize commands.

Security MUST remain the authority responsible for authorization.

---

# 24. Separation of Concerns

The resulting responsibilities MUST be:

| Component                 | Responsibility                                           |
| ------------------------- | -------------------------------------------------------- |
| `commands.yaml`           | Source of command definitions                            |
| `host-service`            | Load catalog, publish catalog, execute physical commands |
| `orchestrator`            | Maintain command projection and orchestrate execution    |
| `CommandResolver`         | Convert natural-language phrase to logical command       |
| `ParameterResolverEngine` | Integrate and invoke resolvers                           |
| `security-service`        | Authorize/deny command execution                         |
| NATS                      | Distribute command catalog                               |
| Planner                   | Determine intended action/command structure              |

No component should assume another component's private responsibilities.

---

# 25. NATS Normalization

The implementation MUST use the established NOVA NATS communication model.

The command catalog MUST use:

```text
event.host.commands.available
```

The event represents a complete catalog snapshot.

Consumers MUST treat each received event as authoritative for the current catalog and update their in-memory projection accordingly.

No REST synchronization endpoint is required.

---

# 26. Failure and Recovery Model

The following scenarios MUST be supported:

### Consumer starts after host-service

```text
consumer starts
      ↓
waits
      ↓
next catalog publication
      ↓
catalog reconstructed
```

Maximum normal recovery interval is approximately the publication interval:

```text
≤ 60 seconds
```

### Consumer restarts

No `host-service` restart is required.

### NATS temporarily loses delivery

The next periodic publication provides another opportunity to reconstruct the catalog.

### host-service restarts

It validates and publishes the catalog immediately after startup and resumes periodic publication.

### Invalid configuration

No invalid/partial catalog is distributed.

### Unknown command

Security denies.

### Missing catalog

Resolver cannot resolve; Security denies.

### Ambiguous fuzzy match

Resolver does not produce an executable command.

---

# 27. Testing Requirements

Testing MUST cover at least:

## 27.1 Catalog

* valid catalog;
* invalid catalog;
* duplicate command names;
* invalid risk;
* missing fields;
* malformed phrases.

## 27.2 NATS

* initial publication;
* periodic publication;
* correct subject;
* correct payload;
* absence of physical `command`;
* consumer catalog reconstruction;
* consumer update after receiving a newer publication.

## 27.3 Normalization

Tests MUST cover:

* uppercase/lowercase;
* accented/unaccented text;
* repeated whitespace;
* punctuation;
* Unicode normalization.

Example:

```text
"  ¡MÁQUINA   DE CALCULAR! "
```

must normalize consistently with:

```text
"maquina de calcular"
```

## 27.4 Exact matching

Exact matches MUST resolve deterministically.

## 27.5 Fuzzy matching

Tests MUST cover representative STT errors.

## 27.6 Risk policy

Tests MUST verify that:

```text
low < medium < high
```

in terms of matching tolerance.

The exact numerical relationship is an implementation detail, but higher-risk commands MUST require stricter evidence.

## 27.7 Ambiguity

Tests MUST verify that close competing candidates do not result in arbitrary selection.

## 27.8 Missing catalog

`CommandResolver` MUST fail to resolve without a catalog.

## 27.9 Security

Unknown commands MUST produce:

```text
DENY
```

---

# 28. Acceptance Criteria

The feature is considered complete when all of the following are true:

### AC-01 — Catalog

`config/commands.yaml` is the source of truth for commands.

### AC-02 — Risk

`risk` is defined per command and remains user-configurable.

### AC-03 — Host ownership

Only `host-service` knows and executes physical command definitions.

### AC-04 — NATS publication

`host-service` publishes:

```text
event.host.commands.available
```

immediately after startup.

### AC-05 — Periodic publication

The catalog is republished every 60 seconds.

### AC-06 — Consumer reconstruction

`orchestrator` and `security-service` can reconstruct their in-memory catalog without restarting `host-service`.

### AC-07 — Public projection

The NATS event contains `name`, `risk`, and `phrases`, but not the physical `command`.

### AC-08 — Resolver integration

`CommandResolver` uses the existing `BaseParameterResolver` / `ParameterResolverEngine` architecture.

### AC-09 — Normalization

Configured phrases and input text are normalized consistently.

### AC-10 — Exact matching

Exact normalized matches are resolved deterministically.

### AC-11 — Fuzzy matching

RapidFuzz is used only after exact matching fails.

### AC-12 — Risk-sensitive tolerance

Fuzzy matching is more restrictive for higher-risk commands.

### AC-13 — Ambiguity

Ambiguous matches do not produce executable commands.

### AC-14 — Existing status contract

No new `ParameterResolutionStatus` value is introduced.

### AC-15 — Missing catalog

No catalog means no command resolution.

### AC-16 — Security fail-closed

Unknown commands or missing Security catalog result in `DENY`.

### AC-17 — Physical command isolation

No physical command definition crosses the public command catalog boundary.

### AC-18 — No semantic inference

The first implementation does not introduce NLP, semantic matching, synonyms, embeddings or LLM-based resolution.

### AC-19 — Disconnection resilience and convergence window

Following a restart or loss of NATS connectivity by consumers (`orchestrator` or `security-service`), intermediate requests operate in safe fail-closed mode (`UNRESOLVED` / `DENY`) without unhandled errors. Upon receiving the subsequent periodic publication, the in-memory catalog is restored autonomously without manual intervention. The publication interval MUST be configurable to enable fast automated testing without real-time delays.

---

# 29. Migration

The migration MUST move command catalog ownership from `host-service` internal configuration to:

```text
config/commands.yaml
```

The physical command definitions remain available to `host-service` through this shared NOVA configuration.

The migration MUST remove duplicate command catalog definitions from `host-service`.

There MUST be a single authoritative command definition.

The migration MUST preserve existing command behavior.

---

# 30. Documentation and ADR Impact

The implementation MUST update relevant architectural documentation.

At minimum, documentation SHOULD cover:

1. Command catalog ownership.
2. `event.host.commands.available`.
3. Public catalog projection.
4. `CommandResolver`.
5. Risk-dependent fuzzy matching.
6. `host-service` execution boundary.
7. Security catalog consumption.
8. Periodic catalog publication.

An ADR SHOULD document the key architectural decisions, especially:

* why the catalog is NOVA-level configuration;
* why physical commands are not distributed;
* why NATS is used for catalog distribution;
* why publication is periodic;
* why risk influences fuzzy matching;
* why ambiguity does not create a new global resolver status;
* why semantic NLP is intentionally excluded from the first implementation.

---

# 31. Non-Goals

The following are explicitly outside this feature:

```text
Dynamic command creation
Dynamic command deletion
Hot reload
REST catalog synchronization
Semantic intent recognition
LLM command interpretation
Automatic synonyms
Embeddings
Natural-language command extraction
New global ParameterResolutionStatus values
Remote physical command execution
```

These may be considered independently in future features.

---

# 32. Final Architecture

The resulting architecture is:

```text
                         config/commands.yaml
                                  │
                                  ▼
                           ┌─────────────┐
                           │ host-service│
                           └──────┬──────┘
                                  │
                  publish at startup + every 60s
                                  │
                                  ▼
                                 NATS
                                  │
                    event.host.commands.available
                                  │
                         ┌────────┴────────┐
                         ▼                 ▼
                  orchestrator       security-service
                         │                 │
                  command catalog    security catalog
                         │
                         ▼
                  ParameterResolver
                         │
                         ▼
                   CommandResolver
                         │
                    logical name
                         │
                         ▼
                    ExecutionPlan
                         │
                         ▼
                      Security
                         │
                    ALLOW / DENY
                         │
                         ▼
                    host-service
                         │
                  physical command
                         │
                         ▼
                      execution
```

The central architectural invariant is:

> **NOVA resolves and authorizes logical commands; `host-service` alone knows how those commands are physically executed.**

This keeps command resolution deterministic, Security fail-closed, configuration centralized, and physical execution details encapsulated.
