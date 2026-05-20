#!/bin/bash
yay -S dunst fastfetch fish hyprland ncspot neovim rofi waybar yazi ghostty

set -e

CONFIG_DIR="$HOME/.config"

mkdir -p "$CONFIG_DIR"

cp -r dunst fastfetch fish ghostty hypr ncmpcpp nvim rofi waybar yazi "$CONFIG_DIR/"
