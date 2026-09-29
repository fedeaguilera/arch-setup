#!/usr/bin/env python3
"""Almanaque: popup de calendario para el reloj de Waybar (estilo Windows).

Clic en el reloj -> abre. Esc, clic afuera o clic en el reloj -> cierra.
Queda residente y oculto (`almanaque.py --daemon` en hyprland.conf); el reloj
llama a almanaque-toggle.sh, que lo muestra/oculta por D-Bus al instante.
Eventos: ~/.config/almanaque/calendars.conf (URLs .ics de Google Calendar),
cacheados por almanaque-sync.py en ~/.cache/almanaque/.
"""
import os
import sys

# gtk4-layer-shell tiene que cargarse antes que libwayland-client: con
# Python la unica forma confiable es LD_PRELOAD, asi que nos re-ejecutamos.
_LS_LIB = "/usr/lib/libgtk4-layer-shell.so"
if os.path.exists(_LS_LIB) and _LS_LIB not in os.environ.get("LD_PRELOAD", ""):
    os.environ["LD_PRELOAD"] = f"{_LS_LIB} {os.environ.get('LD_PRELOAD', '')}".strip()
    os.execv(sys.executable, [sys.executable, *sys.argv])

import configparser
import re
import subprocess
import threading
import time
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from pathlib import Path

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Gdk", "4.0")
gi.require_version("Gtk4LayerShell", "1.0")
from gi.repository import Gdk, GLib, Gtk, Pango  # noqa: E402
from gi.repository import Gtk4LayerShell as LayerShell  # noqa: E402

try:
    import icalendar
except ImportError:
    icalendar = None
try:
    import recurring_ical_events
except ImportError:
    recurring_ical_events = None

CONF_DIR = Path.home() / ".config/almanaque"
CONF = CONF_DIR / "calendars.conf"
STYLE = CONF_DIR / "style.css"
CACHE = Path.home() / ".cache/almanaque"
SYNC = Path.home() / ".local/bin/almanaque-sync.py"
STALE_SECS = 15 * 60
BAR_OFFSET = 48  # margin-top (6) + alto de waybar (34) + aire

DIAS = ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"]
DIAS_CORTOS = ["Lu", "Ma", "Mi", "Ju", "Vi", "Sá", "Do"]
MESES = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio",
         "agosto", "septiembre", "octubre", "noviembre", "diciembre"]

MOCHA = {
    "rosewater": "#f5e0dc", "flamingo": "#f2cdcd", "pink": "#f5c2e7",
    "mauve": "#cba6f7", "red": "#f38ba8", "maroon": "#eba0ac",
    "peach": "#fab387", "yellow": "#f9e2af", "green": "#a6e3a1",
    "teal": "#94e2d5", "sky": "#89dceb", "sapphire": "#74c7ec",
    "blue": "#89b4fa", "lavender": "#b4befe",
}
BASE = "#1e1e2e"


def slug(name: str) -> str:  # igual que en almanaque-sync.py
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-") or "calendario"


@dataclass
class Event:
    title: str
    start: datetime | date
    end: datetime | date
    all_day: bool
    location: str
    color: str
    holiday: bool


@dataclass
class Calendar:
    name: str
    color: str
    holiday: bool
    cal: object  # icalendar.Calendar


def to_local(value):
    """date -> date; datetime (con o sin tz) -> datetime naive en hora local."""
    if isinstance(value, datetime):
        return value.astimezone().replace(tzinfo=None) if value.tzinfo else value
    return value


