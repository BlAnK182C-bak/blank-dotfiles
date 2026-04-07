#!/usr/bin/env bash
# Dynamic theme: pick shuffled wallpaper, support GIF/video, derive colors for Hyprland ecosystem.

set -e

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
HYPR_DIR="$CONFIG_DIR/hypr"
WAYBAR_DIR="$CONFIG_DIR/waybar"
ROFI_DIR="$CONFIG_DIR/rofi"
DUNST_DIR="$CONFIG_DIR/dunst"
WALLPAPER_DIR="${WALLPAPER_DIR:-~/.config/wallpapers/}"
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
EXTRACT_PY="$SCRIPT_DIR/extract-theme-colors.py"

if [[ ! -d "$WALLPAPER_DIR" ]]; then
  echo "Wallpaper dir not found: $WALLPAPER_DIR" >&2
  exit 1
fi

# ── Collect wallpapers ───────────────────────────────────────────────────────
shopt -s nullglob
files=("$WALLPAPER_DIR"/*.{png,jpg,jpeg,gif,mp4,webm})
shopt -u nullglob

n=${#files[@]}
if [[ $n -eq 0 ]]; then
  echo "No images in $WALLPAPER_DIR" >&2
  exit 1
fi

# ── Shuffle system (no repeats until cycle ends) ─────────────────────────────
shuffle_file="/tmp/hyprpaper-wallpaper-shuffle"
index_file="/tmp/hyprpaper-wallpaper-index"

if [[ ! -f "$shuffle_file" ]]; then
  printf "%s\n" "${files[@]}" | shuf >"$shuffle_file"
  echo 0 >"$index_file"
fi

mapfile -t shuffled <"$shuffle_file"
index=$(cat "$index_file")

if ((index >= ${#shuffled[@]})); then
  printf "%s\n" "${files[@]}" | shuf >"$shuffle_file"
  mapfile -t shuffled <"$shuffle_file"
  index=0
fi

wallpaper="${shuffled[$index]}"
echo $((index + 1)) >"$index_file"

# ── Extract colors from wallpaper ────────────────────────────────────────────
if [[ ! -x "$EXTRACT_PY" ]]; then
  chmod +x "$EXTRACT_PY" 2>/dev/null || true
fi

out=$(python3 "$EXTRACT_PY" "$wallpaper") || exit 1

# ✅ Read extracted colors
read -r dom_hue avg_luminance accent_hex inact_hex btn_hex active_border_hex inactive_border_hex bg_hex <<<"$out"

# ── DEBUG: print avg_luminance ───────────────────────────────────────────────
echo "DEBUG: avg_luminance=$avg_luminance"

# ── Derive UI colors ──────────────────────────────────────────────────────────
read -r btn_hover_hex cal_days_hex cal_wd_hex \
  battery_warn_hex battery_crit_hex battery_charge_hex <<EOF
$(
    python3 - "$btn_hex" "$inact_hex" "$dom_hue" "$avg_luminance" <<'PYEOF'
import sys, colorsys

def h2r(h):
    h = h.lstrip('#')
    return int(h[0:2],16), int(h[2:4],16), int(h[4:6],16)

def r2h(r,g,b):
    return f"{min(255,int(r)):02x}{min(255,int(g)):02x}{min(255,int(b)):02x}"

def lighten(h, f):
    r,g,b = h2r(h)
    return r2h(r+(255-r)*f, g+(255-g)*f, b+(255-b)*f)

def blend(h1, h2, t):
    r1,g1,b1 = h2r(h1); r2,g2,b2 = h2r(h2)
    return r2h(r1*(1-t)+r2*t, g1*(1-t)+g2*t, b1*(1-t)+b2*t)

def hsl2hex(h, s, l):
    h = h / 360.0
    r,g,b = colorsys.hls_to_rgb(h, l, s)
    return r2h(r*255, g*255, b*255)

btn, inact = sys.argv[1], sys.argv[2]
dom_hue = float(sys.argv[3])
luminance = float(sys.argv[4])
is_dark = luminance < 0.5

btn_hover = lighten(btn, 0.15)
cal_days = blend(btn, inact, 0.55)
cal_wd = lighten(btn, 0.08)

if is_dark:
    warn_l = 0.70
    crit_l = 0.62
    charge_l = 0.62
else:
    warn_l = 0.42
    crit_l = 0.45
    charge_l = 0.38

battery_warn = hsl2hex(48, 0.95, warn_l)
battery_crit = hsl2hex(4, 0.90, crit_l)
battery_charge = hsl2hex(122, 0.55, charge_l)

print(btn_hover, cal_days, cal_wd, battery_warn, battery_crit, battery_charge)
PYEOF
  )
EOF

# ── Wallpaper engine selection ────────────────────────────────────────────────
ext="${wallpaper##*.}"
ext="${ext,,}"

pkill -x hyprpaper 2>/dev/null || true
pkill -x mpvpaper 2>/dev/null || true

if [[ "$ext" == "gif" || "$ext" == "mp4" || "$ext" == "webm" ]]; then
  mpvpaper -o "loop" '*' "$wallpaper" &
  disown
else
  hyprpaper_conf="$HYPR_DIR/hyprpaper.conf"
  cat >"$hyprpaper_conf" <<EOF
wallpaper {
    monitor =
    path = $wallpaper
    fit_mode = cover
}
EOF
  hyprpaper &
  disown
fi

# ── Hyprland borders ──────────────────────────────────────────────────────────
hypr_conf="$HYPR_DIR/hyprland.conf"
sed -i "s/^[[:space:]]*col\.active_border[[:space:]]*=.*/ col.active_border = rgba(${active_border_hex}ee)/" "$hypr_conf"
sed -i "s/^[[:space:]]*col\.inactive_border[[:space:]]*=.*/ col.inactive_border = rgba(${inactive_border_hex}aa)/" "$hypr_conf"
hyprctl reload 2>/dev/null || true

# ── Waybar style.css ──────────────────────────────────────────────────────────
style_template="$WAYBAR_DIR/style.css.template"
style_css="$WAYBAR_DIR/style.css"

if [[ -f "$style_template" ]]; then
  sed \
    -e "s/THEME_ACCENT/#${accent_hex}/g" \
    -e "s/THEME_INACT/#${inact_hex}/g" \
    -e "s/THEME_BTN_HOVER/#${btn_hover_hex}/g" \
    -e "s/THEME_BTN/#${btn_hex}/g" \
    -e "s/THEME_BATTERY_WARN/#${battery_warn_hex}/g" \
    -e "s/THEME_BATTERY_CRIT/#${battery_crit_hex}/g" \
    -e "s/THEME_BATTERY_CHARGE/#${battery_charge_hex}/g" \
    "$style_template" >"$style_css"
fi

# ── Waybar config ─────────────────────────────────────────────────────────────
config_template="$WAYBAR_DIR/config.jsonc.template"
config_out="$WAYBAR_DIR/config.jsonc"

if [[ -f "$config_template" ]]; then
  sed \
    -e "s/THEME_ACCENT/#${accent_hex}/g" \
    -e "s/THEME_INACT/#${inact_hex}/g" \
    -e "s/THEME_CAL_DAYS/#${cal_days_hex}/g" \
    -e "s/THEME_CAL_WD/#${cal_wd_hex}/g" \
    -e "s/THEME_BTN_HOVER/#${btn_hover_hex}/g" \
    -e "s/THEME_BTN/#${btn_hex}/g" \
    "$config_template" >"$config_out"
fi

pkill -x waybar 2>/dev/null || true
waybar &
disown

# ── Rofi ──────────────────────────────────────────────────────────────────────
rofi_template="$ROFI_DIR/config.rasi.template"
rofi_config="$ROFI_DIR/config.rasi"

if [[ -f "$rofi_template" ]]; then
  cp "$rofi_template" "$rofi_config"
  sed -i \
    -e "s|THEME_INACTb3|#${inact_hex}b3|g" \
    -e "s|THEME_INACTc4|#${inact_hex}c4|g" \
    -e "s|THEME_INACT|#${inact_hex}|g" \
    -e "s|THEME_ACCENT|#${accent_hex}|g" \
    -e "s|THEME_BTN|#${btn_hex}|g" \
    -e "s|THEME_WALLPAPER|${wallpaper}|g" \
    "$rofi_config"
fi

# ── Dunst ─────────────────────────────────────────────────────────────────────
dunst_template="$DUNST_DIR/dunstrc.template"
dunst_config="$DUNST_DIR/dunstrc"

if [[ -f "$dunst_template" ]]; then
  mkdir -p "$DUNST_DIR"
  sed \
    -e "s/THEME_ACCENT/#${accent_hex}/g" \
    -e "s/THEME_INACT/#${inact_hex}/g" \
    -e "s/THEME_BTN/#${btn_hex}/g" \
    "$dunst_template" >"$dunst_config"
  pkill -x dunst 2>/dev/null || true
  dunst &
  disown
fi

# ── ncspot ────────────────────────────────────────────────────────────────────
NCSPOT_DIR="$CONFIG_DIR/ncspot"
ncspot_template="$NCSPOT_DIR/config.toml.template"
ncspot_config="$NCSPOT_DIR/config.toml"

if [[ -f "$ncspot_template" ]]; then
  sed \
    -e "s/THEME_ACCENT/${accent_hex}/g" \
    -e "s/THEME_INACT/${inact_hex}/g" \
    -e "s/THEME_BTN/${btn_hex}/g" \
    -e "s/THEME_BTN_HOVER/${btn_hover_hex}/g" \
    "$ncspot_template" >"$ncspot_config"
fi

# ── Alacritty ─────────────────────────────────────────────────────────────────
ALACRITTY_DIR="$CONFIG_DIR/alacritty"
alacritty_template="$ALACRITTY_DIR/alacritty.toml.template"
alacritty_config="$ALACRITTY_DIR/alacritty.toml"

if [[ -f "$alacritty_template" ]]; then
  sed \
    -e "s/THEME_ACCENT/#${accent_hex}/g" \
    -e "s/THEME_INACT/#${inact_hex}/g" \
    -e "s/THEME_BTN/#${btn_hex}/g" \
    "$alacritty_template" >"$alacritty_config"
fi

# ── Yazi ─────────────────────────────────────────────────────────────────────
YAZI_DIR="$CONFIG_DIR/yazi"
yazi_template="$YAZI_DIR/theme.toml.template"
yazi_theme="$YAZI_DIR/theme.toml"

if [[ -f "$yazi_template" ]]; then
  mkdir -p "$YAZI_DIR"
  sed \
    -e "s/THEME_ACCENT/#${accent_hex}/g" \
    -e "s/THEME_INACT/#${inact_hex}/g" \
    -e "s/THEME_BTN/#${btn_hex}/g" \
    -e "s/THEME_BTN_HOVER/#${btn_hover_hex}/g" \
    -e "s/THEME_BG/#${bg_hex}/g" \
    "$yazi_template" >"$yazi_theme"
fi

# ── LazyVim dynamic theme ───────────────────────────────────────────────────
NVIM_TEMPLATE="$HOME/.config/nvim/lua/plugins/theme.lua.template"
NVIM_OUT="$HOME/.config/nvim/lua/plugins/theme.lua"

if [[ -f "$NVIM_TEMPLATE" ]]; then
  # Ensure avg_luminance is passed as a number between 0 and 1
  sed \
    -e "s/{{AVG_LUMINANCE}}/${avg_luminance}/g" \
    -e "s/{{ACCENT_HEX}}/${accent_hex}/g" \
    -e "s/{{BG_HEX}}/${bg_hex}/g" \
    -e "s/{{BTN_HOVER_HEX}}/${btn_hover_hex}/g" \
    -e "s/{{INACT_HEX}}/${inact_hex}/g" \
    "$NVIM_TEMPLATE" >"$NVIM_OUT"
else
  echo "Warning: NVIM template missing at $NVIM_TEMPLATE"
fi

# ── ASCII mapping for fastfetch ──────────────────────────────────────────────
ASCII_DIR="$CONFIG_DIR/fastfetch/ascii-arts"
wall_base="$(basename "$wallpaper")"
ascii_file="$ASCII_DIR/cat.txt"

case "$wall_base" in
Berserk*) ascii_file="$ASCII_DIR/berserk.txt" ;;
CSM*) ascii_file="$ASCII_DIR/csm.txt" ;;
Deltarune*) ascii_file="$ASCII_DIR/deltarune.txt" ;;
EldenRing* | souls* | Bloodborne*) ascii_file="$ASCII_DIR/souls.txt" ;;
AoT*) ascii_file="$ASCII_DIR/survey_corps.txt" ;;
kny*) ascii_file="$ASCII_DIR/nezuko.txt" ;;
OnePiece*) ascii_file="$ASCII_DIR/one-piece.txt" ;;
NieR*) ascii_file="$ASCII_DIR/2b.txt" ;;
Portal*) ascii_file="$ASCII_DIR/portal.txt" ;;
TokyoGhoul*) ascii_file="$ASCII_DIR/tg.txt" ;;
VinlandSaga*) ascii_file="$ASCII_DIR/thorfinn.txt" ;;
TLoZ*) ascii_file="$ASCII_DIR/triforce.txt" ;;
*) ascii_file="$ASCII_DIR/cat.txt" ;;
esac

# ── Fastfetch ────────────────────────────────────────────────────────────────
FASTFETCH_DIR="$CONFIG_DIR/fastfetch"
FASTFETCH_TEMPLATE="$FASTFETCH_DIR/config.jsonc.template"
FASTFETCH_CONFIG="$FASTFETCH_DIR/config.jsonc"

if [[ -f "$FASTFETCH_TEMPLATE" ]]; then
  sed \
    -e "s|THEME_ASCII_PATH|${ascii_file}|g" \
    -e "s|THEME_ACCENT|#${accent_hex}|g" \
    -e "s|THEME_BTN|#${btn_hex}|g" \
    "$FASTFETCH_TEMPLATE" >"$FASTFETCH_CONFIG"
fi

# ── Final debug output ───────────────────────────────────────────────────────
echo "Theme set: wallpaper=$(basename "$wallpaper")"
echo "accent=#$accent_hex inact=#$inact_hex btn=#$btn_hex bg=#$bg_hex"
echo "btn_hover=#$btn_hover_hex cal_days=#$cal_days_hex cal_wd=#$cal_wd_hex"
echo "battery: warn=#$battery_warn_hex crit=#$battery_crit_hex charge=#$battery_charge_hex"
