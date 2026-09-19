#!/usr/bin/env bash

# Streams "add" / "remove" lines whenever a USB device is plugged or
# unplugged. Filters out the "bind"/"unbind" driver-attach noise udevadm
# also reports for the same physical event.

exec stdbuf -oL udevadm monitor --udev --subsystem-match=usb 2>/dev/null | \
    stdbuf -oL awk '
        /^UDEV/ {
            for (i = 1; i <= NF; i++) {
                if ($i == "add") { print "add"; fflush(); break }
                if ($i == "remove") { print "remove"; fflush(); break }
            }
        }
    '
