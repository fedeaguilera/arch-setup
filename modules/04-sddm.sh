#!/usr/bin/env bash
# Tema SDDM + greeter forzado a la MISMA gpu que usa Hyprland (la iGPU).
#
# Por que: si el greeter de SDDM arranca en la NVIDIA y la sesion de
# Hyprland en la AMD (o viceversa), el login se traba/falla justo al
# ingresar la contraseña — ya paso en este equipo. Usamos el mismo symlink
# udev estable /dev/dri/gpu-igpu que genera 02-gpu.sh, asi los dos quedan
# atados a la misma GPU pase lo que pase con la numeracion de cards.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if is_done "04-sddm"; then log "04-sddm: ya hecho, salteo"; exit 0; fi

if [[ ! -e /dev/dri/gpu-igpu ]]; then
    error "/dev/dri/gpu-igpu no existe. Corre 02-gpu.sh primero (./install.sh --only 02-gpu)."
    exit 1
fi

if ! pacman -Qi sddm-astronaut-theme >/dev/null 2>&1; then
    command -v paru >/dev/null || { error "falta paru, corre 01-aur.sh primero"; exit 1; }
    log "Instalando sddm-astronaut-theme"
    install_aur sddm-astronaut-theme
fi

log "Configurando greeter en la iGPU (misma GPU que Hyprland)"
sudo mkdir -p /etc/sddm.conf.d
sudo tee /etc/sddm.conf.d/10.wayland.conf > /dev/null <<'EOF'
[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell,AQ_DRM_DEVICES=/dev/dri/gpu-igpu

[Wayland]
CompositorCommand=kwin_wayland --no-lockscreen --no-global-shortcuts --locale1
EOF

sudo tee /etc/sddm.conf.d/20.virtualkbd.conf > /dev/null <<'EOF'
[General]
InputMethod=qtvirtualkeyboard
EOF

sudo tee /etc/sddm.conf.d/theme.conf > /dev/null <<'EOF'
# /etc/sddm.conf.d/theme.conf
[Theme]
Current=sddm-astronaut-theme
EOF

mark_done "04-sddm"
ok "04-sddm listo"
