"""Draws the macOS DMG window background: VesperTV black + gold.

Reuses assets/icon/gen_icon.py (horizon-glow background, gold V + star mark,
gold gradient) so the installer matches the app icon. Writes background.png
(660x400, the Finder window size) and background@2x.png (Retina); build.sh
combines the pair into one HiDPI TIFF (tiffutil).

Run from the repo root:  python tools/macos_dmg/make_background.py <out dir>
Coordinates here must match build.sh (window size, icon positions).
"""
import importlib.util
import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "gen_icon", os.path.join(HERE, "..", "..", "assets", "icon", "gen_icon.py"))
gen_icon = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(gen_icon)

W, H = 660, 400          # Finder window content size (points)
APP_X, APPS_X = 170, 490  # icon centres, see build.sh
ICON_Y = 228

FONTS = [
    ("/System/Library/Fonts/Avenir Next.ttc", 2),     # Demi Bold
    ("/System/Library/Fonts/HelveticaNeue.ttc", 1),   # Bold
    ("/System/Library/Fonts/Helvetica.ttc", 1),
]


def font(size):
    for path, index in FONTS:
        try:
            return ImageFont.truetype(path, size, index=index)
        except OSError:
            continue
    return ImageFont.load_default()


def gold_text(img, xy_center, text, size, top=(255, 236, 170), bot=(222, 160, 40)):
    f = font(size)
    d = ImageDraw.Draw(img)
    l, t, r, b = d.textbbox((0, 0), text, font=f)
    tw, th = r - l, b - t
    mask = Image.new("L", (tw + 8, th + 8), 0)
    ImageDraw.Draw(mask).text((4 - l, 4 - t), text, font=f, fill=255)
    grad = gen_icon.gold_gradient(mask.size, top=top, bot=bot)
    x = int(xy_center[0] - mask.size[0] / 2)
    y = int(xy_center[1] - mask.size[1] / 2)
    img.paste(grad, (x, y), mask)


def plain_text(img, xy_center, text, size, fill):
    f = font(size)
    d = ImageDraw.Draw(img)
    d.text(xy_center, text, font=f, fill=fill, anchor="mm")


def draw(scale):
    w, h = W * scale, H * scale
    s = lambda v: int(round(v * scale))  # noqa: E731
    img = gen_icon.background(w=w, h=h).convert("RGBA")

    # A few faint stars in the dark upper sky (fixed seed: reproducible).
    rnd = random.Random(1760256)
    sky = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sky)
    for _ in range(70):
        x, y = rnd.uniform(0, w), rnd.uniform(0, h * 0.55)
        r = rnd.uniform(0.4, 1.3) * scale
        a = int(rnd.uniform(40, 150))
        sd.ellipse((x - r, y - r, x + r, y + r), fill=(255, 236, 190, a))
    img.alpha_composite(sky)

    # Mark + wordmark, top centre.
    m = gen_icon.mark(scale=1.0, size=s(78))
    img.alpha_composite(m, (s(W / 2 - 39 - 92), s(26)))
    gold_text(img, (s(W / 2 + 40), s(66)), "VesperTV", s(42))

    # Gold "shelf" the icons sit on. Finder draws icon labels black in light
    # mode and white in dark mode: a mid-tone warm band keeps both readable.
    shelf = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(shelf).rounded_rectangle(
        (s(48), s(ICON_Y - 92), s(W - 48), s(ICON_Y + 98)),
        radius=s(28), fill=(150, 112, 52, 150))
    shelf = shelf.filter(ImageFilter.GaussianBlur(s(1.2)))
    img.alpha_composite(shelf)
    rim = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(rim).rounded_rectangle(
        (s(48), s(ICON_Y - 92), s(W - 48), s(ICON_Y + 98)),
        radius=s(28), outline=(255, 214, 120, 170), width=max(1, s(1.5)))
    img.alpha_composite(rim)

    # Arrow from the app to Applications.
    arrow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ad = ImageDraw.Draw(arrow)
    x0, x1, y = s(APP_X + 82), s(APPS_X - 82), s(ICON_Y - 8)
    ad.line((x0, y, x1 - s(14), y), fill=(255, 226, 140, 235), width=s(5))
    ad.polygon([(x1, y), (x1 - s(20), y - s(13)), (x1 - s(20), y + s(13))],
               fill=(255, 226, 140, 235))
    glow = arrow.filter(ImageFilter.GaussianBlur(s(4)))
    img.alpha_composite(glow)
    img.alpha_composite(arrow)

    # Hints under the shelf.
    plain_text(img, (s(W / 2), s(352)), "Drag VesperTV to Applications to install",
               s(15), (255, 236, 200, 235))
    plain_text(img, (s(W / 2), s(376)),
               "Unsigned build: if macOS blocks it, System Settings > Privacy & Security > Open Anyway",
               s(11), (230, 205, 160, 190))
    return img.convert("RGB")


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    os.makedirs(out, exist_ok=True)
    draw(1).save(os.path.join(out, "background.png"), dpi=(72, 72))
    draw(2).save(os.path.join(out, "background@2x.png"), dpi=(144, 144))


if __name__ == "__main__":
    main()
