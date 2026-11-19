#!/usr/bin/env python3
"""Draws the Quill app icon (app/resources/Quill.iconset). Requires Pillow."""
import math
import os
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "app", "resources", "Quill.iconset")
S = 1024


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def rounded_mask(size, box, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle(box, radius=radius, fill=255)
    return m


def draw():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    # Shadow
    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((100, 118, 924, 942), radius=185, fill=(0, 0, 0, 110))
    shadow = shadow.filter(ImageFilter.GaussianBlur(18))
    img.alpha_composite(shadow)
    # Background gradient squircle
    bg = Image.new("RGBA", (S, S))
    top, bottom = (58, 76, 202), (24, 136, 229)
    px = bg.load()
    for y in range(S):
        c = lerp(top, bottom, y / S)
        for x in range(S):
            px[x, y] = c + (255,)
    img.paste(bg, (0, 0), rounded_mask((S, S), (100, 100, 924, 924), 185))
    d = ImageDraw.Draw(img)
    # Paper
    paper = [(300, 230), (640, 230), (740, 330), (740, 800), (300, 800)]
    d.polygon(paper, fill=(250, 251, 255, 255))
    d.polygon([(640, 230), (640, 330), (740, 330)], fill=(205, 214, 240, 255))
    # Code lines
    colors = [(171, 71, 188), (30, 136, 229), (67, 160, 71), (239, 108, 0), (30, 136, 229), (120, 120, 140)]
    widths = [260, 330, 210, 300, 180, 240]
    indents = [0, 40, 40, 80, 40, 0]
    for i, (c, w, ind) in enumerate(zip(colors, widths, indents)):
        y = 380 + i * 62
        d.rounded_rectangle((350 + ind, y, 350 + ind + w, y + 26), radius=13, fill=c + (255,))
    # Quill feather (rotated ellipse + spine)
    feather = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    fd = ImageDraw.Draw(feather)
    fd.ellipse((420, 120, 600, 700), fill=(255, 196, 0, 255))
    fd.ellipse((470, 140, 600, 680), fill=(255, 221, 87, 255))
    fd.line((512, 140, 512, 900), fill=(120, 72, 0, 255), width=14)
    for k in range(9):
        y = 250 + k * 50
        fd.line((512, y, 440 + (k % 2) * 8, y - 40), fill=(230, 160, 0, 255), width=6)
    feather = feather.rotate(-35, resample=Image.BICUBIC, center=(512, 512))
    feather = feather.transform((S, S), Image.AFFINE, (1, 0, -150, 0, 1, 40), resample=Image.BICUBIC)
    img.alpha_composite(feather)
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    big = draw()
    for base in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            px = base * scale
            name = "icon_%dx%d%s.png" % (base, base, "@2x" if scale == 2 else "")
            big.resize((px, px), Image.LANCZOS).save(os.path.join(OUT, name))
    print("icon written to", OUT)


if __name__ == "__main__":
    main()
