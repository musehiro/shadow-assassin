#!/usr/bin/env python3
"""Generate v6 art for Shadow Assassin (PIL, drawn from scratch):
- art/bms_splash.png  (720x1280)  — BMS boot splash: big bold BMS letters,
  colourful, matching the homepage look (purple/teal gradient, gold trim).
  Replaces the Godot logo at launch (Buddhika, 2026-11-21).
- art/guide_kill_1.png (940x520) — HOW TO KILL guide picture: kill from
  behind = GOOD, face to face = YOU DIE.
- art/guide_kill_2.png (940x520) — TWO GUARDS TOGETHER guide picture:
  wait in a bush until they split up / shoot one from far away.
All sprites composited from the game's own art (player/guard/bush/gun).
Supersampled 2x then downscaled for crisp AA.
"""
import math
import os
import random
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.join(HERE, "..", "art")
FONT_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

SS = 2  # supersample factor


def font(size):
    return ImageFont.truetype(FONT_BOLD, int(size * SS))


def load(name, size=None):
    im = Image.open(os.path.join(ART, name)).convert("RGBA")
    if size is not None:
        im = im.resize((int(size[0] * SS), int(size[1] * SS)), Image.LANCZOS)
    return im


def vgrad(w, h, top, bottom):
    img = Image.new("RGBA", (w * SS, h * SS))
    d = ImageDraw.Draw(img)
    for y in range(h * SS):
        t = y / (h * SS)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        d.line([(0, y), (w * SS, y)], fill=c + (255,))
    return img


def text_center(d, cx, y, s, fnt, fill, stroke=0, stroke_fill=(0, 0, 0, 255)):
    bbox = d.textbbox((0, 0), s, font=fnt)
    w = bbox[2] - bbox[0]
    d.text((cx - w / 2 - bbox[0], y), s, font=fnt, fill=fill,
           stroke_width=int(stroke * SS), stroke_fill=stroke_fill)
    return bbox[3] - bbox[1]


def gold_frame(d, w, h, inset=22, width=6, color=(255, 204, 64, 170)):
    d.rounded_rectangle([inset * SS, inset * SS, (w - inset) * SS, (h - inset) * SS],
                        radius=28 * SS, outline=color, width=int(width * SS))


