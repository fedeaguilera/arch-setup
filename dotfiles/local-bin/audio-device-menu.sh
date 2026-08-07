#!/usr/bin/env bash
# Selector de dispositivo de salida de audio (rofi + pactl).
set -uo pipefail

SPEAKER=$''

notify() {
    gdbus call --session \
        --dest org.freedesktop.Notifications \
        --object-path /org/freedesktop/Notifications \
        --method org.freedesktop.Notifications.Notify \
        "Audio" 0 "" "$1" "$2" "[]" "{}" 4000 >/dev/null 2>&1
}

current="$(pactl get-default-sink)"

mapfile -t names < <(pactl list sinks | awk -F': ' '/^\tName:/ {print $2}')
mapfile -t descs < <(pactl list sinks | awk -F': ' '/^\tDescription:/ {print $2}')

if [ "${#names[@]}" -eq 0 ]; then
    notify "Audio" "No se encontraron dispositivos de salida"
    exit 1
fi

menu=""
for i in "${!names[@]}"; do
    label="${descs[$i]}"
    if [ "${names[$i]}" = "$current" ]; then
        label="$label (activo)"
    fi
    menu+="$SPEAKER  $label"$'\n'
done

selected=$(printf '%s' "$menu" | rofi -dmenu -i -p "Salida de audio" \
    -theme "$HOME/.config/rofi/launchers/type-2/style-1.rasi" \
    -theme-str 'listview { columns: 1; lines: 4; } element-icon { size: 0px; } window { width: 30%; }')

[ -z "$selected" ] && exit 0

chosen_name=""
for i in "${!names[@]}"; do
    label="${descs[$i]}"
    if [ "${names[$i]}" = "$current" ]; then
        label="$label (activo)"
    fi
    if [ "$SPEAKER  $label" = "$selected" ]; then
        chosen_name="${names[$i]}"
        chosen_desc="${descs[$i]}"
        break
    fi
done

[ -z "$chosen_name" ] && exit 1

pactl set-default-sink "$chosen_name"

# Mueve los streams que ya estan sonando al nuevo dispositivo.
pactl list short sink-inputs | cut -f1 | while read -r sink_input; do
    pactl move-sink-input "$sink_input" "$chosen_name" 2>/dev/null
done

notify "Audio" "Salida cambiada a $chosen_desc"
