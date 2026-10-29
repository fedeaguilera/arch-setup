#!/usr/bin/env bash
# Muestra en rofi los binds activos de Hyprland (con la descripcion definida en hyprland.lua).
set -uo pipefail

hyprctl binds -j | python3 -c '
import json, sys
MODS = [(64, "SUPER"), (1, "SHIFT"), (4, "CTRL"), (8, "ALT")]
binds = []
for b in json.load(sys.stdin):
    mods = [n for bit, n in MODS if b["modmask"] & bit]
    combo = "+".join(mods + [b["key"]])
    binds.append((combo, b.get("description") or b["dispatcher"]))
width = max((len(c) for c, _ in binds), default=10)
for combo, desc in binds:
    print(f"{combo:<{width}}  →  {desc}")
' | rofi -dmenu -i -p "Keybinds" \
    -theme "$HOME/.config/rofi/launchers/type-2/style-1.rasi" \
    -theme-str 'element-icon { size: 0px; } window { width: 45%; } listview { lines: 15; }'
