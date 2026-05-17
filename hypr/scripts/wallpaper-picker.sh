#!/usr/bin/env bash

WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers/Wallpapers}"
THEME_SCRIPT="$HOME/.config/hypr/scripts/set-dynamic-theme.sh"

selected=$(
    find "$WALLPAPER_DIR" -type f \
        \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.gif" \) |
        while read -r img; do
            printf "%s\0icon\x1f%s\n" "$(basename "$img")" "$img"
        done |
        rofi -dmenu \
            -show-icons \
            -theme-str 'window {width: 1200px;} listview {columns: 2; lines: 10;}'
)

[[ -z "$selected" ]] && exit 0

wallpaper=$(find "$WALLPAPER_DIR" -type f | grep "/$selected$" | head -n1)

"$THEME_SCRIPT" "$wallpaper"
