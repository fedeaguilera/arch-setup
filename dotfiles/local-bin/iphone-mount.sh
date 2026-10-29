#!/usr/bin/env bash
# Mounts the iPhone's storage (AFC: DCIM with the photos) when it is plugged in.
# The "iPhone" gphoto2 entry Nautilus shows on its own often comes up empty,
# so this mounts afc://<udid>/ instead, which appears as "iPhone de ..." in Nautilus.

APPLE=05ac

mount_iphones() {
    # Retries for up to 2 minutes: a locked or untrusted iPhone refuses access
    local warned=0
    for _ in $(seq 60); do
        local udids
        udids=$(idevice_id -l 2>/dev/null)
        [ -z "$udids" ] && { sleep 2; continue; }
        local pending=0
        for udid in $udids; do
            gio mount -l | grep -q "afc://$udid/" && continue
            if idevicepair validate -u "$udid" >/dev/null 2>&1 && gio mount "afc://$udid/" 2>/dev/null; then
                echo "mounted $udid"
            else
                pending=1
                if (( !warned )); then
                    notify-send -i phone "iPhone" "Desbloquealo y tocá «Confiar» para ver las fotos"
                    warned=1
                fi
            fi
        done
        (( pending )) || return 0
        sleep 2
    done
}

# Already plugged in when the service starts
mount_iphones &

stdbuf -oL udevadm monitor --udev --property --subsystem-match=usb | while read -r line; do
    case "$line" in
        ACTION=*)       action=${line#ACTION=} ;;
        DEVTYPE=*)      devtype=${line#DEVTYPE=} ;;
        ID_VENDOR_ID=*) vendor=${line#ID_VENDOR_ID=} ;;
        "")
            # End of an event block
            if [ "$action" = add ] && [ "$devtype" = usb_device ] && [ "$vendor" = $APPLE ]; then
                # Give usbmuxd a moment to pick up the device
                (sleep 2; mount_iphones) &
            fi
            action=; devtype=; vendor=
            ;;
    esac
done
