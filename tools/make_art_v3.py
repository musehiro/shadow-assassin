#!/usr/bin/env python3
"""Shadow Assassin v3 — BRIGHTER PALETTE + CHARACTER REDESIGN.

Regenerates the tile art (floor / wall / crate / container / bush / plant)
in 3 palette variants and redraws the player + 8 guard sprites once
(shared across variants). All output is 128x128 RGBA, same filenames as
the v2 art, drawn from scratch with PIL (supersampled 4x, LANCZOS downscale).

Variants (written to tools/v3_variants/<name>/):
  daylight  - bright neutral grey concrete, mid-grey brick, honey crates
  warm      - warm cream floor, tan brick, reddish-brown crates
  contrast  - light cool-grey floor, dark slate walls, saturated amber crates
Characters (written to tools/v3_variants/chars/):
  Bigger figures (~86% of the canvas vs ~67% in v2), dark outline for
  separation from the light floor, bright facing wedge + gun barrel
  pointing north (sprites rotate with facing), distinct colours per type.
  Guard texture colours are PRE-COMPENSATED for the modulate tint in
  scripts/guard.gd TYPE_STATS (tint multiplies the texture), so the
  RENDERED colour is the intended one.
"""
import math
import os
import random
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
VAR_DIR = os.path.join(HERE, "v3_variants")
SS = 4
SIZE = 128
BIG = SIZE * SS


def canvas():
    return Image.new("RGBA", (BIG, BIG), (0, 0, 0, 0))


def save(img, path):
    img = img.resize((SIZE, SIZE), Image.LANCZOS)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print("wrote", os.path.relpath(path, ROOT))


def rr(d, box, rad, **kw):
    d.rounded_rectangle(box, radius=rad, **kw)


def blend(mark, base, alpha):
    """Opaque colour = mark drawn at opacity alpha over base (0..255)."""
    a = alpha / 255.0
    return tuple(round(m * a + b * (1.0 - a)) for m, b in zip(mark, base))


