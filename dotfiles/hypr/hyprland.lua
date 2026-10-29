-- Config de Hyprland en Lua (Hyprland >= 0.57 ya no lee hyprland.conf).
-- Traducida 1:1 desde hyprland.conf (backup en hyprland.conf.pre-0.57.bak).

-- GPU: iGPU AMD primero, NVIDIA como secundaria
hl.env("AQ_DRM_DEVICES", "/dev/dri/gpu-igpu:/dev/dri/gpu-dgpu")

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("MOZ_ENABLE_WAYLAND", "1")

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})

local terminal    = "kitty"
local fileManager = "nautilus"
local menu        = "~/.config/rofi/launchers/type-2/launcher.sh"

hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd([[sh -c 'for i in $(seq 1 25); do awww query >/dev/null 2>&1 && break; sleep 0.2; done; [ -f "$HOME/.cache/current_wallpaper" ] && awww img "$(cat "$HOME/.cache/current_wallpaper")"']])
    hl.exec_cmd("sleep 0.5 && waybar")
    hl.exec_cmd("swaync")
    hl.exec_cmd("~/.local/bin/almanaque.py --daemon")
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("blueman-applet")
    hl.exec_cmd("wl-paste --watch cliphist store")
    hl.exec_cmd("swayosd-server")
    hl.exec_cmd("thunderbird")
end)

hl.config({
    general = {
        gaps_in     = 5,
        gaps_out    = 10,
        border_size = 2,
        col = {
            active_border   = { colors = { "rgba(89b4faee)", "rgba(cba6f7ee)" }, angle = 45 },
            inactive_border = "rgba(45475aaa)",
        },
        layout = "dwindle",
    },

    decoration = {
        rounding = 10,
        blur = {
            enabled = true,
            size    = 6,
            passes  = 2,
        },
    },

    animations = {
        enabled = true,
    },

    input = {
        kb_layout    = "latam",
        follow_mouse = 1,
        touchpad = {
            natural_scroll       = true,
            disable_while_typing = true,
        },
    },

    dwindle = {
        preserve_split = true,
    },

    misc = {
        disable_hyprland_logo   = true,
        force_default_wallpaper = 0,
    },

    debug = {
        disable_logs = false,
    },
})

hl.window_rule({ match = { class = "^(kitty)$" }, opacity = "0.85 0.85" })
hl.window_rule({ match = { class = [[^(org\.mozilla\.Thunderbird)$]] }, workspace = "4 silent" })

-- Almanaque (popup del reloj de waybar): blur solo detras de la tarjeta.
hl.layer_rule({ match = { namespace = "^(almanaque)$" }, blur = true, ignore_alpha = 0.3 })

hl.curve("smooth", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.0} } })
hl.animation({ leaf = "windows",      enabled = true, speed = 5, bezier = "smooth" })
hl.animation({ leaf = "fade",         enabled = true, speed = 5, bezier = "default" })
hl.animation({ leaf = "fadeIn",       enabled = true, speed = 8, bezier = "default" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 8, bezier = "default" })
hl.animation({ leaf = "workspaces",   enabled = true, speed = 4, bezier = "smooth", style = "slide" })

local mod = "SUPER"

-- bind(teclas, dispatcher, descripcion, opciones): la descripcion la muestra SUPER+K (keybinds.sh)
local function bind(keys, dsp, desc, opts)
    opts = opts or {}
    opts.description = desc
    return hl.bind(keys, dsp, opts)
end

