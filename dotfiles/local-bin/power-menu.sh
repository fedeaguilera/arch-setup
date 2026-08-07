#!/usr/bin/env bash
# Menu de rofi: perfil de energia (powerprofilesctl) + perfil de inactividad (hypridle).
set -uo pipefail

STATE_FILE="$HOME/.cache/power-profile"
HYPRIDLE_CONF="$HOME/.config/hypr/hypridle.conf"
THEME="$HOME/.config/rofi/launchers/type-2/style-1.rasi"

notify() {
    gdbus call --session \
        --dest org.freedesktop.Notifications \
        --object-path /org/freedesktop/Notifications \
        --method org.freedesktop.Notifications.Notify \
        "Power Menu" 0 "" "$1" "$2" "[]" "{}" 4000 >/dev/null 2>&1
}

rofi_menu() {
    local prompt="$1" width="$2"
    rofi -dmenu -i -p "$prompt" \
        -theme "$THEME" \
        -theme-str "listview { columns: 1; } element-icon { size: 0px; } window { width: ${width}; }"
}

rofi_input() {
    local prompt="$1"
    printf '' | rofi -dmenu -p "$prompt" -theme "$THEME" \
        -theme-str 'listview { lines: 0; } window { width: 20%; }'
}

load_state() {
    idle_profile="normal"
    custom_brightness=4
    custom_lock=6
    custom_screen=8
    custom_suspend=20
    # shellcheck disable=SC1090
    [ -f "$STATE_FILE" ] && source "$STATE_FILE"
}

save_state() {
    cat > "$STATE_FILE" <<EOF
idle_profile=$idle_profile
custom_brightness=$custom_brightness
custom_lock=$custom_lock
custom_screen=$custom_screen
custom_suspend=$custom_suspend
EOF
}

write_hypridle() {
    local profile="$1"
    {
        echo "general {"
        echo "    lock_cmd = pidof hyprlock || hyprlock"
        echo "    before_sleep_cmd = loginctl lock-session"
        echo "    after_sleep_cmd = hyprctl dispatch dpms on"
        echo "}"
        if [ "$profile" != "presentacion" ]; then
            local b l s p
            case "$profile" in
                normal)  b=4; l=6; s=8;  p=20 ;;
                bateria) b=2; l=3; s=5;  p=10 ;;
                custom)  b=$custom_brightness; l=$custom_lock; s=$custom_screen; p=$custom_suspend ;;
            esac
            cat <<LISTENERS

listener {
    timeout = $((b * 60))
    on-timeout = brightnessctl -s set 10%
    on-resume = brightnessctl -r
}

listener {
    timeout = $((l * 60))
    on-timeout = loginctl lock-session
}

listener {
    timeout = $((s * 60))
    on-timeout = hyprctl dispatch dpms off
    on-resume = hyprctl dispatch dpms on
}

listener {
    timeout = $((p * 60))
    on-timeout = systemctl suspend
}
LISTENERS
        fi
    } > "$HYPRIDLE_CONF"

    systemctl --user enable --now hypridle.service >/dev/null 2>&1
    systemctl --user restart hypridle.service
}

apply_idle_profile() {
    local profile="$1"
    write_hypridle "$profile"
    idle_profile="$profile"
    save_state
    notify "Perfil de inactividad" "Cambiado a $profile"
}

custom_menu() {
    load_state
    while true; do
        options="🔆  Brillo: ${custom_brightness} min
🔒  Lock: ${custom_lock} min
🖥️  Pantalla apagada: ${custom_screen} min
😴  Suspender: ${custom_suspend} min
✅  Aplicar y guardar
←  Volver"
        sel=$(printf '%s\n' "$options" | rofi_menu "Personalizado" "25%")
        case "$sel" in
            *Brillo*)
                v=$(rofi_input "Brillo (minutos), actual: $custom_brightness")
                [[ "$v" =~ ^[0-9]+$ ]] && custom_brightness=$v
                ;;
            *Lock*)
                v=$(rofi_input "Lock (minutos), actual: $custom_lock")
                [[ "$v" =~ ^[0-9]+$ ]] && custom_lock=$v
                ;;
            *"Pantalla apagada"*)
                v=$(rofi_input "Pantalla apagada (minutos), actual: $custom_screen")
                [[ "$v" =~ ^[0-9]+$ ]] && custom_screen=$v
                ;;
            *Suspender*)
                v=$(rofi_input "Suspender (minutos), actual: $custom_suspend")
                [[ "$v" =~ ^[0-9]+$ ]] && custom_suspend=$v
                ;;
            *"Aplicar y guardar"*)
                apply_idle_profile "custom"
                return
                ;;
            *)
                return
                ;;
        esac
    done
}

main_menu() {
    load_state
    active_power="$(powerprofilesctl get 2>/dev/null)"

    mark_power() { [ "$active_power" = "$1" ] && echo " (activo)" || echo ""; }
    mark_idle()  { [ "$idle_profile" = "$1" ] && echo " (activo)" || echo ""; }

    options="⚡  Performance$(mark_power performance)
⚖️  Balanced$(mark_power balanced)
🍃  Power Saver$(mark_power power-saver)
──────────────
🎤  Presentación$(mark_idle presentacion)
🖥️  Normal$(mark_idle normal)
🔋  Batería$(mark_idle bateria)
✏️  Personalizado$(mark_idle custom)"

    sel=$(printf '%s\n' "$options" | rofi_menu "Power Menu" "25%")

    case "$sel" in
        *Performance*)
            powerprofilesctl set performance && notify "Power Profile" "Cambiado a performance"
            ;;
        *Balanced*)
            powerprofilesctl set balanced && notify "Power Profile" "Cambiado a balanced"
            ;;
        *"Power Saver"*)
            powerprofilesctl set power-saver && notify "Power Profile" "Cambiado a power-saver"
            ;;
        *Presentación*)
            apply_idle_profile "presentacion"
            ;;
        *Normal*)
            apply_idle_profile "normal"
            ;;
        *Batería*)
            apply_idle_profile "bateria"
            ;;
        *Personalizado*)
            custom_menu
            ;;
        *)
            exit 0
            ;;
    esac
}

main_menu
