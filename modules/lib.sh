#!/usr/bin/env bash
# Helpers compartidos por todos los modulos. Se sourcea, no se ejecuta solo.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="$HOME/.cache/arch-setup"
LOG_FILE="$HOME/arch-setup-install.log"
mkdir -p "$STATE_DIR"

C_RESET=$'\033[0m'; C_BLUE=$'\033[1;34m'; C_YELLOW=$'\033[1;33m'; C_RED=$'\033[1;31m'; C_GREEN=$'\033[1;32m'

log() {
    local msg="[$(date '+%H:%M:%S')] $*"
    echo "${C_BLUE}==>${C_RESET} $*"
    echo "$msg" >> "$LOG_FILE"
}

warn() {
    echo "${C_YELLOW}==> ADVERTENCIA:${C_RESET} $*"
    echo "[$(date '+%H:%M:%S')] WARN: $*" >> "$LOG_FILE"
}

error() {
    echo "${C_RED}==> ERROR:${C_RESET} $*" >&2
    echo "[$(date '+%H:%M:%S')] ERROR: $*" >> "$LOG_FILE"
}

ok() {
    echo "${C_GREEN}==>${C_RESET} $*"
    echo "[$(date '+%H:%M:%S')] OK: $*" >> "$LOG_FILE"
}

# confirm "Pregunta" -> 0 si el usuario dice que si.
# Con ARCH_SETUP_YES=1 (flag --yes de install.sh) no pregunta, asume que si.
confirm() {
    local prompt="$1"
    if [[ "${ARCH_SETUP_YES:-0}" == "1" ]]; then
        return 0
    fi
    local reply
    read -r -p "${C_YELLOW}?${C_RESET} $prompt [s/N] " reply
    [[ "$reply" =~ ^([sS]|[yY])$ ]]
}

# Idempotencia: cada modulo marca sus pasos hechos para poder re-correr
# install.sh sin repetir trabajo (o para --only saltando lo ya hecho).
is_done()   { [[ -f "$STATE_DIR/$1.done" ]]; }
mark_done() { touch "$STATE_DIR/$1.done"; }

# Mantiene viva la sesion de sudo durante todo el script (paru compila,
# pacman descarga; sin esto puede pedir la contraseña de nuevo a mitad de
# camino y frenar todo).
require_sudo() {
    if ! sudo -v; then
        error "Se necesita sudo para continuar."
        exit 1
    fi
    ( while true; do sudo -n true; sleep 60; kill -0 "$$" 2>/dev/null || exit; done ) &
    SUDO_KEEPALIVE_PID=$!
    trap '[[ -n "${SUDO_KEEPALIVE_PID:-}" ]] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null' EXIT
}

install_pacman() {
    [[ $# -eq 0 ]] && return 0
    sudo pacman -S --needed --noconfirm "$@"
}

install_aur() {
    [[ $# -eq 0 ]] && return 0
    paru -S --needed --noconfirm "$@"
}

# Lee un packages/*.txt y devuelve solo los nombres de paquete (sin
# comentarios ni lineas vacias).
read_pkglist() {
    grep -vE '^\s*#|^\s*$' "$1" | awk '{print $1}'
}

# pkgs_in_category packages/oficiales.txt graficos
# Extrae los paquetes bajo el header "# --- <categoria> ---" hasta el
# proximo header. Asi packages/*.txt queda como fuente editable: agregar
# una linea bajo la categoria correcta alcanza para que el modulo la instale.
pkgs_in_category() {
    local file="$1" category="$2"
    awk -v cat="# --- ${category} ---" '
        $0 == cat { on=1; next }
        /^# --- / { on=0 }
        on && /^#/ { next }
        on && NF { print $1 }
    ' "$file"
}