# ---------------------------------------------------------------- palettes
# Each palette: floor / floor_dark / wall / crate / container / bush / plant.
PALETTES = {
    "daylight": {
        "floor":      dict(base=(198, 198, 192), light=(221, 221, 215), dark=(169, 169, 163),
                           stain=(148, 148, 142), crack=(118, 118, 112)),
        "floor_dark": dict(base=(170, 172, 170), light=(193, 195, 193), dark=(139, 141, 141),
                           stain=(124, 126, 126), crack=(98, 100, 100)),
        "wall":       dict(base=(110, 110, 118), mortar=(74, 74, 82), dark=(96, 96, 104),
                           hi=(158, 158, 166), lo=(64, 64, 72), speck=(136, 136, 144)),
        "crate":      dict(frame=(198, 158, 100), inner=(226, 190, 132), gap=(168, 126, 70),
                           grain=(180, 138, 80), brace_d=(150, 108, 58), brace_l=(210, 164, 102),
                           nail_d=(96, 66, 34), nail_l=(60, 40, 20), outline=(120, 84, 44)),
        "container":  dict(base=(70, 145, 210), ridge=(88, 162, 226), ridge_d=(40, 100, 160),
                           frame=(28, 72, 122), top=(32, 84, 138)),
        "bush":       dict(greens=[(90, 205, 95), (70, 180, 80), (120, 225, 110), (45, 130, 55)],
                           hi=(150, 235, 130)),
        "plant":      dict(pot=(120, 118, 126), pot_top=(150, 148, 156), pot_hi=(178, 176, 184),
                           leaves=[(60, 160, 70), (45, 135, 60), (80, 185, 90), (35, 115, 50)]),
    },
    "warm": {
        "floor":      dict(base=(210, 200, 178), light=(229, 219, 197), dark=(181, 171, 149),
                           stain=(168, 156, 130), crack=(138, 126, 102)),
        "floor_dark": dict(base=(184, 174, 152), light=(205, 195, 173), dark=(155, 145, 125),
                           stain=(143, 133, 110), crack=(113, 103, 82)),
        "wall":       dict(base=(168, 138, 108), mortar=(122, 96, 72), dark=(150, 122, 94),
                           hi=(198, 170, 138), lo=(96, 74, 54), speck=(188, 160, 128)),
        "crate":      dict(frame=(188, 128, 66), inner=(214, 158, 96), gap=(152, 98, 44),
                           grain=(168, 112, 54), brace_d=(140, 88, 40), brace_l=(206, 148, 84),
                           nail_d=(92, 58, 26), nail_l=(58, 34, 16), outline=(110, 66, 30)),
        "container":  dict(base=(60, 150, 175), ridge=(80, 170, 195), ridge_d=(35, 105, 130),
                           frame=(24, 70, 95), top=(28, 82, 108)),
        "bush":       dict(greens=[(96, 200, 88), (74, 175, 72), (126, 222, 100), (48, 128, 50)],
                           hi=(155, 232, 120)),
        "plant":      dict(pot=(150, 110, 88), pot_top=(178, 138, 112), pot_hi=(205, 168, 140),
                           leaves=[(60, 160, 70), (45, 135, 60), (80, 185, 90), (35, 115, 50)]),
    },
    "contrast": {
        "floor":      dict(base=(190, 194, 200), light=(215, 219, 225), dark=(159, 163, 171),
                           stain=(148, 152, 160), crack=(116, 120, 130)),
        "floor_dark": dict(base=(152, 156, 164), light=(177, 181, 189), dark=(125, 129, 137),
                           stain=(116, 120, 128), crack=(90, 94, 104)),
        "wall":       dict(base=(72, 78, 94), mortar=(48, 52, 66), dark=(60, 66, 82),
                           hi=(112, 118, 136), lo=(38, 42, 54), speck=(92, 98, 114)),
        "crate":      dict(frame=(232, 164, 58), inner=(250, 198, 108), gap=(196, 128, 34),
                           grain=(214, 146, 44), brace_d=(190, 120, 30), brace_l=(245, 188, 90),
                           nail_d=(120, 74, 16), nail_l=(80, 48, 10), outline=(150, 92, 20)),
        "container":  dict(base=(50, 130, 220), ridge=(70, 150, 235), ridge_d=(30, 90, 165),
                           frame=(20, 60, 115), top=(24, 72, 130)),
        "bush":       dict(greens=[(90, 205, 95), (70, 180, 80), (120, 225, 110), (45, 130, 55)],
                           hi=(150, 235, 130)),
        "plant":      dict(pot=(120, 118, 126), pot_top=(150, 148, 156), pot_hi=(178, 176, 184),
                           leaves=[(60, 160, 70), (45, 135, 60), (80, 185, 90), (35, 115, 50)]),
    },
}

HAZARD_YELLOW = (240, 205, 40)
HAZARD_BLACK = (28, 28, 32)


