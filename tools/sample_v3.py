#!/usr/bin/env python3
"""Pixel-sample v3 palette screenshots (levels 1/5/10, early capture).

Uses the level maps in scripts/levels.gd to locate floor / wall / crate /
bush / player / guard tiles. Tile (x, y) centre in the 720x1280 shot:
origin = ((720 - 11*64)/2, 150) = (8, 150), tile 64px.
Guards face north at spawn, so the vision cone is sampled ~90px north of
each guard's spawn tile centre.
"""
import math
import os
import re
import statistics
import sys

from PIL import Image

PROJ = os.path.expanduser("~/workspace/game-shadow-assassin")
OX, OY, TILE = 8, 150, 64


def lum(rgb):
    r, g, b = rgb
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def dist(a, b):
    return math.sqrt(sum((x - y) ** 2 for x, y in zip(a, b)))


def patch_median(img, cx, cy, half=2):
    px = []
    for y in range(cy - half, cy + half + 1):
        for x in range(cx - half, cx + half + 1):
            if 0 <= x < img.width and 0 <= y < img.height:
                px.append(img.getpixel((x, y))[:3])
    px.sort(key=lambda p: lum(p))
    return px[len(px) // 2]


def patch_best(img, cx, cy, half=12):
    """Most saturated pixel in a patch (best representative of a character)."""
    best, best_sat = None, -1.0
    for y in range(cy - half, cy + half + 1):
        for x in range(cx - half, cx + half + 1):
            if 0 <= x < img.width and 0 <= y < img.height:
                r, g, b = img.getpixel((x, y))[:3]
                sat = (max(r, g, b) - min(r, g, b)) / 255.0
                if sat > best_sat:
                    best_sat, best = sat, (r, g, b)
    return best, best_sat


def parse_levels():
    src = open(os.path.join(PROJ, "scripts/levels.gd")).read()
    parts = re.split(r'"name":\s*"', src)[1:]
    levels = []
    for part in parts[:10]:
        rows = re.findall(r'"([#X\.PCBJF]+)"', part.split('"guards"')[0])
        # rows above: the map block is the first run of 17 quoted strings
        rows = rows[:17]
        gpos = re.findall(r'"pos":\s*Vector2i\((\d+),\s*(\d+)\)', part)
        gtype = re.findall(r'"type":\s*"(\w+)"', part)
        player = [(x, y) for y, r in enumerate(rows) for x, c in enumerate(r) if c == "P"]
        levels.append({"map": rows,
                       "guards": [(int(x), int(y)) for x, y in gpos],
                       "gtypes": gtype,
                       "player": player[0] if player else None})
    return levels


def tile_c(t):
    x, y = t
    return (OX + x * TILE + TILE // 2, OY + y * TILE + TILE // 2)


def analyse(variant):
    levels = parse_levels()
    print(f"=== variant: {variant} ===")
    for li in (0, 4, 9):
        lvl = levels[li]
        path = os.path.join(PROJ, "verification/shots-v3-palette", variant,
                            f"level_{li + 1}_early.png")
        img = Image.open(path).convert("RGB")
        rows = lvl["map"]
        occ = set(lvl["guards"]) | ({lvl["player"]} if lvl["player"] else set())

        def tiles(ch):
            out = []
            for y, r in enumerate(rows):
                for x, c in enumerate(r):
                    if c == ch and (x, y) not in occ:
                        # keep 1 tile clear of characters (79px sprites bleed)
                        if all(abs(x - gx) + abs(y - gy) > 1 for gx, gy in occ):
                            out.append((x, y))
            return out

        def med(ch):
            # full-tile per-channel median: robust to cracks / mortar lines /
            # banner overlap on a few tiles
            vals = []
            for t in tiles(ch):
                cx, cy = tile_c(t)
                px = [img.getpixel((x, y))[:3]
                      for y in range(cy - 30, cy + 31)
                      for x in range(cx - 30, cx + 31)]
                vals.append(tuple(statistics.median([p[i] for p in px]) for i in range(3)))
            if not vals:
                return None
            return tuple(round(statistics.median([v[i] for v in vals])) for i in range(3))

        floor = med(".")
        wall = med("#")
        crate = med("X")
        bush = med("B")
        print(f"  L{li + 1}: floor={floor} lum={lum(floor):.0f} | wall={wall} lum={lum(wall):.0f} "
              f"| crate={crate} lum={lum(crate):.0f} | bush={bush}")
        print(f"       floor-wall lum gap={lum(floor) - lum(wall):+.0f} | "
              f"crate-floor colour dist={dist(crate, floor):.0f} | "
              f"wall-floor colour dist={dist(wall, floor):.0f}")
        # player
        px, py = tile_c(lvl["player"])
        pmed = patch_median(img, px, py, half=6)
        pbest, psat = patch_best(img, px, py)
        print(f"       player tile med={pmed} best-sat px={pbest} (sat {psat:.2f}) "
              f"dist-to-floor={dist(pbest, floor):.0f}")
        # guards + cones
        for gi, g in enumerate(lvl["guards"]):
            gx, gy = tile_c(g)
            gmed = patch_median(img, gx, gy, half=6)
            gbest, gsat = patch_best(img, gx, gy)
            # cone: guards patrol/turn, so facing at capture time is unknown.
            # Robust check: brightest pixel in an annulus (r 55..120) around
            # the guard — the white cone covers a ~90-degree wedge there, so
            # its max luminance must sit clearly above the floor.
            cone_max = 0.0
            for y in range(gy - 120, gy + 121):
                for x in range(gx - 120, gx + 121):
                    r = ((x - gx) ** 2 + (y - gy) ** 2) ** 0.5
                    if 55 <= r <= 120 and 0 <= x < img.width and 0 <= y < img.height:
                        cone_max = max(cone_max, lum(img.getpixel((x, y))[:3]))
            cone_med = (0, 0, 0)
            gt = lvl["gtypes"][gi] if gi < len(lvl["gtypes"]) else "?"
            print(f"       guard {gt} @{g} med={gmed} best-sat px={gbest} (sat {gsat:.2f}) "
                  f"dist-to-floor={dist(gbest, floor):.0f} | cone annulus max lum={cone_max:.0f} "
                  f"(floor {lum(floor):.0f}, +{cone_max - lum(floor):+.0f})")


if __name__ == "__main__":
    for v in sys.argv[1:]:
        analyse(v)
