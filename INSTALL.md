# INSTALL.md — reinstalación completa (Lenovo Legion, Ryzen 7 + RTX 3050)

Esto es lo que **`install.sh` no puede hacer por vos**: particionar, correr
`archinstall`, tocar la BIOS, ni adivinar el bus PCI de tus GPUs si algún día
corrés este repo en otra máquina. Seguí esta guía a mano, en orden, hasta
tener un sistema Arch que arranca a un prompt. Recién ahí entra `install.sh`.

Hardware de referencia: Lenovo Legion, Ryzen 7 con iGPU Radeon Vega
(PCI `05:00.0`) + RTX 3050 Mobile (PCI `01:00.0`) en modo híbrido sin MUX
(la pantalla está cableada solo a la iGPU). NVMe Samsung 512GB con dual
boot Windows 11. WiFi Intel AX200.

---

## 1. Preparar Windows (antes de tocar particiones)

Arrancá en Windows y hacé, en este orden:

1. **Desactivar BitLocker** — Panel de control → Cifrado de unidad BitLocker
   → Desactivar en la unidad C:. Si lo dejás activo, achicar la partición o
   tocarla desde Linux puede dejarla ilegible.
2. **Desactivar Fast Startup** — Panel de control → Opciones de energía →
   "Elegir el comportamiento de los botones de inicio/apagado" → desmarcar
   "Iniciar rápido". Fast Startup deja el filesystem NTFS en un estado
   híbrido (hibernado parcial) que btrfs/Linux no puede tocar y que además
   confunde a GRUB al detectar la partición.
3. **Achicar la partición de Windows** — Administración de discos → click
   derecho en C: → Reducir volumen. Dejá el espacio libre sin asignar (no
   crees una partición ahí, eso lo hace el particionador de Linux).
4. Reiniciá **dos veces** dentro de Windows después de esto (para que
   realmente aplique el apagado limpio) antes de bootear el pendrive de Arch.

## 2. BIOS

Entrá a la BIOS (F2 / Novo Button en Legion) y confirmá:

- **Secure Boot: OFF** — GRUB sin shim firmado no arranca con Secure Boot on.
- **SATA/NVMe Mode: AHCI** (no RAID).
- **Graphics: Hybrid / Switchable** (⚠️ **crítico**) — si la BIOS tiene un
  modo "Discrete only" que desconecta la iGPU del panel, Linux se queda sin
  forma de sacar imagen por la pantalla interna. Tiene que quedar en modo
  híbrido para que el panel siga cableado a la iGPU y la NVIDIA quede
  disponible como GPU secundaria vía PCIe.
- Fast Boot: opcional, no crítico, pero si te complica entrar al menú de
  boot para el pendrive, desactivalo mientras instalás.

## 3. Particionado

Arrancá el ISO de Arch. El espacio libre que dejaste en el paso 1 es donde
va todo esto (revisá con `lsblk` cuál es tu disco, acá es `/dev/nvme0n1`):

| Partición        | Tamaño   | FS    | Uso                          |
|-------------------|---------|-------|-------------------------------|
| ESP de Windows     | ~200M   | vfat  | ya existe, no tocar           |
| MSR                | 16M     | —     | ya existe, no tocar           |
| Windows C:         | resto   | ntfs  | ya existe, no tocar           |
| Recovery           | ~860M   | ntfs  | ya existe, no tocar           |
| **ESP de Linux**   | **1G**  | vfat  | `/boot` — propia, no compartida con la de Windows |
| **Root**           | resto   | btrfs | `/` con subvolúmenes          |

```
cgdisk /dev/nvme0n1   # o cfdisk, lo que tengas a mano
```

Creá una partición EFI nueva de **1GiB** (código `ef00`) y una partición
btrfs con el resto del espacio libre.

### Subvolúmenes btrfs

```
mkfs.btrfs /dev/nvme0n1pX          # la partición root que acabas de crear
mount /dev/nvme0n1pX /mnt

btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@pkg
btrfs subvolume create /mnt/@.snapshots

umount /mnt

mount -o compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@ /dev/nvme0n1pX /mnt
mkdir -p /mnt/{home,var/log,var/cache/pacman/pkg,.snapshots,boot}
mount -o compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@home     /dev/nvme0n1pX /mnt/home
mount -o compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@log      /dev/nvme0n1pX /mnt/var/log
mount -o compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@pkg      /dev/nvme0n1pX /mnt/var/cache/pacman/pkg
mount -o compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@.snapshots /dev/nvme0n1pX /mnt/.snapshots

mkfs.fat -F32 /dev/nvme0n1pY       # la ESP nueva de 1G
mount /dev/nvme0n1pY /mnt/boot
```

`@.snapshots` se crea acá pero **snapper todavía no está configurado** — de
eso se encarga `modules/05-snapper.sh` más adelante (necesita un baile
particular de umount/create-config/delete/mkdir porque el subvolumen ya
existe).

