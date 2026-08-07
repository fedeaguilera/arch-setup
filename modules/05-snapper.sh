#!/usr/bin/env bash
# Configura snapper reutilizando el subvolumen @.snapshots que ya crea el
# particionado de INSTALL.md (archinstall no deja crear la config de
# snapper directo sobre un subvolumen que ya existe montado en /.snapshots,
# hay que sacarlo del medio y dejar que snapper cree el suyo).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if is_done "05-snapper"; then log "05-snapper: ya hecho, salteo"; exit 0; fi

if [[ -f /etc/snapper/configs/root ]]; then
    log "La config de snapper 'root' ya existe, salteo la creacion"
else
    log "Recreando /.snapshots para que snapper pueda tomar el subvolumen"
    sudo umount /.snapshots
    sudo rm -rf /.snapshots
    sudo snapper -c root create-config /
    sudo btrfs subvolume delete /.snapshots
    sudo mkdir /.snapshots
    sudo mount -a
    sudo chmod 750 /.snapshots
fi

log "Habilitando timers de snapper y grub-btrfsd"
sudo systemctl enable --now snapper-timeline.timer snapper-cleanup.timer
sudo systemctl enable --now grub-btrfsd.service

log "Regenerando grub.cfg para que grub-btrfs liste los snapshots"
sudo grub-mkconfig -o /boot/grub/grub.cfg

mark_done "05-snapper"
ok "05-snapper listo"
