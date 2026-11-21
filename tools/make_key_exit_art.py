#!/usr/bin/env python3
"""Generate key + exit art for Shadow Assassin (key/exit win condition).

New files only (art/key.png, art/exit.png) — drawn from scratch with PIL,
same 128px supersampled style as tools/make_art.py. No existing art touched.
- key.png: chunky gold key (ring + shaft + teeth), transparent background.
- exit.png: bright-green glowing exit tile with a white arrow + EXIT text,
  deliberately unlike any other board tile so it reads at a glance.
"""
import math
import os
from PIL import Image, ImageDraw, ImageFont

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art")
os.makedirs(OUT, exist_ok=True)
SS = 4
SIZE = 128
BIG = SIZE * SS


def canvas():
    return Image.new("RGBA", (BIG, BIG), (0, 0, 0, 0))


def save(img, name):
    img = img.resize((SIZE, SIZE), Image.LANCZOS)
    img.save(os.path.join(OUT, name))
    print("wrote", name)


def font(sz):
    try:
        return ImageFont.truetype("DejaVuSans-Bold.ttf", sz)
    except OSError:
        return ImageFont.load_default()


def key():
    img = canvas()
    d = ImageDraw.Draw(img, "RGBA")
    cx, cy = BIG / 2, BIG / 2
    gold = (242, 183, 5)
    gold_dark = (176, 118, 0)
    gold_light = (255, 217, 92)
    # soft glow halo behind the key
    d.ellipse([cx - 78 * SS, cy - 78 * SS, cx + 78 * SS, cy + 78 * SS],
              fill=(255, 210, 60, 60))
    # ring (bow) at top-left, shaft diagonal down-right
    d.ellipse([cx - 88 * SS, cy - 88 * SS, cx - 8 * SS, cy - 8 * SS],
              outline=gold, width=16 * SS)
    d.ellipse([cx - 88 * SS, cy - 88 * SS, cx - 8 * SS, cy - 8 * SS],
              outline=gold_dark, width=4 * SS)
    d.ellipse([cx - 66 * SS, cy - 66 * SS, cx - 30 * SS, cy - 30 * SS],
              outline=gold_dark, width=3 * SS)
    # shaft: thick gold bar from ring to bottom-right
    d.line([cx - 30 * SS, cy - 30 * SS, cx + 74 * SS, cy + 74 * SS],
           fill=gold_dark, width=20 * SS)
    d.line([cx - 30 * SS, cy - 30 * SS, cx + 74 * SS, cy + 74 * SS],
           fill=gold, width=13 * SS)
    d.line([cx - 30 * SS, cy - 32 * SS, cx + 72 * SS, cy + 70 * SS],
           fill=gold_light, width=4 * SS)
    # teeth (two notches near the tip, on the lower side of the shaft)
    d.line([cx + 44 * SS, cy + 52 * SS, cx + 30 * SS, cy + 82 * SS],
           fill=gold_dark, width=12 * SS)
    d.line([cx + 44 * SS, cy + 52 * SS, cx + 30 * SS, cy + 82 * SS],
           fill=gold, width=8 * SS)
    d.line([cx + 66 * SS, cy + 74 * SS, cx + 56 * SS, cy + 96 * SS],
           fill=gold_dark, width=12 * SS)
    d.line([cx + 66 * SS, cy + 74 * SS, cx + 56 * SS, cy + 96 * SS],
           fill=gold, width=8 * SS)
    # sparkle
    for (x, y, r) in [(cx - 58 * SS, cy - 58 * SS, 10 * SS),
                      (cx + 10 * SS, cy + 30 * SS, 7 * SS)]:
        d.polygon([(x, y - r), (x + r // 3, y - r // 3), (x + r, y),
                   (x + r // 3, y + r // 3), (x, y + r),
                   (x - r // 3, y + r // 3), (x - r, y),
                   (x - r // 3, y - r // 3)], fill=(255, 255, 255, 230))
    return img


def exit_tile():
    img = canvas()
    d = ImageDraw.Draw(img, "RGBA")
    # full-bleed bright green tile: unmistakable on the board
    d.rounded_rectangle([2 * SS, 2 * SS, BIG - 2 * SS, BIG - 2 * SS],
                        radius=14 * SS, fill=(28, 200, 80))
    d.rounded_rectangle([10 * SS, 10 * SS, BIG - 10 * SS, BIG - 10 * SS],
                        radius=10 * SS, outline=(190, 255, 200), width=5 * SS)
    d.rounded_rectangle([20 * SS, 20 * SS, BIG - 20 * SS, BIG - 20 * SS],
                        radius=8 * SS, fill=(64, 224, 110))
    # white arrow pointing up (the way out) + EXIT text
    cx = BIG / 2
    d.polygon([(cx, 34 * SS), (cx + 26 * SS, 66 * SS), (cx + 10 * SS, 66 * SS),
               (cx + 10 * SS, 92 * SS), (cx - 10 * SS, 92 * SS),
               (cx - 10 * SS, 66 * SS), (cx - 26 * SS, 66 * SS)],
              fill=(255, 255, 255))
    d.polygon([(cx, 34 * SS), (cx + 26 * SS, 66 * SS), (cx + 10 * SS, 66 * SS),
               (cx + 10 * SS, 92 * SS), (cx - 10 * SS, 92 * SS),
               (cx - 10 * SS, 66 * SS), (cx - 26 * SS, 66 * SS)],
              outline=(16, 120, 48), width=3 * SS)
    f = font(30 * SS)
    d.text((cx, BIG - 34 * SS), "EXIT", fill=(255, 255, 255), font=f,
           anchor="mm", stroke_width=4 * SS, stroke_fill=(16, 120, 48))
    return img


save(key(), "key.png")
save(exit_tile(), "exit.png")
print("done")
