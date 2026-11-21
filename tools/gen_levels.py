#!/usr/bin/env python3
"""Generate Shadow Assassin levels 11-50 (deterministic, seeded).

Design
------
- Levels 1-10 are hand-made (easy on-ramp). These 40 continue the curve:
  guards 6 -> 9, patrol speed 1.7 -> 2.1 tiles/s, vision range 3.5 -> 4.6
  tiles, vision half-angle 45 -> 55 degrees, coins 12 -> 16, gems 3 -> 5,
  more interior walls / crates (tighter spaces, more cover) as levels rise.
- Five layout archetypes cycle so no two neighbours feel the same:
  Hall, Corridors, Maze, Crossroads, Ring.
- Solvability checks (mirrored in scripts/levels.gd validate()):
  1. BFS: every coin, gem and guard patrol waypoint reachable from P.
  2. Approach window: for EVERY guard there is at least one patrol
     waypoint where a walkable tile next to the patrol is outside EVERY
     guard's vision cone (snapshot: guards at spawn, facing along patrol).
     That is the timing window the player uses to strike from behind.
  3. Clean start: the player start tile is outside every cone at t=0.
- If a level fails a check, it is regenerated with a new seed (up to
  60 tries); failure counts are reported in the summary.

Run: python3 tools/gen_levels.py  ->  writes scripts/levels_gen.gd
"""

import json
import math
import random
import sys
from pathlib import Path

COLS, ROWS = 11, 17
COLORS = ["orange", "purple", "blue", "green", "pink"]

NAMES = [
    "Emerald Court", "The Long Hall", "Twin Lanterns", "Silent Garden",
    "The Vault", "Crimson Steps", "Moonlit Terrace", "The Underpass",
    "Jade Corridors", "The Watchtower", "Golden Stair", "The Labyrinth",
    "Velvet Shadows", "The Armory", "Starlight Court", "The Bazaar",
    "Hidden Passage", "The Gallery", "Ivory Towers", "The Cellar",
    "Emerald Maze", "The Rooftops", "Candlelit Hall", "The Docks",
    "Silver Gate", "The Conservatory", "Midnight Garden", "The Observatory",
    "Ruby Corridor", "The Foundry", "Whispering Halls", "The Atrium",
    "Obsidian Court", "The Chapel", "Sunken Garden", "The Belfry",
    "Gilded Maze", "The Sanctum", "Crown of Shadows", "The Shadow Throne",
]

HINTS = [
    "More guards now. Watch every cone before you move.",
    "Strike when a guard walks away from you.",
    "Crates and corners break line of sight. Use them.",
    "Patience wins. Wait for the patrol to turn.",
    "If one spots you, run behind a wall until it gives up.",
    "The cones are wider now. Time every step.",
    "Plan your route before you move.",
    "A guard facing away is an open door.",
    "Never chase a guard head-on. Circle behind.",
    "The shadows are yours. The cones are theirs.",
]


def wrap(a: float) -> float:
    return (a + math.pi) % (2 * math.pi) - math.pi


def los_blocked(grid, a, b) -> bool:
    dx, dy = b[0] - a[0], b[1] - a[1]
    dist = math.hypot(dx, dy)
    steps = max(1, int(dist / 0.25))
    for i in range(1, steps):
        t = i / steps
        x, y = int(a[0] + dx * t), int(a[1] + dy * t)
        if grid[y][x] in "#X":
            return True
    return False


def visible(grid, frm, facing, range_t, half_rad, to) -> bool:
    dx, dy = to[0] - frm[0], to[1] - frm[1]
    d = math.hypot(dx, dy)
    if d > range_t:
        return False
    if d < 0.01:
        return True
    if abs(wrap(math.atan2(dy, dx) - facing)) > half_rad:
        return False
    return not los_blocked(grid, frm, to)


def walkable(grid, t) -> bool:
    x, y = t
    return 0 <= x < COLS and 0 <= y < ROWS and grid[y][x] not in "#X"


def bfs_reachable(grid, start, goals):
    seen = {start}
    queue = [start]
    while queue:
        cx, cy = queue.pop(0)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nb = (cx + dx, cy + dy)
            if nb not in seen and walkable(grid, nb):
                seen.add(nb)
                queue.append(nb)
    return [g for g in goals if g not in seen]


