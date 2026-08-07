#!/usr/bin/env bash
# Habilita los servicios de sistema relevados en la maquina real (sin
# docker: no esta instalado en este sistema, se saco del script a pedido).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if is_done "09-servicios"; then log "09-servicios: ya hecho, salteo"; exit 0; fi

SERVICES=(
    sddm.service
    NetworkManager.service
    NetworkManager-dispatcher.service
    NetworkManager-wait-online.service
    bluetooth.service
    power-profiles-daemon.service
    rtkit-daemon.service
    upower.service
    swayosd-libinput-backend.service
)

log "Habilitando: ${SERVICES[*]}"
sudo systemctl enable "${SERVICES[@]}"

mark_done "09-servicios"
ok "09-servicios listo (nvidia-suspend/hibernate/resume se habilitan en 10-hibernate.sh)"
