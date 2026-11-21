#!/usr/bin/env python3
"""Generate original art for Shadow Assassin (top-down 2D stealth game).

All sprites are drawn from scratch with PIL - no copied assets.
Style (remake, 2026-11-21): dark warehouse look - flat, chunky, cartoonish,
high-contrast, minimalist. Grey concrete floors with stains/cracks, dark grey
stone/brick walls, light-brown wooden crates with cross-plank detail, blue
shipping containers with yellow-black hazard stripes, bright green bushes.
Small top-down figures (~1 tile), colour-coded guards holding visible guns.
Supersampled 4x then downscaled for crisp AA.

Kept from the original generator: the old teal/green/sand floor tiles,
star.png and poof.png (unchanged), and icon.png.
"""
import math
import os
import random
from PIL import Image, ImageDraw, ImageFont

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art")
os.makedirs(OUT, exist_ok=True)

SS = 4          # supersample factor
SIZE = 128      # final sprite size
BIG = SIZE * SS


def canvas():
    return Image.new("RGBA", (BIG, BIG), (0, 0, 0, 0))


def save(img, name):
    img = img.resize((SIZE, SIZE), Image.LANCZOS)
    img.save(os.path.join(OUT, name))
    print("wrote", name)


def rr(d, box, rad, **kw):
    d.rounded_rectangle(box, radius=rad, **kw)


