# Especificación de Cambio: Aislamiento de Variables de Entorno por Servicio

## Objetivo

Eliminar la exposición innecesaria de información de configuración entre servicios de Nova mediante la separación de las variables de entorno en archivos independientes.

Con este cambio, cada servicio únicamente dispondrá de la configuración necesaria para desempeñar sus responsabilidades, reforzando el principio de aislamiento entre dominios y reduciendo la superficie de exposición de información.

---

# Motivación

La arquitectura de Nova establece como principio que cada dominio es propiedad de un único servicio.

Los servicios sólo deben acceder a información perteneciente a otros dominios mediante las APIs públicas expuestas por el servicio propietario.

Actualmente este principio no se cumple completamente, ya que múltiples servicios cargan un archivo común de variables de entorno que contiene información perteneciente a distintos dominios.

Aunque un servicio ignore las variables que no utiliza, dichas variables siguen estando disponibles dentro del proceso, lo que rompe el aislamiento arquitectónico.

---

# Requisitos funcionales

## RF-1. Configuración independiente por servicio

Cada servicio deberá disponer de un conjunto de variables de entorno independiente del resto de servicios.

Ningún servicio deberá cargar un archivo de configuración compartido que contenga información perteneciente a otros dominios.

---

## RF-2. Visibilidad mínima

Cada servicio únicamente deberá recibir las variables de entorno necesarias para realizar sus funciones.

No deberán exponerse configuraciones pertenecientes a otros servicios aunque no sean utilizadas.

---

## RF-3. Conservación del comportamiento

La separación de la configuración no deberá modificar el comportamiento funcional del sistema.

Todos los servicios deberán mantener exactamente las mismas funcionalidades existentes.

---

## RF-4. Conservación de la configuración existente

Todas las variables actualmente utilizadas deberán seguir estando disponibles para el servicio que las necesita.

No deberán eliminarse opciones de configuración existentes.

---

## RF-5. Compatibilidad con Docker Compose

La definición de despliegue deberá permitir que cada servicio cargue exclusivamente su propia configuración durante el arranque.

---

## RF-6. Independencia entre dominios

Las variables de configuración de un dominio no deberán estar disponibles para servicios pertenecientes a otros dominios, salvo que sean estrictamente necesarias para su funcionamiento.

---

# Requisitos no funcionales

## RNF-1. Refuerzo del aislamiento arquitectónico

La organización de la configuración deberá alinearse con el principio arquitectónico de que cada dominio es propietario exclusivo de sus datos.

---

## RNF-2. Principio de mínimo privilegio

Cada servicio deberá disponer únicamente de la información imprescindible para ejecutar sus responsabilidades.

---

## RNF-3. Reducción de la superficie de exposición

La exposición accidental de información sensible entre servicios deberá minimizarse mediante la separación física de la configuración.

---

## RNF-4. Mantenibilidad

La configuración deberá organizarse de forma que resulte sencillo localizar qué parámetros pertenecen a cada servicio.

La incorporación de nuevos servicios no deberá requerir modificar archivos de configuración de dominios ajenos.

---

## RNF-5. Escalabilidad

La estructura de configuración deberá permitir añadir nuevos servicios sin aumentar el acoplamiento entre los ya existentes.

---

## RNF-6. Legibilidad

La organización de los archivos de configuración deberá facilitar la comprensión de las responsabilidades de cada servicio.

---

## RNF-7. Compatibilidad

El cambio no deberá requerir modificaciones en las APIs públicas ni alterar la comunicación entre servicios.

---

# Criterios de aceptación

* Cada servicio carga exclusivamente su propio archivo de configuración.
* Ningún servicio dispone de variables pertenecientes a dominios ajenos.
* El sistema mantiene exactamente el mismo comportamiento funcional previo al cambio.
* Todos los servicios arrancan correctamente utilizando únicamente su configuración específica.
* La incorporación de nuevas variables de un servicio no requiere modificar la configuración de otros servicios.
* La estructura final refleja el principio de aislamiento de dominios definido por la arquitectura de Nova.
