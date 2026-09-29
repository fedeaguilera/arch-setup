#!/usr/bin/env bash
# Clic en el reloj de waybar: muestra/oculta el almanaque residente.
# gdbus responde en milisegundos; si el almanaque no esta corriendo (primer
# clic tras un crash, o sin el exec-once) lo arranca y se abre directo.
gdbus call --session --dest dev.aguidev.Almanaque \
    --object-path /dev/aguidev/Almanaque \
    --method org.freedesktop.Application.Activate '{}' >/dev/null 2>&1 \
    || exec "$HOME/.local/bin/almanaque.py"
