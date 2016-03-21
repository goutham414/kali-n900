#!/bin/sh

if [ -f /run/console-setup/keymap_loaded ]; then
    rm /run/console-setup/keymap_loaded
    exit 0
fi
kbd_mode '-a' 
loadkeys '/etc/console-setup/cached_ISO-8859-15_del.kmap.gz' > '/dev/null' 
