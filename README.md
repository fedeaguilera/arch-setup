# arch-setup

![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=flat-square&logo=arch-linux&logoColor=white)
![Hyprland](https://img.shields.io/badge/Hyprland-58E1FF?style=flat-square&logo=wayland&logoColor=black)
![btrfs](https://img.shields.io/badge/btrfs-snapshots-6E6E6E?style=flat-square)
![Bash](https://img.shields.io/badge/bash-modular-4EAA25?style=flat-square&logo=gnubash&logoColor=white)

Reinstalación automatizada de mi Arch Linux, generada leyendo el sistema
**ya funcionando** en vez de asumir valores. Si esta máquina se rompe o
cambio de disco, esto es lo que la vuelve a dejar como estaba — dotfiles
reales, paquetes reales, y tres bugs de hardware específico que ya no
tengo que volver a diagnosticar.

| | |
|---|---|
| **Equipo**   | Lenovo Legion, Ryzen 7 |
| **GPU**      | iGPU Radeon Vega (`05:00.0`) + RTX 3050 Mobile (`01:00.0`), híbrida sin MUX |
| **Disco**    | NVMe 512GB, dual boot Windows 11 |
| **Root**     | btrfs, subvolúmenes `@ @home @log @pkg @.snapshots`, zstd |
| **Boot**     | GRUB, kernels `linux` + `linux-lts` |
| **Escritorio** | Hyprland + SDDM (sddm-astronaut-theme) |
| **Editor**   | Neovim + LazyVim, Catppuccin Mocha transparente |

## Por qué existe esto

Cada bug de esta lista costó horas de diagnóstico la primera vez.
`install.sh` los evita desde el arranque; documentarlos acá es la garantía
de que no se repiten si algún día toca resolverlos a mano de nuevo.

> **archinstall deja mkinitcpio en modo UKI aunque elijas GRUB.**
> El sistema no bootea hasta que editás `/etc/mkinitcpio.d/*.preset`
> (`default_uki` → `default_image`) y corrés `grub-install` de nuevo.
> Ver [`INSTALL.md`](INSTALL.md#5-bug-crítico-archinstall-deja-mkinitcpio-en-modo-uki).

> **La numeración de `/dev/dri/cardN` no es estable entre arranques.**
> Precargar los módulos de nvidia en el initramfs (para mejorar el resume
> de hibernación) cambió el orden de carga de drivers y corrió la
> numeración — Hyprland quedó apuntando a la GPU equivocada y la pantalla
> del laptop (cableada solo a la iGPU) se puso negra. Fix real: symlinks
> `udev` estables por bus PCI (`/dev/dri/gpu-igpu`, `/dev/dri/gpu-dgpu`),
> no números de card. Ver `modules/02-gpu.sh`.

> **`NVreg_PreserveVideoMemoryAllocations=1` rompe la hibernación en este
> driver.** `nv_pmops_freeze` devuelve `-5` porque
> `/proc/driver/nvidia/suspend` no existe en nvidia-open-dkms 610.43.03, y
> el hibernate cae a un boot limpio en vez de resumir la sesión. A
> propósito **no** se configura ese parámetro. Ver `modules/10-hibernate.sh`.

## Estructura

```
arch-setup/
├── INSTALL.md            # particionado, BIOS, archinstall — todo lo manual
├── install.sh             # orquestador: --only <modulo>, --yes, --list
├── modules/                # 00-base ... 11-neovim, uno por dominio
├── dotfiles/                 # hypr/ waybar/ kitty/ rofi/ swaync/ nvim/ .zshrc
├── packages/                   # oficiales.txt (108) + aur.txt (8), categorizados
├── notas-gaming.md               # PRIME offload, launch options por juego
└── notas-neovim.md                # LazyVim viniendo de VS Code
```

## Uso

Instalación completa desde cero: seguí [`INSTALL.md`](INSTALL.md) hasta
tener un Arch mínimo que bootea a un prompt. Recién ahí:

```sh
git clone <url-de-este-repo> ~/arch-setup
cd ~/arch-setup
./install.sh                # pide confirmación antes de cada módulo
```

```sh
./install.sh --list         # qué está hecho y qué falta
./install.sh --only 02-gpu  # corre un solo módulo
./install.sh --yes          # sin preguntar, para dejarlo corriendo
```

Cada módulo se marca hecho en `~/.cache/arch-setup/*.done` — correr
`install.sh` de nuevo no repite trabajo ya aplicado.

## Módulos

El orden importa: cada uno asume que el anterior ya corrió.

| # | Módulo | Qué hace |
|---|---|---|
| 00 | `base` | multilib, `Color`/`ParallelDownloads`, reflector, paquetes base |
| 01 | `aur` | compila `paru` desde fuente (nunca `paru-bin`), instala AUR |
| 02 | `gpu` | drivers nvidia-open-dkms, kernel params, symlinks `udev` estables por PCI |
| 03 | `hyprland` | stack wayland completo + `hypridle.service` |
| 04 | `sddm` | tema astronaut, greeter forzado a la misma GPU que Hyprland |
| 05 | `snapper` | reusa el subvolumen `@.snapshots`, `snap-pac`, `grub-btrfs` |
| 06 | `grub-theme` | catppuccin-mocha, resolución detectada con `hyprctl` |
| 07 | `apps` | gaming, dev, apps de usuario |
| 08 | `dotfiles` | copia `dotfiles/` a `~/.config`, `~/.local/bin`, `~/.zshrc` |
| 09 | `servicios` | habilita NetworkManager, bluetooth, sddm, rtkit, upower, etc. |
| 10 | `hibernate` | swapfile en subvolumen propio, hook `resume`, servicios nvidia de sleep |
| 11 | `neovim` | LazyVim (Python/TS/React), Catppuccin Mocha, bootstrap headless de plugins/LSP |

## Paquetes

`pacman -Qqen` / `pacman -Qqem` reales de la máquina, agrupados por
categoría en `packages/*.txt` — agregar una línea bajo el header correcto
alcanza para que el módulo correspondiente la instale.

| Categoría | Oficiales | AUR |
|---|--:|--:|
| base | 29 | — |
| gráficos | 13 | — |
| hyprland | 33 | 3 (temas) |
| audio | 2 | — |
| gaming | 7 | 2 |
| dev | 7 | — |
| apps | 17 | 2 |
| **total** | **108** | **8** |

## Lo que queda manual

`install.sh` lo recuerda al terminar, pero para tenerlo a mano:

- Reiniciar y confirmar boot (GRUB tiene submenú de snapshots vía `grub-btrfs`
  si algo sale mal).
- Probar `systemctl suspend` / `hibernate` / `suspend-then-hibernate`.
- Proton-GE vía ProtonUp-Qt (Steam → Configuración → Compatibilidad).
- Restaurar `~/vpn/` — a propósito no viaja en este repo (ver `.gitignore`).
- `notas-gaming.md` para las opciones de lanzamiento por juego/launcher.
- `notas-neovim.md` para arrancar con LazyVim viniendo de VS Code.

---

Generado y mantenido con ayuda de Claude Code, leyendo esta misma máquina
como fuente de verdad. Sin garantías fuera de este hardware específico.
