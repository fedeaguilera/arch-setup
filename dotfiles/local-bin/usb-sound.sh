#!/usr/bin/env bash
# Plays a sound when a USB device (pendrive, mouse, phone...) is connected or removed.
# Listens to udev events; one physical device = one "usb_device" event.

ADD=$HOME/.local/share/sounds/usb/usb-connect.oga
REMOVE=$HOME/.local/share/sounds/usb/usb-disconnect.oga
last=0

stdbuf -oL udevadm monitor --udev --property --subsystem-match=usb | while read -r line; do
    case "$line" in
        ACTION=*)  action=${line#ACTION=} ;;
        DEVTYPE=*) devtype=${line#DEVTYPE=} ;;
        "")
            # End of an event block
            if [ "$devtype" = usb_device ] && [[ $action == add || $action == remove ]]; then
                now=$(date +%s)
                # Debounce: avoids a burst of sounds on resume from suspend
                if (( now - last >= 2 )); then
                    echo "usb $action"
                    case "$action" in
                        add)    paplay "$ADD" & ;;
                        remove) paplay "$REMOVE" & ;;
                    esac
                    last=$now
                fi
            fi
            action=; devtype=
            ;;
    esac
done
