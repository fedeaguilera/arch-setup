#!/usr/bin/env bash
# Compila paru desde fuente. NUNCA paru-bin: se rompe con actualizaciones de
# pacman por el ABI de libalpm.so (paru-bin queda linkeado contra una
# libalpm vieja y deja de poder resolver paquetes tras un -Syu).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if is_done "01-aur"; then log "01-aur: ya hecho, salteo"; exit 0; fi

if command -v paru >/dev/null; then
    log "paru ya esta instalado ($(paru --version | head -1))"
    mark_done "01-aur"
    exit 0
fi

log "Instalando dependencias de compilacion (base-devel, git)"
install_pacman base-devel git

BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

log "Clonando paru desde AUR"
git clone --depth 1 https://aur.archlinux.org/paru.git "$BUILD_DIR/paru"

log "Compilando e instalando paru (makepkg -si)"
(cd "$BUILD_DIR/paru" && makepkg -si --noconfirm)

command -v paru >/dev/null || { error "paru no quedo instalado"; exit 1; }

log "Instalando paquetes AUR de packages/aur.txt"
mapfile -t aur_pkgs < <(read_pkglist "$REPO_DIR/packages/aur.txt" | grep -v '^paru$' || true)
if [[ ${#aur_pkgs[@]} -gt 0 ]]; then
    install_aur "${aur_pkgs[@]}"
fi

mark_done "01-aur"
ok "01-aur listo"
