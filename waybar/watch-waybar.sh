#!/bin/bash

CONFIG="$HOME/.config/waybar/config.jsonc"
STYLE="$HOME/.config/waybar/style.css"

# Start Waybar if not already running
if ! pgrep -x "waybar" > /dev/null; then
    waybar &
fi

# Get initial checksums
checksum_config=$(md5sum "$CONFIG")
checksum_style=$(md5sum "$STYLE")

while true; do
    sleep 1
    new_checksum_config=$(md5sum "$CONFIG")
    new_checksum_style=$(md5sum "$STYLE")

    if [[ "$checksum_config" != "$new_checksum_config" ]] || [[ "$checksum_style" != "$new_checksum_style" ]]; then
        killall waybar
        waybar &
        checksum_config=$new_checksum_config
        checksum_style=$new_checksum_style
    fi
done