def scatter(d, img, w, h, n_coin=10, n_gem=6, seed=7, alpha=90):
    rng = random.Random(seed)
    for _ in range(n_coin):
        s = load("coin.png", (46, 46))
        a = s.copy()
        a.putalpha(a.split()[3].point(lambda v: v * alpha // 255))
        img.paste(a, (int(rng.randrange(30, w - 76) * SS), int(rng.randrange(90, h - 76) * SS)), a)
    for i in range(n_gem):
        s = load(["gem_cyan.png", "gem_pink.png", "gem_purple.png"][i % 3], (40, 40))
        a = s.copy()
        a.putalpha(a.split()[3].point(lambda v: v * alpha // 255))
        img.paste(a, (int(rng.randrange(30, w - 70) * SS), int(rng.randrange(90, h - 70) * SS)), a)


def save(img, name, size):
    img = img.resize(size, Image.LANCZOS)
    img.save(os.path.join(ART, name))
    print("wrote", name, size)


def check_circle(d, cx, cy, r, color):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color + (255,),
              outline=(255, 255, 255, 255), width=int(5 * SS))
    d.line([(cx - r * 0.45, cy), (cx - r * 0.1, cy + r * 0.4), (cx + r * 0.5, cy - r * 0.4)],
           fill=(255, 255, 255, 255), width=int(9 * SS), joint="curve")


def cross_circle(d, cx, cy, r, color):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color + (255,),
              outline=(255, 255, 255, 255), width=int(5 * SS))
    o = r * 0.45
    d.line([(cx - o, cy - o), (cx + o, cy + o)], fill=(255, 255, 255, 255), width=int(9 * SS))
    d.line([(cx - o, cy + o), (cx + o, cy - o)], fill=(255, 255, 255, 255), width=int(9 * SS))


def floor_tiles(d, x0, y0, x1, y1, tile=68):
    light = (196, 198, 205, 255)
    dark = (168, 171, 180, 255)
    for yy in range(int(y0), int(y1), tile):
        for xx in range(int(x0), int(x1), tile):
            c = light if ((xx - x0) // tile + (yy - y0) // tile) % 2 == 0 else dark
            d.rectangle([xx * SS, yy * SS, min((xx + tile), x1) * SS, min((yy + tile), y1) * SS], fill=c)


def vision_cone(d, apex, direction, length=150, half_angle=0.6, color=(255, 255, 255, 90)):
    # A soft vision cone fanning out from the guard, like the in-game
    # white cones. direction: unit vector the guard is looking.
    import math as _m
    base_ang = _m.atan2(direction[1], direction[0])
    pts = [apex]
    for i in range(9):
        a = base_ang - half_angle + (2 * half_angle) * i / 8
        pts.append((apex[0] + _m.cos(a) * length, apex[1] + _m.sin(a) * length))
    d.polygon([(x * SS, y * SS) for x, y in pts], fill=color)


# ---------------------------------------------------------------- BMS splash
def make_splash():
    W, H = 720, 1280
    img = vgrad(W, H, (56, 26, 115), (5, 51, 56))
    d = ImageDraw.Draw(img)
    scatter(d, img, W, H)
    gold_frame(d, W, H)
    # The assassin himself, large, above the brand.
    hero = load("player.png", (300, 300))
    img.paste(hero, (int((W / 2 - 150) * SS), int(210 * SS)), hero)
    # BMS — big bold gold letters with a teal shadow + dark outline.
    f_big = font(250)
    d.text((W / 2 * SS, 560 * SS), "BMS", font=f_big, fill=(0, 190, 170, 255),
           anchor="ma", stroke_width=int(10 * SS), stroke_fill=(0, 120, 110, 255))
    d.text((W / 2 * SS, 548 * SS), "BMS", font=f_big, fill=(255, 205, 60, 255),
           anchor="ma", stroke_width=int(10 * SS), stroke_fill=(45, 12, 80, 255))
    # Subtitle.
    f_sub = font(58)
    d.text((W / 2 * SS, 830 * SS), "SHADOW ASSASSIN", font=f_sub,
           fill=(90, 240, 210, 255), anchor="ma",
           stroke_width=int(4 * SS), stroke_fill=(0, 0, 0, 255))
    d.line([(170 * SS, 920 * SS), (550 * SS, 920 * SS)], fill=(255, 205, 60, 220), width=int(4 * SS))
    # The tagline — the game's identity.
    f_tag = font(34)
    d.text((W / 2 * SS, 1100 * SS), "Think with your brain —", font=f_tag,
           fill=(255, 215, 90, 255), anchor="ma")
    d.text((W / 2 * SS, 1150 * SS), "or you die!", font=f_tag,
           fill=(255, 215, 90, 255), anchor="ma")
    save(img, "bms_splash.png", (W, H))


# ------------------------------------------------------- guide pictures
def scene_box(d, x0, y0, x1, y1, border):
    d.rounded_rectangle([x0 * SS, y0 * SS, x1 * SS, y1 * SS], radius=18 * SS,
                        outline=border + (255,), width=int(5 * SS))


def make_guide_1():
    W, H = 940, 520
    img = Image.new("RGBA", (W * SS, H * SS), (10, 45, 50, 255))
    d = ImageDraw.Draw(img)
    # LEFT — kill from behind = GOOD. The guard looks AWAY (white cone
    # points up, away from the player below) so the player can sneak in.
    scene_box(d, 16, 16, 462, 504, (60, 200, 90))
    f_t = font(44)
    d.text((239 * SS, 34 * SS), "GOOD", font=f_t, fill=(90, 230, 120, 255), anchor="ma")
    floor_tiles(d, 36, 110, 442, 420, tile=68)
    vision_cone(d, (239, 215), (0, -1), length=115, half_angle=0.45, color=(255, 255, 255, 85))
    guard = load("guard_orange.png", (120, 120))
    img.paste(guard, (int((239 - 60) * SS), int(150 * SS)), guard)
    player = load("player.png", (120, 120))
    img.paste(player, (int((239 - 60) * SS), int(290 * SS)), player)
    knife = load("icon_knife.png", (56, 56))
    img.paste(knife, (int((300) * SS), int(250 * SS)), knife)
    check_circle(d, 400 * SS, 380 * SS, 42, (40, 180, 80))
    d.text((239 * SS, 436 * SS), "from BEHIND", font=font(34), fill=(220, 240, 220, 255), anchor="ma")
    # RIGHT — face to face = YOU DIE. The guard's cone points DOWN at
    # the player: he sees you, he shoots, you die.
    scene_box(d, 478, 16, 924, 504, (220, 60, 60))
    d.text((701 * SS, 34 * SS), "YOU DIE", font=f_t, fill=(255, 90, 90, 255), anchor="ma")
    floor_tiles(d, 498, 110, 904, 420, tile=68)
    vision_cone(d, (701, 210), (0, 1), color=(255, 60, 60, 110))
    guard2 = load("guard_blue.png", (120, 120))
    img.paste(guard2, (int((701 - 60) * SS), int(150 * SS)), guard2)
    player2 = load("player.png", (120, 120))
    img.paste(player2, (int((701 - 60) * SS), int(290 * SS)), player2)
    cross_circle(d, 862 * SS, 380 * SS, 42, (200, 40, 40))
    d.text((701 * SS, 436 * SS), "face to FACE", font=font(34), fill=(240, 210, 210, 255), anchor="ma")
    save(img, "guide_kill_1.png", (W, H))


def make_guide_2():
    W, H = 940, 520
    img = Image.new("RGBA", (W * SS, H * SS), (10, 45, 50, 255))
    d = ImageDraw.Draw(img)
    # LEFT — WAIT: two guards together, hide in a bush until they split.
    scene_box(d, 16, 16, 462, 504, (60, 200, 90))
    f_t = font(44)
    d.text((239 * SS, 34 * SS), "WAIT", font=f_t, fill=(90, 230, 120, 255), anchor="ma")
    floor_tiles(d, 36, 110, 442, 420, tile=68)
    g1 = load("guard_orange.png", (110, 110))
    img.paste(g1, (int(150 * SS), int(150 * SS)), g1)
    g2 = load("guard_blue.png", (110, 110))
    img.paste(g2, (int(260 * SS), int(150 * SS)), g2)
    # dashed arrow: one guard walks away (they split up).
    for i in range(6):
        x = 330 + i * 16
        y = 205 - i * 4
        d.ellipse([(x - 6) * SS, (y - 6) * SS, (x + 6) * SS, (y + 6) * SS], fill=(255, 205, 60, 255))
    d.polygon([(420 * SS, 165 * SS), (420 * SS, 195 * SS), (446 * SS, 180 * SS)], fill=(255, 205, 60, 255))
    bush = load("bush.png", (150, 150))
    player = load("player.png", (90, 90))
    img.paste(bush, (int((70 - 75) * SS), int(300 * SS)), bush)
    # The assassin peeks out from behind the bush's right edge.
    img.paste(player, (int((140 - 45) * SS), int(320 * SS)), player)
    d.text((239 * SS, 436 * SS), "hide — they split up", font=font(32), fill=(220, 240, 220, 255), anchor="ma")
    # RIGHT — SHOOT: shoot one from far away with the gun.
    scene_box(d, 478, 16, 924, 504, (255, 205, 60))
    d.text((701 * SS, 34 * SS), "SHOOT", font=f_t, fill=(255, 205, 60, 255), anchor="ma")
    floor_tiles(d, 498, 110, 904, 420, tile=68)
    gun = load("icon_gun.png", (120, 120))
    img.paste(gun, (int((560 - 60) * SS), int(220 * SS)), gun)
    g3 = load("guard_orange.png", (120, 120))
    img.paste(g3, (int((790 - 60) * SS), int(220 * SS)), g3)
    d.line([(640 * SS, 280 * SS), (720 * SS, 280 * SS)], fill=(255, 220, 80, 255), width=int(8 * SS))
    for i, x in enumerate([660, 690, 720]):
        d.ellipse([(x - 7) * SS, (273) * SS, (x + 7) * SS, (287) * SS], fill=(255, 240, 150, 255))
    d.text((701 * SS, 436 * SS), "from FAR away", font=font(32), fill=(240, 230, 200, 255), anchor="ma")
    save(img, "guide_kill_2.png", (W, H))


if __name__ == "__main__":
    make_splash()
    make_guide_1()
    make_guide_2()
