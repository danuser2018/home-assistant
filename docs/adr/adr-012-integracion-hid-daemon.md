# ADR-012: Integración del Servicio HID Daemon (hid-daemon)

## Fecha
05-07-2026

## Estado
Aceptado

## Contexto
El asistente de voz local Nova-2 requiere interactuar con periféricos de hardware físico (como pedales USB de un solo botón, teclados macro o botones dedicados) para controlar el estado de grabación del micrófono (modos Push-To-Talk o Toggle).

Sin embargo:
1. Acceder directamente a los archivos de dispositivos de entrada del kernel en `/dev/input/event*` requiere privilegios de lectura y escritura que pertenecen al grupo de sistema `input` o al superusuario `root`.
2. Siguiendo el [ADR-002: Modularización de Servicios](adr/adr-002.md), el plano de procesamiento en Docker es ciego a los periféricos de hardware y no debe interactuar con ellos para mantener la portabilidad y la seguridad.
3. Se necesita que la captura de estas teclas físicas funcione de fondo de forma continua, incluso en instalaciones de tipo servidor headless, sin depender de un servidor X11/Wayland o de un gestor de ventanas de escritorio activo (como GNOME o KDE).

## Decisión
Se implementará el servicio `hid-daemon` en el **Plano de Hardware (Host Nativo)** como un servicio de usuario de systemd (`systemd --user`).

Este servicio tendrá las siguientes características:
- Utilizará la interfaz del kernel de Linux `evdev` mediante la biblioteca de Python homónima para acceder y monitorizar los archivos de dispositivos.
- Buscará y se conectará al periférico por su ruta física (`device_path`) o escaneando de forma dinámica los nombres legibles de los dispositivos de entrada (`device_name`).
- Ofrecerá tolerancia a desconexiones de hardware físicas mediante un bucle de reconexión automático no bloqueante ante señales de apagado del sistema.
- Resolverá de forma insensible a mayúsculas/minúsculas atajos por nombre de tecla (ej. `KEY_F9`) o código numérico crudo.
- Soportará dos modos principales de ejecución:
  - **PTT (Push-To-Talk):** Ejecuta un comando en la pulsación de tecla y otro en su liberación.
  - **TOGGLE:** Alterna la ejecución de comandos en pulsaciones sucesivas, ignorando eventos repetidos.
- Delegará la ejecución de comandos del sistema a través de subprocesos aislados (usando `subprocess`), llamando de forma nativa a los scripts de control ya provistos por otros servicios (ej. `mic-toggle.sh`).

## Alternativas consideradas
- **Captura mediante atajos globales del entorno de escritorio (GNOME/KDE):** Descartada porque requiere una sesión de escritorio gráfico activa y logueada en pantalla, no siendo viable para servidores domésticos headless.
- **Dockerizar el servicio HID pasando `/dev/input` al contenedor:** Descartada porque requiere ejecutar el contenedor con privilegios elevados (`--privileged`) o mapear grupos de manera manual en docker-compose, lo que degrada drásticamente la seguridad del sandbox y la portabilidad acústica.

## Consecuencias
+ **Control de hardware físico nativo:** Captura de bajo nivel en cualquier circunstancia, con o sin pantalla conectada.
+ **Seguridad de privilegios:** El daemon corre en el espacio de usuario del host (`systemd --user`) y lee los dispositivos perteneciendo al grupo `input`, sin requerir permisos de `root`.
+ **Desacoplamiento:** El orquestador y los contenedores de procesamiento no tienen conocimientos del hardware de entrada física específico conectado.
+ **Tolerancia a fallos:** El daemon reconecta de forma transparente ante tirones del cable USB u otros fallos de hardware.
- **Gestión mixta de servicios:** Añade un tercer servicio host a monitorizar (`hid-daemon`), incrementando ligeramente la complejidad en la administración del sistema.
- **Dependencia de configuración local:** Requiere mantener un archivo de bindings YAML en la ruta del proyecto.
