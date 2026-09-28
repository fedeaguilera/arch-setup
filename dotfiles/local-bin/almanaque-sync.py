#!/usr/bin/env python3
"""Descarga los calendarios .ics de ~/.config/almanaque/calendars.conf al
cache (~/.cache/almanaque/<nombre>.ics). Lo corre el timer de systemd
almanaque-sync.timer cada 15 min, y el popup cuando el cache esta viejo.

Solo usa la stdlib: tiene que andar aunque falten los paquetes de icalendar.
"""
import configparser
import os
import re
import sys
import urllib.request
from pathlib import Path

CONF = Path.home() / ".config/almanaque/calendars.conf"
CACHE = Path.home() / ".cache/almanaque"


def slug(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-") or "calendario"


def load_conf() -> configparser.ConfigParser:
    cp = configparser.ConfigParser(interpolation=None)
    if CONF.exists():
        cp.read(CONF)
    return cp


def fetch(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "almanaque/1.0"})
    with urllib.request.urlopen(req, timeout=20) as r:
        return r.read()


def main() -> int:
    cp = load_conf()
    CACHE.mkdir(parents=True, exist_ok=True)
    wanted = set()
    errors = 0
    for name in cp.sections():
        url = cp[name].get("url", "").strip()
        if not url or cp[name].getboolean("enabled", True) is False:
            continue
        dest = CACHE / f"{slug(name)}.ics"
        wanted.add(dest.name)
        try:
            data = fetch(url)
            if b"BEGIN:VCALENDAR" not in data[:200]:
                raise ValueError("la respuesta no es un .ics (¿URL mal copiada?)")
            tmp = dest.with_suffix(".tmp")
            tmp.write_bytes(data)
            os.replace(tmp, dest)
        except Exception as e:  # sin red, URL vieja, etc.: se queda el cache anterior
            print(f"almanaque-sync: {name}: {e}", file=sys.stderr)
            errors += 1

    # Borra caches de calendarios que ya no estan en el conf.
    for f in CACHE.glob("*.ics"):
        if f.name not in wanted:
            f.unlink()
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