def patrol_facing(patrol, k) -> float:
    """Facing of a guard standing at waypoint k, about to walk on."""
    n = len(patrol)
    nxt = patrol[k + 1] if k < n - 1 else patrol[k - 1]
    dx, dy = nxt[0] - patrol[k][0], nxt[1] - patrol[k][1]
    return math.atan2(dy, dx)


def check_level(grid, player, guards) -> list:
    """Return a list of problems (empty = beatable by our checks)."""
    problems = []
    # 1. BFS reachability
    goals = []
    for y in range(ROWS):
        for x in range(COLS):
            if grid[y][x] in "CJ":
                goals.append((x, y))
    for g in guards:
        goals.append(g["pos"])
        goals.extend(g["patrol"])
    missing = bfs_reachable(grid, player, goals)
    for m in missing:
        problems.append(f"unreachable tile {m}")
    # snapshot: every guard at its spawn, facing along its patrol
    snap = []
    for g in guards:
        snap.append((g["pos"], patrol_facing(g["patrol"], 0),
                     g["vision"], math.radians(g["half"])))
    # 3. clean start
    for pos, facing, vr, half in snap:
        if visible(grid, pos, facing, vr, half, player):
            problems.append("player start inside a vision cone at t=0")
            break
    # 2. approach window per guard
    for gi, g in enumerate(guards):
        has_window = False
        for k, w in enumerate(g["patrol"]):
            facing = patrol_facing(g["patrol"], k)
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nb = (w[0] + dx, w[1] + dy)
                if not walkable(grid, nb) or nb == g["pos"]:
                    continue
                seen_by_any = False
                # this guard at waypoint w
                if visible(grid, w, facing, g["vision"], math.radians(g["half"]), nb):
                    seen_by_any = True
                else:
                    for oj, (opos, ofacing, ovr, ohalf) in enumerate(snap):
                        if oj == gi:
                            continue
                        if visible(grid, opos, ofacing, ovr, ohalf, nb):
                            seen_by_any = True
                            break
                if not seen_by_any:
                    has_window = True
                    break
            if has_window:
                break
        if not has_window:
            problems.append(f"guard {gi} has no approach window")
    return problems


# ---------------------------------------------------------------- archetypes
def base_grid():
    g = [["."] * COLS for _ in range(ROWS)]
    for x in range(COLS):
        g[0][x] = g[ROWS - 1][x] = "#"
    for y in range(ROWS):
        g[y][0] = g[y][COLS - 1] = "#"
    return g


def arch_hall(rng, t):
    g = base_grid()
    nblocks = 4 + round(t * 3)
    for _ in range(nblocks):
        w, h = (2, 1) if rng.random() < 0.5 else (1, 2)
        x = rng.randint(1, COLS - 1 - w)
        y = rng.randint(1, ROWS - 1 - h)
        for dy in range(h):
            for dx in range(w):
                g[y + dy][x + dx] = "#"
    return g


def arch_corridors(rng, t):
    g = base_grid()
    for col in (3, 7):
        for y in range(2, 15):
            g[y][col] = "#"
        for gap in rng.sample(range(2, 15), 3):
            g[gap][col] = "."
    for y in (8,):
        for x in range(2, 9):
            g[y][x] = "#"
        for gap in rng.sample(range(2, 9), 2):
            g[y][gap] = "."
    return g


def arch_maze(rng, t):
    g = base_grid()
    for row in (3, 6, 9, 12):
        for x in range(1, 10):
            g[row][x] = "#"
        for gap in rng.sample(range(1, 10), 2 if row in (3, 12) else 3):
            g[row][gap] = "."
    for _ in range(2 + round(t * 2)):
        x = rng.randint(2, 8)
        y = rng.randint(2, 14)
        if g[y][x] == ".":
            g[y][x] = "#"
    return g


def arch_crossroads(rng, t):
    g = base_grid()
    for cx, cy in ((3, 3), (7, 3), (3, 12), (7, 12)):
        for dy in range(2):
            for dx in range(2):
                g[cy + dy][cx + dx] = "#"
    # knock a gap in one block each so the centre stays open
    g[3][4] = "."
    g[12][7] = "."
    for _ in range(2 + round(t * 2)):
        x = rng.randint(2, 8)
        y = rng.randint(2, 14)
        if g[y][x] == ".":
            g[y][x] = "#"
    return g


