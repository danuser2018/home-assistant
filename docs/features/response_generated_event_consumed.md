# Refactor de la entrada - Fase 5

## Objetivo

Sustituir el mecanismo de detección de nuevas locuciones basado en la monitorización del sistema de archivos por la recepción del evento `SpeechCapturedEvent`.

Al finalizar esta fase, `interaction-manager` dejará de inspeccionar periódicamente el directorio compartido de audio y reaccionará exclusivamente a los eventos publicados por `mic-daemon`.

El comportamiento observable de Nova permanecerá inalterado.

---

# Alcance

Esta fase afecta exclusivamente a:

- `interaction-manager`

No se modifica el comportamiento de:

- `mic-daemon`
- `hid-daemon`
- `novactl`
- `orchestrator`

---

# Diseño

## Recepción del evento

`interaction-manager` se suscribirá al evento:

```
SpeechCapturedEvent
```

Al recibir el evento deberá:

1. Resolver la ruta física del fichero a partir del `audioPath` recibido.
2. Cargar el fichero WAV desde el volumen compartido.
3. Continuar el flujo de procesamiento existente.

No deberá realizar ninguna modificación sobre el procesamiento posterior del audio.

---

## Resolución de la ruta

El evento contiene una ruta relativa:

```
audioPath
```

`interaction-manager` será responsable de resolver la ubicación física del fichero utilizando la configuración local del volumen compartido.

Ejemplo:

```
Directorio compartido:
/data/audio

audioPath:
20260801/abcd1234.wav

Ruta resultante:
/data/audio/20260801/abcd1234.wav
```

Esta responsabilidad pertenece al consumidor, ya que cada servicio conoce la ubicación de su propio volumen.

---

# Compatibilidad

Con la implantación de esta fase desaparece el mecanismo de monitorización periódica del directorio de audio.

`SpeechCapturedEvent` pasa a ser el único mecanismo utilizado por `interaction-manager` para detectar nuevas locuciones.

No se modifica el resto del flujo de procesamiento del audio.

---

# Nota de arquitectura

Con esta fase queda eliminada la comunicación entre `mic-daemon` e `interaction-manager` basada en el sistema de archivos.

El volumen compartido permanece únicamente como mecanismo de persistencia del audio, mientras que la coordinación entre ambos servicios pasa a realizarse exclusivamente mediante eventos.

Este cambio completa la migración del pipeline de entrada desde un modelo basado en polling hacia una arquitectura orientada a eventos.

---

# Beneficios

- Eliminación del polling realizado por `interaction-manager`.
- Eliminación de comprobaciones periódicas sobre el sistema de archivos.
- Menor latencia entre la captura del audio y el inicio de su procesamiento.
- Desacoplamiento entre la persistencia del audio y su descubrimiento.
- Comunicación completamente basada en eventos entre `mic-daemon` e `interaction-manager`.

---

# Criterios de aceptación

- `interaction-manager` se suscribe a `SpeechCapturedEvent`.
- Cada `SpeechCapturedEvent` provoca el procesamiento de una única locución.
- `interaction-manager` resuelve correctamente `audioPath` utilizando su configuración local.
- El mecanismo de monitorización del directorio de audio ha sido eliminado.
- El flujo posterior de procesamiento permanece inalterado.
- El comportamiento observable de Nova permanece inalterado.
