#!/usr/bin/env bash
# Gaming, dev y apps de usuario (oficiales). Los AUR (spotify, onlyoffice,
# heroic, protonup-qt, temas) ya se instalaron en 01-aur.sh.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if is_done "07-apps"; then log "07-apps: ya hecho, salteo"; exit 0; fi

for cat in gaming dev apps; do
    log "Instalando categoria: $cat"
    install_pacman $(pkgs_in_category "$REPO_DIR/packages/oficiales.txt" "$cat")
done

log "Agregando $USER al grupo gamemode (necesario para renice)"
sudo usermod -aG gamemode "$USER"
warn "el grupo gamemode no toma efecto hasta que cierres sesion y vuelvas a entrar"

mark_done "07-apps"
ok "07-apps listo"