def star_points(cx, cy, r_out, r_in, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        r = r_out if i % 2 == 0 else r_in
        a = math.radians(rot + i * 180 / n)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


# ---------------------------------------------------------------- old floor tiles (kept)
def floor_tile(base, light, dark, deco=None):
    img = canvas()
    d = ImageDraw.Draw(img)
    rr(d, [4 * SS, 4 * SS, BIG - 4 * SS, BIG - 4 * SS], 26 * SS, fill=base)
    rr(d, [16 * SS, 16 * SS, BIG - 16 * SS, BIG - 16 * SS], 18 * SS, fill=light)
    for (x, y) in [(24, 24), (BIG - 24, 24), (24, BIG - 24), (BIG - 24, BIG - 24)]:
        d.ellipse([x - 5 * SS, y - 5 * SS, x + 5 * SS, y + 5 * SS], fill=dark)
    if deco == "star":
        d.polygon(star_points(BIG / 2, BIG / 2, 34 * SS, 15 * SS), fill=(255, 217, 60, 255))
        d.polygon(star_points(BIG / 2, BIG / 2, 20 * SS, 9 * SS), fill=(255, 240, 160, 255))
    elif deco == "dot":
        d.ellipse([BIG / 2 - 14 * SS, BIG / 2 - 14 * SS, BIG / 2 + 14 * SS, BIG / 2 + 14 * SS],
                  fill=(255, 255, 255, 60))
    elif deco == "leaf":
        d.ellipse([BIG / 2 - 26 * SS, BIG / 2 - 12 * SS, BIG / 2 + 26 * SS, BIG / 2 + 12 * SS],
                  fill=(255, 255, 255, 46))
    return img


save(floor_tile((43, 178, 163), (62, 210, 180), (24, 130, 118)), "floor_teal.png")
save(floor_tile((43, 178, 163), (62, 210, 180), (24, 130, 118), "star"), "floor_teal_star.png")
save(floor_tile((105, 194, 74), (132, 216, 96), (70, 150, 48)), "floor_green.png")
save(floor_tile((105, 194, 74), (132, 216, 96), (70, 150, 48), "dot"), "floor_green_dot.png")
save(floor_tile((232, 190, 96), (244, 208, 130), (190, 150, 60), "leaf"), "floor_sand.png")


# ---------------------------------------------------------------- NEW: concrete floors
def concrete_floor(base, speck_light, speck_dark, stain, seed, dark_variant=False):
    """Full-bleed seamless-ish concrete tile: speckle noise, stains, cracks."""
    rng = random.Random(seed)
    img = Image.new("RGBA", (BIG, BIG), base + (255,))
    d = ImageDraw.Draw(img, "RGBA")
    # large soft stains
    for _ in range(3):
        cx, cy = rng.randint(60, BIG - 60), rng.randint(60, BIG - 60)
        rx, ry = rng.randint(50, 130), rng.randint(40, 100)
        d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=stain + (26,))
    # speckle
    for _ in range(900):
        x, y = rng.randint(0, BIG - 1), rng.randint(0, BIG - 1)
        col = speck_light if rng.random() < 0.5 else speck_dark
        r = rng.choice([2, 3, 3, 4])
        d.ellipse([x - r, y - r, x + r, y + r], fill=col + (70,))
    # cracks: jagged dark polylines
    for _ in range(3 if not dark_variant else 4):
        x, y = rng.randint(30, BIG - 30), rng.randint(30, BIG - 30)
        pts = [(x, y)]
        for _ in range(rng.randint(4, 7)):
            x += rng.randint(-38, 38)
            y += rng.randint(-38, 38)
            pts.append((x, y))
        d.line(pts, fill=(30, 30, 32, 150), width=3 * SS // 2)
    # faint expansion joint along two edges so tiling reads
    d.line([0, 2 * SS, BIG, 2 * SS], fill=(0, 0, 0, 40), width=2 * SS)
    d.line([2 * SS, 0, 2 * SS, BIG], fill=(0, 0, 0, 40), width=2 * SS)
    return img


save(concrete_floor((138, 138, 133), (168, 168, 162), (104, 104, 100), (70, 70, 66), 11),
     "floor_concrete.png")
save(concrete_floor((86, 87, 92), (112, 113, 118), (58, 59, 64), (40, 40, 44), 23,
                    dark_variant=True),
     "floor_concrete_dark.png")


# ---------------------------------------------------------------- NEW: dark stone/brick wall
def wall_dark():
    img = Image.new("RGBA", (BIG, BIG), (58, 58, 64, 255))
    d = ImageDraw.Draw(img, "RGBA")
    rng = random.Random(5)
    row_h = 32 * SS
    # brick courses, offset joints
    for row in range(0, BIG, row_h):
        off = (row // row_h) % 2 * 32 * SS
        d.line([0, row, BIG, row], fill=(38, 38, 43, 255), width=4 * SS)
        for x in range(-32 * SS + off, BIG + 32 * SS, 64 * SS):
            d.line([x, row, x, row + row_h], fill=(38, 38, 43, 255), width=4 * SS)
        # a few darker bricks for variety
        for _ in range(2):
            bx = rng.randint(0, 7) * 64 * SS + off
            d.rectangle([bx + 2 * SS, row + 2 * SS, bx + 62 * SS, row + row_h - 2 * SS],
                        fill=(48, 48, 54, 160))
    # top highlight edge, bottom shadow
    d.rectangle([0, 0, BIG, 6 * SS], fill=(96, 96, 104, 255))
    d.rectangle([0, BIG - 8 * SS, BIG, BIG], fill=(30, 30, 34, 255))
    # speckles
    for _ in range(300):
        x, y = rng.randint(0, BIG - 1), rng.randint(0, BIG - 1)
        d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=(80, 80, 88, 90))
    return img


save(wall_dark(), "wall.png")


# ---------------------------------------------------------------- NEW: wooden crate (cross-plank)
def crate_wood():
    img = canvas()
    d = ImageDraw.Draw(img, "RGBA")
    # outer frame
    rr(d, [6 * SS, 6 * SS, BIG - 6 * SS, BIG - 6 * SS], 8 * SS, fill=(169, 124, 70))
    rr(d, [14 * SS, 14 * SS, BIG - 14 * SS, BIG - 14 * SS], 6 * SS, fill=(201, 154, 95))
    # horizontal plank gaps
    for y in (BIG // 3, 2 * BIG // 3):
        d.line([14 * SS, y, BIG - 14 * SS, y], fill=(150, 108, 58), width=4 * SS)
    # wood grain
    rng = random.Random(9)
    for _ in range(10):
        y = rng.randint(20 * SS, BIG - 20 * SS)
        x0 = rng.randint(16 * SS, BIG // 2)
        d.line([x0, y, x0 + rng.randint(30 * SS, 70 * SS), y + rng.randint(-3, 3) * SS],
               fill=(170, 128, 72, 180), width=2 * SS)
    # X cross braces (diagonal planks with dark outline)
    for (a, b) in [((20 * SS, 20 * SS), (BIG - 20 * SS, BIG - 20 * SS)),
                   ((BIG - 20 * SS, 20 * SS), (20 * SS, BIG - 20 * SS))]:
        d.line([a, b], fill=(140, 100, 52), width=16 * SS)
        d.line([a, b], fill=(185, 140, 84), width=10 * SS)
    # corner nails
    for (x, y) in [(24, 24), (BIG - 24, 24), (24, BIG - 24), (BIG - 24, BIG - 24)]:
        d.ellipse([x - 6 * SS, y - 6 * SS, x + 6 * SS, y + 6 * SS], fill=(90, 62, 32))
        d.ellipse([x - 3 * SS, y - 3 * SS, x + 3 * SS, y + 3 * SS], fill=(60, 40, 20))
    # edge shadow
    rr(d, [6 * SS, 6 * SS, BIG - 6 * SS, BIG - 6 * SS], 8 * SS,
       outline=(110, 78, 40, 255), width=4 * SS)
    return img


save(crate_wood(), "crate.png")


# ---------------------------------------------------------------- NEW: blue container + hazard stripes
def container_blue():
    img = Image.new("RGBA", (BIG, BIG), (46, 111, 176, 255))
    d = ImageDraw.Draw(img, "RGBA")
    # corrugation: alternating light/dark vertical ridges
    for x in range(0, BIG, 16 * SS):
        d.rectangle([x, 0, x + 8 * SS, BIG], fill=(58, 128, 196, 255))
        d.line([x + 8 * SS, 0, x + 8 * SS, BIG], fill=(30, 84, 140, 255), width=3 * SS)
    # dark frame
    d.rectangle([0, 0, BIG - 1, BIG - 1], outline=(22, 60, 102, 255), width=6 * SS)
    d.rectangle([0, 0, BIG, 10 * SS], fill=(26, 70, 118, 255))
    # hazard stripe band along the bottom: diagonal yellow/black stripes
    band_y0, band_y1 = BIG - 34 * SS, BIG - 10 * SS
    d.rectangle([0, band_y0, BIG, band_y1], fill=(232, 196, 32, 255))
    for x in range(-40 * SS, BIG + 40 * SS, 24 * SS):
        d.polygon([(x, band_y1), (x + 12 * SS, band_y1),
                   (x + 12 * SS + 20 * SS, band_y0), (x + 20 * SS, band_y0)],
                  fill=(24, 24, 28, 255))
    d.line([0, band_y0, BIG, band_y0], fill=(22, 60, 102, 255), width=3 * SS)
    d.line([0, band_y1, BIG, band_y1], fill=(22, 60, 102, 255), width=3 * SS)
    # rivets on the top bar
    for x in range(16 * SS, BIG, 32 * SS):
        d.ellipse([x - 3 * SS, 2 * SS, x + 3 * SS, 8 * SS], fill=(180, 205, 230, 255))
    return img


save(container_blue(), "container_blue.png")


# ---------------------------------------------------------------- NEW: bush (hiding spot)
def bush():
    img = canvas()
    d = ImageDraw.Draw(img, "RGBA")
    rng = random.Random(17)
    greens = [(63, 174, 74), (47, 143, 58), (87, 201, 94), (31, 107, 42)]
    # dense cluster of overlapping leaf circles
    blobs = []
    for _ in range(16):
        cx = BIG / 2 + rng.randint(-70, 70) * SS // 2
        cy = BIG / 2 + rng.randint(-70, 70) * SS // 2
        r = rng.randint(26, 48) * SS // 2
        blobs.append((cx, cy, r))
    for (cx, cy, r) in blobs:
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=rng.choice(greens[:3]) + (255,))
    # darker under-leaves for depth, then bright highlights
    for (cx, cy, r) in blobs[::3]:
        d.ellipse([cx - r // 2, cy - r // 2, cx + r // 2, cy + r // 2],
                  fill=(31, 107, 42, 220))
    for _ in range(24):
        cx = BIG / 2 + rng.randint(-80, 80) * SS // 2
        cy = BIG / 2 + rng.randint(-80, 80) * SS // 2
        r = rng.randint(6, 12) * SS // 2
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(120, 220, 110, 255))
    # soft ground shadow
    d.ellipse([BIG / 2 - 52 * SS, BIG - 34 * SS, BIG / 2 + 52 * SS, BIG - 14 * SS],
              fill=(0, 0, 0, 70))
    return img


save(bush(), "bush.png")


# ---------------------------------------------------------------- NEW: dark potted plant (floor prop)
def plant_dark():
    img = canvas()
    d = ImageDraw.Draw(img, "RGBA")
    # dark pot
    d.polygon([(BIG / 2 - 34 * SS, BIG / 2 + 6 * SS), (BIG / 2 + 34 * SS, BIG / 2 + 6 * SS),
               (BIG / 2 + 24 * SS, BIG - 14 * SS), (BIG / 2 - 24 * SS, BIG - 14 * SS)],
              fill=(58, 58, 64))
    d.rectangle([BIG / 2 - 38 * SS, BIG / 2 - 4 * SS, BIG / 2 + 38 * SS, BIG / 2 + 12 * SS],
                fill=(74, 74, 82))
    d.rectangle([BIG / 2 - 38 * SS, BIG / 2 - 4 * SS, BIG / 2 + 38 * SS, BIG / 2 + 2 * SS],
                fill=(96, 96, 104))
    # dark green leaves
    for (dx, dy, r, col) in [(-18, -16, 26, (31, 107, 42)), (16, -22, 30, (47, 143, 58)),
                             (0, -34, 28, (24, 88, 36)), (-30, 2, 20, (47, 143, 58)),
                             (30, 0, 20, (31, 107, 42)), (0, -6, 22, (63, 174, 74))]:
        cx, cy = BIG / 2 + dx * SS, BIG / 2 + dy * SS
        d.ellipse([cx - r * SS, cy - r * SS, cx + r * SS, cy + r * SS], fill=col)
    return img


save(plant_dark(), "plant.png")


# ---------------------------------------------------------------- characters (new dark flat look)
def shadow(d):
    d.ellipse([BIG / 2 - 46 * SS, BIG - 52 * SS, BIG / 2 + 46 * SS, BIG - 22 * SS],
              fill=(0, 0, 0, 90))


def gun(d, kind):
    """Gun held at the figure's right side, pointing north (up)."""
    gx0 = BIG / 2 + 16 * SS
    if kind == "rifle":
        d.rectangle([gx0, 6 * SS, gx0 + 8 * SS, 58 * SS], fill=(34, 36, 42))
        d.rectangle([gx0 - 2 * SS, 2 * SS, gx0 + 10 * SS, 10 * SS], fill=(20, 21, 26))
        d.rectangle([gx0 - 3 * SS, 50 * SS, gx0 + 11 * SS, 68 * SS], fill=(52, 42, 30))
    elif kind == "shotgun":
        d.rectangle([gx0 - 2 * SS, 12 * SS, gx0 + 12 * SS, 58 * SS], fill=(40, 40, 46))
        d.rectangle([gx0 - 2 * SS, 8 * SS, gx0 + 12 * SS, 16 * SS], fill=(22, 22, 26))
        d.rectangle([gx0, 34 * SS, gx0 + 10 * SS, 46 * SS], fill=(120, 84, 48))
        d.rectangle([gx0 - 3 * SS, 50 * SS, gx0 + 13 * SS, 68 * SS], fill=(58, 46, 32))
    elif kind == "sniper":
        d.rectangle([gx0 + 2 * SS, 0, gx0 + 7 * SS, 58 * SS], fill=(28, 30, 36))
        d.rectangle([gx0 - 1 * SS, 24 * SS, gx0 + 10 * SS, 34 * SS], fill=(52, 56, 64))
        d.rectangle([gx0 - 3 * SS, 50 * SS, gx0 + 12 * SS, 68 * SS], fill=(46, 38, 28))
    elif kind == "pistol":
        d.rectangle([gx0, 22 * SS, gx0 + 7 * SS, 56 * SS], fill=(34, 36, 42))
        d.rectangle([gx0 - 2 * SS, 50 * SS, gx0 + 9 * SS, 66 * SS], fill=(52, 42, 30))
    # hands gripping the gun (low on the torso, clear of the face)
    d.ellipse([gx0 - 4 * SS, 58 * SS, gx0 + 12 * SS, 70 * SS], fill=(214, 178, 140))
    d.ellipse([gx0 - 4 * SS, 68 * SS, gx0 + 12 * SS, 78 * SS], fill=(214, 178, 140))


def figure(body, body_dark, head_kind, head_col, gun_kind=None, shield=False,
           stripes=False, knife=False):
    """Small top-down figure facing UP (north). head_kind: 'hood' or 'helmet'."""
    img = canvas()
    d = ImageDraw.Draw(img, "RGBA")
    shadow(d)
    # trousers / lower body
    d.ellipse([BIG / 2 - 32 * SS, BIG / 2 + 22 * SS, BIG / 2 + 32 * SS, BIG - 24 * SS],
              fill=body_dark)
    # torso
    d.ellipse([BIG / 2 - 36 * SS, BIG / 2 - 12 * SS, BIG / 2 + 36 * SS, BIG / 2 + 34 * SS],
              fill=body)
    d.ellipse([BIG / 2 - 36 * SS, BIG / 2 + 18 * SS, BIG / 2 + 36 * SS, BIG / 2 + 34 * SS],
              fill=body_dark)
    if stripes:  # tracksuit side stripes
        d.line([BIG / 2 - 32 * SS, BIG / 2 - 4 * SS, BIG / 2 - 32 * SS, BIG / 2 + 28 * SS],
               fill=(240, 240, 240), width=4 * SS)
        d.line([BIG / 2 + 32 * SS, BIG / 2 - 4 * SS, BIG / 2 + 32 * SS, BIG / 2 + 28 * SS],
               fill=(240, 240, 240), width=4 * SS)
    else:  # belt
        d.rectangle([BIG / 2 - 34 * SS, BIG / 2 + 18 * SS, BIG / 2 + 34 * SS, BIG / 2 + 26 * SS],
                    fill=(24, 24, 30))
    # front shield (drawn before head so the helmet peeks above it)
    if shield:
        rr(d, [BIG / 2 - 44 * SS, 26 * SS, BIG / 2 + 44 * SS, BIG / 2 + 30 * SS], 12 * SS,
           fill=(138, 143, 152))
        rr(d, [BIG / 2 - 44 * SS, 26 * SS, BIG / 2 + 44 * SS, BIG / 2 + 30 * SS], 12 * SS,
           outline=(88, 92, 100), width=4 * SS)
        d.ellipse([BIG / 2 - 10 * SS, BIG / 2 - 6 * SS, BIG / 2 + 10 * SS, BIG / 2 + 14 * SS],
                  fill=(90, 94, 102))
        d.ellipse([BIG / 2 - 5 * SS, BIG / 2 - 1 * SS, BIG / 2 + 5 * SS, BIG / 2 + 9 * SS],
                  fill=(180, 184, 192))
    # head
    if head_kind == "hood":
        d.ellipse([BIG / 2 - 30 * SS, 20 * SS, BIG / 2 + 30 * SS, 80 * SS], fill=head_col)
        d.ellipse([BIG / 2 - 30 * SS, 20 * SS, BIG / 2 + 30 * SS, 64 * SS],
                  fill=(head_col[0] + 14, head_col[1] + 14, head_col[2] + 18))
        d.ellipse([BIG / 2 - 19 * SS, 36 * SS, BIG / 2 + 19 * SS, 68 * SS], fill=(14, 12, 22))
        d.ellipse([BIG / 2 - 11 * SS, 46 * SS, BIG / 2 - 3 * SS, 54 * SS], fill=(255, 240, 200))
        d.ellipse([BIG / 2 + 3 * SS, 46 * SS, BIG / 2 + 11 * SS, 54 * SS], fill=(255, 240, 200))
        d.arc([BIG / 2 - 30 * SS, 20 * SS, BIG / 2 + 30 * SS, 80 * SS], 200, 340,
              fill=(110, 110, 130), width=5 * SS)
    else:  # helmet
        d.ellipse([BIG / 2 - 30 * SS, 18 * SS, BIG / 2 + 30 * SS, 76 * SS], fill=head_col)
        d.arc([BIG / 2 - 30 * SS, 18 * SS, BIG / 2 + 30 * SS, 76 * SS], 180, 360,
              fill=(255, 255, 255, 70), width=5 * SS)
        d.ellipse([BIG / 2 - 16 * SS, 42 * SS, BIG / 2 + 16 * SS, 66 * SS], fill=(28, 26, 38))
        d.ellipse([BIG / 2 - 10 * SS, 48 * SS, BIG / 2 - 2 * SS, 56 * SS], fill=(255, 240, 200))
        d.ellipse([BIG / 2 + 2 * SS, 48 * SS, BIG / 2 + 10 * SS, 56 * SS], fill=(255, 240, 200))
        if head_col == (214, 48, 48):  # red football helmet: white faceguard bars
            d.line([BIG / 2 - 16 * SS, 58 * SS, BIG / 2 + 16 * SS, 58 * SS],
                   fill=(235, 235, 235), width=3 * SS)
            d.line([BIG / 2 - 14 * SS, 66 * SS, BIG / 2 + 14 * SS, 66 * SS],
                   fill=(235, 235, 235), width=3 * SS)
    if gun_kind:
        gun(d, gun_kind)
    if knife:  # assassin's blade at the right side, clearly visible
        d.polygon([(BIG / 2 + 36 * SS, BIG / 2 + 0 * SS), (BIG / 2 + 60 * SS, BIG / 2 + 14 * SS),
                   (BIG / 2 + 44 * SS, BIG / 2 + 28 * SS)], fill=(235, 240, 248))
        d.polygon([(BIG / 2 + 36 * SS, BIG / 2 + 0 * SS), (BIG / 2 + 60 * SS, BIG / 2 + 14 * SS),
                   (BIG / 2 + 48 * SS, BIG / 2 + 18 * SS)], fill=(255, 255, 255))
        d.rectangle([BIG / 2 + 34 * SS, BIG / 2 + 20 * SS, BIG / 2 + 46 * SS, BIG / 2 + 32 * SS],
                    fill=(110, 74, 38))
    return img


DARK = (29, 29, 38)
# Player: dark hood, GREEN shirt, dark trousers, knife visible
save(figure((47, 174, 78), (35, 35, 46), "hood", (26, 26, 36), knife=True), "player.png")
# Orange guard: orange uniform + orange helmet, rifle
save(figure((244, 132, 43), (198, 98, 24), "helmet", (244, 132, 43), gun_kind="rifle"),
     "guard_orange.png")
# NEW red-helmet guard: dark uniform, red helmet, shotgun
save(figure((58, 62, 78), (40, 43, 56), "helmet", (214, 48, 48), gun_kind="shotgun"),
     "guard_red.png")
# Blue tracksuit guard: blue tracksuit + white stripes, blue cap/helmet, pistol
save(figure((46, 110, 210), (30, 82, 168), "helmet", (46, 110, 210),
            gun_kind="pistol", stripes=True), "guard_blue.png")
# NEW sniper: dark green-grey uniform, long rifle + scope
save(figure((74, 96, 74), (52, 70, 52), "helmet", (58, 74, 58), gun_kind="sniper"),
     "guard_sniper.png")
# NEW shield guard: grey-blue uniform, front shield, pistol at the side
save(figure((96, 110, 132), (70, 82, 102), "helmet", (96, 110, 132),
            gun_kind="pistol", shield=True), "guard_shield.png")
# Basic guard variants: BLUE uniform, helmet colour varies, rifle
for name, helm in [("guard_green", (39, 174, 96)), ("guard_purple", (142, 68, 173)),
                   ("guard_pink", (232, 67, 147))]:
    save(figure((43, 90, 168), (30, 68, 128), "helmet", helm, gun_kind="rifle"), name + ".png")


# ---------------------------------------------------------------- NEW: blood pool
def blood():
    img = canvas()
    d = ImageDraw.Draw(img, "RGBA")
    rng = random.Random(31)
    cx, cy = BIG / 2, BIG / 2 + 6 * SS
    for (dx, dy, rx, ry, col) in [(-8, 0, 44, 30, (160, 18, 18)), (14, 8, 36, 26, (192, 24, 24)),
                                  (-20, 12, 24, 16, (122, 14, 14)), (24, -10, 22, 15, (160, 18, 18)),
                                  (0, -16, 26, 16, (192, 24, 24)), (4, 18, 30, 16, (122, 14, 14))]:
        d.ellipse([cx + dx * SS - rx * SS, cy + dy * SS - ry * SS,
                   cx + dx * SS + rx * SS, cy + dy * SS + ry * SS], fill=col + (255,))
    # splatter drops around the pool
    for _ in range(14):
        a = rng.uniform(0, 2 * math.pi)
        dist = rng.randint(52, 78) * SS // 2
        x, y = cx + int(math.cos(a) * dist), cy + int(math.sin(a) * dist)
        r = rng.randint(3, 8) * SS // 2
        d.ellipse([x - r, y - r, x + r, y + r], fill=(160, 18, 18, 255))
    # darker centre
    d.ellipse([cx - 22 * SS, cy - 12 * SS, cx + 22 * SS, cy + 12 * SS], fill=(110, 12, 12, 255))
    return img


save(blood(), "blood.png")


# ---------------------------------------------------------------- NEW: cash (fan of green banknotes)
def cash():
    img = canvas()
    d = ImageDraw.Draw(img, "RGBA")

    def note(angle_deg, dx, dy):
        w, h = 46 * SS, 22 * SS
        a = math.radians(angle_deg)
        ca, sa = math.cos(a), math.sin(a)
        cx, cy = BIG / 2 + dx * SS, BIG / 2 + dy * SS
        corners = []
        for (px, py) in [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)]:
            corners.append((cx + px * ca - py * sa, cy + px * sa + py * ca))
        d.polygon(corners, fill=(63, 174, 90))
        d.polygon(corners, outline=(28, 110, 52), width=3 * SS)
        # centre band + value dot
        inner = []
        for (px, py) in [(-w / 2 + 6 * SS, -h / 2 + 5 * SS), (w / 2 - 6 * SS, -h / 2 + 5 * SS),
                         (w / 2 - 6 * SS, h / 2 - 5 * SS), (-w / 2 + 6 * SS, h / 2 - 5 * SS)]:
            inner.append((cx + px * ca - py * sa, cy + px * sa + py * ca))
        d.polygon(inner, fill=(120, 220, 140))
        d.ellipse([cx - 6 * SS, cy - 6 * SS, cx + 6 * SS, cy + 6 * SS], fill=(28, 110, 52))

    note(-24, -8, 10)
    note(22, 8, 8)
    note(0, 0, -14)
    return img


save(cash(), "cash.png")


# ---------------------------------------------------------------- NEW: green target/crosshair icon (HUD counter)
def target_icon():
    img = canvas()
    d = ImageDraw.Draw(img, "RGBA")
    cx, cy = BIG / 2, BIG / 2
    green = (47, 224, 90)
    d.ellipse([cx - 40 * SS, cy - 40 * SS, cx + 40 * SS, cy + 40 * SS],
              outline=green, width=7 * SS)
    d.ellipse([cx - 26 * SS, cy - 26 * SS, cx + 26 * SS, cy + 26 * SS],
              outline=(20, 120, 44), width=3 * SS)
    for (x0, y0, x1, y1) in [(cx - 52 * SS, cy, cx - 40 * SS, cy),
                             (cx + 40 * SS, cy, cx + 52 * SS, cy),
                             (cx, cy - 52 * SS, cx, cy - 40 * SS),
                             (cx, cy + 40 * SS, cx, cy + 52 * SS)]:
        d.line([x0, y0, x1, y1], fill=green, width=8 * SS)
    d.ellipse([cx - 8 * SS, cy - 8 * SS, cx + 8 * SS, cy + 8 * SS], fill=green)
    return img


save(target_icon(), "target_icon.png")


# ---------------------------------------------------------------- NEW: health barrel (green "+")
def barrel_health():
    img = canvas()
    d = ImageDraw.Draw(img, "RGBA")
    cx, cy = BIG / 2, BIG / 2 + 4 * SS
    # barrel body (slight side depth) + top
    d.ellipse([cx - 42 * SS, cy - 30 * SS, cx + 42 * SS, cy + 42 * SS], fill=(52, 52, 56))
    d.ellipse([cx - 42 * SS, cy - 38 * SS, cx + 42 * SS, cy + 34 * SS], fill=(74, 78, 74))
    d.ellipse([cx - 34 * SS, cy - 32 * SS, cx + 34 * SS, cy + 28 * SS], fill=(92, 96, 92))
    d.ellipse([cx - 34 * SS, cy - 32 * SS, cx + 34 * SS, cy + 28 * SS],
              outline=(48, 50, 48), width=3 * SS)
    # green cross
    d.rectangle([cx - 7 * SS, cy - 22 * SS, cx + 7 * SS, cy + 18 * SS], fill=(47, 224, 90))
    d.rectangle([cx - 22 * SS, cy - 7 * SS, cx + 22 * SS, cy + 7 * SS], fill=(47, 224, 90))
    d.rectangle([cx - 7 * SS, cy - 22 * SS, cx + 7 * SS, cy + 18 * SS],
                outline=(20, 120, 44), width=2 * SS)
    d.rectangle([cx - 22 * SS, cy - 7 * SS, cx + 22 * SS, cy + 7 * SS],
                outline=(20, 120, 44), width=2 * SS)
    return img


save(barrel_health(), "barrel_health.png")


# ---------------------------------------------------------------- pickups (restyled, flat)
def coin():
    img = canvas()
    d = ImageDraw.Draw(img, "RGBA")
    d.ellipse([BIG / 2 - 38 * SS, BIG / 2 - 38 * SS, BIG / 2 + 38 * SS, BIG / 2 + 38 * SS],
              fill=(209, 143, 0))
    d.ellipse([BIG / 2 - 32 * SS, BIG / 2 - 32 * SS, BIG / 2 + 32 * SS, BIG / 2 + 32 * SS],
              fill=(242, 183, 5))
    d.ellipse([BIG / 2 - 24 * SS, BIG / 2 - 24 * SS, BIG / 2 + 24 * SS, BIG / 2 + 24 * SS],
              outline=(255, 217, 92), width=4 * SS)
    try:
        font = ImageFont.truetype("DejaVuSans-Bold.ttf", 56 * SS)
    except OSError:
        try:
            font = ImageFont.load_default(size=56 * SS)
        except TypeError:
            font = ImageFont.load_default()
    d.text((BIG / 2, BIG / 2), "$", fill=(176, 118, 0), font=font, anchor="mm")
    d.arc([BIG / 2 - 32 * SS, BIG / 2 - 32 * SS, BIG / 2 + 32 * SS, BIG / 2 + 32 * SS],
          200, 320, fill=(255, 255, 255, 200), width=5 * SS)
    return img


save(coin(), "coin.png")


def gem(col, light):
    img = canvas()
    d = ImageDraw.Draw(img, "RGBA")
    cx, cy = BIG / 2, BIG / 2
    d.polygon([(cx, cy - 36 * SS), (cx + 30 * SS, cy - 8 * SS), (cx, cy + 38 * SS),
               (cx - 30 * SS, cy - 8 * SS)], fill=col)
    d.polygon([(cx, cy - 36 * SS), (cx + 30 * SS, cy - 8 * SS), (cx, cy - 8 * SS),
               (cx - 30 * SS, cy - 8 * SS)], fill=light)
    d.line([cx, cy - 36 * SS, cx, cy + 38 * SS], fill=(255, 255, 255, 160), width=4 * SS)
    d.polygon(star_points(cx - 12 * SS, cy - 16 * SS, 10 * SS, 4 * SS),
              fill=(255, 255, 255, 220))
    return img


save(gem((77, 208, 225), (150, 235, 245)), "gem_cyan.png")
save(gem((255, 111, 181), (255, 170, 210)), "gem_pink.png")
save(gem((179, 136, 255), (210, 180, 255)), "gem_purple.png")


def star():
    img = canvas()
    d = ImageDraw.Draw(img)
    d.polygon(star_points(BIG / 2, BIG / 2, 46 * SS, 20 * SS), fill=(255, 201, 60))
    d.polygon(star_points(BIG / 2, BIG / 2, 30 * SS, 13 * SS), fill=(255, 232, 140))
    return img


save(star(), "star.png")


def poof():
    img = canvas()
    d = ImageDraw.Draw(img)
    for (dx, dy, r, a) in [(-22, 6, 26, 220), (20, 2, 28, 220), (0, -18, 30, 235),
                           (-6, 18, 22, 200), (24, 20, 18, 190)]:
        cx, cy = BIG / 2 + dx * SS, BIG / 2 + dy * SS
        d.ellipse([cx - r * SS, cy - r * SS, cx + r * SS, cy + r * SS], fill=(255, 255, 255, a))
    d.polygon(star_points(BIG / 2, BIG / 2, 22 * SS, 9 * SS), fill=(255, 201, 60))
    return img


save(poof(), "poof.png")


# ---------------------------------------------------------------- NEW: bomb (tripwire device)
def bomb():
    """Top-down tripwire bomb: dark metal disc body, red blinking light,
    two small tripwire posts joined by a thin red wire."""
    img = canvas()
    d = ImageDraw.Draw(img, "RGBA")
    cx, cy = BIG / 2, BIG / 2
    # soft ground shadow
    d.ellipse([cx - 50 * SS, BIG - 40 * SS, cx + 50 * SS, BIG - 18 * SS],
              fill=(0, 0, 0, 70))
    # tripwire posts (top-left and top-right) with red wire between them
    for px in (cx - 46 * SS, cx + 46 * SS):
        d.rectangle([px - 5 * SS, cy - 52 * SS, px + 5 * SS, cy - 28 * SS],
                    fill=(52, 54, 60))
        d.ellipse([px - 7 * SS, cy - 56 * SS, px + 7 * SS, cy - 42 * SS],
                  fill=(84, 86, 94))
    d.line([cx - 46 * SS, cy - 50 * SS, cx + 46 * SS, cy - 50 * SS],
           fill=(232, 32, 32), width=3 * SS)
    # metal body: dark disc with rim and top plate
    d.ellipse([cx - 40 * SS, cy - 34 * SS, cx + 40 * SS, cy + 42 * SS],
              fill=(28, 29, 34))
    d.ellipse([cx - 34 * SS, cy - 28 * SS, cx + 34 * SS, cy + 36 * SS],
              fill=(58, 60, 68))
    d.ellipse([cx - 28 * SS, cy - 22 * SS, cx + 28 * SS, cy + 30 * SS],
              fill=(74, 77, 86))
    # rivets around the rim
    for ang in range(0, 360, 60):
        a = math.radians(ang)
        x, y = cx + int(31 * SS * math.cos(a)), cy + 4 * SS + int(31 * SS * math.sin(a))
        d.ellipse([x - 3 * SS, y - 3 * SS, x + 3 * SS, y + 3 * SS], fill=(30, 31, 36))
    # red blinking light: glow halo + bright core + white hot spot
    d.ellipse([cx - 14 * SS, cy - 12 * SS, cx + 14 * SS, cy + 16 * SS],
              fill=(232, 32, 32, 90))
    d.ellipse([cx - 9 * SS, cy - 7 * SS, cx + 9 * SS, cy + 11 * SS], fill=(255, 48, 48))
    d.ellipse([cx - 4 * SS, cy - 4 * SS, cx + 4 * SS, cy + 4 * SS], fill=(255, 170, 160))
    return img


save(bomb(), "bomb.png")


# ---------------------------------------------------------------- NEW: cryo mine (frozen disc)
def cryo_mine():
    """Top-down cryo mine: pale blue/white disc with frost spikes and an
    icy core dome."""
    img = canvas()
    d = ImageDraw.Draw(img, "RGBA")
    cx, cy = BIG / 2, BIG / 2
    # soft ground shadow
    d.ellipse([cx - 48 * SS, BIG - 40 * SS, cx + 48 * SS, BIG - 18 * SS],
              fill=(0, 0, 0, 70))
    # outer frost ring
    d.ellipse([cx - 42 * SS, cy - 42 * SS, cx + 42 * SS, cy + 42 * SS],
              fill=(196, 226, 244))
    d.ellipse([cx - 42 * SS, cy - 42 * SS, cx + 42 * SS, cy + 42 * SS],
              outline=(140, 190, 224), width=4 * SS)
    # frost spikes radiating from the centre
    for ang in range(0, 360, 30):
        a = math.radians(ang)
        x0, y0 = cx + int(14 * SS * math.cos(a)), cy + int(14 * SS * math.sin(a))
        x1, y1 = cx + int(38 * SS * math.cos(a)), cy + int(38 * SS * math.sin(a))
        d.line([x0, y0, x1, y1], fill=(255, 255, 255, 230), width=5 * SS)
        # small side branches on alternating spikes
        if ang % 60 == 0:
            bx, by = cx + int(28 * SS * math.cos(a)), cy + int(28 * SS * math.sin(a))
            a2 = a + math.radians(35)
            d.line([bx, by, bx + int(8 * SS * math.cos(a2)), by + int(8 * SS * math.sin(a2))],
                   fill=(255, 255, 255, 200), width=3 * SS)
    # inner icy disc
    d.ellipse([cx - 26 * SS, cy - 26 * SS, cx + 26 * SS, cy + 26 * SS],
              fill=(120, 196, 232))
    d.ellipse([cx - 26 * SS, cy - 26 * SS, cx + 26 * SS, cy + 26 * SS],
              outline=(220, 242, 252), width=3 * SS)
    # core dome: bright centre with sparkle
    d.ellipse([cx - 12 * SS, cy - 12 * SS, cx + 12 * SS, cy + 12 * SS],
              fill=(235, 248, 255))
    d.polygon(star_points(cx - 4 * SS, cy - 4 * SS, 7 * SS, 3 * SS),
              fill=(255, 255, 255, 255))
    return img


save(cryo_mine(), "cryo_mine.png")


# ---------------------------------------------------------------- icon 512 (kept, dark hood + green shirt to match new player)
def icon():
    S = 512
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([4, 4, S - 4, S - 4], radius=110, fill=(32, 32, 38))
    d.rounded_rectangle([14, 14, S - 14, S - 14], radius=100, outline=(47, 224, 90), width=10)
    d.rounded_rectangle([14, 330, S - 14, S - 14], radius=40, fill=(138, 138, 133))
    cx = S // 2
    d.ellipse([cx - 120, 210, cx + 120, 430], fill=(47, 174, 78))
    d.ellipse([cx - 120, 210, cx + 120, 340], fill=(35, 35, 46))
    d.polygon([(cx - 42, 330), (cx + 42, 330), (cx + 26, 470), (cx - 26, 470)], fill=(35, 35, 46))
    d.ellipse([cx - 82, 90, cx + 82, 240], fill=(26, 26, 36))
    d.ellipse([cx - 82, 90, cx + 82, 205], fill=(40, 40, 54))
    d.ellipse([cx - 52, 140, cx + 52, 210], fill=(14, 12, 22))
    d.ellipse([cx - 30, 160, cx - 8, 178], fill=(255, 240, 200))
    d.ellipse([cx + 8, 160, cx + 30, 178], fill=(255, 240, 200))
    d.polygon(star_points(S - 92, 92, 52, 22), fill=(255, 201, 60))
    d.polygon(star_points(S - 92, 92, 34, 15), fill=(255, 232, 140))
    d.polygon(star_points(84, 420, 34, 15), fill=(255, 201, 60))
    img.save(os.path.join(OUT, "..", "icon.png"))
    print("wrote icon.png")


icon()
print("done")
