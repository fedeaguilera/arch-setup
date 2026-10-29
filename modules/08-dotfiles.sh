#!/usr/bin/env bash
# Aplica los dotfiles del repo (fuente de verdad: la config que ya tenias
# funcionando) a ~/.config, ~/.local/bin y ~/.zshrc.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if is_done "08-dotfiles"; then log "08-dotfiles: ya hecho, salteo"; exit 0; fi

mkdir -p ~/.config ~/.local/bin

for d in hypr waybar kitty rofi swaync mpv; do
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
mkdir -p ~/.local/share/sounds/usb
cp -f "$REPO_DIR"/dotfiles/sounds/usb-*.oga ~/.local/share/sounds/usb/
cp -f "$REPO_DIR"/dotfiles/systemd-user/almanaque-{sync.service,sync.timer,alertas.service} "$REPO_DIR"/dotfiles/systemd-user/usb-sound.service "$REPO_DIR"/dotfiles/systemd-user/iphone-mount.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now almanaque-sync.timer almanaque-alertas.service usb-sound.service iphone-mount.service

# Carpetas en Nautilus: por defecto ganaba kitty-open y "abrir descarga" en Firefox abria una terminal
xdg-mime default org.gnome.Nautilus.desktop inode/directory
# Imagenes con Loupe (uno por tipo: xdg-mime con varios tipos juntos escribe una linea invalida)
for t in $(grep '^MimeType=' /usr/share/applications/org.gnome.Loupe.desktop | cut -d= -f2 | tr ';' ' '); do
    xdg-mime default org.gnome.Loupe.desktop "$t"
done
# Videos con Celluloid, leyendo ~/.config/mpv/mpv.conf (decodifica en la AMD)
for t in $(grep '^MimeType=' /usr/share/applications/io.github.celluloid_player.Celluloid.desktop | cut -d= -f2 | tr ';' '\n' | grep '^video/'); do
    xdg-mime default io.github.celluloid_player.Celluloid.desktop "$t"
done
gsettings set io.github.celluloid-player.Celluloid mpv-config-enable true
gsettings set io.github.celluloid-player.Celluloid mpv-config-file "file://$HOME/.config/mpv/mpv.conf"
# Loupe/Celluloid se abren por D-Bus: estos overrides fuerzan GL/Vulkan de la AMD
# para que abrir una foto o un video no despierte la NVIDIA
mkdir -p ~/.local/share/dbus-1/services
cp -f "$REPO_DIR"/dotfiles/dbus-services/*.service ~/.local/share/dbus-1/services/

log "Copiando .zshrc"
cp -f "$REPO_DIR/dotfiles/zshrc" ~/.zshrc

if [[ "$SHELL" != *zsh ]]; then
    log "Poniendo zsh como shell por defecto"
    sudo chsh -s "$(command -v zsh)" "$USER"
fi

mark_done "08-dotfiles"
ok "08-dotfiles listo"
