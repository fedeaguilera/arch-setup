#!/usr/bin/env bash
# Tema de GRUB (catppuccin-mocha), detectando la resolucion real del panel
# para que el menu no quede en una resolucion generica/borrosa.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if is_done "06-grub-theme"; then log "06-grub-theme: ya hecho, salteo"; exit 0; fi

THEME_FILE="/usr/share/grub/themes/catppuccin-mocha/theme.txt"
if [[ ! -f "$THEME_FILE" ]]; then
    command -v paru >/dev/null || { error "falta paru, corre 01-aur.sh primero"; exit 1; }
    log "Instalando catppuccin-mocha-grub-theme-git"
    install_aur catppuccin-mocha-grub-theme-git
fi

RES="1920x1080"
if command -v hyprctl >/dev/null && hyprctl monitors -j >/dev/null 2>&1; then
    detected="$(hyprctl monitors -j | jq -r '.[0] | "\(.width)x\(.height)"' 2>/dev/null || true)"
    [[ -n "$detected" && "$detected" != "nullxnull" ]] && RES="$detected"
fi
log "Resolucion detectada para GRUB: $RES"

sudo sed -i "\#^GRUB_THEME=#d" /etc/default/grub
sudo sed -i "\#^GRUB_GFXMODE=#d" /etc/default/grub
{
    echo "GRUB_THEME=\"$THEME_FILE\""
    echo "GRUB_GFXMODE=${RES}x32,auto"
} | sudo tee -a /etc/default/grub > /dev/null

log "Regenerando grub.cfg"
sudo grub-mkconfig -o /boot/grub/grub.cfg

mark_done "06-grub-theme"
ok "06-grub-theme listo"
