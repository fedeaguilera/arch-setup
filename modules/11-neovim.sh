#!/usr/bin/env bash
# Neovim + LazyVim (Python/JS/TS/React), tema Catppuccin Mocha transparente
# a juego con el resto del escritorio. La config vive en dotfiles/nvim y es
# el mismo LazyVim/starter con .git propio (no el template original).
#
# Notas del bootstrap headless (asi se armo y probo esta config):
#   - mason.nvim solo registra el comando ":Mason" al arrancar (lazy-load
#     por cmd); ":MasonInstall" no existe hasta que ":Mason" lo carga una
#     vez. Por eso la secuencia es "Mason" primero, "MasonInstall" despues.
#   - Mismo caso con nvim-treesitter: el stub inicial solo trae "TSInstall"
#     (no "TSInstallSync"), asi que se usa TSInstall + sleep para dejarlo
#     terminar antes de salir.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if is_done "11-neovim"; then log "11-neovim: ya hecho, salteo"; exit 0; fi

log "Instalando neovim, ripgrep, fd, lazygit"
install_pacman neovim ripgrep fd lazygit

log "Copiando config de dotfiles/nvim a ~/.config/nvim"
mkdir -p ~/.config/nvim
cp -rf "$REPO_DIR"/dotfiles/nvim/. ~/.config/nvim/
[[ -d ~/.config/nvim/.git ]] && rm -rf ~/.config/nvim/.git
(cd ~/.config/nvim && git init -q)

log "Sincronizando plugins (headless, puede tardar un par de minutos)"
nvim --headless "+Lazy! sync" +qa

log "Instalando LSP/herramientas via Mason (pyright, ruff, typescript-language-server, prettier, eslint, hadolint, tree-sitter-cli)"
nvim --headless \
    -c "Mason" \
    -c "MasonInstall pyright ruff typescript-language-server prettier eslint-lsp hadolint tree-sitter-cli" \
    -c "sleep 90" \
    -c "qa"

log "Compilando parsers de treesitter"
nvim --headless \
    -c "TSInstall python javascript typescript tsx json dockerfile lua markdown bash yaml" \
    -c "sleep 60" \
    -c "qa"

log "Copiando notas-neovim.md a ~/"
cp -f "$REPO_DIR/notas-neovim.md" ~/notas-neovim.md

mark_done "11-neovim"
ok "11-neovim listo — abrí nvim, corré :checkhealth si algo se ve raro. Guia: ~/notas-neovim.md"