class Store:
    """Lee los .ics cacheados y responde 'que eventos hay tal dia'."""

    def __init__(self):
        self.calendars: list[Calendar] = []
        self.configured = 0
        self.status = ""
        self.loaded_sig = None
        self.reload()

    @staticmethod
    def signature():
        """Cambia cuando cambia el conf o algun .ics (el sync los reescribe)."""
        files = [CONF, *sorted(CACHE.glob("*.ics"))]
        return tuple((f.name, f.stat().st_mtime) for f in files if f.exists())

    def changed(self) -> bool:
        return self.signature() != self.loaded_sig

    def reload(self):
        self.loaded_sig = self.signature()
        self.calendars = []
        cp = configparser.ConfigParser(interpolation=None)
        if CONF.exists():
            cp.read(CONF)
        sections = [s for s in cp.sections()
                    if cp[s].get("url", "").strip() and cp[s].getboolean("enabled", True)]
        self.configured = len(sections)
        if icalendar is None:
            self.status = "Falta python-icalendar para ver eventos"
            return
        for name in sections:
            path = CACHE / f"{slug(name)}.ics"
            if not path.exists():
                continue
            try:
                cal = icalendar.Calendar.from_ical(path.read_bytes())
            except Exception as e:
                print(f"almanaque: {name}: {e}", file=sys.stderr)
                continue
            color = MOCHA.get(cp[name].get("color", "mauve").strip(), MOCHA["mauve"])
            self.calendars.append(
                Calendar(name, color, cp[name].getboolean("holidays", False), cal))
        self.status = ""

    def cache_age(self) -> float | None:
        mtimes = [f.stat().st_mtime for f in CACHE.glob("*.ics")]
        return time.time() - min(mtimes) if mtimes else None

    def needs_sync(self) -> bool:
        if not self.configured:
            return False
        age = self.cache_age()
        conf_newer = CONF.exists() and any(
            f.stat().st_mtime < CONF.stat().st_mtime for f in CACHE.glob("*.ics"))
        return age is None or age > STALE_SECS or conf_newer or \
            len(list(CACHE.glob("*.ics"))) < self.configured

    def events_between(self, first: date, last: date) -> dict[date, list[Event]]:
        """Eventos por dia en [first, last] (ambos inclusive)."""
        days: dict[date, list[Event]] = {}
        for c in self.calendars:
            for comp in self._components(c.cal, first, last + timedelta(days=1)):
                ev = self._to_event(comp, c)
                if ev is None:
                    continue
                for d in self._days_of(ev):
                    if first <= d <= last:
                        days.setdefault(d, []).append(ev)
        for evs in days.values():
            # Todo el dia primero, despues por hora.
            evs.sort(key=lambda e: (not e.all_day,
                                    e.start if isinstance(e.start, datetime)
                                    else datetime.combine(e.start, datetime.min.time())))
        return days

    @staticmethod
    def _components(cal, start: date, end: date):
        if recurring_ical_events is not None:
            try:
                return recurring_ical_events.of(cal).between(start, end)
            except Exception as e:
                print(f"almanaque: {e}", file=sys.stderr)
        # Sin la libreria de recurrencias: solo eventos sueltos.
        return [c for c in cal.walk("VEVENT") if "RRULE" not in c]

    @staticmethod
    def _to_event(comp, c: Calendar) -> Event | None:
        if "DTSTART" not in comp or str(comp.get("STATUS", "")).upper() == "CANCELLED":
            return None
        start = to_local(comp["DTSTART"].dt)
        all_day = not isinstance(start, datetime)
        if "DTEND" in comp:
            end = to_local(comp["DTEND"].dt)
        elif "DURATION" in comp:
            end = start + comp["DURATION"].dt
        else:
            end = start + timedelta(days=1) if all_day else start
        # Google mezcla feriados ("Día festivo") con celebraciones (Día del
        # Maestro, etc.): solo los primeros pintan el numero del dia.
        observance = str(comp.get("DESCRIPTION", "")).startswith(("Celebración", "Observance"))
        return Event(
            title=str(comp.get("SUMMARY", "(sin título)")),
            start=start, end=end, all_day=all_day,
            location=str(comp.get("LOCATION", "")).split("\n")[0],
            color=c.color, holiday=c.holiday and not observance,
        )

    @staticmethod
    def _days_of(ev: Event):
        if ev.all_day:
            d, last = ev.start, max(ev.end - timedelta(days=1), ev.start)
        else:
            d = ev.start.date()
            # Un evento que termina justo a las 00:00 no ocupa el dia siguiente.
            last = max((ev.end - timedelta(seconds=1)).date(), d)
        while d <= last:
            yield d
            d += timedelta(days=1)


