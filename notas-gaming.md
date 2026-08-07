# Gaming en Arch — Ryzen 7 5800H (iGPU Vega) + RTX 3050 (dGPU)

Setup híbrido sin MUX: la pantalla está cableada solo a la iGPU AMD, así que
todo se compone ahí. Para que un juego use la dedicada (NVIDIA), hay que
forzar **PRIME render offload** — el juego renderiza en la RTX 3050 y el
frame se pasa a la iGPU para mostrarse en pantalla.

Verificado (2026-08-05):
```
$ glxinfo | grep "OpenGL renderer"
OpenGL renderer string: AMD Radeon Graphics (radeonsi, renoir, ACO, DRM 3.64, 6.18.41-1-lts)

$ prime-run glxinfo | grep "OpenGL renderer"
OpenGL renderer string: NVIDIA GeForce RTX 3050 Laptop GPU/PCIe/SSE2
```
`prime-run` (de `nvidia-prime`) simplemente setea estas variables y ejecuta
el comando:
```
__NV_PRIME_RENDER_OFFLOAD=1 __VK_LAYER_NV_optimus=NVIDIA_only __GLX_VENDOR_LIBRARY_NAME=nvidia "$@"
```

## Herramientas instaladas

- **steam**, **lutris**, **heroic** (heroic-games-launcher-bin, AUR) — launchers.
- **gamemode** + **lib32-gamemode** — optimizaciones temporales (CPU governor,
  prioridad de proceso) mientras el juego corre. Config en
  `~/.config/gamemode.ini` (override de usuario, ya ajustado para este hardware).
- **mangohud** + **lib32-mangohud** — overlay de FPS/stats en juego.
- **protonup-qt** (AUR) — instala versiones de Proton-GE / Wine-GE para
  Steam, Lutris y Heroic sin hacerlo a mano.
- **goverlay** — GUI para armar presets de MangoHud sin editar el config a mano.

Nota: tenés que estar en el grupo `gamemode` para que `renice` funcione
(`sudo usermod -aG gamemode $USER`, ya lo hace el script de instalación) —
hace falta cerrar sesión una vez para que tome efecto.

## Opciones de lanzamiento por launcher

### Steam
`Botón derecho al juego → Propiedades → General → Opciones de lanzamiento`:

```
gamemoderun mangohud prime-run %command%
```

- `gamemoderun` — pide las optimizaciones de gamemode (equivalente a
  `LD_PRELOAD=libgamemodeauto.so.0`).
- `mangohud` — activa el overlay (opcional, sacalo si no lo querés siempre).
- `prime-run` — fuerza el render en la RTX 3050.

Si algún juego no arranca con esa combinación, probá versiones más simples
en este orden: `prime-run %command%` solo, después sumá `mangohud`, después
`gamemoderun`.

Proton: usá **ProtonUp-Qt** para instalar GE-Proton (queda disponible en
Steam → Configuración → Compatibilidad → herramienta de compatibilidad de Steam Play).

### Lutris
No hace falta escribir nada a mano para gamemode/mangohud — Lutris los tiene
como toggles nativos:

`Configurar el juego → pestaña "System options"`:
- ✅ **Feral GameMode** (activa gamemode solo)
- ✅ **FPS counter (MangoHud)**
- **Command prefix**: `prime-run`

Si un runner específico no respeta "Command prefix", como alternativa poné
esto en la pestaña **Environment variables**:
```
__NV_PRIME_RENDER_OFFLOAD=1
__VK_LAYER_NV_optimus=NVIDIA_only
__GLX_VENDOR_LIBRARY_NAME=nvidia
```

Proton-GE / Wine-GE para Lutris también se instalan con **ProtonUp-Qt**
(elegí Lutris como destino ahí).

### Heroic Games Launcher
`Configuración del juego (ícono de engranaje) → Advanced/Other Settings`:
- ✅ **Enable GameMode** (toggle nativo, no hace falta `gamemoderun`)
- ✅ **Enable MangoHud** (toggle nativo)
- **Wrapper command**: `prime-run`

Wine-GE/Proton-GE para Heroic también vía **ProtonUp-Qt**.

## Verificar que todo esté andando

```bash
# Confirmar que un proceso arbitrario usa la NVIDIA
prime-run glxinfo | grep "OpenGL renderer"

# Confirmar Vulkan por la NVIDIA (necesita vulkan-tools, ya instalado)
prime-run vulkaninfo --summary | grep -i "deviceName\|driverName"

# Mientras un juego corre con gamemoderun, chequear que gamemode lo detectó:
gamemoded -s
```

`gamemoded -s` con el juego corriendo debería listar el PID del juego como
cliente activo. Si devuelve vacío, revisá que estés en el grupo `gamemode`
(`groups` tiene que incluirlo) y que hayas reiniciado sesión después de
correr el script de instalación.
