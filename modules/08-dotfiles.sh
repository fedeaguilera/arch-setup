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
cp -f "$REPO_DIR"/dotfiles/local-bin/*.sh "$REPO_DIR"/dotfiles/local-bin/*.py ~/.local/bin/
chmod +x ~/.local/bin/*.sh ~/.local/bin/*.py

log "Almanaque (popup del reloj de waybar)"
mkdir -p ~/.config/almanaque ~/.config/systemd/user
cp -f "$REPO_DIR/dotfiles/almanaque/style.css" ~/.config/almanaque/
# calendars.conf lleva URLs secretas de Google: nunca se pisa ni viaja en el repo.
if [[ ! -f ~/.config/almanaque/calendars.conf ]]; then
    cp "$REPO_DIR/dotfiles/almanaque/calendars.conf.example" ~/.config/almanaque/calendars.conf
    chmod 600 ~/.config/almanaque/calendars.conf
fi
cp -f "$REPO_DIR"/dotfiles/systemd-user/almanaque-{sync.service,sync.timer,alertas.service} ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now almanaque-sync.timer almanaque-alertas.service

log "Copiando .zshrc"
cp -f "$REPO_DIR/dotfiles/zshrc" ~/.zshrc

if [[ "$SHELL" != *zsh ]]; then
    log "Poniendo zsh como shell por defecto"
    sudo chsh -s "$(command -v zsh)" "$USER"
fi

mark_done "08-dotfiles"
ok "08-dotfiles listo"