class Almanaque(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="dev.aguidev.Almanaque")
        self.win = None
        self.store = None
        self.today = date.today()
        self.selected = self.today
        self.month = self.today.replace(day=1)
        self.month_events: dict[date, list[Event]] = {}
        self.syncing = False
        self._scroll_acc = 0.0

    # ── Arranque ────────────────────────────────────────────────────────
    # Queda residente (arranca oculto con --daemon desde hyprland.conf). El clic
    # en el reloj (almanaque-toggle.sh) le manda Activate por D-Bus -> mostrar u
    # ocultar al instante, sin arrancar Python ni releer los .ics cada vez.
    def do_activate(self):
        if self.win is None:
            self.hold()  # no salir al ocultar la ventana
            self._load_css()
            self.store = Store()
            self.win = self._build_window()
            GLib.timeout_add_seconds(60, self._reload_if_changed)
            if "--daemon" in sys.argv:
                self._refresh()
                return
        if self.win.get_visible():
            self._hide()
        else:
            self._show()

    def _show(self):
        # Al abrir, como en Windows: siempre arranca en hoy.
        self.today = date.today()
        self.selected = self.today
        self.month = self.today.replace(day=1)
        self.header_weekday.set_label(DIAS[self.today.weekday()])
        self.header_date.set_label(
            f"{self.today.day} de {MESES[self.today.month - 1]} de {self.today.year}")
        if self.store.changed():
            self.store.reload()
        self._refresh()
        self.win.set_visible(True)
        if self.store.needs_sync():
            self._start_sync()

    def _hide(self):
        self.win.set_visible(False)

    def _reload_if_changed(self):
        # Mientras esta oculto, precarga lo que trajo el timer de sync para que
        # abrir no tenga que parsear nada.
        if not self.win.get_visible() and self.store.changed():
            self.store.reload()
            self._refresh()
        return True

    def _load_css(self):
        provider = Gtk.CssProvider()
        if STYLE.exists():
            provider.load_from_path(str(STYLE))
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_USER)

    def _build_window(self):
        win = Gtk.Window(application=self)
        win.add_css_class("almanaque")
        win.set_decorated(False)

        LayerShell.init_for_window(win)
        LayerShell.set_namespace(win, "almanaque")
        LayerShell.set_layer(win, LayerShell.Layer.OVERLAY)
        for edge in (LayerShell.Edge.TOP, LayerShell.Edge.BOTTOM,
                     LayerShell.Edge.LEFT, LayerShell.Edge.RIGHT):
            LayerShell.set_anchor(win, edge, True)
        LayerShell.set_exclusive_zone(win, -1)
        LayerShell.set_keyboard_mode(win, LayerShell.KeyboardMode.EXCLUSIVE)

        self.card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.card.add_css_class("card")
        self.card.set_halign(Gtk.Align.CENTER)
        self.card.set_valign(Gtk.Align.START)
        self.card.set_margin_top(BAR_OFFSET)
        win.set_child(self.card)

        # Cabecera con el dia de hoy.
        self.header_weekday = Gtk.Label(label=DIAS[self.today.weekday()], xalign=0)
        self.header_weekday.add_css_class("today-weekday")
        self.header_date = Gtk.Label(
            xalign=0, label=f"{self.today.day} de {MESES[self.today.month - 1]}"
                            f" de {self.today.year}")
        self.header_date.add_css_class("today-date")
        self.card.append(self.header_weekday)
        self.card.append(self.header_date)

        # Navegacion: ‹ Mes Año ›   [Hoy]
        nav = Gtk.Box(spacing=4)
        nav.add_css_class("nav")
        prev_b = Gtk.Button(label="\uf053")
        prev_b.connect("clicked", lambda *_: self._shift_month(-1))
        next_b = Gtk.Button(label="\uf054")
        next_b.connect("clicked", lambda *_: self._shift_month(1))
        self.month_label = Gtk.Label(hexpand=True, xalign=0)
        self.month_label.add_css_class("month-label")
        self.today_btn = Gtk.Button(label="Hoy")
        self.today_btn.add_css_class("today-btn")
        self.today_btn.connect("clicked", lambda *_: self._go_today())
        for w in (self.month_label, prev_b, next_b, self.today_btn):
            nav.append(w)
        self.card.append(nav)

        self.grid = Gtk.Grid(column_spacing=2, row_spacing=2, column_homogeneous=True)
        self.card.append(self.grid)

        self.events_title = Gtk.Label(xalign=0)
        self.events_title.add_css_class("events-title")
        self.card.append(self.events_title)
        self.events_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.card.append(self.events_box)

        self.footer = Gtk.Label(xalign=0, wrap=True, max_width_chars=40)
        self.footer.add_css_class("footer")
        self.card.append(self.footer)

        # Rueda del mouse / touchpad sobre la tarjeta -> cambia de mes.
        scroll = Gtk.EventControllerScroll.new(Gtk.EventControllerScrollFlags.VERTICAL)
        scroll.connect("scroll", self._on_scroll)
        self.card.add_controller(scroll)

        keys = Gtk.EventControllerKey()
        keys.connect("key-pressed", self._on_key)
        win.add_controller(keys)

        # Clic fuera de la tarjeta -> cerrar.
        click = Gtk.GestureClick()
        click.set_button(0)
        click.connect("pressed", self._on_backdrop_click)
        win.add_controller(click)
        return win

    # ── Interaccion ─────────────────────────────────────────────────────
    def _on_backdrop_click(self, _gesture, _n, x, y):
        w = self.win.pick(x, y, Gtk.PickFlags.DEFAULT)
        while w is not None:
            if w is self.card:
                return
            w = w.get_parent()
        self._hide()

    def _on_key(self, _ctrl, keyval, _code, _state):
        if keyval == Gdk.KEY_Escape:
            self._hide()
        elif keyval in (Gdk.KEY_Left, Gdk.KEY_Page_Up):
            self._shift_month(-1)
        elif keyval in (Gdk.KEY_Right, Gdk.KEY_Page_Down):
            self._shift_month(1)
        elif keyval in (Gdk.KEY_Home, Gdk.KEY_t, Gdk.KEY_h):
            self._go_today()
        else:
            return False
        return True

    def _on_scroll(self, _ctrl, _dx, dy):
        self._scroll_acc += dy
        if abs(self._scroll_acc) >= 1:
            self._shift_month(1 if self._scroll_acc > 0 else -1)
            self._scroll_acc = 0.0
        return True

    def _shift_month(self, delta: int):
        m = self.month.month - 1 + delta
        self.month = date(self.month.year + m // 12, m % 12 + 1, 1)
        self._refresh()

    def _go_today(self):
        self.month = self.today.replace(day=1)
        self.selected = self.today
        self._refresh()

    def _select(self, d: date):
        self.selected = d
        if d.month != self.month.month:
            self.month = d.replace(day=1)
        self._refresh()

    # ── Dibujo ──────────────────────────────────────────────────────────
    def _grid_range(self):
        start = self.month - timedelta(days=self.month.weekday())
        return start, start + timedelta(days=41)

    def _refresh(self):
        first, last = self._grid_range()
        self.month_events = self.store.events_between(first, last)
        self.month_label.set_label(f"{MESES[self.month.month - 1].capitalize()} {self.month.year}")
        self.today_btn.set_visible(self.selected != self.today
                                   or self.month != self.today.replace(day=1))
        self._draw_grid(first)
        self._draw_events()
        self._draw_footer()

    def _draw_grid(self, first: date):
        while (child := self.grid.get_first_child()) is not None:
            self.grid.remove(child)
        for col, name in enumerate(DIAS_CORTOS):
            lbl = Gtk.Label(label=name)
            lbl.add_css_class("weekday")
            if col >= 5:
                lbl.add_css_class("weekend")
            self.grid.attach(lbl, col, 0, 1, 1)

        for i in range(42):
            d = first + timedelta(days=i)
            evs = self.month_events.get(d, [])
            btn = Gtk.Button()
            btn.add_css_class("day")
            box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
            num = Gtk.Label(label=str(d.day))
            num.add_css_class("num")
            dot = Gtk.Label()
            dot.add_css_class("dot")
            box.append(num)
            box.append(dot)
            btn.set_child(box)

            if d.month != self.month.month:
                btn.add_css_class("other-month")
            if d.weekday() >= 5:
                btn.add_css_class("weekend")
            if any(e.holiday for e in evs):
                btn.add_css_class("holiday")
            if d == self.selected:
                btn.add_css_class("selected")
            if d == self.today:
                btn.add_css_class("today")
            if evs:
                colors = list(dict.fromkeys(e.color for e in evs))[:3]
                if d == self.today:
                    colors = [BASE] * len(colors)
                dot.set_markup("".join(f'<span foreground="{c}">●</span>' for c in colors))
                btn.set_tooltip_text("\n".join(e.title for e in evs[:6]))

            btn.connect("clicked", lambda _b, day=d: self._select(day))
            self.grid.attach(btn, i % 7, 1 + i // 7, 1, 1)

    def _day_title(self, d: date) -> str:
        delta = (d - self.today).days
        rel = {0: "Hoy", 1: "Mañana", -1: "Ayer"}.get(delta)
        full = f"{DIAS[d.weekday()]} {d.day} de {MESES[d.month - 1]}"
        if d.year != self.today.year:
            full += f" de {d.year}"
        return f"{rel} · {full}" if rel else full

    def _draw_events(self):
        self.events_title.set_label(self._day_title(self.selected))
        while (child := self.events_box.get_first_child()) is not None:
            self.events_box.remove(child)

        evs = self.month_events.get(self.selected, [])
        if not evs:
            lbl = Gtk.Label(label="Sin eventos", xalign=0)
            lbl.add_css_class("no-events")
            self.events_box.append(lbl)
            return

        for ev in evs:
            row = Gtk.Box(spacing=10)
            row.add_css_class("event")

            bar = Gtk.DrawingArea()
            bar.set_content_width(4)
            bar.set_draw_func(self._paint_bar, ev.color)
            row.append(bar)

            tl = Gtk.Label(label=self._time_text(ev), xalign=0, valign=Gtk.Align.CENTER)
            tl.add_css_class("event-time")
            row.append(tl)

            texts = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, hexpand=True)
            title = Gtk.Label(label=ev.title, xalign=0, max_width_chars=24,
                              ellipsize=Pango.EllipsizeMode.END)
            title.add_css_class("event-title")
            title.set_tooltip_text(ev.title)
            texts.append(title)
            if ev.location:
                loc = Gtk.Label(label=ev.location, xalign=0, max_width_chars=28,
                                ellipsize=Pango.EllipsizeMode.END)
                loc.add_css_class("event-sub")
                texts.append(loc)
            row.append(texts)
            self.events_box.append(row)

    @staticmethod
    def _paint_bar(_area, cr, w, h, color):
        rgba = Gdk.RGBA()
        rgba.parse(color)
        Gdk.cairo_set_source_rgba(cr, rgba)
        r = w / 2
        cr.arc(r, r, r, 3.1416, 0)
        cr.arc(r, h - r, r, 0, 3.1416)
        cr.close_path()
        cr.fill()

    def _time_text(self, ev: Event) -> str:
        if ev.all_day:
            return "Todo el día"
        d = self.selected
        starts_today = ev.start.date() == d
        ends_today = ev.end.date() == d or (ev.end - timedelta(seconds=1)).date() == d
        s = ev.start.strftime("%H:%M") if starts_today else "…"
        e = ev.end.strftime("%H:%M") if ends_today else "…"
        return s if ev.end == ev.start else f"{s} – {e}"

    def _draw_footer(self):
        if self.syncing:
            text = "Sincronizando calendarios…"
        elif self.store.status:
            text = self.store.status
        elif not self.store.configured:
            text = "Sin calendarios · configurá ~/.config/almanaque/calendars.conf"
        else:
            age = self.store.cache_age()
            if age is None:
                text = "Sin datos todavía (¿hay internet?)"
            elif age < 90:
                text = "Actualizado recién"
            elif age < 3600:
                text = f"Actualizado hace {int(age // 60)} min"
            else:
                text = f"Actualizado hace {int(age // 3600)} h"
        self.footer.set_label(text)

    # ── Sync en segundo plano ───────────────────────────────────────────
    def _start_sync(self):
        if not SYNC.exists():
            return
        self.syncing = True
        self._draw_footer()

        def run():
            env = {k: v for k, v in os.environ.items() if k != "LD_PRELOAD"}
            try:
                subprocess.run([sys.executable, str(SYNC)], env=env, timeout=60,
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            except Exception:
                pass
            GLib.idle_add(self._sync_done)

        threading.Thread(target=run, daemon=True).start()

    def _sync_done(self):
        self.syncing = False
        if self.win is not None:
            self.store.reload()
            self._refresh()
        return False


if __name__ == "__main__":
    sys.exit(Almanaque().run([]))
