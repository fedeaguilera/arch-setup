#!/usr/bin/env bash
# Drivers GPU hibrida (AMD iGPU + NVIDIA dGPU) + symlinks udev estables por
# PCI bus para que AQ_DRM_DEVICES (Hyprland) y el greeter de SDDM nunca
# dependan del numero de /dev/dri/cardN.
#
# Por que: el numero de card depende del ORDEN en que el kernel carga los
# drivers, que puede cambiar entre arranques (nos paso en esta misma
# maquina: precargar los modulos nvidia en el initramfs para mejorar el
# resume de hibernacion corrio la numeracion, card1 paso de ser la AMD a
# ser la NVIDIA, y Hyprland arrancaba con pantalla negra). El bus PCI en
# cambio es fijo mientras no cambies de placa madre.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if is_done "02-gpu"; then log "02-gpu: ya hecho, salteo"; exit 0; fi

log "Instalando drivers de GPU (nvidia-open-dkms + mesa/vulkan)"
install_pacman $(pkgs_in_category "$REPO_DIR/packages/oficiales.txt" graficos)
install_pacman linux-headers linux-lts-headers

log "Detectando bus PCI de las GPUs con lspci"
IGPU_PCI="$(lspci -d 1002: -nn | grep -Ei 'vga|3d controller' | head -1 | awk '{print $1}')"
DGPU_PCI="$(lspci -d 10de: -nn | grep -Ei 'vga|3d controller' | head -1 | awk '{print $1}')"

if [[ -z "$IGPU_PCI" || -z "$DGPU_PCI" ]]; then
    error "No se detectaron ambas GPUs (iGPU AMD 1002: / dGPU NVIDIA 10de:). IGPU='$IGPU_PCI' DGPU='$DGPU_PCI'"
    error "Revisa 'lspci -nn' a mano y segui manualmente, esto asume la hibrida AMD+NVIDIA de la Legion."
    exit 1
fi
log "iGPU AMD en PCI 0000:${IGPU_PCI} / dGPU NVIDIA en PCI 0000:${DGPU_PCI}"

log "Creando symlinks udev estables /dev/dri/gpu-igpu y /dev/dri/gpu-dgpu"
sudo tee /etc/udev/rules.d/61-gpu-symlinks.rules > /dev/null <<EOF
# Generado por arch-setup/modules/02-gpu.sh — no depende del numero de card,
# solo del bus PCI (estable mientras no cambies de placa madre).
SUBSYSTEM=="drm", KERNEL=="card[0-9]*", KERNELS=="0000:${IGPU_PCI}", SYMLINK+="dri/gpu-igpu"
SUBSYSTEM=="drm", KERNEL=="card[0-9]*", KERNELS=="0000:${DGPU_PCI}", SYMLINK+="dri/gpu-dgpu"
EOF
sudo udevadm control --reload
sudo udevadm trigger --subsystem-match=drm

log "Kernel params nvidia_drm.modeset=1 nvidia_drm.fbdev=1 en GRUB"
if ! grep -q "nvidia_drm.modeset=1" /etc/default/grub; then
    sudo sed -i 's/^\(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*\)"/\1 nvidia_drm.modeset=1 nvidia_drm.fbdev=1"/' /etc/default/grub
fi

log "Precargando modulos nvidia en initramfs (mejora tiempos de resume)"
sudo sed -i 's/^MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf

log "Regenerando initramfs y grub.cfg"
sudo mkinitcpio -P
sudo grub-mkconfig -o /boot/grub/grub.cfg

warn "NO se configura NVreg_PreserveVideoMemoryAllocations: en el driver 610.43.03"
warn "esto rompe la hibernacion (nv_pmops_freeze devuelve -5, /proc/driver/nvidia/suspend"
warn "no existe en esta version). Ver modules/10-hibernate.sh."

mark_done "02-gpu"
ok "02-gpu listo — acordate de usar /dev/dri/gpu-igpu:/dev/dri/gpu-dgpu en vez de card0/card1/card2 en cualquier config (Hyprland, SDDM)"
