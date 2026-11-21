#!/usr/bin/env python3
"""Generate original art for Shadow Assassin (top-down 2D stealth game).

All sprites are drawn from scratch with PIL - no copied assets.
Style: bright teal/green floors, red/orange accents, gold highlights,
dark player with a red scarf. Supersampled 4x then downscaled for crisp AA.
"""
import math
import os
from PIL import Image, ImageDraw

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


# ---------------------------------------------------------------- floor tiles
def floor_tile(base, light, dark, deco=None):
    img = canvas()
    d = ImageDraw.Draw(img)
    rr(d, [4 * SS, 4 * SS, BIG - 4 * SS, BIG - 4 * SS], 26 * SS, fill=base)
    rr(d, [16 * SS, 16 * SS, BIG - 16 * SS, BIG - 16 * SS], 18 * SS, fill=light)
    # grout dots at corners
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
# sandy path tile (extra colour)
save(floor_tile((232, 190, 96), (244, 208, 130), (190, 150, 60), "leaf"), "floor_sand.png")

# ---------------------------------------------------------------- wall
def wall():
    img = canvas()
    d = ImageDraw.Draw(img)
    rr(d, [4 * SS, 4 * SS, BIG - 4 * SS, BIG - 4 * SS], 20 * SS, fill=(43, 45, 66))
    rr(d, [14 * SS, 14 * SS, BIG - 14 * SS, BIG - 14 * SS], 14 * SS, fill=(56, 59, 86))
    # gold top trim
    rr(d, [14 * SS, 14 * SS, BIG - 14 * SS, 34 * SS], 10 * SS, fill=(255, 201, 60))
    d.rectangle([14 * SS, 24 * SS, BIG - 14 * SS, 34 * SS], fill=(255, 201, 60))
    # rivets
    for x in (34 * SS, BIG / 2, BIG - 34 * SS):
        d.ellipse([x - 6 * SS, 18 * SS, x + 6 * SS, 30 * SS], fill=(255, 232, 140))
    # brick lines
    for y in (58 * SS, 84 * SS):
        d.line([16 * SS, y, BIG - 16 * SS, y], fill=(43, 45, 66), width=4 * SS)
    d.line([BIG / 2, 34 * SS, BIG / 2, 58 * SS], fill=(43, 45, 66), width=4 * SS)
    d.line([BIG / 3, 58 * SS, BIG / 3, 84 * SS], fill=(43, 45, 66), width=4 * SS)
    d.line([2 * BIG / 3, 58 * SS, 2 * BIG / 3, 84 * SS], fill=(43, 45, 66), width=4 * SS)
    return img


save(wall(), "wall.png")


# ---------------------------------------------------------------- crate
def crate():
    img = canvas()
    d = ImageDraw.Draw(img)
    rr(d, [10 * SS, 10 * SS, BIG - 10 * SS, BIG - 10 * SS], 14 * SS, fill=(176, 122, 69))
    rr(d, [20 * SS, 20 * SS, BIG - 20 * SS, BIG - 20 * SS], 10 * SS, fill=(198, 145, 88))
    d.line([20 * SS, BIG / 2, BIG - 20 * SS, BIG / 2], fill=(140, 94, 50), width=5 * SS)
    d.line([BIG / 2, 20 * SS, BIG / 2, BIG - 20 * SS], fill=(140, 94, 50), width=5 * SS)
    # gold corner brackets
    for (x, y) in [(20, 20), (BIG - 20, 20), (20, BIG - 20), (BIG - 20, BIG - 20)]:
        d.ellipse([x - 9 * SS, y - 9 * SS, x + 9 * SS, y + 9 * SS], fill=(255, 201, 60))
    return img


save(crate(), "crate.png")


# ---------------------------------------------------------------- plant
def plant():
    img = canvas()
    d = ImageDraw.Draw(img)
    # pot
    d.polygon([(BIG / 2 - 34 * SS, BIG / 2 + 6 * SS), (BIG / 2 + 34 * SS, BIG / 2 + 6 * SS),
               (BIG / 2 + 24 * SS, BIG - 16 * SS), (BIG / 2 - 24 * SS, BIG - 16 * SS)],
              fill=(214, 96, 60))
    d.rectangle([BIG / 2 - 38 * SS, BIG / 2 - 2 * SS, BIG / 2 + 38 * SS, BIG / 2 + 12 * SS],
                fill=(232, 120, 80))
    # leaves
    for (dx, dy, r, col) in [(-18, -16, 26, (46, 160, 90)), (16, -22, 30, (62, 190, 110)),
                             (0, -34, 28, (38, 140, 80)), (-30, 2, 20, (62, 190, 110)),
                             (30, 0, 20, (46, 160, 90))]:
        cx, cy = BIG / 2 + dx * SS, BIG / 2 + dy * SS
        d.ellipse([cx - r * SS, cy - r * SS, cx + r * SS, cy + r * SS], fill=col)
    return img


