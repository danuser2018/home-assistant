---
name: system-deployment
description: Reglas de despliegue, configuración de contenedores, variables de entorno y daemons nativos en Linux.
---

# system-deployment

## Objetivo
Garantizar la consistencia, portabilidad y repetibilidad de la instalación en entornos locales Linux.

## Cuándo aplicar esta skill
- Al modificar archivos de configuración de entornos (`.env.example`), orquestación de contenedores (`docker-compose.yml`) o servicios systemd.
- Al añadir dependencias del host o variables del sistema.

## Responsabilidades
Despliegue, configuraciones de red, variables globales y montaje de recursos.

## Invariantes (Leyes — 🔴 Críticas — Hard Constraints)
- **Seguridad en origen:** Queda estrictamente prohibida la inclusión de credenciales SMTP o API keys reales en archivos bajo control de versiones.
- **Servicio de usuario:** Los daemons de audio nativos deben ejecutarse en el espacio de usuario (`systemd --user`) para heredar los permisos de sonido de la sesión activa del usuario.

## Reglas (Procedimientos — 🟡 Recomendadas — Soft Constraints)
- Validar la existencia de variables locales requeridas al iniciar cualquier módulo del sistema.
- Declarar todos los mapeos de directorios compartidos del host usando rutas relativas al directorio de instalación.

## Buenas prácticas (Recomendaciones — 🟢 Opcionales)
- Utilizar redes privadas aisladas en Docker Compose (`assistant-network`) para ocultar los puertos internos de los servicios del exterior.

## Antipatrones (Errores conocidos)
- ❌ Configurar dependencias absolutas a rutas de directorios específicas de un host concreto (`/home/usuario/...`).
- ❌ Ejecutar daemons de audio como servicio de sistema (`sudo systemctl`) en lugar de servicio de usuario.

## Referencias
- [installation.md](file:///home/danuser2018/workspace/home-assistant/docs/installation.md) (Guía de instalación rápida y dependencias nativas).
- [docker-compose.yml](file:///home/danuser2018/workspace/home-assistant/docker-compose.yml) (Configuración actual de redes y variables de entorno).
- [ADR-002: Modularización de Servicios](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-002.md) (Host para Hardware y Docker para Procesamiento).
- [ADR-005: Distribución mediante Imágenes Precompiladas en DockerHub](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-005.md).
- [ADR-010: Aislamiento de Variables de Entorno por Servicio](file:///home/danuser2018/workspace/home-assistant/docs/adr/adr-010.md) (Establece un archivo `.env` independiente por servicio como patrón estándar del ecosistema, eliminando el archivo compartido `config/assistant.env`).
