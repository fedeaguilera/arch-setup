#!/usr/bin/env bash
# Orquestador de arch-setup. Correr DESPUES de instalar Arch a mano segun
# INSTALL.md (particionado, archinstall, fix del bug UKI/mkinitcpio, boot
# funcionando). Este script asume que ya estas logueado en una sesion
# minima (TTY o el Hyprland recien instalado con lo justo).
#
# Uso:
#   ./install.sh                # corre todos los modulos en orden, pide
#                                # confirmacion antes de cada uno
#   ./install.sh --yes          # igual, pero sin preguntar (para dejarlo
#                                # corriendo y volver mas tarde)
#   ./install.sh --only 02-gpu  # corre un solo modulo (podes usar "02-gpu"
#                                # o "02-gpu.sh" o el nombre completo)
#   ./install.sh --list         # lista los modulos y si ya estan hechos
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$REPO_DIR/modules/lib.sh"

MODULES=(
    00-base
    01-aur
    02-gpu
    03-hyprland
    04-sddm
    05-snapper
    06-grub-theme
    07-apps
    08-dotfiles
    09-servicios
    10-hibernate
)

ONLY=""
ARCH_SETUP_YES="${ARCH_SETUP_YES:-0}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --only)
            ONLY="${2:?falta el nombre del modulo despues de --only}"
            ONLY="${ONLY%.sh}"
            shift 2
            ;;
        --yes)
            ARCH_SETUP_YES=1
            shift
            ;;
        --list)
            for m in "${MODULES[@]}"; do
                if is_done "$m"; then echo "[hecho]     $m"; else echo "[pendiente] $m"; fi
            done
            exit 0
            ;;
        *)
            error "Argumento desconocido: $1"
            exit 1
            ;;
    esac
done
export ARCH_SETUP_YES

echo "arch-setup — log completo en $LOG_FILE" | tee -a "$LOG_FILE"

require_sudo

run_module() {
    local m="$1"
    if is_done "$m"; then
        log "[$m] ya hecho, salteo (borra $STATE_DIR/$m.done para forzar)"
        return 0
    fi
    if ! confirm "¿Correr el modulo $m?"; then
        warn "[$m] salteado a pedido"
        return 0
    fi
    log "===== $m ====="
    if bash "$REPO_DIR/modules/$m.sh"; then
        ok "[$m] terminado"
    else
        error "[$m] fallo — revisa $LOG_FILE, corregi, y volve a correr con: ./install.sh --only $m"
        exit 1
    fi
}

if [[ -n "$ONLY" ]]; then
    run_module "$ONLY"
else
    for m in "${MODULES[@]}"; do
        run_module "$m"
    done
fi

cat <<'EOF'

============================================================
 Listo. Esto queda MANUAL (no lo hace el script):
============================================================
  - Reiniciar y confirmar que arranca bien (tenes GRUB con
    submenu de snapshots via grub-btrfs si algo sale mal).
  - Probar suspend/hibernate:
        systemctl suspend
        systemctl hibernate
        systemctl suspend-then-hibernate
    y mirar journalctl -b -1 -p err si algo se ve raro al volver.
  - ProtonUp-Qt: instalar GE-Proton a mano (Steam → Configuracion
    → Compatibilidad).
  - Restaurar ~/vpn/ (certificados, .ovpn) — a proposito NO viaja
    en este repo, revisa el .gitignore.
  - Revisar fuentes/lenguaje de teclado si difieren del layout
    usado durante el desarrollo de este repo.
  - Ver notas-gaming.md (en este repo) para las opciones de
    lanzamiento de Steam/Lutris/Heroic (gamemoderun mangohud
    prime-run %command%).
============================================================
EOF
