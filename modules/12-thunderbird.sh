#!/usr/bin/env bash
# Thunderbird, tema Catppuccin Mocha Mauve, autostart en workspace 3 (esto
# ultimo ya viene con dotfiles/hypr/hyprland.conf via 08-dotfiles.sh).
#
# El tema (.xpi) no se puede instalar de forma confiable por linea de
# comandos: Thunderbird lo instala via su Add-ons Manager, y sortear eso
# significaria pelear con la verificacion de firmas de extensiones. Este
# modulo deja todo listo (paquete + archivo del tema) y el ultimo paso
# (2 clicks) queda para el usuario.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if is_done "12-thunderbird"; then log "12-thunderbird: ya hecho, salteo"; exit 0; fi

log "Instalando thunderbird"
install_pacman thunderbird

log "Copiando el tema a ~/.local/share/thunderbird-theme/"
mkdir -p ~/.local/share/thunderbird-theme
cp -f "$REPO_DIR/dotfiles/thunderbird/mocha-mauve.xpi" ~/.local/share/thunderbird-theme/

log "Copiando notas-thunderbird.md a ~/"
cp -f "$REPO_DIR/notas-thunderbird.md" ~/notas-thunderbird.md

log "Fijando Firefox como navegador por defecto (para que los links de Thunderbird abran ahi)"
command -v xdg-settings >/dev/null && xdg-settings set default-web-browser firefox.desktop || warn "xdg-settings no disponible, fijalo a mano"

mark_done "12-thunderbird"
ok "12-thunderbird listo. Falta a mano: abrir thunderbird, configurar cuentas (ver ~/notas-thunderbird.md),"
ok "y instalar el tema desde Configuracion > Complementos y temas > engranaje > Instalar complemento desde archivo > ~/.local/share/thunderbird-theme/mocha-mauve.xpi"
