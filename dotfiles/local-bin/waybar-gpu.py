#!/usr/bin/env python3
# Modulo de waybar: uso de la iGPU AMD y estado de la dGPU NVIDIA.
# A la NVIDIA no se le consulta nada (nvidia-smi la despertaria y no la dejaria
# volver a dormir): solo se lee su estado de energia en sysfs.
import json
import os

DRM = "/sys/class/drm"


def card(link):
    # Symlinks de udev estables (/dev/dri/gpu-igpu, gpu-dgpu): cardN cambia entre boots
    return os.path.join(DRM, os.path.basename(os.readlink(link)), "device")


def read(path, default=None):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return default


igpu = card("/dev/dri/gpu-igpu")
dgpu = card("/dev/dri/gpu-dgpu")

busy = int(read(f"{igpu}/gpu_busy_percent", "0"))
vram_used = int(read(f"{igpu}/mem_info_vram_used", "0")) / 2**30
vram_total = int(read(f"{igpu}/mem_info_vram_total", "0")) / 2**30
nvidia_on = read(f"{dgpu}/power/runtime_status") == "active"

tooltip = [f"AMD (integrada): {busy}%  ·  VRAM {vram_used:.1f} / {vram_total:.1f} GiB"]
tooltip.append("NVIDIA: ACTIVA" if nvidia_on else "NVIDIA: dormida")

print(json.dumps({
    "text": f"󰢮  {busy}%" + ("  NV" if nvidia_on else ""),
    "tooltip": "\n".join(tooltip),
    "class": "dgpu" if nvidia_on else "igpu",
    "percentage": busy,
}))
