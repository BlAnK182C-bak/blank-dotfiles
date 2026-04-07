#!/usr/bin/env bash
# battery-warn.sh — sends a dunst notification when battery is low
# Run via systemd user timer every 2 minutes

THRESHOLD=15
CRITICAL=5

# Get battery percentage and status
BATTERY=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null \
       || cat /sys/class/power_supply/BAT1/capacity 2>/dev/null \
       || echo 100)

STATUS=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null \
      || cat /sys/class/power_supply/BAT1/status 2>/dev/null \
      || echo "Unknown")

# Don't notify if charging or full
if [[ "$STATUS" == "Charging" || "$STATUS" == "Full" ]]; then
    exit 0
fi

# Use a lock file to avoid spamming — only notify once per discharge cycle
LOCK_FILE="/tmp/battery-warn-${BATTERY}.lock"

if [[ $BATTERY -le $CRITICAL ]]; then
    LOCK="/tmp/battery-warn-critical.lock"
    if [[ ! -f "$LOCK" ]]; then
        # Remove lower-threshold lock so it can re-notify if battery recovers
        rm -f /tmp/battery-warn-low.lock
        touch "$LOCK"
        notify-send \
            --urgency=critical \
            --icon=battery-caution \
            --app-name="Battery" \
            --hint=int:transient:0 \
            "⚠ Critical Battery" \
            "${BATTERY}% remaining — plug in now"
    fi
elif [[ $BATTERY -le $THRESHOLD ]]; then
    LOCK="/tmp/battery-warn-low.lock"
    if [[ ! -f "$LOCK" ]]; then
        touch "$LOCK"
        notify-send \
            --urgency=normal \
            --icon=battery-low \
            --app-name="Battery" \
            "󰂃 Low Battery" \
            "${BATTERY}% remaining"
    fi
else
    # Battery recovered above threshold — clear locks so next drop notifies again
    rm -f /tmp/battery-warn-low.lock /tmp/battery-warn-critical.lock
fi
