#!/bin/bash
export XDG_MENU_PREFIX=batocera-
export XDG_CONFIG_DIRS=/etc/xdg
export XDG_CACHE_HOME=/tmp/xdg_cache

batocera-mouse show
pcmanfm /userdata
batocera-mouse hide
