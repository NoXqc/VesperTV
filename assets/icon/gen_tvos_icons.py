"""Builds the Apple TV app icon (layered, for the parallax effect) and the Top
Shelf images from VesperTV's gold logo (dev-notes/apple-tv.md).

Run from the repo root:  python assets/icon/gen_tvos_icons.py
(after gen_from_logo.py, which writes icon_foreground.png).

Writes into tvos/Runner/Assets.xcassets/AppIcon.brandassets:
- App Icon - Small (400x240, @2x) and Large (1280x768, App Store), each a
  Back layer (opaque warm backdrop), a Middle layer (soft gold glow) and a
  Front layer (the V + star);
- Top Shelf Image (1920x720) and Top Shelf Image Wide (2320x720), @2x too:
  the whole logo (V + wordmark) on the backdrop.
"""
import numpy as np
from PIL import Image, ImageFilter

ICON = "assets/icon"
OUT = "tvos/Runner/Assets.xcassets/AppIcon.brandassets"
SRC = f"{ICON}/logo_source.png"
# 16:9 around V + wordmark in logo_source.png (as gen_from_logo.py BANNER).
BANNER = (268, 104, 1556, 829)


def backdrop(w, h):
    """Near-black with a warm glow rising from the bottom (gen_from_logo.py)."""
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    r = np.hypot((x - w * 0.5) / w, (y - h * 1.08) / h * 1.1) / 0.95
    t = np.clip(1 - r, 0, 1) ** 2.0
    base = np.stack([6 + 6 * y / h, 3 + 3 * y / h, np.zeros_like(y)], -1)
    glow = np.stack([t * 70, t * 36, t * 4], -1)
    return Image.fromarray(np.clip(base + glow, 0, 255).astype(np.uint8), "RGB")


def mark():
    """The V + star alone, cropped to its pixels (RGBA)."""
    im = Image.open(f"{ICON}/icon_foreground.png").convert("RGBA")
    return im.crop(im.getbbox())


def centered(layer, w, h, height_share):
    """[layer] scaled to [height_share] of h, centred on a transparent w x h."""
    scale = h * height_share / layer.height
    size = (round(layer.width * scale), round(layer.height * scale))
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.alpha_composite(layer.resize(size, Image.LANCZOS),
                        ((w - size[0]) // 2, (h - size[1]) // 2))
    return out


def glow(front, w):
    """A soft gold halo behind the mark (Middle layer)."""
    a = front.getchannel("A").filter(ImageFilter.GaussianBlur(w / 40))
    a = a.point(lambda v: int(v * 0.55))
    g = Image.new("RGBA", front.size, (214, 160, 60, 0))
    g.putalpha(a)
    return g


def icon(prefix, w, h, folder):
    for scale, suffix in ((1, ""), (2, "@2x")):
        W, H = w * scale, h * scale
        front = centered(mark(), W, H, 0.62)
        layers = {
            "Back": backdrop(W, H),
            "Middle": glow(front, W),
            "Front": front,
        }
        for name, im in layers.items():
            path = (f"{OUT}/{folder}.imagestack/{name}.imagestacklayer/"
                    f"Content.imageset/{prefix}_{name.lower()}{suffix}.png")
            im.save(path)
            print(path, im.size)


def top_shelf(name, w, h, folder):
    logo = Image.open(SRC).convert("RGB").crop(BANNER)
    # Lift the logo off its own backdrop by brightness, like gen_from_logo.py.
    lum = np.asarray(logo.convert("L"), np.float32)
    alpha = np.clip((lum - 40) / 50, 0, 1) * 255
    logo = logo.convert("RGBA")
    logo.putalpha(Image.fromarray(alpha.astype(np.uint8), "L"))
    for scale, suffix in ((1, ""), (2, "@2x")):
        W, H = w * scale, h * scale
        out = backdrop(W, H).convert("RGBA")
        out.alpha_composite(centered(logo, W, H, 0.9))
        path = f"{OUT}/{folder}.imageset/{name}{suffix}.png"
        out.convert("RGB").save(path)
        print(path, out.size)


icon("small", 400, 240, "App Icon - Small")
icon("large", 1280, 768, "App Icon - Large")
top_shelf("top_shelf", 1920, 720, "Top Shelf Image")
top_shelf("top_shelf_wide", 2320, 720, "Top Shelf Image Wide")
