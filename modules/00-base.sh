#!/usr/bin/env bash
# Multilib, opciones de pacman, reflector, actualizacion inicial, paquetes base.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if is_done "00-base"; then log "00-base: ya hecho, salteo"; exit 0; fi

log "Habilitando [multilib] en /etc/pacman.conf"
if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
    sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
else
    log "multilib ya estaba habilitado"
fi

log "Color y ParallelDownloads en pacman.conf"
sudo sed -i 's/^#Color/Color/' /etc/pacman.conf
if ! grep -q "^ParallelDownloads" /etc/pacman.conf; then
    sudo sed -i '/^Color/a ParallelDownloads = 5' /etc/pacman.conf
fi

log "Sincronizando repos"
sudo pacman -Sy

log "Instalando reflector y aplicando config"
install_pacman reflector
sudo mkdir -p /etc/xdg/reflector
sudo tee /etc/xdg/reflector/reflector.conf > /dev/null <<'EOF'
--save /etc/pacman.d/mirrorlist
--protocol https
--latest 5
--sort age
EOF
sudo reflector --config /etc/xdg/reflector/reflector.conf || warn "reflector fallo, seguimos con el mirrorlist actual"

log "Instalando paquetes base"
install_pacman $(pkgs_in_category "$REPO_DIR/packages/oficiales.txt" base)

log "pacman -Syu completo"
sudo pacman -Syu --noconfirm

mark_done "00-base"
ok "00-base listo"
