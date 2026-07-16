# Refinamiento de la Feature: Holidays Plugins (Integración con Calendar Service)

- **Archivo de origen**: [holidays_plugins.md](file:///home/danuser2018/workspace/orchestrator/doc/features/holidays_plugins.md)
- **Fecha**: 2026-07-16
- **Estado**: Refinado
- **Ubicación del Refinamiento**: [holidays_plugins_refinement.md](file:///home/danuser2018/workspace/home-assistant/docs/refinement/holidays_plugins_refinement.md)

---

## 1. Resumen y Contexto de Negocio

### Objetivo Principal
Implementar los cuatro plugins iniciales en el `orchestrator` que se integran con el `calendar-service` local para responder de forma local y offline consultas sobre el calendario civil y festivos oficiales. Asimismo, se implementarán dos componentes comunes: el servicio compartido `NextHolidayService` para consolidar las consultas del festivo siguiente, y la utilidad genérica `TimeFormatter` para transformar días restantes en expresiones naturales para la interacción por voz. 

Todas las respuestas de voz y control de errores están optimizados de acuerdo con los principios de mínima información, brevedad y ausencia de lenguaje conversacional definidos en `TONE_GUIDE.md`.

### Actores y Flujo de Alto Nivel
1. **Usuario**: Realiza preguntas por voz referidas a festivos (ej. "¿Hoy es festivo?", "¿Cuánto queda para la próxima fiesta?", "Dime los festivos de este año").
2. **Orchestrator**: Evalúa las frases empleando la biblioteca de similitud semántica y delega el flujo al plugin con mayor coincidencia.
3. **TodayHolidayPlugin / NextHolidayPlugin / DaysUntilNextHolidayPlugin**: Invocan los endpoints REST del `calendar-service` local empleando el cliente común y devuelven respuestas de voz inmediatas y sin adornos conversacionales.
4. **HolidaysOfYearPlugin**: Realiza la petición del año completo al `calendar-service`, genera el HTML correspondiente y encola el correo asíncronamente en el sistema de mensajería (siguiendo el contrato sin destinatario `"to"` definido en el **ADR-009**).
5. **Calendar Service**: Resuelve localmente las consultas en memoria basándose en los datos anuales del volumen compartido.
6. **Mail Watchdog**: Detecta el archivo JSON del correo pendiente, consulta el correo electrónico real del usuario llamando a `identity-service` de forma síncrona y envía el mensaje de forma asíncrona vía SMTP.

---

## 2. Análisis de Servicios e Impacto

| Servicio | Tipo de Cambio | Descripción del Impacto |
| :--- | :--- | :--- |
| `orchestrator` | Modificar | - `core/config.py`: Añadir el parámetro de configuración `calendar_service_base_url` en la clase `Settings` con valor por defecto `"http://calendar-service:8000"`. <br>- `core/calendar_service_client.py` [NEW]: Crear el cliente HTTP asíncrono `CalendarServiceClient` y el servicio compartido `NextHolidayService` junto con los modelos Pydantic necesarios. <br>- `core/time_formatter.py` [NEW]: Crear la utilidad `TimeFormatter` para humanizar los días en lenguaje natural. <br>- `plugins/holidays/main.py` [NEW]: Crear el módulo agrupador de plugins que expone `TodayHolidayPlugin`, `NextHolidayPlugin`, `DaysUntilNextHolidayPlugin` y `HolidaysOfYearPlugin`. <br>- `tests/test_holidays_plugins.py` [NEW]: Crear suite de pruebas unitarias para probar la utilidad de formateo, el cliente REST y la respuesta lógica de los cuatro plugins. <br>- `README.md` y `CHANGELOG.md`: Registrar la adición de los nuevos plugins y clientes. |
| `home-assistant` | Modificar | - `docker-compose.yml`: La variable de entorno `CALENDAR_SERVICE_BASE_URL: http://calendar-service:8000` ya se encuentra configurada en la sección `environment` del servicio `orchestrator` (tarea ya realizada). <br>- `docs/services.md`: Registrar en el catálogo de servicios las nuevas capacidades por voz aportadas por los plugins de festivos. <br>- `CHANGELOG.md`: Registrar la integración de los plugins en el orquestador vinculados al servicio de calendario. |
| Todos los demás servicios | Ninguno | Las interfaces HTTP REST públicas del resto de servicios no se ven afectadas por este cambio. |

### Evaluación de necesidad de ADR (Architectural Decision Record)
No se requiere un nuevo ADR. La estrategia de contenerización de `calendar-service` y su interfaz REST ya están aprobados formalmente en el `ADR-016`. El mecanismo de envío de correos sin el campo `"to"` delegando en el sistema de buzones y el `identity-service` está establecido por el `ADR-009`. El estilo de las respuestas del asistente de voz está gobernado íntegramente por `TONE_GUIDE.md`.

---

## 3. Especificación de Comportamiento (Criterios de Aceptación)

### Escenario 1: Hoy es festivo
```gherkin
Dado que el servicio calendar-service responde con HTTP 200 y el JSON {"isHoliday": true, "holiday": {"date": "2026-10-12", "dayOfWeek": "MONDAY", "name": "Fiesta Nacional de España", "scope": "national"}}
Cuando el usuario pregunta "¿Hoy es festivo?" y el Orchestrator enruta la petición a TodayHolidayPlugin
Entonces el plugin responde con success=True
Y el speech devuelto es exactamente "Fiesta Nacional de España. Festivo nacional."
Y el JSON de data contiene "is_holiday": true y los detalles del festivo
```

### Escenario 2: Hoy no es festivo
```gherkin
Dado que el servicio calendar-service responde con HTTP 200 y el JSON {"isHoliday": false}
Cuando el usuario pregunta "¿Es fiesta hoy?" y el Orchestrator enruta la petición a TodayHolidayPlugin
Entonces el plugin responde con success=True
Y el speech devuelto es exactamente "Hoy no es festivo."
Y el JSON de data contiene "is_holiday": false
```

### Escenario 3: Consulta del siguiente festivo (NextHolidayPlugin)
```gherkin
Dado que el servicio calendar-service responde con HTTP 200 y el JSON {"date": "2026-10-12", "dayOfWeek": "MONDAY", "name": "Fiesta Nacional de España", "scope": "national", "daysUntil": 88}
Cuando el usuario pregunta "¿Cuál es el próximo festivo?" y el Orchestrator enruta la petición a NextHolidayPlugin
Entonces el plugin responde con success=True
Y el speech devuelto es exactamente "Fiesta Nacional de España. Lunes 12 de octubre. Festivo nacional. Falta casi tres meses."
```

### Escenario 4: Días restantes hasta el siguiente festivo (DaysUntilNextHolidayPlugin)
```gherkin
Dado que el servicio calendar-service responde con HTTP 200 y el JSON {"date": "2026-07-23", "dayOfWeek": "THURSDAY", "name": "Santiago Apóstol", "scope": "regional", "daysUntil": 7}
Cuando el usuario pregunta "¿Cuánto falta para el próximo festivo?" y el Orchestrator enruta la petición a DaysUntilNextHolidayPlugin
Entonces el plugin responde con success=True
Y el speech devuelto es exactamente "Falta una semana."
```

### Escenario 5: Solicitud de listado anual de festivos por correo (HolidaysOfYearPlugin)
```gherkin
Dado que el servicio calendar-service responde con HTTP 200 y el JSON conteniendo 5 festivos para el año 2026
Cuando el usuario pregunta "¿Qué festivos hay este año?" y el Orchestrator enruta la petición a HolidaysOfYearPlugin
Entonces el plugin responde con success=True
Y el speech devuelto es exactamente "5 festivos. Lista enviada por correo."
Y se escribe un archivo JSON de correo en "/shared/mail/pending" con el asunto "Festivos de 2026", tipo de contenido "text/html" y sin el campo "to".
```

### Escenario 6: Error de conexión o timeout con Calendar Service
```gherkin
Dado que calendar-service está fuera de línea o la petición tiene timeout
Cuando el usuario realiza cualquier consulta de festivos
Entonces el plugin que atiende la consulta responde con success=False
Y el speech devuelto es exactamente "Servicio no disponible."
```

### Escenario 7: Error interno en el servicio o año no cargado
```gherkin
Dado que calendar-service devuelve un código de error HTTP 404 (DATA_NOT_FOUND) o HTTP 500
Cuando el usuario realiza una consulta de festivos
Entonces el plugin que atiende la consulta responde con success=False
Y el speech devuelto es exactamente "No he podido obtener la información."
```

---

## 4. Diseño Técnico y Contratos

### Parámetros de Configuración y Despliegue (`core/config.py` y `docker-compose.yml`)

En la clase `Settings` de `core/config.py`:
```python
class Settings(BaseSettings):
    # ... otras configuraciones ...
    calendar_service_base_url: str = "http://calendar-service:8000"
```

En `docker-compose.yml` de `home-assistant`:
```yaml
  orchestrator:
    # ...
    environment:
      # ...
      CALENDAR_SERVICE_BASE_URL: http://calendar-service:8000
```

### Utilidad Común `TimeFormatter` (`core/time_formatter.py`)

Esta utilidad se encarga de formatear la duración temporal en días a lenguaje natural en español:

```python
class TimeFormatter:
    @staticmethod
    def humanize_days(days: int) -> str:
        if days < 0:
            raise ValueError("Days cannot be negative")
            
        exact_mappings = {
            0: "hoy",
            1: "mañana",
            2: "pasado mañana",
            5: "cinco días",
            7: "una semana",
            14: "dos semanas",
            21: "tres semanas",
            30: "un mes",
            45: "un mes y medio",
            60: "dos meses",
            88: "casi tres meses",
            365: "un año"
        }
        if days in exact_mappings:
            return exact_mappings[days]
            
        if days < 7:
            words = {3: "tres", 4: "cuatro", 6: "seis"}
            return f"{words.get(days, str(days))} días"
        elif days < 14:
            return "una semana"
        elif days < 21:
            return "dos semanas"
        elif days < 30:
            return "tres semanas"
        elif days < 45:
            return "un mes"
        elif days < 60:
            return "un mes y medio"
        elif days < 90:
            if days >= 80:
                return "casi tres meses"
            return "dos meses"
        elif days < 365:
            months = int(round(days / 30.0))
            if months == 12:
                return "un año"
            month_words = {
                1: "un mes", 2: "dos meses", 3: "tres meses", 4: "cuatro meses",
                5: "cinco meses", 6: "medio año", 7: "siete meses", 8: "ocho meses",
                9: "nueve meses", 10: "diez meses", 11: "once meses"
            }
            return month_words.get(months, f"{months} meses")
        else:
            years = int(round(days / 365.0))
            if years == 1:
                return "un año"
            return f"{years} años"
```

### Cliente de Calendar Service y Servicio Compartido (`core/calendar_service_client.py`)

```python
import httpx
import logging
from typing import Optional, List
from pydantic import BaseModel, Field, ConfigDict

logger = logging.getLogger(__name__)

class HolidayInfo(BaseModel):
    model_config = ConfigDict(populate_by_name=True)
    date: str
    day_of_week: str = Field(..., alias="dayOfWeek")
    name: str
    scope: str

class HolidayDateResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)
    is_holiday: bool = Field(..., alias="isHoliday")
    holiday: Optional[HolidayInfo] = None

class HolidayYearResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)
    year: int
    holidays: List[HolidayInfo]

class NextHolidayResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)
    date: str
    day_of_week: str = Field(..., alias="dayOfWeek")
    name: str
    scope: str
    days_until: int = Field(..., alias="daysUntil")

class CalendarServiceClient:
    def __init__(self, base_url: str = None):
        from core.config import settings
        self.base_url = base_url or settings.calendar_service_base_url

    async def get_holiday(self, query_date: str) -> HolidayDateResponse:
        url = f"{self.base_url.rstrip('/')}/api/v1/holidays?date={query_date}"
        logger.info(f"Consuming URL: {url}")
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.get(url)
            response.raise_for_status()
            return HolidayDateResponse.model_validate(response.json())

    async def get_next_holiday(self, from_date: str) -> NextHolidayResponse:
        url = f"{self.base_url.rstrip('/')}/api/v1/holidays/next?from={from_date}"
        logger.info(f"Consuming URL: {url}")
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.get(url)
            response.raise_for_status()
            return NextHolidayResponse.model_validate(response.json())

    async def get_year_holidays(self, year: int) -> HolidayYearResponse:
        url = f"{self.base_url.rstrip('/')}/api/v1/holidays?year={year}"
        logger.info(f"Consuming URL: {url}")
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.get(url)
            response.raise_for_status()
            return HolidayYearResponse.model_validate(response.json())


class NextHolidayService:
    def __init__(self, client: Optional[CalendarServiceClient] = None):
        self.client = client or CalendarServiceClient()

    async def get_next_holiday_data(self, from_date: str) -> Optional[NextHolidayResponse]:
        try:
            return await self.client.get_next_holiday(from_date)
        except (httpx.ConnectError, httpx.TimeoutException) as conn_err:
            logger.error(f"Connection error or timeout connecting to Calendar Service: {conn_err}")
            raise conn_err
        except httpx.HTTPStatusError as status_err:
            logger.error(f"HTTP error status from Calendar Service: {status_err}")
            raise status_err
        except Exception as e:
            logger.error(f"Unexpected error in NextHolidayService: {e}", exc_info=True)
            raise e
```

### Módulo Agrupador de Plugins (`plugins/holidays/main.py`)

```python
import json
import logging
import uuid
from datetime import datetime
from pathlib import Path
from typing import List, Dict

import httpx

from core.config import settings
from core.models import PluginContext, PluginResult
from plugins.base import Plugin
from core.calendar_service_client import CalendarServiceClient, NextHolidayService
from core.time_formatter import TimeFormatter

logger = logging.getLogger(__name__)

SPANISH_WEEKDAYS = {
    "MONDAY": "Lunes",
    "TUESDAY": "Martes",
    "WEDNESDAY": "Miércoles",
    "THURSDAY": "Jueves",
    "FRIDAY": "Viernes",
    "SATURDAY": "Sábado",
    "SUNDAY": "Domingo"
}

SPANISH_MONTHS = [
    None, "enero", "febrero", "marzo", "abril", "mayo", "junio", 
    "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"
]

SCOPE_MAPPING_VOICE = {
    "national": "nacional",
    "regional": "regional",
    "local": "local"
}

SCOPE_MAPPING_EMAIL = {
    "national": "Nacional",
    "regional": "Regional",
    "local": "Local"
}

def format_date_to_spanish(date_str: str, day_of_week: str) -> str:
    # date_str: YYYY-MM-DD
    dt = datetime.strptime(date_str, "%Y-%m-%d")
    weekday = SPANISH_WEEKDAYS.get(day_of_week.upper(), day_of_week)
    day = dt.day
    month = SPANISH_MONTHS[dt.month]
    return f"{weekday} {day} de {month}"

def format_date_to_dmy(date_str: str) -> str:
    # date_str: YYYY-MM-DD -> DD/MM/AAAA
    parts = date_str.split("-")
    return f"{parts[2]}/{parts[1]}/{parts[0]}"


class TodayHolidayPlugin(Plugin):
    def __init__(self):
        super().__init__()
        self.client = None

    @property
    def name(self) -> str:
        return "TodayHolidayPlugin"

    @property
    def description(self) -> str:
        return "Determina si la fecha actual es festiva."

    @property
    def id(self) -> str:
        return "today_holiday"

    @property
    def priority(self) -> int:
        return 60

    @property
    def examples(self) -> List[str]:
        return [
            "¿Hoy es festivo?",
            "¿Es festivo hoy?",
            "Hoy hay fiesta",
            "Hoy se trabaja",
            "¿Hoy es fiesta?",
            "¿Es día festivo?",
            "Dime si hoy es festivo",
            "¿Tenemos fiesta hoy?",
            "Hoy es laboral",
            "¿Hoy descansamos?"
        ]

    def initialize(self) -> None:
        logger.info("Initializing TodayHolidayPlugin")
        self.client = CalendarServiceClient()

    async def execute(self, context: PluginContext) -> PluginResult:
        logger.info("Starting execution of TodayHolidayPlugin")
        today_str = datetime.now().strftime("%Y-%m-%d")
        try:
            res = await self.client.get_holiday(today_str)
            if res.is_holiday and res.holiday:
                scope_es = SCOPE_MAPPING_VOICE.get(res.holiday.scope, res.holiday.scope)
                speech = f"{res.holiday.name}. Festivo {scope_es}."
                return PluginResult(
                    success=True,
                    speech=speech,
                    data={"is_holiday": True, "holiday": res.holiday.model_dump()}
                )
            else:
                return PluginResult(
                    success=True,
                    speech="Hoy no es festivo.",
                    data={"is_holiday": False}
                )
        except (httpx.ConnectError, httpx.TimeoutException) as conn_err:
            logger.error(f"Connection error to Calendar Service: {conn_err}")
            return PluginResult(success=False, speech="Servicio no disponible.")
        except Exception as e:
            logger.error(f"Error querying TodayHolidayPlugin: {e}", exc_info=True)
            return PluginResult(success=False, speech="No he podido obtener la información.")


class NextHolidayPlugin(Plugin):
    def __init__(self):
        super().__init__()
        self.service = None

    @property
    def name(self) -> str:
        return "NextHolidayPlugin"

    @property
    def description(self) -> str:
        return "Informa del siguiente festivo."

    @property
    def id(self) -> str:
        return "next_holiday"

    @property
    def priority(self) -> int:
        return 60

    @property
    def examples(self) -> List[str]:
        return [
            "¿Cuál es el próximo festivo?",
            "¿Cuándo es el siguiente festivo?",
            "¿Qué festivo viene ahora?",
            "¿Cuál es la próxima fiesta?",
            "Próximo festivo",
            "¿Qué día es el próximo festivo?",
            "¿Cuál será el siguiente festivo?",
            "Dime el próximo festivo",
            "¿Qué fiesta viene después?",
            "Próxima fiesta"
        ]

    def initialize(self) -> None:
        logger.info("Initializing NextHolidayPlugin")
        self.service = NextHolidayService()

    async def execute(self, context: PluginContext) -> PluginResult:
        logger.info("Starting execution of NextHolidayPlugin")
        today_str = datetime.now().strftime("%Y-%m-%d")
        try:
            next_h = await self.service.get_next_holiday_data(today_str)
            if not next_h:
                return PluginResult(success=False, speech="No he podido obtener la información.")
            
            date_es = format_date_to_spanish(next_h.date, next_h.day_of_week)
            scope_es = SCOPE_MAPPING_VOICE.get(next_h.scope, next_h.scope)
            human_days = TimeFormatter.humanize_days(next_h.days_until)
            speech = f"{next_h.name}. {date_es}. Festivo {scope_es}. Falta {human_days}."
            
            return PluginResult(
                success=True,
                speech=speech,
                data=next_h.model_dump()
            )
        except (httpx.ConnectError, httpx.TimeoutException) as conn_err:
            logger.error(f"Connection error in NextHolidayPlugin: {conn_err}")
            return PluginResult(success=False, speech="Servicio no disponible.")
        except Exception as e:
            logger.error(f"Error querying NextHolidayPlugin: {e}", exc_info=True)
            return PluginResult(success=False, speech="No he podido obtener la información.")


class DaysUntilNextHolidayPlugin(Plugin):
    def __init__(self):
        super().__init__()
        self.service = None

    @property
    def name(self) -> str:
        return "DaysUntilNextHolidayPlugin"

    @property
    def description(self) -> str:
        return "Informa únicamente del tiempo restante hasta el siguiente festivo."

    @property
    def id(self) -> str:
        return "days_until_next_holiday"

    @property
    def priority(self) -> int:
        return 60

    @property
    def examples(self) -> List[str]:
        return [
            "¿Cuánto queda para el próximo festivo?",
            "¿Cuántos días faltan para el siguiente festivo?",
            "¿Cuándo descansamos otra vez?",
            "¿Cuánto falta para el próximo festivo?",
            "¿Cuántos días quedan para la próxima fiesta?",
            "Dime cuánto falta para el siguiente festivo",
            "¿Falta mucho para el próximo festivo?",
            "¿Cuándo será la próxima fiesta?",
            "¿En cuántos días es fiesta?",
            "¿Cuánto queda para descansar?"
        ]

    def initialize(self) -> None:
        logger.info("Initializing DaysUntilNextHolidayPlugin")
        self.service = NextHolidayService()

    async def execute(self, context: PluginContext) -> PluginResult:
        logger.info("Starting execution of DaysUntilNextHolidayPlugin")
        today_str = datetime.now().strftime("%Y-%m-%d")
        try:
            next_h = await self.service.get_next_holiday_data(today_str)
            if not next_h:
                return PluginResult(success=False, speech="No he podido obtener la información.")
            
            human_days = TimeFormatter.humanize_days(next_h.days_until)
            speech = f"Falta {human_days}."
            return PluginResult(
                success=True,
                speech=speech,
                data={"days_until": next_h.days_until, "date": next_h.date}
            )
        except (httpx.ConnectError, httpx.TimeoutException) as conn_err:
            logger.error(f"Connection error in DaysUntilNextHolidayPlugin: {conn_err}")
            return PluginResult(success=False, speech="Servicio no disponible.")
        except Exception as e:
            logger.error(f"Error querying DaysUntilNextHolidayPlugin: {e}", exc_info=True)
            return PluginResult(success=False, speech="No he podido obtener la información.")


class HolidaysOfYearPlugin(Plugin):
    def __init__(self):
        super().__init__()
        self.client = None

    @property
    def name(self) -> str:
        return "HolidaysOfYearPlugin"

    @property
    def description(self) -> str:
        return "Obtiene el listado completo de festivos del año y lo envía por correo."

    @property
    def id(self) -> str:
        return "holidays_of_year"

    @property
    def priority(self) -> int:
        return 60

    @property
    def examples(self) -> List[str]:
        return [
            "¿Qué festivos hay este año?",
            "Dime los festivos de este año",
            "¿Cuáles son los festivos?",
            "Muéstrame los festivos",
            "Lista de festivos",
            "¿Qué días festivos hay?",
            "¿Qué fiestas hay este año?",
            "Enséñame el calendario laboral",
            "Quiero ver los festivos",
            "¿Cuáles son los días festivos?"
        ]

    def initialize(self) -> None:
        logger.info("Initializing HolidaysOfYearPlugin")
        self.client = CalendarServiceClient()

    async def execute(self, context: PluginContext) -> PluginResult:
        logger.info("Starting execution of HolidaysOfYearPlugin")
        current_year = datetime.now().year
        try:
            res = await self.client.get_year_holidays(current_year)
            holidays = res.holidays
            n = len(holidays)
            
            # Generar contenido HTML del correo
            html_rows = ""
            for h in holidays:
                dmy_date = format_date_to_dmy(h.date)
                day_es = SPANISH_WEEKDAYS.get(h.day_of_week.upper(), h.day_of_week)
                scope_es = SCOPE_MAPPING_EMAIL.get(h.scope, h.scope.capitalize())
                html_rows += f"""
                <tr>
                    <td style="padding: 10px; border-bottom: 1px solid #E2E8F0;">{dmy_date}</td>
                    <td style="padding: 10px; border-bottom: 1px solid #E2E8F0;">{day_es}</td>
                    <td style="padding: 10px; border-bottom: 1px solid #E2E8F0; font-weight: bold;">{h.name}</td>
                    <td style="padding: 10px; border-bottom: 1px solid #E2E8F0;">{scope_es}</td>
                </tr>
                """
                
            html_body = f"""
            <html>
            <body style="font-family: Arial, sans-serif; background-color: #F7FAFC; padding: 20px; color: #2D3748;">
                <div style="max-width: 600px; margin: 0 auto; background-color: #FFFFFF; border-radius: 8px; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1); padding: 30px; border-top: 5px solid #3182CE;">
                    <h2 style="color: #2B6CB0; margin-top: 0;">Calendario Oficial de Festivos {current_year}</h2>
                    <p style="font-size: 16px;">Lista ordenada cronológicamente de los días no laborables oficiales cargados en el sistema.</p>
                    <table style="width: 100%; border-collapse: collapse; margin-top: 20px; margin-bottom: 20px; text-align: left;">
                        <thead>
                            <tr style="background-color: #EBF8FF; color: #2B6CB0;">
                                <th style="padding: 10px; border-bottom: 2px solid #BEE3F8;">Fecha</th>
                                <th style="padding: 10px; border-bottom: 2px solid #BEE3F8;">Día</th>
                                <th style="padding: 10px; border-bottom: 2px solid #BEE3F8;">Festivo</th>
                                <th style="padding: 10px; border-bottom: 2px solid #BEE3F8;">Ámbito</th>
                            </tr>
                        </thead>
                        <tbody>
                            {html_rows}
                        </tbody>
                    </table>
                    <p style="font-size: 14px; font-weight: bold; border-top: 1px solid #E2E8F0; padding-top: 15px; margin-bottom: 0;">Total de festivos registrados: {n}</p>
                </div>
            </body>
            </html>
            """
            
            mail_uuid = uuid.uuid4().hex[:8]
            mail_id = f"mail-{mail_uuid}"
            
            # De acuerdo al ADR-009, no se incluye el campo "to"
            email_payload = {
                "id": mail_id,
                "subject": f"Festivos de {current_year}",
                "body": html_body,
                "content_type": "text/html"
            }
            
            pending_dir = Path(settings.mail_pending_dir)
            file_path = pending_dir / f"{mail_id}.json"
            
            pending_dir.mkdir(parents=True, exist_ok=True)
            with open(file_path, "w", encoding="utf-8") as f:
                json.dump(email_payload, f, indent=2, ensure_ascii=False)
                
            logger.info(f"Generated mail artifact under: {file_path}")
            
            # Respuesta alineada con TONE_GUIDE.md
            speech = f"{n} festivos. Lista enviada por correo."
            
            return PluginResult(
                success=True,
                speech=speech,
                data={
                    "num_holidays": n,
                    "mail_id": mail_id,
                    "file_path": str(file_path)
                }
            )
        except (httpx.ConnectError, httpx.TimeoutException) as conn_err:
            logger.error(f"Connection error in HolidaysOfYearPlugin: {conn_err}")
            return PluginResult(success=False, speech="Servicio no disponible.")
        except Exception as e:
            logger.error(f"Error querying HolidaysOfYearPlugin: {e}", exc_info=True)
            return PluginResult(success=False, speech="No he podido obtener la información.")
```

---

## 5. Casos de Borde y Manejo de Errores

| Caso de Borde | Comportamiento Esperado | Implementación Técnica |
| :--- | :--- | :--- |
| **Fallo de conexión o timeout con Calendar Service** | Retornar `PluginResult(success=False, speech="Servicio no disponible.")`. | Capturar las excepciones `httpx.ConnectError` y `httpx.TimeoutException` en el plugin. |
| **Respuesta HTTP fallida (4xx/5xx) de Calendar Service** | Retornar `PluginResult(success=False, speech="No he podido obtener la información.")`. | `httpx.AsyncClient` e invocar `response.raise_for_status()`. Capturar `httpx.HTTPError` en la llamada. |
| **Ausencia de festivos futuros en /holidays/next** | Retornar `PluginResult(success=False, speech="No he podido obtener la información.")`. | Capturar el error `HTTP 404 (NO_NEXT_HOLIDAY_FOUND)` lanzado por el servicio calendario y mapearlo a error interno. |
| **Valor de días negativo en TimeFormatter** | Lanzar excepción `ValueError`. | El método `humanize_days` valida la entrada y arroja `ValueError` si es menor que 0. |

---

## 6. Estrategia de Testing

### Pruebas Unitarias (`tests/test_holidays_plugins.py`)
Se implementarán pruebas exhaustivas utilizando `pytest` y mocks de `httpx`:

1.  **Validación de `TimeFormatter.humanize_days`**:
    *   Probar valores límite (`0 -> "hoy"`, `1 -> "mañana"`, `2 -> "pasado mañana"`, `5 -> "cinco días"`, `7 -> "una semana"`, `14 -> "dos semanas"`, `88 -> "casi tres meses"`, `365 -> "un año"`).
    *   Probar valores intermedios (ej. `3 -> "tres días"`, `10 -> "una semana"`, `28 -> "tres semanas"`, `50 -> "un mes y medio"`).
    *   Verificar que los días negativos arrojan `ValueError`.
2.  **Validación de `TodayHolidayPlugin`**:
    *   Mockear respuesta afirmativa de festivo y verificar que devuelve el speech `"{nombre}. Festivo {ámbito}."` (sin muletillas).
    *   Mockear respuesta negativa de festivo y verificar que devuelve `"Hoy no es festivo."`.
3.  **Validación de `NextHolidayPlugin`**:
    *   Mockear respuesta válida del festivo siguiente y asegurar el speech `"{nombre}. {formatted_date}. Festivo {ámbito}. Falta {humanized_days}."`.
4.  **Validación de `DaysUntilNextHolidayPlugin`**:
    *   Mockear respuesta de días hasta el festivo y validar el speech `"Falta {humanized_days}."`.
5.  **Validación de `HolidaysOfYearPlugin`**:
    *   Mockear listado de festivos, verificar la correcta escritura del archivo JSON del artefacto de correo en `settings.mail_pending_dir` con el formato HTML estructurado, tipo de contenido `"text/html"` y asegurar que **NO** contiene la propiedad `"to"`.
    *   Verificar que la salida por voz sea `"{N} festivos. Lista enviada por correo."`.
6.  **Validación de Robustez de Excepciones**:
    *   Mockear excepciones de red (`ConnectError`, `TimeoutException`) y validar la respuesta de error `"Servicio no disponible."`.
    *   Mockear errores HTTP (`HTTPStatusError`) y validar la respuesta de error `"No he podido obtener la información."`.

### Ejecución de Pruebas locales
```bash
PYTHONPATH=. pytest tests/test_holidays_plugins.py
```

---

## 7. Plan de Implementación (Checklist)

- [ ] **Fase 1: Configuración y Utilidades en Orchestrator**
  - [ ] Modificar [core/config.py](file:///home/danuser2018/workspace/orchestrator/core/config.py) para añadir `calendar_service_base_url` a `Settings`.
  - [ ] Crear el archivo [core/time_formatter.py](file:///home/danuser2018/workspace/orchestrator/core/time_formatter.py) con la clase `TimeFormatter`.
  - [ ] Crear el archivo [core/calendar_service_client.py](file:///home/danuser2018/workspace/orchestrator/core/calendar_service_client.py) con `CalendarServiceClient`, `NextHolidayService` y los esquemas Pydantic correspondientes.

- [ ] **Fase 2: Implementación de Plugins en Orchestrator**
  - [ ] Crear el directorio `plugins/holidays` y el archivo [plugins/holidays/main.py](file:///home/danuser2018/workspace/orchestrator/plugins/holidays/main.py) con los cuatro plugins heredados de `Plugin`.
  - [ ] Escribir la lógica de generación del cuerpo de correo HTML en `HolidaysOfYearPlugin` y su serialización a JSON sin el campo `"to"`.

- [ ] **Fase 3: Suite de Pruebas Unitarias**
  - [ ] Crear el archivo de pruebas [tests/test_holidays_plugins.py](file:///home/danuser2018/workspace/orchestrator/tests/test_holidays_plugins.py) cubriendo `TimeFormatter`, clientes, y la lógica conversacional directa de los plugins.
  - [ ] Ejecutar `PYTHONPATH=. pytest` para validar que no existan regresiones en el orquestador.

- [ ] **Fase 4: Configuración de Entornos y Documentación**
  - [x] Verificar [docker-compose.yml](file:///home/danuser2018/workspace/home-assistant/docker-compose.yml) (la variable `CALENDAR_SERVICE_BASE_URL` en la sección `environment` de `orchestrator` ya está configurada).
  - [ ] Modificar [docs/services.md](file:///home/danuser2018/workspace/home-assistant/docs/services.md) para agregar los ejemplos de speech abreviados bajo el catálogo de servicios de voz.
  - [ ] Modificar [README.md](file:///home/danuser2018/workspace/orchestrator/README.md) en `orchestrator` para dejar constancia de la existencia de los nuevos plugins de calendario.
  - [ ] Modificar [CHANGELOG.md](file:///home/danuser2018/workspace/orchestrator/CHANGELOG.md) y [CHANGELOG.md](file:///home/danuser2018/workspace/home-assistant/CHANGELOG.md) registrando la feature refinada bajo la sección `[Sin publicar]`.
