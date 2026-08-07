#!/usr/bin/env bash
# Stack completo de escritorio Hyprland (wayland, barra, launcher, portals,
# fuentes) + audio, y el servicio de usuario hypridle.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if is_done "03-hyprland"; then log "03-hyprland: ya hecho, salteo"; exit 0; fi

log "Instalando paquetes hyprland"
install_pacman $(pkgs_in_category "$REPO_DIR/packages/oficiales.txt" hyprland)

log "Instalando audio (pipewire-pulse, pavucontrol)"
install_pacman $(pkgs_in_category "$REPO_DIR/packages/oficiales.txt" audio)

log "Habilitando hypridle.service (usuario)"
systemctl --user enable hypridle.service 2>/dev/null || warn "no se pudo habilitar hypridle.service (¿corriendo fuera de una sesion grafica?)"

mark_done "03-hyprland"
ok "03-hyprland listo"
