#!/usr/bin/env python3
"""
Extract theme colors from wallpaper.
Outputs:
HUE LUMINANCE ACCENT_HEX INACTIVE_HEX BTN_HEX ACTIVE_BORDER_HEX INACTIVE_BORDER_HEX BG_HEX
"""
import sys
import colorsys
from collections import Counter

try:
    from PIL import Image
except ImportError:
    sys.stderr.write("install Pillow: pip install Pillow\n")
    sys.exit(1)


def rgb_to_hsl(r, g, b):
    r, g, b = r / 255.0, g / 255.0, b / 255.0
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    return h * 360.0, s, l


def hsl_to_rgb(h, s, l):
    h = h / 360.0
    r, g, b = colorsys.hls_to_rgb(h, l, s)
    return int(r * 255), int(g * 255), int(b * 255)


def hex2(x):
    return format(int(x), "02x")


def to_hex(r, g, b):
    return f"{hex2(r)}{hex2(g)}{hex2(b)}"


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else sys.stdin.read().strip()
    if not path:
        sys.exit(1)

    try:
        img = Image.open(path).convert("RGB")
    except Exception as e:
        sys.stderr.write(f"open image: {e}\n")
        sys.exit(1)

    w, h = img.size
    step = max(1, int((w * h / 10000) ** 0.5))
    pixels = [
        img.getpixel((x, y))
        for y in range(0, h, step)
        for x in range(0, w, step)
    ]

    # ── Dominant hue: bin saturated pixels into 36 × 10° buckets ─────────────
    hue_bins = []
    luminances = []

    for (r, g, b) in pixels:
        hue, sat, lum = rgb_to_hsl(r, g, b)
        if 0.1 < lum < 0.9:
            luminances.append(lum)
        # Only count pixels with meaningful saturation for hue detection
        if sat > 0.15 and 0.1 < lum < 0.9:
            hue_bins.append(round(hue / 10) * 10 % 360)

    # fallback luminance
    if luminances:
        avg_luminance = sum(luminances) / len(luminances)
    else:
        avg_luminance = sum(
            rgb_to_hsl(r, g, b)[2] for (r, g, b) in pixels
        ) / len(pixels)

    # fallback hue
    if hue_bins:
        dom_hue = Counter(hue_bins).most_common(1)[0][0]
    else:
        r = sum(p[0] for p in pixels) / len(pixels)
        g = sum(p[1] for p in pixels) / len(pixels)
        b = sum(p[2] for p in pixels) / len(pixels)
        dom_hue, _, _ = rgb_to_hsl(r, g, b)

    # ── Always use dark theme; only go light for very bright wallpapers ───────
    # Raised threshold from 0.5 → 0.72 to strongly prefer dark mode
    is_dark = avg_luminance < 0.72

    if is_dark:
        # Dark theme — deep background, muted accent, subtle inactive
        bg_r, bg_g, bg_b = 13, 13, 13                              # #0d0d0d
        accent_r, accent_g, accent_b = hsl_to_rgb(dom_hue, 0.25, 0.82)
        inact_r, inact_g, inact_b = 30, 30, 30                     # #1e1e1e
        btn_r, btn_g, btn_b = hsl_to_rgb(dom_hue, 0.30, 0.40)
    else:
        # Light wallpaper — still keep UI dark for readability
        bg_r, bg_g, bg_b = 18, 18, 18                              # #121212
        accent_r, accent_g, accent_b = hsl_to_rgb(dom_hue, 0.30, 0.78)
        inact_r, inact_g, inact_b = 35, 35, 35                     # #232323
        btn_r, btn_g, btn_b = hsl_to_rgb(dom_hue, 0.30, 0.45)

    accent_hex = to_hex(accent_r, accent_g, accent_b)
    inact_hex  = to_hex(inact_r,  inact_g,  inact_b)
    btn_hex    = to_hex(btn_r,    btn_g,    btn_b)
    bg_hex     = to_hex(bg_r,     bg_g,     bg_b)

    def rel_luma(r, g, b):
        return 0.299 * r + 0.587 * g + 0.114 * b

    luma_acc   = rel_luma(accent_r, accent_g, accent_b)
    luma_inact = rel_luma(inact_r,  inact_g,  inact_b)

    if luma_acc >= luma_inact:
        active_border_hex, inactive_border_hex = accent_hex, inact_hex
    else:
        active_border_hex, inactive_border_hex = inact_hex, accent_hex

    print(
        f"{dom_hue:.0f} "
        f"{avg_luminance:.3f} "
        f"{accent_hex} "
        f"{inact_hex} "
        f"{btn_hex} "
        f"{active_border_hex} "
        f"{inactive_border_hex} "
        f"{bg_hex}"
    )


if __name__ == "__main__":
    main()
