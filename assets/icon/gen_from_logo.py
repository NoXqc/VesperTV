"""Builds VesperTV's launcher icons from the rendered gold logo
(assets/icon/logo_source.png, 1672x941: brushed-gold V + star, "VesperTV"
wordmark, dark warm backdrop). Owner, 2026-11-12: "use this nicer logo for
the app logo on OS home screens". Replaces gen_icon.py's drawn mark.

Run from the repo root:  python assets/icon/gen_from_logo.py
then:                    dart run flutter_launcher_icons

Writes icon_flat / icon_background / icon_foreground (1024 px) and
tv_banner (1280x720, the whole logo) into assets/icon, plus the Android TV
banner drawables.

The V + star is cut out by brightness (soft edge) and laid on a clean
square backdrop of the same colours with a rebuilt glow: a plain square
crop would cut into the wordmark.
"""
import numpy as np
from PIL import Image, ImageFilter

SRC = "assets/icon/logo_source.png"
N = 1024
# The V + star in the source (measured: x 343-723, y 303-626).
MARK = (300, 262, 768, 668)
# 16:9 around V + wordmark, ~88% of the width.
BANNER = (268, 104, 1556, 829)


def backdrop(w, h):
    """Near-black with the source's warm glow rising from the bottom."""
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    r = np.hypot((x - w * 0.5) / w, (y - h * 1.08) / h * 1.1) / 0.95
    t = np.clip(1 - r, 0, 1) ** 2.0
    base = np.stack([6 + 6 * y / h, 3 + 3 * y / h, np.zeros_like(y)], -1)
    glow = np.stack([t * 70, t * 36, t * 4], -1)
    return np.clip(base + glow, 0, 255)


def lifted_mark():
    """The mark as RGBA: alpha from brightness with a soft ramp (the gold
    is far brighter than the grainy backdrop), plus a soft gold glow
    rebuilt from that alpha. Subtracting an estimated backdrop kept its
    grain as a speckled square."""
    x0, y0, x1, y1 = MARK
    src = Image.open(SRC).convert("RGB").crop((x0, y0, x1, y1))
    rgb = np.asarray(src, dtype=np.float32)
    lum = rgb.max(axis=2)
    t = np.clip((lum - 80) / (135 - 80), 0, 1)
    alpha = t * t * (3 - 2 * t)
    # Halo: the source's warm glow, from the cut-out itself.
    halo = Image.fromarray((alpha * 255).astype(np.uint8)).filter(
        ImageFilter.GaussianBlur(14))
    halo = np.asarray(halo, dtype=np.float32) / 255 * 0.35
    return rgb, alpha, halo


def place(mark, size, fill):
    """[mark] scaled so its width = fill * size, centred: (rgb, alpha, halo)
    as size x size float arrays."""
    rgb, alpha, halo = mark
    h, w = alpha.shape
    scale = size * fill / w
    nw, nh = round(w * scale), round(h * scale)
    ox = (size - nw) // 2
    oy = (size - nh) // 2 + round(size * 0.01)

    def fit(a, mode):
        img = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), mode)
        return np.asarray(img.resize((nw, nh), Image.LANCZOS), dtype=np.float32)

    out_rgb = np.zeros((size, size, 3), np.float32)
    out_a = np.zeros((size, size), np.float32)
    out_h = np.zeros((size, size), np.float32)
    out_rgb[oy:oy + nh, ox:ox + nw] = fit(rgb, "RGB")
    out_a[oy:oy + nh, ox:ox + nw] = fit(alpha * 255, "L") / 255
    out_h[oy:oy + nh, ox:ox + nw] = fit(halo * 255, "L") / 255
    return out_rgb, out_a, out_h


GLOW = np.array([255, 170, 50], np.float32)


def composite(bg, placed):
    rgb, a, h = placed
    lit = bg + GLOW * h[..., None] * (1 - a[..., None])
    return np.clip(lit * (1 - a[..., None]) + rgb * a[..., None], 0, 255)


def main():
    mark = lifted_mark()
    bg = backdrop(N, N)
    Image.fromarray(bg.astype(np.uint8)).save("assets/icon/icon_background.png")

    # Legacy / iOS / Windows / macOS icon: the mark fills ~78% of the square.
    flat = composite(bg, place(mark, N, 0.78))
    Image.fromarray(flat.astype(np.uint8)).save("assets/icon/icon_flat.png")

    # Adaptive foreground: launchers mask to the centre ~66%, so the mark
    # sits at ~56%; transparent around it (halo as partial alpha).
    rgb, a, h = place(mark, N, 0.56)
    fa = np.clip(a + h * (1 - a), 0, 1)
    frgb = (rgb * a[..., None] + GLOW * (h * (1 - a))[..., None]) / np.maximum(fa, 1e-3)[..., None]
    fg = np.dstack([np.clip(frgb, 0, 255), fa * 255]).astype(np.uint8)
    Image.fromarray(fg, "RGBA").save("assets/icon/icon_foreground.png")

    # TV banner: the whole logo, cropped 16:9 around V + wordmark (x 343-
    # 1480, y 303-626) so it fills the launcher tile; the source's wide
    # empty margins made it small and dim on a box's home row (owner).
    ban = Image.open(SRC).convert("RGB").crop(BANNER).resize(
        (1280, 720), Image.LANCZOS)
    ban.save("assets/icon/tv_banner.png")
    for dens, (w, h) in {"mdpi": (160, 90), "hdpi": (240, 135), "xhdpi": (320, 180),
                         "xxhdpi": (480, 270), "xxxhdpi": (640, 360)}.items():
        path = f"android/app/src/main/res/drawable-{dens}/vespertv_banner.png"
        try:
            cur = Image.open(path).size
        except OSError:
            cur = (w, h)
        ban.resize(cur, Image.LANCZOS).save(path)


if __name__ == "__main__":
    main()