save(plant(), "plant.png")


# ---------------------------------------------------------------- characters
def shadow(d):
    d.ellipse([BIG / 2 - 46 * SS, BIG - 52 * SS, BIG / 2 + 46 * SS, BIG - 22 * SS],
              fill=(0, 0, 0, 90))


def character(body, body_dark, accent, helmet=None, scarf=True):
    """Top-down character facing UP (north). Scarf trails at the south."""
    img = canvas()
    d = ImageDraw.Draw(img)
    shadow(d)
    # shoulders / cloak
    d.ellipse([BIG / 2 - 46 * SS, BIG / 2 - 8 * SS, BIG / 2 + 46 * SS, BIG - 26 * SS], fill=body)
    d.ellipse([BIG / 2 - 46 * SS, BIG / 2 - 8 * SS, BIG / 2 + 46 * SS, BIG / 2 + 34 * SS],
              fill=body_dark)
    # gold belt
    d.rectangle([BIG / 2 - 40 * SS, BIG / 2 + 22 * SS, BIG / 2 + 40 * SS, BIG / 2 + 30 * SS],
                fill=(255, 201, 60))
    d.ellipse([BIG / 2 - 8 * SS, BIG / 2 + 20 * SS, BIG / 2 + 8 * SS, BIG / 2 + 32 * SS],
              fill=(255, 232, 140))
    # scarf trailing south
    if scarf:
        d.polygon([(BIG / 2 - 16 * SS, BIG / 2 + 34 * SS), (BIG / 2 + 16 * SS, BIG / 2 + 34 * SS),
                   (BIG / 2 + 10 * SS, BIG - 8 * SS), (BIG / 2 - 10 * SS, BIG - 8 * SS)],
                  fill=accent)
        d.polygon([(BIG / 2 - 8 * SS, BIG / 2 + 34 * SS), (BIG / 2 + 8 * SS, BIG / 2 + 34 * SS),
                   (BIG / 2 + 4 * SS, BIG - 14 * SS), (BIG / 2 - 4 * SS, BIG - 14 * SS)],
                  fill=(255, 255, 255, 70))
    # head / hood
    d.ellipse([BIG / 2 - 30 * SS, 22 * SS, BIG / 2 + 30 * SS, 82 * SS], fill=body_dark)
    d.ellipse([BIG / 2 - 30 * SS, 22 * SS, BIG / 2 + 30 * SS, 66 * SS], fill=body)
    if helmet:
        # coloured helmet dome + gold band + plume
        d.ellipse([BIG / 2 - 30 * SS, 18 * SS, BIG / 2 + 30 * SS, 74 * SS], fill=helmet)
        d.arc([BIG / 2 - 30 * SS, 18 * SS, BIG / 2 + 30 * SS, 74 * SS], 0, 180, fill=(255, 201, 60),
              width=7 * SS)
        d.ellipse([BIG / 2 - 6 * SS, 6 * SS, BIG / 2 + 6 * SS, 26 * SS], fill=accent)
        # face slit
        d.ellipse([BIG / 2 - 16 * SS, 44 * SS, BIG / 2 + 16 * SS, 66 * SS], fill=(30, 28, 40))
        d.ellipse([BIG / 2 - 10 * SS, 50 * SS, BIG / 2 - 2 * SS, 58 * SS], fill=(255, 240, 200))
        d.ellipse([BIG / 2 + 2 * SS, 50 * SS, BIG / 2 + 10 * SS, 58 * SS], fill=(255, 240, 200))
    else:
        # hood opening: dark face with two eyes
        d.ellipse([BIG / 2 - 19 * SS, 38 * SS, BIG / 2 + 19 * SS, 70 * SS], fill=(16, 14, 26))
        d.ellipse([BIG / 2 - 11 * SS, 48 * SS, BIG / 2 - 3 * SS, 56 * SS], fill=(255, 240, 200))
        d.ellipse([BIG / 2 + 3 * SS, 48 * SS, BIG / 2 + 11 * SS, 56 * SS], fill=(255, 240, 200))
        # hood rim highlight
        d.arc([BIG / 2 - 30 * SS, 22 * SS, BIG / 2 + 30 * SS, 82 * SS], 200, 340,
              fill=(120, 120, 160), width=5 * SS)
    # little dagger at the right side
    d.polygon([(BIG / 2 + 40 * SS, BIG / 2 + 6 * SS), (BIG / 2 + 52 * SS, BIG / 2 + 18 * SS),
               (BIG / 2 + 44 * SS, BIG / 2 + 26 * SS)], fill=(220, 225, 235))
    d.rectangle([BIG / 2 + 38 * SS, BIG / 2 + 22 * SS, BIG / 2 + 46 * SS, BIG / 2 + 30 * SS],
                fill=(120, 80, 40))
    return img


