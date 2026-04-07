#!/usr/bin/env bash
cache="$HOME/.config/waybar/quote.json"

if [[ ! -f "$cache" ]]; then
    echo '{"text": "You are filled with DETERMINATION.", "tooltip": ""}'
    exit 0
fi

quote=$(jq -r '.content' "$cache")
author=$(jq -r '.author' "$cache")

echo "{\"text\": \"\\\"${quote}\\\" — ${author}\", \"tooltip\": \"\"}"