bind(mod .. " + Q", hl.dsp.exec_cmd(terminal), "Terminal")
bind(mod .. " + C", hl.dsp.window.close(), "Cerrar ventana")
bind(mod .. " + M", hl.dsp.exit(), "Salir de Hyprland")
bind(mod .. " + E", hl.dsp.exec_cmd(fileManager), "Gestor de archivos")
bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }), "Alternar flotante")
bind(mod .. " + R", hl.dsp.exec_cmd(menu), "Lanzador (rofi)")
bind(mod .. " + W", hl.dsp.exec_cmd("~/.local/bin/wallpaper.sh"), "Cambiar wallpaper")
bind(mod .. " + O", hl.dsp.exec_cmd("~/.local/bin/kitty-opacity.sh"), "Opacidad de kitty")
bind(mod .. " + K", hl.dsp.exec_cmd("~/.local/bin/keybinds.sh"), "Ver atajos")
bind(mod .. " + F", hl.dsp.window.fullscreen(), "Pantalla completa")
bind(mod .. " + L", hl.dsp.exec_cmd("hyprlock"), "Bloquear pantalla")
-- Workaround bug conocido de Hyprland: a veces el click del mouse/touchpad deja de
-- responder aunque el cursor se mueva. Esto reinicia los dispositivos sin desenchufar el mouse.
bind(mod .. " + SHIFT + I", hl.dsp.exec_cmd("~/.local/bin/reset-input.sh"), "Reiniciar mouse/touchpad")

for _, dir in ipairs({ "left", "right", "up", "down" }) do
    bind(mod .. " + " .. dir,         hl.dsp.focus({ direction = dir }),       "Foco " .. dir)
    bind(mod .. " + SHIFT + " .. dir, hl.dsp.window.move({ direction = dir }), "Mover ventana " .. dir)
end

bind(mod .. " + CTRL + left",  hl.dsp.window.resize({ x = -40, y = 0,   relative = true }), "Achicar ancho",  { repeating = true })
bind(mod .. " + CTRL + right", hl.dsp.window.resize({ x = 40,  y = 0,   relative = true }), "Agrandar ancho", { repeating = true })
bind(mod .. " + CTRL + up",    hl.dsp.window.resize({ x = 0,   y = -40, relative = true }), "Achicar alto",   { repeating = true })
bind(mod .. " + CTRL + down",  hl.dsp.window.resize({ x = 0,   y = 40,  relative = true }), "Agrandar alto",  { repeating = true })

bind(mod .. " + SHIFT + S", hl.dsp.window.swap({ next = true }), "Intercambiar con la siguiente")

for i = 1, 6 do
    bind(mod .. " + " .. i,         hl.dsp.focus({ workspace = i }), "Ir al workspace " .. i)
    -- SHIFT (silent): mueve la ventana pero no te sigue al workspace nuevo
    bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i, follow = false }), "Mandar ventana al workspace " .. i)
    -- ALT: mueve la ventana Y te lleva con ella
    bind(mod .. " + ALT + " .. i,   hl.dsp.window.move({ workspace = i, follow = true }),  "Llevar ventana al workspace " .. i)
end

bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), "Workspace siguiente")
bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }), "Workspace anterior")

-- Tecla de captura real en este Legion (confirmado con wev): XF86SelectiveScreenshot, no Print
bind("XF86SelectiveScreenshot", hl.dsp.exec_cmd([[grim -g "$(slurp)" - | swappy -f -]]), "Captura region + editor")
bind("SHIFT + XF86SelectiveScreenshot", hl.dsp.exec_cmd("grim - | wl-copy"), "Captura pantalla al portapapeles")
bind("SUPER + XF86SelectiveScreenshot", hl.dsp.exec_cmd([[grim -g "$(slurp)" ~/Pictures/Screenshots/$(date +%Y%m%d_%H%M%S).png]]), "Captura region a archivo")
bind("ALT + XF86SelectiveScreenshot", hl.dsp.exec_cmd([[grim -g "$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')" - | wl-copy]]), "Captura ventana al portapapeles")

bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("swayosd-client --output-volume raise"),       "Subir volumen",  { locked = true, repeating = true })
bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("swayosd-client --output-volume lower"),       "Bajar volumen",  { locked = true, repeating = true })
bind("XF86AudioMute",         hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle"), "Silenciar",      { locked = true, repeating = true })
bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("swayosd-client --brightness raise"),          "Subir brillo",   { locked = true, repeating = true })
bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("swayosd-client --brightness lower"),          "Bajar brillo",   { locked = true, repeating = true })

bind(mod .. " + mouse:272", hl.dsp.window.drag(),   "Arrastrar ventana",     { mouse = true })
bind(mod .. " + mouse:273", hl.dsp.window.resize(), "Redimensionar ventana", { mouse = true })
