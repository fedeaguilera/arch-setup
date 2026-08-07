#!/usr/bin/env bash
# Swapfile de hibernacion en subvolumen btrfs propio + hook resume +
# servicios nvidia de sleep. Todo esto salio de resolver la hibernacion en
# esta misma maquina — incluye la vuelta atras de un parametro que en su
# momento parecia buena idea:
#
#   NVreg_PreserveVideoMemoryAllocations=1 rompe el hibernate en el driver
#   610.43.03 (nv_pmops_freeze devuelve -5 porque /proc/driver/nvidia/suspend
#   no existe en esta version — el freeze se cancela y el kernel cae a un
#   boot limpio en vez de resumir). A proposito NO se configura ese
#   parametro aca.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if is_done "10-hibernate"; then log "10-hibernate: ya hecho, salteo"; exit 0; fi

ROOT_UUID="$(findmnt -no UUID /)"
RAM_GB="$(awk '/MemTotal/{printf "%.0f", $2/1024/1024 + 2}' /proc/meminfo)"

log "Creando subvolumen /swap (queda fuera de los snapshots del subvolumen root)"
[[ -d /swap ]] || sudo btrfs subvolume create /swap

log "Creando swapfile de ${RAM_GB}G (RAM + margen) en /swap/swapfile"
if [[ ! -f /swap/swapfile ]]; then
    sudo btrfs filesystem mkswapfile --size "${RAM_GB}g" /swap/swapfile
fi

log "Activando swap y agregando a fstab"
sudo swapon /swap/swapfile 2>/dev/null || true
grep -q '/swap/swapfile' /etc/fstab || echo '/swap/swapfile none swap defaults 0 0' | sudo tee -a /etc/fstab > /dev/null

log "Calculando resume_offset"
RESUME_OFFSET="$(sudo btrfs inspect-internal map-swapfile -r /swap/swapfile)"
log "resume_offset=${RESUME_OFFSET}"

log "Agregando hook resume a mkinitcpio.conf"
if ! grep -qE '^HOOKS=.*\bresume\b' /etc/mkinitcpio.conf; then
    sudo sed -i 's/^HOOKS=(\(.*\)block \(.*\)filesystems/HOOKS=(\1block resume \2filesystems/' /etc/mkinitcpio.conf
fi

log "Agregando resume=/resume_offset= a GRUB"
if ! grep -q 'resume=' /etc/default/grub; then
    sudo sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"|GRUB_CMDLINE_LINUX_DEFAULT=\"\1 resume=UUID=${ROOT_UUID} resume_offset=${RESUME_OFFSET}\"|" /etc/default/grub
fi

log "Regenerando initramfs y grub.cfg"
sudo mkinitcpio -P
sudo grub-mkconfig -o /boot/grub/grub.cfg

log "Habilitando servicios nvidia de sleep (freeze/resume de la GPU sin preservar VRAM)"
sudo systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service nvidia-suspend-then-hibernate.service

log "suspend-then-hibernate: hiberna solo tras 2h de suspendido (ahorro de bateria)"
sudo mkdir -p /etc/systemd/sleep.conf.d /etc/systemd/logind.conf.d
sudo tee /etc/systemd/sleep.conf.d/hibernate-delay.conf > /dev/null <<'EOF'
[Sleep]
HibernateDelaySec=2h
EOF
sudo tee /etc/systemd/logind.conf.d/lid.conf > /dev/null <<'EOF'
[Login]
HandleLidSwitch=suspend-then-hibernate
HandleLidSwitchExternalPower=suspend-then-hibernate
EOF

warn "IMPORTANTE: no agregar NVreg_PreserveVideoMemoryAllocations a /etc/modprobe.d — rompe el hibernate en este driver (ver comentario arriba)"

mark_done "10-hibernate"
ok "10-hibernate listo — reiniciá y probá: systemctl suspend / systemctl hibernate"
