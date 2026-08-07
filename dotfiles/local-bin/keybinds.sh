#!/usr/bin/env bash
# Lee los binds de hyprland.conf, los formatea y los muestra en rofi.
set -uo pipefail

CONF="$HOME/.config/hypr/hyprland.conf"

python3 - "$CONF" << 'PYEOF' | rofi -dmenu -i -p "Keybinds" \
    -theme "$HOME/.config/rofi/launchers/type-2/style-1.rasi" \
    -theme-str 'element-icon { size: 0px; } window { width: 45%; } listview { lines: 15; }'
import re
import sys

path = sys.argv[1]

binds = []
with open(path, encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        m = re.match(r'^(bind[a-z]*)\s*=\s*(.*)$', line)
        if not m:
            continue
        _, rest = m.groups()
        parts = [p.strip() for p in rest.split(',')]
        if len(parts) < 2:
            continue
        mods, key = parts[0], parts[1]
        action = ", ".join(p for p in parts[2:] if p)
        mods = mods.replace("$mod", "SUPER")
        combo = f"{mods}+{key}" if mods else key
        binds.append((combo, action))

width = max((len(c) for c, _ in binds), default=10)
for combo, action in binds:
    print(f"{combo:<{width}}  →  {action}")
PYEOF
