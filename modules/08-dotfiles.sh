#!/usr/bin/env bash
# Aplica los dotfiles del repo (fuente de verdad: la config que ya tenias
# funcionando) a ~/.config, ~/.local/bin y ~/.zshrc.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if is_done "08-dotfiles"; then log "08-dotfiles: ya hecho, salteo"; exit 0; fi

mkdir -p ~/.config ~/.local/bin

for d in hypr waybar kitty rofi swaync; do
    log "Copiando dotfiles/$d -> ~/.config/$d"
    mkdir -p ~/.config/"$d"
    cp -rf "$REPO_DIR/dotfiles/$d/." ~/.config/"$d"/
done

log "Copiando scripts a ~/.local/bin"
cp -f "$REPO_DIR"/dotfiles/local-bin/*.sh ~/.local/bin/
chmod +x ~/.local/bin/*.sh

log "Copiando .zshrc"
cp -f "$REPO_DIR/dotfiles/zshrc" ~/.zshrc

if [[ "$SHELL" != *zsh ]]; then
    log "Poniendo zsh como shell por defecto"
    sudo chsh -s "$(command -v zsh)" "$USER"
fi

mark_done "08-dotfiles"
ok "08-dotfiles listo"