# ---------------------------------------------------------------- tiles
def concrete_floor(p, seed, dark_variant=False):
    """Full-bleed concrete tile. Stains are kept very subtle (alpha 16)
    and cracks thin + low-contrast — the v2 floor read black because its
    stains/cracks were far too dark."""
    rng = random.Random(seed)
    img = Image.new("RGBA", (BIG, BIG), p["base"] + (255,))
    d = ImageDraw.Draw(img, "RGBA")
    base = p["base"]
    for _ in range(3):
        cx, cy = rng.randint(60, BIG - 60), rng.randint(60, BIG - 60)
        rx, ry = rng.randint(50, 130), rng.randint(40, 100)
        d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry],
                  fill=blend(p["stain"], base, 60) + (255,))
    for _ in range(900):
        x, y = rng.randint(0, BIG - 1), rng.randint(0, BIG - 1)
        col = p["light"] if rng.random() < 0.5 else p["dark"]
        r = rng.choice([2, 3, 3, 4])
        d.ellipse([x - r, y - r, x + r, y + r],
                  fill=blend(col, base, 90) + (255,))
    for _ in range(2 if not dark_variant else 3):
        x, y = rng.randint(30, BIG - 30), rng.randint(30, BIG - 30)
        pts = [(x, y)]
        for _ in range(rng.randint(4, 7)):
            x += rng.randint(-38, 38)
            y += rng.randint(-38, 38)
            pts.append((x, y))
        d.line(pts, fill=blend(p["crack"], base, 130) + (255,), width=3 * SS // 2)
    edge = blend((0, 0, 0), base, 26)
    d.line([0, 2 * SS, BIG, 2 * SS], fill=edge + (255,), width=2 * SS)
    d.line([2 * SS, 0, 2 * SS, BIG], fill=edge + (255,), width=2 * SS)
    return img


def wall(p):
    img = Image.new("RGBA", (BIG, BIG), p["base"] + (255,))
    d = ImageDraw.Draw(img, "RGBA")
    rng = random.Random(5)
    row_h = 32 * SS
    for row in range(0, BIG, row_h):
        off = (row // row_h) % 2 * 32 * SS
        d.line([0, row, BIG, row], fill=p["mortar"] + (255,), width=4 * SS)
        for x in range(-32 * SS + off, BIG + 32 * SS, 64 * SS):
            d.line([x, row, x, row + row_h], fill=p["mortar"] + (255,), width=4 * SS)
        for _ in range(2):
            bx = rng.randint(0, 7) * 64 * SS + off
            d.rectangle([bx + 2 * SS, row + 2 * SS, bx + 62 * SS, row + row_h - 2 * SS],
                        fill=blend(p["dark"], p["base"], 160) + (255,))
    d.rectangle([0, 0, BIG, 6 * SS], fill=p["hi"] + (255,))
    d.rectangle([0, BIG - 8 * SS, BIG, BIG], fill=p["lo"] + (255,))
    for _ in range(300):
        x, y = rng.randint(0, BIG - 1), rng.randint(0, BIG - 1)
        d.ellipse([x - 2, y - 2, x + 2, y + 2],
                  fill=blend(p["speck"], p["base"], 90) + (255,))
    return img


def crate(p):
    img = canvas()
    d = ImageDraw.Draw(img, "RGBA")
    rr(d, [6 * SS, 6 * SS, BIG - 6 * SS, BIG - 6 * SS], 8 * SS, fill=p["frame"])
    rr(d, [14 * SS, 14 * SS, BIG - 14 * SS, BIG - 14 * SS], 6 * SS, fill=p["inner"])
    for y in (BIG // 3, 2 * BIG // 3):
        d.line([14 * SS, y, BIG - 14 * SS, y], fill=p["gap"], width=4 * SS)
    rng = random.Random(9)
    for _ in range(10):
        y = rng.randint(20 * SS, BIG - 20 * SS)
        x0 = rng.randint(16 * SS, BIG // 2)
        d.line([x0, y, x0 + rng.randint(30 * SS, 70 * SS), y + rng.randint(-3, 3) * SS],
               fill=blend(p["grain"], p["inner"], 180) + (255,), width=2 * SS)
    for (a, b) in [((20 * SS, 20 * SS), (BIG - 20 * SS, BIG - 20 * SS)),
                   ((BIG - 20 * SS, 20 * SS), (20 * SS, BIG - 20 * SS))]:
        d.line([a, b], fill=p["brace_d"], width=16 * SS)
        d.line([a, b], fill=p["brace_l"], width=10 * SS)
    for (x, y) in [(24, 24), (BIG - 24, 24), (24, BIG - 24), (BIG - 24, BIG - 24)]:
        d.ellipse([x - 6 * SS, y - 6 * SS, x + 6 * SS, y + 6 * SS], fill=p["nail_d"])
        d.ellipse([x - 3 * SS, y - 3 * SS, x + 3 * SS, y + 3 * SS], fill=p["nail_l"])
    rr(d, [6 * SS, 6 * SS, BIG - 6 * SS, BIG - 6 * SS], 8 * SS,
       outline=p["outline"] + (255,), width=4 * SS)
    return img


def container(p):
    img = Image.new("RGBA", (BIG, BIG), p["base"] + (255,))
    d = ImageDraw.Draw(img, "RGBA")
    for x in range(0, BIG, 16 * SS):
        d.rectangle([x, 0, x + 8 * SS, BIG], fill=p["ridge"] + (255,))
        d.line([x + 8 * SS, 0, x + 8 * SS, BIG], fill=p["ridge_d"] + (255,), width=3 * SS)
    d.rectangle([0, 0, BIG - 1, BIG - 1], outline=p["frame"] + (255,), width=6 * SS)
    d.rectangle([0, 0, BIG, 10 * SS], fill=p["top"] + (255,))
    band_y0, band_y1 = BIG - 34 * SS, BIG - 10 * SS
    d.rectangle([0, band_y0, BIG, band_y1], fill=HAZARD_YELLOW + (255,))
    for x in range(-40 * SS, BIG + 40 * SS, 24 * SS):
        d.polygon([(x, band_y1), (x + 12 * SS, band_y1),
                   (x + 12 * SS + 20 * SS, band_y0), (x + 20 * SS, band_y0)],
                  fill=HAZARD_BLACK + (255,))
    d.line([0, band_y0, BIG, band_y0], fill=p["frame"] + (255,), width=3 * SS)
    d.line([0, band_y1, BIG, band_y1], fill=p["frame"] + (255,), width=3 * SS)
    for x in range(16 * SS, BIG, 32 * SS):
        d.ellipse([x - 3 * SS, 2 * SS, x + 3 * SS, 8 * SS], fill=(180, 205, 230, 255))
    return img


def bush(p):
    img = canvas()
    d = ImageDraw.Draw(img, "RGBA")
    rng = random.Random(17)
    greens = p["greens"]
    blobs = []
    for _ in range(16):
        cx = BIG / 2 + rng.randint(-70, 70) * SS // 2
        cy = BIG / 2 + rng.randint(-70, 70) * SS // 2
        r = rng.randint(26, 48) * SS // 2
        blobs.append((cx, cy, r))
    for (cx, cy, r) in blobs:
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=rng.choice(greens[:3]) + (255,))
    for (cx, cy, r) in blobs[::3]:
        d.ellipse([cx - r // 2, cy - r // 2, cx + r // 2, cy + r // 2],
                  fill=greens[3] + (220,))
    for _ in range(24):
        cx = BIG / 2 + rng.randint(-80, 80) * SS // 2
        cy = BIG / 2 + rng.randint(-80, 80) * SS // 2
        r = rng.randint(6, 12) * SS // 2
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=p["hi"] + (255,))
    d.ellipse([BIG / 2 - 52 * SS, BIG - 34 * SS, BIG / 2 + 52 * SS, BIG - 14 * SS],
              fill=(0, 0, 0, 70))
    return img


def plant(p):
    img = canvas()
    d = ImageDraw.Draw(img, "RGBA")
    d.polygon([(BIG / 2 - 34 * SS, BIG / 2 + 6 * SS), (BIG / 2 + 34 * SS, BIG / 2 + 6 * SS),
               (BIG / 2 + 24 * SS, BIG - 14 * SS), (BIG / 2 - 24 * SS, BIG - 14 * SS)],
              fill=p["pot"])
    d.rectangle([BIG / 2 - 38 * SS, BIG / 2 - 4 * SS, BIG / 2 + 38 * SS, BIG / 2 + 12 * SS],
                fill=p["pot"])
    d.rectangle([BIG / 2 - 38 * SS, BIG / 2 - 4 * SS, BIG / 2 + 38 * SS, BIG / 2 + 2 * SS],
                fill=p["pot_hi"])
    leaves = p["leaves"]
    for (dx, dy, r, col) in [(-18, -16, 26, leaves[3]), (16, -22, 30, leaves[1]),
                             (0, -34, 28, leaves[3]), (-30, 2, 20, leaves[1]),
                             (30, 0, 20, leaves[3]), (0, -6, 22, leaves[0])]:
        cx, cy = BIG / 2 + dx * SS, BIG / 2 + dy * SS
        d.ellipse([cx - r * SS, cy - r * SS, cx + r * SS, cy + r * SS], fill=col)
    return img


def gen_tiles(name, pal):
    out = os.path.join(VAR_DIR, name)
    save(concrete_floor(pal["floor"], 11), os.path.join(out, "floor_concrete.png"))
    save(concrete_floor(pal["floor_dark"], 23, dark_variant=True),
         os.path.join(out, "floor_concrete_dark.png"))
    save(wall(pal["wall"]), os.path.join(out, "wall.png"))
    save(crate(pal["crate"]), os.path.join(out, "crate.png"))
    save(container(pal["container"]), os.path.join(out, "container_blue.png"))
    save(bush(pal["bush"]), os.path.join(out, "bush.png"))
    save(plant(pal["plant"]), os.path.join(out, "plant.png"))


if __name__ == "__main__":
    for name, pal in PALETTES.items():
        gen_tiles(name, pal)
    print("tiles done")


# ---------------------------------------------------------------- characters
# All figures face UP (north) — guard.gd / player.gd rotate the sprite by
# facing + PI/2, so the gun barrel + facing wedge at the top of the sprite
# always point the way the character faces.
#
# Coordinates below are in TILE units (0..128 across the 128px sprite);
# S() converts to the 512px supersampled canvas. The figure spans
# y ~0..125 of 128 (v2 spanned ~20..104) so characters read bigger at the
# same 0.62 sprite scale. Semi-transparent pixels are fine here: the
# canvas is transparent and Godot composites the sprite over the floor.

def S(v):
    return v * SS


OUTLINE = (14, 14, 18)      # dark outline drawn under every body part
SKIN = (214, 178, 140)
EYE = (255, 240, 200)
WEDGE = (255, 214, 64)      # bright facing wedge (gold) at the top of the head
MUZZLE = (255, 214, 64)


def comp(col, tint):
    """Pre-compensate a desired RENDERED colour for guard.gd's tint
    (rendered = texture * tint), clamped to 0..255."""
    return tuple(min(255, max(0, round(c / t))) if t > 0 else 0
                 for c, t in zip(col, tint))


# guard.gd TYPE_STATS tints
TINT = {
    "basic": (1.0, 1.0, 1.0),
    "rifle": (1.0, 0.78, 0.5),
    "shotgun": (1.0, 0.55, 0.55),
    "grenade": (0.6, 0.8, 1.0),
    "sniper": (0.8, 0.6, 1.0),
    "shielded": (0.75, 0.8, 0.85),
}


def _ell(d, cx, cy, rx, ry, fill, outline=None, ow=0):
    if outline is not None:
        d.ellipse([S(cx - rx - ow), S(cy - ry - ow), S(cx + rx + ow), S(cy + ry + ow)],
                  fill=outline)
    d.ellipse([S(cx - rx), S(cy - ry), S(cx + rx), S(cy + ry)], fill=fill)


def _gun(d, kind, gx):
    """Gun on the figure's right side, barrel pointing north (up)."""
    if kind == "rifle":
        d.rectangle([S(gx - 2.5), S(2), S(gx + 2.5), S(62)], fill=OUTLINE)
        d.rectangle([S(gx - 1.5), S(3.5), S(gx + 1.5), S(61)], fill=(36, 38, 44))
        d.rectangle([S(gx - 2), S(2), S(gx + 2), S(5.5)], fill=(20, 21, 26))
        d.rectangle([S(gx - 2.5), S(50), S(gx + 2.5), S(62)], fill=(58, 46, 32))
        d.rectangle([S(gx - 1.8), S(52), S(gx + 1.8), S(61)], fill=(96, 70, 40))
        d.ellipse([S(gx - 1.5), S(1.5), S(gx + 1.5), S(4.5)], fill=MUZZLE)
    elif kind == "shotgun":
        d.rectangle([S(gx - 3.5), S(6.5), S(gx + 3.5), S(62)], fill=OUTLINE)
        d.rectangle([S(gx - 2.5), S(7.5), S(gx + 2.5), S(61)], fill=(44, 44, 50))
        d.rectangle([S(gx - 2.5), S(5.5), S(gx + 2.5), S(9)], fill=(22, 22, 26))
        d.rectangle([S(gx - 2), S(32), S(gx + 2), S(45)], fill=(120, 84, 48))
        d.rectangle([S(gx - 3), S(50), S(gx + 3), S(62)], fill=(62, 50, 34))
        d.ellipse([S(gx - 2), S(5), S(gx + 2), S(8.5)], fill=MUZZLE)
    elif kind == "sniper":
        d.rectangle([S(gx - 2), S(-1), S(gx + 2), S(64)], fill=OUTLINE)
        d.rectangle([S(gx - 1), S(0), S(gx + 1), S(64)], fill=(28, 30, 36))
        d.rectangle([S(gx - 2.8), S(24), S(gx + 2.8), S(32)], fill=(52, 56, 64))
        d.ellipse([S(gx - 1.2), S(26.5), S(gx + 1.2), S(29.5)], fill=(180, 220, 255))
        d.rectangle([S(gx - 2.5), S(52), S(gx + 2.5), S(64)], fill=(46, 38, 28))
        d.ellipse([S(gx - 1.2), S(-1), S(gx + 1.2), S(2)], fill=MUZZLE)
    elif kind == "pistol":
        d.rectangle([S(gx - 2.2), S(22), S(gx + 2.2), S(62)], fill=OUTLINE)
        d.rectangle([S(gx - 1.2), S(23), S(gx + 1.2), S(61)], fill=(36, 38, 44))
        d.rectangle([S(gx - 2.2), S(50), S(gx + 2.2), S(62)], fill=(58, 46, 32))
        d.ellipse([S(gx - 1.2), S(21.5), S(gx + 1.2), S(24.5)], fill=MUZZLE)


def figure(body, body_dark, head_kind, head_col, gun_kind=None, shield=False,
           stripes=False, knife=False, ring=None, trim=None, grenade=False,
           faceguard=False):
    """body/body_dark/head_col are TEXTURE colours (already tint-compensated
    by the caller). head_kind: 'hood' or 'helmet'."""
    img = canvas()
    d = ImageDraw.Draw(img, "RGBA")
    # ground shadow
    d.ellipse([S(64 - 22), S(116 - 4), S(64 + 22), S(116 + 4)], fill=(0, 0, 0, 90))
    if ring is not None:  # bright base ring (player only)
        d.ellipse([S(64 - 24), S(116 - 5), S(64 + 24), S(116 + 5)],
                  outline=ring, width=2 * SS)
    # legs / lower body
    _ell(d, 64, 100, 17, 14, body_dark, OUTLINE, 1.2)
    # torso
    _ell(d, 64, 76, 20, 18, body, OUTLINE, 1.2)
    _ell(d, 64, 84, 20, 11, body_dark)  # lower shading
    # shoulders
    _ell(d, 44, 66, 7.5, 7.5, body, OUTLINE, 1)
    _ell(d, 84, 66, 7.5, 7.5, body, OUTLINE, 1)
    if stripes:
        for sx in (44, 84):
            d.line([S(sx), S(62), S(sx), S(86)], fill=(240, 240, 240), width=1 * SS)
    else:
        d.rectangle([S(45), S(82), S(83), S(86)], fill=(24, 24, 30))
    if grenade:  # small green grenade on the belt
        d.ellipse([S(50), S(80), S(56), S(86)], fill=(47, 174, 78))
        d.ellipse([S(50), S(80), S(56), S(86)], outline=OUTLINE, width=1 * SS)
        d.rectangle([S(52), S(78), S(54), S(80.5)], fill=(120, 120, 120))
    # front shield (before head so the helmet peeks above it)
    if shield:
        rr(d, [S(41), S(38), S(87), S(86)], 4 * SS, fill=(150, 156, 166))
        rr(d, [S(41), S(38), S(87), S(86)], 4 * SS, outline=(88, 92, 100), width=1 * SS)
        rr(d, [S(44.5), S(41), S(83.5), S(83)], 3 * SS, fill=(178, 184, 194))
        d.ellipse([S(58.5), S(56.5), S(69.5), S(67.5)], fill=(90, 94, 102))
        d.ellipse([S(61.5), S(59.5), S(66.5), S(64.5)], fill=(200, 204, 212))
    # head
    if head_kind == "hood":
        _ell(d, 64, 33, 17, 17, head_col, OUTLINE, 1.2)
        _ell(d, 64, 29, 17, 13.5, tuple(min(255, c + 16) for c in head_col))
        d.ellipse([S(53.5), S(28), S(74.5), S(44)], fill=(14, 12, 22))
        d.ellipse([S(57), S(32), S(61), S(36)], fill=EYE)
        d.ellipse([S(67), S(32), S(71), S(36)], fill=EYE)
        if trim is not None:  # gold hood trim arc
            d.arc([S(47), S(16), S(81), S(50)], 200, 340, fill=trim, width=1 * SS)
    else:  # helmet
        _ell(d, 64, 32.5, 17, 17, head_col, OUTLINE, 1.2)
        d.arc([S(47), S(15.5), S(81), S(49.5)], 180, 360,
              fill=(255, 255, 255, 80), width=1 * SS)
        d.ellipse([S(55), S(29.5), S(73), S(41)], fill=(28, 26, 38))
        d.ellipse([S(58), S(32.5), S(62), S(36.5)], fill=EYE)
        d.ellipse([S(66), S(32.5), S(70), S(36.5)], fill=EYE)
        if faceguard:  # white faceguard bars (red-helmet shotgun guard)
            d.line([S(55), S(38), S(73), S(38)], fill=(235, 235, 235), width=1 * SS)
            d.line([S(56), S(41.5), S(72), S(41.5)], fill=(235, 235, 235), width=1 * SS)
    # ---- facing indicator: bright gold wedge at the very top of the head,
    # pointing north, + a centre stripe down the top of the helmet/hood.
    d.polygon([(S(64), S(7)), (S(58), S(19)), (S(70), S(19))], fill=WEDGE)
    d.polygon([(S(64), S(7)), (S(58), S(19)), (S(70), S(19))],
              outline=OUTLINE, width=1 * SS)
    d.rectangle([S(62.5), S(19), S(65.5), S(24)], fill=WEDGE)
    # gun + hands
    if gun_kind:
        _gun(d, gun_kind, 85)
        d.ellipse([S(80.5), S(59), S(89.5), S(68)], fill=SKIN)
        d.ellipse([S(80.5), S(64), S(89.5), S(73)], fill=SKIN)
    if knife:  # assassin's blade, right side, angled up-forward
        d.polygon([(S(83), S(60)), (S(95), S(45)), (S(89), S(59))], fill=(235, 240, 248))
        d.polygon([(S(83), S(60)), (S(95), S(45)), (S(91), S(54))], fill=(255, 255, 255))
        d.polygon([(S(83), S(60)), (S(95), S(45)), (S(89), S(59))],
                  outline=OUTLINE, width=1 * SS)
        d.rectangle([S(82), S(59.5), S(87), S(65.5)], fill=(110, 74, 38))
        d.ellipse([S(80.5), S(63), S(89.5), S(72)], fill=SKIN)
    return img


def gen_characters():
    out = os.path.join(VAR_DIR, "chars")
    # ---- player: dark hood, BRIGHT green shirt, gold trim, knife, lime ring
    save(figure((47, 200, 90), (32, 140, 62), "hood", (26, 26, 36), knife=True,
                ring=(120, 255, 120), trim=(255, 214, 64)),
         os.path.join(out, "player.png"))
    # ---- rifle (orange): rendered orange uniform + orange helmet
    t = TINT["rifle"]
    save(figure(comp((245, 140, 45), t), comp((200, 105, 30), t), "helmet",
                comp((245, 140, 45), t), gun_kind="rifle"),
         os.path.join(out, "guard_orange.png"))
    # ---- shotgun (red helmet): rendered all-red guard, white faceguard bars
    t = TINT["shotgun"]
    save(figure(comp((170, 55, 50), t), comp((130, 40, 38), t), "helmet",
                comp((220, 50, 50), t), gun_kind="shotgun", faceguard=True),
         os.path.join(out, "guard_red.png"))
    # ---- grenade (blue tracksuit): rendered blue tracksuit, white stripes,
    # pistol + grenade on belt
    t = TINT["grenade"]
    save(figure(comp((50, 120, 220), t), comp((36, 90, 175), t), "helmet",
                comp((50, 120, 220), t), gun_kind="pistol", stripes=True, grenade=True),
         os.path.join(out, "guard_blue.png"))
    # ---- sniper: rendered muted sage-green uniform, long rifle + scope glint
    t = TINT["sniper"]
    save(figure(comp((96, 132, 84), t), comp((70, 98, 62), t), "helmet",
                comp((110, 140, 96), t), gun_kind="sniper"),
         os.path.join(out, "guard_sniper.png"))
    # ---- shielded: rendered steel blue-grey uniform, big front shield
    t = TINT["shielded"]
    save(figure(comp((110, 130, 155), t), comp((82, 98, 122), t), "helmet",
                comp((110, 130, 155), t), gun_kind="pistol", shield=True),
         os.path.join(out, "guard_shield.png"))
    # ---- basic guards: blue uniform, helmet colour varies, rifle
    for name, helm in [("guard_green", (39, 190, 100)),
                       ("guard_purple", (165, 85, 200)),
                       ("guard_pink", (240, 80, 160))]:
        save(figure((43, 96, 175), (30, 72, 135), "helmet", helm, gun_kind="rifle"),
             os.path.join(out, name + ".png"))


if __name__ == "__main__":
    for name, pal in PALETTES.items():
        gen_tiles(name, pal)
    gen_characters()
    print("v3 art done")
