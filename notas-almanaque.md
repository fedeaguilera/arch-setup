# Almanaque — calendario del reloj de Waybar

Clic en la fecha/hora de Waybar → se abre un calendario (estilo Windows) con
Catppuccin Mocha. Muestra el mes, marca hoy, pinta los feriados de Argentina
y, al tocar un día, lista sus eventos de Google Calendar.

| Acción | Cómo |
|---|---|
| Abrir / cerrar | clic en el reloj · `Esc` · clic afuera de la tarjeta |
| Cambiar de mes | flechas ‹ › · rueda del mouse · teclas `←` `→` |
| Volver a hoy | botón **Hoy** · tecla `t` o `Inicio` |
| Ver eventos de un día | clic en el día (los puntitos = hay eventos) |

## Conectar tu agenda de Gmail (una sola vez)

1. Abrí <https://calendar.google.com> → engranaje ⚙ → **Configuración**.
2. Izquierda: **Configuración de mis calendarios** → clic en tu calendario.
3. **Integrar el calendario** → **Dirección secreta en formato iCal** → copiar.
4. Abrí `~/.config/almanaque/calendars.conf` (tiene estas mismas
   instrucciones adentro), descomentá la sección `[Gmail]` y pegá la URL.
5. Listo: aparecen en ≤ 15 min, o al instante con
   `~/.local/bin/almanaque-sync.py`.

Se pueden agregar más calendarios (trabajo, cumpleaños…) repitiendo la
sección con otro nombre y `color`.

> La URL secreta da acceso de **solo lectura** a tu agenda a quien la tenga.
> `calendars.conf` queda con permisos `600` y **no** se sube a este repo. Si
> se filtra, en la misma pantalla de Google está **Restablecer**.

## Notificaciones (alertas de eventos)

`almanaque-alertas.service` corre en segundo plano y manda la notificación
(swaync) cuando toca:

- **Alertas propias del evento** ("30 min antes", "el día a las 9:00"…):
  siempre llegan.
- **Recordatorio por defecto de Google**: *no* viene en el feed iCal (Google
  solo exporta las alertas puestas a mano en cada evento). Para suplirlo,
  `aviso = N` en la sección del calendario → aviso N minutos antes de cada
  evento con hora que no tenga alerta propia. Sin `aviso`, solo las propias.
- Si la compu estaba suspendida, al despertar avisa lo que se perdió en los
  últimos 15 min; lo más viejo se descarta para no spamear.
- Nunca repite un aviso (estado en `~/.cache/almanaque/alertas.json`).

Ver qué va a sonar en los próximos 7 días:
`~/.local/bin/almanaque-alertas.py --proximas`

Ojo: un evento nuevo tarda hasta 15 min en llegar (lo que tarda el sync); una
alerta que cae antes de eso se pierde.

## Cómo funciona

- `~/.local/bin/almanaque.py` — el popup (Python + GTK4 + gtk4-layer-shell).
  Es una capa *overlay* transparente a pantalla completa con la tarjeta
  arriba al centro; por eso cualquier clic afuera lo cierra.
- `~/.local/bin/almanaque-sync.py` — baja los `.ics` a `~/.cache/almanaque/`.
  Lo corre `almanaque-sync.timer` (systemd de usuario) cada 15 min, y el
  popup mismo si el cache tiene más de 15 min.
- `~/.config/almanaque/style.css` — colores/tamaños, editable.
- `layerrule` en `hyprland.conf` → blur detrás de la tarjeta.

## Problemas

- **"Falta python-icalendar"** en el pie → `sudo pacman -S python-icalendar`
  y `paru -S python-recurring-ical-events` (sin este último los eventos que
  se repiten no aparecen).
- **No aparecen eventos** → `~/.local/bin/almanaque-sync.py` y mirá el error
  (URL mal pegada = "la respuesta no es un .ics").
- **Estado del timer** → `systemctl --user list-timers almanaque-sync.timer`.
- **No llegan notificaciones** → `systemctl --user status almanaque-alertas`
  y `journalctl --user -u almanaque-alertas -n 30`.
