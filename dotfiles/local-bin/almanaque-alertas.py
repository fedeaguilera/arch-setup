#!/usr/bin/env python3
"""Notificaciones (swaync) para los eventos del almanaque.

Servicio de usuario (almanaque-alertas.service) que cada 30 s revisa los .ics
cacheados en ~/.cache/almanaque/ y dispara notify-send cuando toca una alerta:

  - las alertas propias de cada evento (VALARM: "30 min antes", "el dia a las
    9:00"...). Google solo exporta las que pusiste a mano en el evento.
  - `aviso = N` en calendars.conf: N minutos antes de cada evento con hora que
    no tenga alerta propia (reemplaza la notificacion por defecto de Google,
    que no viaja en el feed iCal).

  almanaque-alertas.py --proximas   lista las alertas de los proximos 7 dias.
"""
import configparser
import json
import re
import subprocess
import sys
import time
from datetime import date, datetime, timedelta
from pathlib import Path

import icalendar
import recurring_ical_events

CONF = Path.home() / ".config/almanaque/calendars.conf"
CACHE = Path.home() / ".cache/almanaque"
STATE = CACHE / "alertas.json"
TICK = 30
LOOKBACK = timedelta(days=2)    # alertas "el dia a las 9" de eventos de todo el dia
LOOKAHEAD = timedelta(days=8)   # alertas hasta una semana antes del evento
GRACE = timedelta(minutes=15)   # tras suspender: avisa lo perdido si es reciente


def slug(name: str) -> str:  # igual que en almanaque-sync.py
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-") or "calendario"


def to_local(value) -> datetime:
    """date -> 00:00 local; datetime (con o sin tz) -> naive en hora local."""
    if isinstance(value, datetime):
        return value.astimezone().replace(tzinfo=None) if value.tzinfo else value
    return datetime.combine(value, datetime.min.time())


class Calendars:
    """Recarga cada .ics solo cuando cambia (el sync lo reescribe cada 15 min)."""

    def __init__(self):
        self._cache: dict[str, tuple[float, object]] = {}

    def load(self):
        cp = configparser.ConfigParser(interpolation=None)
        if CONF.exists():
            cp.read(CONF)
        out = []
        for name in cp.sections():
            sec = cp[name]
            if not sec.get("url", "").strip() or not sec.getboolean("enabled", True):
                continue
            path = CACHE / f"{slug(name)}.ics"
            if not path.exists():
                continue
            mtime = path.stat().st_mtime
            cached = self._cache.get(name)
            if cached is None or cached[0] != mtime:
                try:
                    cached = (mtime, icalendar.Calendar.from_ical(path.read_bytes()))
                except Exception as e:
                    print(f"almanaque-alertas: {name}: {e}", file=sys.stderr)
                    continue
                self._cache[name] = cached
            aviso = sec.get("aviso", "").strip()
            out.append((name, cached[1], int(aviso) if aviso.isdigit() else None))
        return out


def alarms(calendars, start: datetime, end: datetime):
    """(momento_alerta, clave_unica, evento) de las ocurrencias en [start, end]."""
    for name, cal, aviso in calendars:
        try:
            occurrences = recurring_ical_events.of(cal).between(start - LOOKBACK, end + LOOKAHEAD)
        except Exception as e:
            print(f"almanaque-alertas: {name}: {e}", file=sys.stderr)
            continue
        for ev in occurrences:
            if "DTSTART" not in ev or str(ev.get("STATUS", "")).upper() == "CANCELLED":
                continue
            raw_start = ev["DTSTART"].dt
            all_day = not isinstance(raw_start, datetime)
            ev_start = to_local(raw_start)
            ev_end = to_local(ev["DTEND"].dt) if "DTEND" in ev else ev_start
            uid = f"{name}/{ev.get('UID', '')}/{ev_start.isoformat()}"

            triggers = []
            for al in ev.walk("VALARM"):
                if str(al.get("ACTION", "DISPLAY")).upper() not in ("DISPLAY", "AUDIO"):
                    continue  # EMAIL: eso lo manda Google por mail
                trig = al.get("TRIGGER")
                if trig is None:
                    continue
                if isinstance(trig.dt, timedelta):
                    base = ev_end if trig.params.get("RELATED") == "END" else ev_start
                    triggers.append(base + trig.dt)
                else:
                    triggers.append(to_local(trig.dt))
            if not triggers and aviso is not None and not all_day:
                triggers.append(ev_start - timedelta(minutes=aviso))

            for t in triggers:
                if start < t <= end:
                    yield t, f"{uid}@{t.isoformat()}", (name, ev, ev_start, ev_end, all_day)


def notify(ev_info, when: datetime):
    name, ev, ev_start, ev_end, all_day = ev_info
    title = str(ev.get("SUMMARY", "(sin título)"))
    if all_day:
        body = "Hoy, todo el día" if ev_start.date() == date.today() else \
            f"{ev_start:%d/%m}, todo el día"
    else:
        mins = round((ev_start - when).total_seconds() / 60)
        if mins <= 0:
            falta = "Ahora"
        elif mins < 60:
            falta = f"En {mins} min"
        elif mins < 24 * 60:
            falta = f"En {mins // 60} h" + (f" {mins % 60} min" if mins % 60 else "")
        else:
            falta = f"El {ev_start:%d/%m}"
        body = f"{falta} · {ev_start:%H:%M} – {ev_end:%H:%M}"
    loc = str(ev.get("LOCATION", "")).split("\n")[0]
    if loc:
        body += f"\n{loc}"
    subprocess.run(["notify-send", "-a", "Calendario", "-i", "x-office-calendar",
                    "-u", "normal", title, f"{body}\n<small>{name}</small>"])


def load_state() -> tuple[datetime | None, dict]:
    try:
        s = json.loads(STATE.read_text())
        return datetime.fromisoformat(s["last"]), s.get("sent", {})
    except Exception:
        return None, {}


def save_state(last: datetime, sent: dict):
    cutoff = (last - timedelta(days=3)).isoformat()
    sent = {k: v for k, v in sent.items() if v >= cutoff}
    tmp = STATE.with_suffix(".tmp")
    tmp.write_text(json.dumps({"last": last.isoformat(), "sent": sent}))
    tmp.replace(STATE)


def run():
    CACHE.mkdir(parents=True, exist_ok=True)
    cals = Calendars()
    last, sent = load_state()
    while True:
        now = datetime.now()
        if last is None or now - last > GRACE or last > now:
            last = now - timedelta(seconds=TICK)
        for when, key, info in sorted(alarms(cals.load(), last, now), key=lambda a: a[0]):
            if key not in sent:
                notify(info, now)
                sent[key] = when.isoformat()
        last = now
        save_state(last, sent)
        time.sleep(TICK)


def proximas():
    now = datetime.now()
    found = sorted(alarms(Calendars().load(), now, now + timedelta(days=7)), key=lambda a: a[0])
    for when, _key, (name, ev, ev_start, _e, _ad) in found:
        print(f"{when:%a %d/%m %H:%M}  [{name}]  {ev.get('SUMMARY', '')}  (evento {ev_start:%d/%m %H:%M})")
    if not found:
        print("Sin alertas en los próximos 7 días.")


if __name__ == "__main__":
    proximas() if "--proximas" in sys.argv else run()
