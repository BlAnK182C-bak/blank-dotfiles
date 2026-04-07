#!/bin/bash

chosen=$(echo -e " Shutdown\n Reboot\n Logout\n Suspend" | rofi -dmenu -i -p "Power Menu")

case "$chosen" in
    " Shutdown") systemctl poweroff ;;
    " Reboot") systemctl reboot ;;
    " Logout") hyprctl dispatch exit ;;   # logout from Hyprland
    " Suspend") systemctl suspend ;;
esac