# Player: dark navy/charcoal with a red scarf
save(character((35, 35, 58), (22, 22, 38), (230, 57, 70)), "player.png")
# Guards: bright helmet colours, gold trim, red plume
save(character((244, 132, 43), (200, 100, 25), (230, 57, 70), helmet=(244, 132, 43)), "guard_orange.png")
save(character((142, 68, 173), (110, 50, 140), (230, 57, 70), helmet=(142, 68, 173)), "guard_purple.png")
save(character((46, 134, 222), (30, 100, 180), (230, 57, 70), helmet=(46, 134, 222)), "guard_blue.png")
save(character((39, 174, 96), (28, 140, 74), (230, 57, 70), helmet=(39, 174, 96)), "guard_green.png")
save(character((232, 67, 147), (190, 45, 115), (255, 201, 60), helmet=(232, 67, 147)), "guard_pink.png")


# ---------------------------------------------------------------- pickups
def coin():
    img = canvas()
    d = ImageDraw.Draw(img)
    d.ellipse([BIG / 2 - 38 * SS, BIG / 2 - 38 * SS, BIG / 2 + 38 * SS, BIG / 2 + 38 * SS],
              fill=(255, 201, 60))
    d.ellipse([BIG / 2 - 30 * SS, BIG / 2 - 30 * SS, BIG / 2 + 30 * SS, BIG / 2 + 30 * SS],
              fill=(255, 217, 92))
    d.polygon(star_points(BIG / 2, BIG / 2, 22 * SS, 9 * SS), fill=(240, 170, 20))
    d.arc([BIG / 2 - 30 * SS, BIG / 2 - 30 * SS, BIG / 2 + 30 * SS, BIG / 2 + 30 * SS],
          200, 320, fill=(255, 255, 255, 200), width=6 * SS)
    return img


save(coin(), "coin.png")


def gem(col, light):
    img = canvas()
    d = ImageDraw.Draw(img)
    cx, cy = BIG / 2, BIG / 2
    d.polygon([(cx, cy - 36 * SS), (cx + 30 * SS, cy - 8 * SS), (cx, cy + 38 * SS),
               (cx - 30 * SS, cy - 8 * SS)], fill=col)
    d.polygon([(cx, cy - 36 * SS), (cx + 30 * SS, cy - 8 * SS), (cx, cy - 8 * SS),
               (cx - 30 * SS, cy - 8 * SS)], fill=light)
    d.line([cx, cy - 36 * SS, cx, cy + 38 * SS], fill=(255, 255, 255, 160), width=4 * SS)
    d.polygon(star_points(cx - 12 * SS, cy - 16 * SS, 10 * SS, 4 * SS), fill=(255, 255, 255, 220))
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


# ---------------------------------------------------------------- icon 512
def icon():
    S = 512
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([4, 4, S - 4, S - 4], radius=110, fill=(18, 60, 66))
    d.rounded_rectangle([14, 14, S - 14, S - 14], radius=100, outline=(255, 201, 60), width=10)
    # teal floor band
    d.rounded_rectangle([14, 330, S - 14, S - 14], radius=40, fill=(43, 178, 163))
    # hooded figure (reuse shapes, bigger)
    cx = S // 2
    d.ellipse([cx - 120, 210, cx + 120, 430], fill=(35, 35, 58))
    d.ellipse([cx - 120, 210, cx + 120, 340], fill=(22, 22, 38))
    d.polygon([(cx - 42, 330), (cx + 42, 330), (cx + 26, 470), (cx - 26, 470)], fill=(230, 57, 70))
    d.ellipse([cx - 82, 90, cx + 82, 240], fill=(22, 22, 38))
    d.ellipse([cx - 82, 90, cx + 82, 205], fill=(35, 35, 58))
    d.ellipse([cx - 52, 140, cx + 52, 210], fill=(16, 14, 26))
    d.ellipse([cx - 30, 160, cx - 8, 178], fill=(255, 240, 200))
    d.ellipse([cx + 8, 160, cx + 30, 178], fill=(255, 240, 200))
    # gold star
    d.polygon(star_points(S - 92, 92, 52, 22), fill=(255, 201, 60))
    d.polygon(star_points(S - 92, 92, 34, 15), fill=(255, 232, 140))
    d.polygon(star_points(84, 420, 34, 15), fill=(255, 201, 60))
    img.save(os.path.join(OUT, "..", "icon.png"))
    print("wrote icon.png")


icon()
print("done")
