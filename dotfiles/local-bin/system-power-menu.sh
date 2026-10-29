#!/usr/bin/env bash
# Menu de rofi: apagar / reiniciar / suspender / cerrar sesion.
set -uo pipefail

THEME="$HOME/.config/rofi/launchers/type-2/style-1.rasi"

options="  Apagar
  Reiniciar
  Suspender
  Cerrar sesión"

sel=$(printf '%s\n' "$options" | rofi -dmenu -i -p "Power Menu" \
    -theme "$THEME" \
    -theme-str "listview { columns: 1; } element-icon { size: 0px; } window { width: 20%; }")

case "$sel" in
    *Apagar*) systemctl poweroff ;;
    *Reiniciar*) systemctl reboot ;;
    *Suspender*) systemctl suspend ;;
    *"Cerrar sesión"*) hyprctl dispatch 'hl.dsp.exit()' ;;
esac
