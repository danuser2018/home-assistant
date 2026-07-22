# ADR-021: Detección de Habla basada en Eventos en mic-daemon (Fase 3 Refactor de Entrada)

- **Fecha**: 22-07-2026
- **Estado**: Aceptado
- **Contexto**:
  Anteriormente, `mic-daemon` actuaba como un observador del sistema de archivos mediante un bucle de polling (`StateWatcher`) sobre `/tmp/voice_assistant/recording.flag` (ADR-001). Esta aproximación introducía latencia de I/O de disco, acoplamiento a ficheros temporales y riesgo de estados inconsistentes (flags obsoletos tras fallos).

  En el marco de la Fase 3 del refactor de entrada del ecosistema Nova-2 y la adopción de `nova-event-bus` (ADR-017, ADR-018, ADR-020), es necesario eliminar definitivamente la supervisión del filesystem en `mic-daemon` y migrar hacia un esquema asíncrono puro orientado a eventos.

- **Decisión**:
  1. Refactorizar `mic-daemon` eliminando `StateWatcher` y la supervisión de `/tmp/voice_assistant/recording.flag`.
  2. Implementar `EventSubscriber` utilizando la API pública de `nova-event-bus` para conectar `mic-daemon` con el broker NATS (obteniendo la configuración mediante `NATS_URL`).
  3. Suscribir asíncronamente `mic-daemon` a los eventos tipados `StartSpeechCaptureCommand` (`novactl.command.start_speech_capture`) y `StopSpeechCaptureCommand` (`novactl.command.stop_speech_capture`).
  4. Actualizar `scripts/mic-start.sh` y `scripts/mic-stop.sh` para delegar su ejecución exclusivamente en `novactl start-capture` y `novactl stop-capture`, eliminando la creación/borrado de flags en el filesystem.
  5. Eliminar de la configuración de `mic-daemon` los parámetros obsoletos `MIC_POLL_INTERVAL_MS` y `flag_path`.

- **Alternativas consideradas**:
  - **Mantener el archivo de marca en filesystem como fallback**: Rechazada por introducir complejidad innecesaria, duplica de canales de control y potenciales condiciones de carrera.
  - **Uso directo de la librería `nats-py` en `mic-daemon`**: Rechazada por violar ADR-018 y omitir los contratos de eventos centralizados.

- **Consecuencias**:
  - **Baja Latencia**: Activación y detención inmediata de la captura de micrófono al recibir eventos NATS sin esperar intervalos de polling.
  - **Mayor Robustez**: Inexistencia de ficheros residuo en `/tmp` o estados incoherentes tras caídas del daemon.
  - **Alineación Arquitectónica**: `mic-daemon` se integra homogéneamente con la CLI `novactl` y la arquitectura event-driven global del ecosistema Nova.