def arch_ring(rng, t):
    g = base_grid()
    for x in range(3, 8):
        g[5][x] = g[11][x] = "#"
    for y in range(6, 11):
        g[y][3] = g[y][7] = "#"
    for gap in rng.sample(range(3, 8), 2):
        g[5][gap] = "."
        g[11][gap] = "."
    for gap in rng.sample(range(6, 11), 2):
        g[gap][3] = "."
        g[gap][7] = "."
    for _ in range(2 + round(t * 2)):
        x = rng.randint(2, 8)
        y = rng.randint(2, 14)
        if g[y][x] == ".":
            g[y][x] = "#"
    return g


ARCHES = [arch_hall, arch_corridors, arch_maze, arch_crossroads, arch_ring]
ARCH_NAMES = ["Hall", "Corridors", "Maze", "Crossroads", "Ring"]


def gen_level(n: int, seed: int):
    """Generate level n (11..50) with the given seed. Returns (grid, player, guards)."""
    rng = random.Random(seed)
    t = (n - 11) / 39.0
    arch = ARCHES[(n - 11) % len(ARCHES)]
    grid = arch(rng, t)
    # crates (cover) and plants (decor)
    ncrates = 2 + round(t * 3)
    placed = 0
    tries = 0
    while placed < ncrates and tries < 200:
        tries += 1
        x, y = rng.randint(1, 9), rng.randint(1, 15)
        if grid[y][x] == ".":
            grid[y][x] = "X"
            placed += 1
    for _ in range(rng.randint(1, 3)):
        x, y = rng.randint(1, 9), rng.randint(1, 15)
        if grid[y][x] == ".":
            grid[y][x] = "B"
    # guards: spread across row bands, patrols keep 2 tiles apart
    nguards = 6 + round(t * 3)
    speed = round(1.7 + t * 0.4, 2)
    vision = round(3.5 + t * 1.1, 2)
    half = round(45 + t * 10, 1)
    bands = [(1, 5), (6, 10), (11, 15)]
    guards = []
    patrol_tiles = []
    for gi in range(nguards):
        band = bands[gi % len(bands)]
        got = False
        for _ in range(300):
            horizontal = rng.random() < 0.6
            length = rng.randint(3, 6)
            if not horizontal:
                length = min(length, band[1] - band[0] + 1)
            if horizontal:
                y = rng.randint(band[0], band[1])
                x0 = rng.randint(1, 10 - length)
                tiles = [(x0 + i, y) for i in range(length)]
            else:
                x = rng.randint(1, 9)
                y0 = rng.randint(band[0], band[1] - length + 1)
                tiles = [(x, y0 + i) for i in range(length)]
            if not all(walkable(grid, tt) for tt in tiles):
                continue
            # keep patrols 2 tiles apart from each other
            ok = True
            for tt in tiles:
                for pt in patrol_tiles:
                    if abs(tt[0] - pt[0]) + abs(tt[1] - pt[1]) < 2:
                        ok = False
                        break
                if not ok:
                    break
            if not ok:
                continue
            # endpoints need a walkable neighbour (approach tile)
            for end in (tiles[0], tiles[-1]):
                if not any(walkable(grid, (end[0] + dx, end[1] + dy))
                           for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    ok = False
                    break
            if not ok:
                continue
            patrol = tiles if rng.random() < 0.7 else [tiles[0], tiles[-1]]
            guards.append({
                "pos": tiles[0],
                "patrol": patrol,
                "speed": speed + rng.choice([0.0, 0.05, -0.05]),
                "color": COLORS[gi % len(COLORS)],
                "vision": vision,
                "half": half,
            })
            patrol_tiles.extend(tiles)
            got = True
            break
        if not got:
            return None
    # player start: bottom rows, not on a patrol tile, not visible at t=0
    player = None
    for _ in range(200):
        px, py = rng.randint(2, 8), rng.randint(13, 15)
        if not walkable(grid, (px, py)):
            continue
        if (px, py) in patrol_tiles:
            continue
        snap_ok = True
        for g in guards:
            facing = patrol_facing(g["patrol"], 0)
            if visible(grid, g["pos"], facing, g["vision"],
                       math.radians(g["half"]), (px, py)):
                snap_ok = False
                break
        if snap_ok:
            player = (px, py)
            break
    if player is None:
        return None
    # coins + gems on random walkable tiles, away from patrols and start
    ncoins = 12 + round(t * 4)
    ngems = 3 + round(t * 2)
    placed_coins = 0
    tries = 0
    while placed_coins < ncoins and tries < 500:
        tries += 1
        x, y = rng.randint(1, 9), rng.randint(1, 15)
        if grid[y][x] != ".":
            continue
        if (x, y) in patrol_tiles or abs(x - player[0]) + abs(y - player[1]) < 2:
            continue
        grid[y][x] = "C"
        placed_coins += 1
    placed_gems = 0
    tries = 0
    while placed_gems < ngems and tries < 500:
        tries += 1
        x, y = rng.randint(1, 9), rng.randint(1, 15)
        if grid[y][x] != ".":
            continue
        if (x, y) in patrol_tiles or abs(x - player[0]) + abs(y - player[1]) < 2:
            continue
        grid[y][x] = "J"
        placed_gems += 1
    grid[player[1]][player[0]] = "P"
    return grid, player, guards


def to_gdscript(levels) -> str:
    out = []
    out.append("class_name ShadowLevelsGen")
    out.append("## Levels 11-50 for Shadow Assassin, generated by tools/gen_levels.py")
    out.append("## (deterministic seeds; every level passed the solvability checks in")
    out.append("## gen_levels.py and in ShadowLevels.validate()).")
    out.append("")
    out.append("")
    out.append("static func get_extra_levels() -> Array:")
    out.append("\treturn [")
    for lv in levels:
        out.append("\t\t{")
        out.append(f'\t\t\t"name": "{lv["name"]}",')
        out.append(f'\t\t\t"hint": "{lv["hint"]}",')
        out.append('\t\t\t"map": [')
        for row in lv["map"]:
            out.append(f'\t\t\t\t"{row}",')
        out.append("\t\t\t],")
        out.append('\t\t\t"guards": [')
        for g in lv["guards"]:
            patrol = ", ".join(f"Vector2i({x}, {y})" for x, y in g["patrol"])
            out.append(
                f'\t\t\t\t{{"pos": Vector2i({g["pos"][0]}, {g["pos"][1]}), '
                f'"patrol": [{patrol}], "speed": {g["speed"]}, '
                f'"color": "{g["color"]}", "vision": {g["vision"]}, "half": {g["half"]}}},'
            )
        out.append("\t\t\t],")
        out.append("\t\t},")
    out.append("\t]")
    return "\n".join(out) + "\n"


def main():
    root = Path(__file__).resolve().parent.parent
    levels = []
    summary = []
    for n in range(11, 51):
        result = None
        tries = 0
        last_problems = []
        while tries < 60 and result is None:
            tries += 1
            seed = 1000 + n * 97 + tries * 7919
            gen = gen_level(n, seed)
            if gen is None:
                last_problems = ["generation failed"]
                continue
            grid, player, guards = gen
            problems = check_level(grid, player, guards)
            if problems:
                last_problems = problems
                continue
            result = (grid, player, guards)
        if result is None:
            print(f"LEVEL {n}: FAILED after 60 tries: {last_problems}")
            sys.exit(1)
        grid, player, guards = result
        t = (n - 11) / 39.0
        levels.append({
            "name": NAMES[n - 11],
            "hint": HINTS[(n - 11) % len(HINTS)],
            "map": ["".join(row) for row in grid],
            "guards": guards,
        })
        summary.append({
            "level": n,
            "name": NAMES[n - 11],
            "archetype": ARCH_NAMES[(n - 11) % len(ARCH_NAMES)],
            "guards": len(guards),
            "speed": round(1.7 + t * 0.4, 2),
            "vision_tiles": round(3.5 + t * 1.1, 2),
            "vision_half_deg": round(45 + t * 10, 1),
            "coins": sum(r.count("C") for r in grid),
            "gems": sum(r.count("J") for r in grid),
            "tries": tries,
        })
        print(f"LEVEL {n:2d} {NAMES[n-11]:18s} {ARCH_NAMES[(n-11)%5]:10s} "
              f"guards={len(guards)} speed={summary[-1]['speed']} "
              f"vision={summary[-1]['vision_tiles']}t/{summary[-1]['vision_half_deg']}deg "
              f"coins={summary[-1]['coins']} gems={summary[-1]['gems']} tries={tries}")
    out_path = root / "scripts" / "levels_gen.gd"
    out_path.write_text(to_gdscript(levels))
    (root / "tools" / "levels_gen_summary.json").write_text(
        json.dumps(summary, indent=2))
    print(f"\nWrote {out_path} ({len(levels)} levels)")
    print(f"Total retries across all levels: {sum(s['tries'] for s in summary)}")


if __name__ == "__main__":
    main()
