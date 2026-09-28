#!/usr/bin/env bash
# Workaround for a known Hyprland bug: clicks (touchpad + mouse) stop registering
# while the cursor still moves, because Hyprland's seat thinks a button is stuck down.
# https://github.com/hyprwm/Hyprland/issues/8558 https://github.com/hyprwm/Hyprland/issues/6551
# Toggling each pointer device off/on forces Hyprland to re-init it, same effect as
# physically unplugging/replugging the mouse, without needing to touch the cable.

names=$(hyprctl devices -j | jq -r '.mice[].name')

while IFS= read -r name; do
  [ -z "$name" ] && continue
  hyprctl keyword "device[$name]:enabled" false >/dev/null
done <<< "$names"

sleep 0.3

while IFS= read -r name; do
  [ -z "$name" ] && continue
  hyprctl keyword "device[$name]:enabled" true >/dev/null
done <<< "$names"

notify-send "Input reset" "Mouse/touchpad devices re-initialized" 2>/dev/null
