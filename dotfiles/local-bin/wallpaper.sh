#!/usr/bin/env bash
# Selector manual de wallpaper vía rofi. Nunca se ejecuta solo: hay que invocarlo
# a mano (SUPER+W) o desde el exec-once de restauración al iniciar sesión.
set -euo pipefail

WALLPAPER_DIR="$HOME/Pictures/wallpapers"
CACHE_FILE="$HOME/.cache/current_wallpaper"

mkdir -p "$WALLPAPER_DIR"
mkdir -p "$(dirname "$CACHE_FILE")"

mapfile -t images < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.bmp' -o -iname '*.gif' \) \
    | sort)

if [ "${#images[@]}" -eq 0 ]; then
    command -v notify-send >/dev/null 2>&1 && \
        notify-send "Wallpaper" "No hay imágenes en $WALLPAPER_DIR"
    exit 1
fi

selected=$(
    for img in "${images[@]}"; do
        printf '%s\x00icon\x1f%s\n' "$(basename "$img")" "$img"
    done | rofi -dmenu -i -p "Wallpaper" -show-icons \
        -theme "$HOME/.config/rofi/launchers/type-2/style-1.rasi" \
        -theme-str 'element-icon { size: 200px; } listview { columns: 3; lines: 2; } window { width: 55%; }'
)

if [ -z "$selected" ]; then
    exit 0
fi

chosen=""
for img in "${images[@]}"; do
    if [ "$(basename "$img")" = "$selected" ]; then
        chosen="$img"
        break
    fi
done

if [ -z "$chosen" ]; then
    exit 1
fi

awww img "$chosen" \
    --transition-type simple \
    --transition-step 30 \
    --transition-fps 60

echo "$chosen" > "$CACHE_FILE"
