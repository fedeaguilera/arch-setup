#!/usr/bin/env bash
# Menu de rofi para cambiar la opacidad de kitty en caliente.
set -uo pipefail

find_socket() {
    # Prioridad 1: PID de la ventana de kitty actualmente enfocada.
    local active
    active=$(hyprctl activewindow -j 2>/dev/null)
    local class pid
    class=$(printf '%s' "$active" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("class",""))' 2>/dev/null)
    pid=$(printf '%s' "$active" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("pid",""))' 2>/dev/null)
    if [ "$class" = "kitty" ] && [ -S "/tmp/kitty-$pid" ]; then
        echo "/tmp/kitty-$pid"
        return 0
    fi
    # Fallback: el socket real (unix socket, PID numerico) mas reciente en /tmp.
    # OJO: el glob usa [0-9] a proposito para no matchear kitty-opacity-err.log.
    local newest
    newest=$(ls -t /tmp/kitty-[0-9]* 2>/dev/null | while read -r f; do [ -S "$f" ] && echo "$f"; done | head -1)
    [ -n "$newest" ] && echo "$newest"
}

notify() {
    gdbus call --session \
        --dest org.freedesktop.Notifications \
        --object-path /org/freedesktop/Notifications \
        --method org.freedesktop.Notifications.Notify \
        "Kitty" 0 "" "$1" "$2" "[]" "{}" 4000 >/dev/null 2>&1
}

selected=$(printf '1.0\n0.95\n0.85\n0.75\n' | rofi -dmenu -i -p "Opacidad" \
    -theme "$HOME/.config/rofi/launchers/type-2/style-1.rasi" \
    -theme-str 'listview { columns: 1; lines: 4; } element-icon { size: 0px; } window { width: 18%; }')

[ -z "$selected" ] && exit 0

socket_path="$(find_socket)"
if [ -z "$socket_path" ]; then
    notify "Kitty: error" "No encontre ninguna ventana de kitty con remote control activo"
    exit 1
fi

if kitty @ --to "unix:$socket_path" set-background-opacity "$selected" 2>/tmp/kitty_opacity_err.log; then
    notify "Kitty" "Opacidad: $selected"
else
    err="$(cat /tmp/kitty_opacity_err.log 2>/dev/null)"
    notify "Kitty: error" "No se pudo aplicar $selected. $err"
fi