## 4. archinstall

```
archinstall
```

Elegí:

- **Bootloader:** GRUB (no systemd-boot, no limine).
- **Kernels:** `linux` y `linux-lts` (los dos — el lts es la red de
  seguridad si un kernel nuevo rompe algo).
- **Profile:** Minimal (todo el resto de paquetes lo pone `install.sh`).
- **Swap:** zram con compresión zstd (no swap en disco acá — el swap para
  hibernación es un módulo aparte, `10-hibernate.sh`, en su propio
  subvolumen).
- **Network:** NetworkManager, con `wpa_supplicant` como backend (no
  `iwd` para NetworkManager — dejamos `iwd` instalado aparte para otros usos,
  pero el backend de NetworkManager queda en wpa_supplicant).
- Disk config: **usar el particionado manual que ya armaste** (no dejes que
  archinstall reparticione), apuntando root a `@`, home a `@home`, etc. con
  los mountpoints de arriba.
- Timezone/locale/hostname/usuario: a gusto.

Cuando termine, **no reinicies todavía**.

## 5. BUG CRÍTICO: archinstall deja mkinitcpio en modo UKI

Aunque elegiste GRUB como bootloader, `archinstall` configura los presets
de mkinitcpio para generar **UKIs** (Unified Kernel Images) en vez de la
imagen `initramfs-*.img` clásica que GRUB espera encontrar en `/boot`. El
resultado: GRUB arranca, pero no encuentra el kernel/initramfs y **el
sistema no bootea**. Esto costó horas de debugging — no te lo saltees.

Todavía en el chroot de archinstall (o hacé `arch-chroot /mnt` si ya
saliste):

```
arch-chroot /mnt

for preset in /etc/mkinitcpio.d/*.preset; do
    sed -i 's/^default_uki=/#default_uki=/' "$preset"
    sed -i 's/^#default_image=/default_image=/' "$preset"
done

# confirmá que quedó así en AMBOS presets (linux.preset y linux-lts.preset):
#   default_image="/boot/initramfs-linux.img"      (sin #)
#   #default_uki="/boot/EFI/Linux/arch-linux.efi"  (comentado)
grep -H "default_" /etc/mkinitcpio.d/*.preset

mkinitcpio -P

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
```

Sin este paso, no hay GRUB que arranque nada.

## 6. Entrada manual de Windows en GRUB

`os-prober` **falla dentro del chroot** (no puede montar/inspeccionar la
partición de Windows desde ahí), así que la entrada de Windows en el menú
de GRUB hay que escribirla a mano. Conseguí el UUID de la ESP de Windows
(la partición vfat pequeña, ~200M, la que **no** creaste vos):

```
blkid | grep -i "vfat"
# ejemplo real de esta maquina: UUID="36B8-A13C" para /dev/nvme0n1p1
```

Editá `/etc/grub.d/40_custom`:

```sh
#!/bin/sh
exec tail -n +3 $0
menuentry "Windows 11" --class windows {
insmod part_gpt
insmod fat
insmod chain
search --no-floppy --fs-uuid --set=root 36B8-A13C
chainloader /EFI/Microsoft/Boot/bootmgfw.efi
}
```

Puntos que rompen esto si te los salteás:

- La llave `{` del `menuentry` va **en la misma línea**, no en la línea
  siguiente (a diferencia de como uno escribiría bash normalmente) — GRUB
  usa su propio parser de config y con la llave en otra línea no reconoce
  el bloque.
- `chmod +x /etc/grub.d/40_custom` — sin el bit de ejecución,
  `grub-mkconfig` lo ignora en silencio (no da error, simplemente no
  aparece la entrada).
- Reemplazá `36B8-A13C` por el UUID real que te dio `blkid` en tu
  instalación — el de acá es el de referencia de esta máquina, no un
  placeholder genérico.

Después de esto:

```
grub-mkconfig -o /boot/grub/grub.cfg
exit        # salir del chroot
umount -R /mnt
reboot
```

## 7. Primer arranque

Sacá el pendrive, arrancá. Deberías ver GRUB con **Arch Linux**, **Arch
Linux (linux-lts fallback si algo falla)**, y **Windows 11**. Entrá a
Arch, logueate por TTY (todavía no hay nada gráfico) y confirmá que tenés
red:

```
ping -c1 archlinux.org
```

Si no hay red, `nmcli device wifi connect "SSID" password "clave"`
(NetworkManager ya debería estar activo desde archinstall).

## 8. Clonar este repo y correr install.sh

```
git clone <url-de-este-repo> ~/arch-setup
cd ~/arch-setup
./install.sh
```

Te va a pedir confirmación antes de cada módulo (`--yes` si preferís que no
pregunte nada y volver más tarde). `./install.sh --list` te muestra qué
quedó pendiente si lo cortás a mitad de camino. Al final imprime un
checklist de lo que sigue siendo manual (Proton-GE, restaurar `~/vpn/`,
probar suspend/hibernate).
