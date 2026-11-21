#!/usr/bin/env python3
"""Generate Shadow Assassin levels 1-50 (deterministic, seeded).

Levels 1-10 are produced by this same generator (fixed seeds, curated
names/hints) and pasted into scripts/levels.gd; levels 11-50 are written
to scripts/levels_gen.gd. One engine, one set of checks, so the two
files can never drift apart.

Design (from docs/reference/hunter-assassin-research-2026-11-21.md §4-5)
-----------------------------------------------------------------------
- Every level is a DENSE maze on one 11x17 portrait screen: crates and
  walls everywhere, corridors 1-2 tiles wide, almost no big empty floor.
  Enforced three ways: a blocked-tile fraction target (32% at L1 rising
  to ~47% at L50), a ban on any 3x3 all-floor square, and a connectivity
  repair so the maze stays fully traversable.
- Guard counts follow the real game: L1 2, L2 3, L3 3 (Double Kill set
  up: two guards patrolling side by side in one corridor), L4-6 4,
  L7-9 5, L10 6, L11-20 6, L21-30 7, L31-40 8, L41-50 9. Difficulty
  rises by guard count, overlapping cones, faster patrols, new enemy
  types and traps -- NOT by map size (every map is 11x17).
- Patrols are LONG A*-routed paths (7-16 tiles) that roam all over the
  map, not short 2-6 tile straight segments: the guard walks the path
  out and back (ping-pong), so the player has to watch patrols, time
  moves and sneak up behind guards. Routes may cross each other —
  guards criss-crossing the same corridors is the point (overlapping
  cones); the game pushes guards apart if they meet.
  (L3 keeps its short parallel Double Kill pair by design.)
- KEY + EXIT win condition: every level has exactly one key 'K' and one
  exit 'E' in the map. The key sits 1-3 tiles from a patrol route,
  closest to the patrol centroid, >= 4 tiles from the player start --
  reaching it means dealing with the guards. The exit is the farthest
  reachable tile from the player start (BFS distance >= 10, Manhattan
  >= 8, never on a patrol route), usually at the opposite end of the
  map. Both are BFS-reachable, and reachable on a path that avoids all
  trap tiles. Win = collect the key, then reach the exit.
- Enemy types (guard "type", optional field, default "basic"):
  basic L1-2 only, rifle from L3, shotgun from L5, grenade from L8,
  sniper (long narrow cone) from L20, shielded from L30. Colour is
  tied to type (basic/shielded green -- they never share a level,
  rifle orange, shotgun pink, grenade blue, sniper purple).
- Themes (level "theme", optional, default "warehouse"): warehouse
  L1-12, cyber L13-25, lab L26-37, prison L38-50.
- Traps (level "traps", optional, absent when empty): from L15, bomb
  tripwires and cryo mines as {"pos": (x, y), "kind": "bomb"|"cryo"}.
  Sparse (1-3 per level), never on a patrol route, never next to the
  player start, and never unavoidable (every goal stays reachable on
  a path that avoids all trap tiles). Bushes are the existing walkable
  'B' plant tiles -- hiding spots, more of them from L15.
- Coins + gems on every level, counts rising gently (coins 7 -> 18,
  gems 1 -> 6); gems are placed riskier -- next to patrol routes and
  in corners -- so reaching them means getting close to a guard.

Solvability checks (mirrored in scripts/levels.gd validate()):
  1. BFS: every coin, gem, guard spawn and patrol-route tile reachable.
  2. Approach window: for EVERY guard there is a patrol waypoint with
     a walkable neighbour tile that is outside EVERY guard's vision
     cone (snapshot: guards at spawn, facing along patrol), not on any
     patrol route, and not a trap tile -- the timing window to strike
     from behind. OR the "sneak up behind" window: the tile two steps
     back along the guard's own patrol, outside his forward cone and
     every other guard's cone -- the player follows the patrol from
     behind. Guards shoot on sight, so the window must let the player
     reach the guard's back without crossing a live cone.
  3. Clean start: the player start tile is outside every cone at t=0,
     NOT on any patrol route tile, and >= 3 tiles from every guard
     spawn -- no instant catch from a guard walking past.
  4. Density: blocked fraction >= target, and no 3x3 all-floor square.
  5. Trap fairness: every goal reachable on a path avoiding traps.
  6. Key + exit: exactly one key 'K' (1-3 tiles from a patrol route,
     >= 4 from the player start) and one exit 'E' (far from the player
     start, never on a patrol route), both reachable, both reachable
     on a path avoiding traps.
If a level fails a check, it is regenerated with a new seed (up to
400 tries, density target relaxing slightly after many failures);
failure counts are reported in the summary.

Run: python3 tools/gen_levels.py  ->  writes scripts/levels_gen.gd,
  tools/levels_gen_summary.json and tools/levels_1_10_fragment.gd
  (paste the fragment into scripts/levels.gd as levels 1-10).
"""

import json
import math
import random
import sys
from pathlib import Path

COLS, ROWS = 11, 17
INTERIOR = 9 * 15  # x 1..9, y 1..15
FAIL_REASON = ""  # last stage that made gen_level() bail (diagnostics)

# --- level curves -------------------------------------------------------
GUARD_COUNT_1_10 = {1: 2, 2: 3, 3: 3, 4: 4, 5: 4, 6: 4, 7: 5, 8: 5, 9: 5, 10: 6}


def guard_count(n: int) -> int:
    if n <= 10:
        return GUARD_COUNT_1_10[n]
    if n <= 20:
        return 6
    if n <= 30:
        return 7
    if n <= 40:
        return 8
    return 9


def base_speed(n: int) -> float:
    if n <= 10:
        return round(1.1 + (n - 1) * 0.065, 2)
    t = (n - 11) / 39.0
    return round(1.7 + t * 0.4, 2)


def base_vision(n: int) -> float:
    return round(3.0 + (n - 1) * 0.033, 2)


def base_half(n: int) -> float:
    return round(40.0 + (n - 1) * 0.31, 1)


def theme(n: int) -> str:
    if n <= 12:
        return "warehouse"
    if n <= 25:
        return "cyber"
    if n <= 37:
        return "lab"
    return "prison"


def type_pool(n: int) -> list:
    if n <= 2:
        return ["basic"]
    if n <= 4:
        return ["rifle"]
    if n <= 7:
        return ["rifle", "shotgun"]
    if n <= 19:
        return ["rifle", "shotgun", "grenade"]
    if n <= 29:
        return ["rifle", "shotgun", "grenade", "sniper"]
    return ["rifle", "shotgun", "grenade", "sniper", "shielded"]


TYPE_COLORS = {
    "basic": "green",
    "rifle": "orange",
    "shotgun": "pink",
    "grenade": "blue",
    "sniper": "purple",
    "shielded": "green",  # never shares a level with "basic"
}
ALLOWED_TYPES = set(TYPE_COLORS)
ALLOWED_THEMES = {"warehouse", "cyber", "lab", "prison"}


def assign_types(n: int, count: int) -> list:
    pool = type_pool(n)
    return [pool[i % len(pool)] for i in range(count)]


def coin_count(n: int) -> int:
    return min(18, 7 + (n - 1) // 3)


def gem_count(n: int) -> int:
    return min(6, 1 + (n - 1) // 8)


def density_target(n: int) -> float:
    return 0.32 + (n - 1) * 0.003


def trap_count(n: int) -> int:
    if n < 15:
        return 0
    if n < 25:
        return 1
    if n < 38:
        return 2
    return 3


def bush_count(n: int, rng) -> int:
    return (2 if n < 15 else 4) + rng.randint(0, 1)


NAMES_1_10 = [
    "First Shadows", "Two Watchers", "Garden Patrol", "The Courtyard",
    "Crossroads", "Golden Hall", "The Maze", "Night Watch",
    "Royal Guard", "Shadow Master",
]
HINTS_1_10 = [
    "Tap a floor tile to move. Strike a guard from behind!",
    "Three guards now. Watch the yellow vision cones!",
    "Two guards patrol side by side. Strike them both for a Double Kill!",
    "Four guards. Strike when a guard walks away from you.",
    "Faster guards. If one spots you, break line of sight!",
    "Four guards guard the gold. Patience wins.",
    "A maze of walls. Use corners to stay unseen.",
    "Five guards on night watch. Move like a shadow.",
    "The royal guard never rests. Time every step.",
    "Six guards. One shadow. Prove you are the master.",
]

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
    "Tripwires and cryo mines now. Step carefully.",
    "Bushes hide you -- but traps do not forgive.",
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


def bfs_seen(grid, start, blocked_extra=frozenset()):
    seen = {start}
    queue = [start]
    while queue:
        cx, cy = queue.pop(0)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nb = (cx + dx, cy + dy)
            if nb not in seen and nb not in blocked_extra and walkable(grid, nb):
                seen.add(nb)
                queue.append(nb)
    return seen


def bfs_dist_map(grid, start):
    """BFS distance (in tiles) from start to every reachable tile."""
    dist = {start: 0}
    queue = [start]
    while queue:
        cx, cy = queue.pop(0)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nb = (cx + dx, cy + dy)
            if nb not in dist and walkable(grid, nb):
                dist[nb] = dist[(cx, cy)] + 1
                queue.append(nb)
    return dist


def bfs_path(grid, a, b):
    """Shortest 4-dir path a..b inclusive, or None when unreachable."""
    prev = {a: None}
    queue = [a]
    while queue:
        cur = queue.pop(0)
        if cur == b:
            break
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nb = (cur[0] + dx, cur[1] + dy)
            if nb not in prev and walkable(grid, nb):
                prev[nb] = cur
                queue.append(nb)
    if b not in prev:
        return None
    path = []
    cur = b
    while cur is not None:
        path.append(cur)
        cur = prev[cur]
    path.reverse()
    return path


def patrol_facing(patrol, k) -> float:
    """Facing of a guard standing at waypoint k, about to walk on."""
    n = len(patrol)
    nxt = patrol[k + 1] if k < n - 1 else patrol[k - 1]
    dx, dy = nxt[0] - patrol[k][0], nxt[1] - patrol[k][1]
    return math.atan2(dy, dx)


def route_tiles(patrol) -> list:
    """Every tile a guard walks on: the straight segments between
    consecutive waypoints (the guard ping-pongs along them)."""
    tiles = []
    for a, b in zip(patrol, patrol[1:]):
        if a[0] == b[0]:
            step = 1 if b[1] > a[1] else -1
            tiles.extend((a[0], y) for y in range(a[1], b[1] + step, step))
        else:
            step = 1 if b[0] > a[0] else -1
            tiles.extend((x, a[1]) for x in range(a[0], b[0] + step, step))
    seen = set()
    out = []
    for t in tiles:
        if t not in seen:
            seen.add(t)
            out.append(t)
    return out


def manhattan(a, b) -> int:
    return abs(a[0] - b[0]) + abs(a[1] - b[1])


def chebyshev(a, b) -> int:
    return max(abs(a[0] - b[0]), abs(a[1] - b[1]))


def blocked_fraction(grid) -> float:
    n = sum(1 for y in range(1, 16) for x in range(1, 10)
            if grid[y][x] in "#X")
    return n / INTERIOR


def open_3x3(grid):
    """First 3x3 all-walkable square in the interior, or None."""
    for y in range(1, 14):
        for x in range(1, 8):
            if all(walkable(grid, (x + dx, y + dy))
                   for dx in range(3) for dy in range(3)):
                return (x, y)
    return None


def check_level(grid, player, guards, traps, target) -> list:
    """Return a list of problems (empty = beatable by our checks)."""
    problems = []
    route_sets = [set(route_tiles(g["patrol"])) for g in guards]
    all_route = set().union(*route_sets) if route_sets else set()
    trap_pos = {t["pos"] for t in traps}
    goals = []
    for y in range(ROWS):
        for x in range(COLS):
            if grid[y][x] in "CJ":
                goals.append((x, y))
    keys = [(x, y) for y in range(ROWS) for x in range(COLS) if grid[y][x] == "K"]
    exits = [(x, y) for y in range(ROWS) for x in range(COLS) if grid[y][x] == "E"]
    if len(keys) != 1:
        problems.append(f"want exactly 1 key, found {len(keys)}")
    if len(exits) != 1:
        problems.append(f"want exactly 1 exit, found {len(exits)}")
    goals.extend(keys)
    goals.extend(exits)
    for g in guards:
        goals.append(g["pos"])
        goals.extend(route_tiles(g["patrol"]))
    # Key + exit placement rules (see module docstring):
    # key 1-3 tiles from a patrol route; exit far from the player start.
    if len(keys) == 1:
        dmin = min((manhattan(keys[0], rt) for rt in all_route), default=99)
        if not 1 <= dmin <= 3:
            problems.append(f"key {dmin} tiles from nearest patrol route (want 1..3)")
        if manhattan(keys[0], player) < 4:
            problems.append("key too close to player start")
    if len(exits) == 1:
        if manhattan(exits[0], player) < 7:
            problems.append("exit too close to player start")
        if exits[0] in all_route:
            problems.append("exit on a patrol route")
    # 1. BFS reachability
    seen = bfs_seen(grid, player)
    for m in goals:
        if m not in seen:
            problems.append(f"unreachable tile {m}")
    # snapshot: every guard at its spawn, facing along its patrol
    snap = []
    for g in guards:
        snap.append((g["pos"], patrol_facing(g["patrol"], 0),
                     g["vision"], math.radians(g["half"])))
    # 3. clean start: outside every cone at t=0, not ON a patrol route,
    # and >= 3 tiles from every guard spawn.
    for pos, facing, vr, half in snap:
        if visible(grid, pos, facing, vr, half, player):
            problems.append("player start inside a vision cone at t=0")
            break
    if player in all_route:
        problems.append(f"player start on patrol route at {player}")
    for g in guards:
        if manhattan(player, g["pos"]) < 3:
            problems.append(f"player start {manhattan(player, g['pos'])} tiles from a guard spawn")
            break
    # 4. density: blocked fraction + no 3x3 open floor
    if blocked_fraction(grid) < target - 0.01:
        problems.append(f"density {blocked_fraction(grid):.2f} < target {target:.2f}")
    sq = open_3x3(grid)
    if sq is not None:
        problems.append(f"3x3 open floor at {sq}")
    # 5. trap fairness: goals reachable while avoiding every trap tile
    if traps:
        for t in traps:
            if not walkable(grid, t["pos"]):
                problems.append(f"trap on unwalkable tile {t['pos']}")
            if t["pos"] in all_route:
                problems.append(f"trap on patrol route {t['pos']}")
            if chebyshev(t["pos"], player) <= 1:
                problems.append(f"trap next to player start {t['pos']}")
        seen_safe = bfs_seen(grid, player, blocked_extra=trap_pos)
        for m in goals:
            if m not in seen_safe:
                problems.append(f"goal {m} only reachable through a trap")
                break
    # 2. approach window per guard: either a walkable neighbour of a
    # patrol waypoint that is off every route, off traps and outside
    # EVERY guard's cone — or the "sneak up behind" window: the tile
    # two steps back along the guard's own patrol, which the guard has
    # just walked away from (outside his forward cone, and outside
    # every other guard's cone at the snapshot). That is how the kill
    # actually happens in play: follow the patrol from behind.
    for gi, g in enumerate(guards):
        has_window = False
        for k, w in enumerate(g["patrol"]):
            facing = patrol_facing(g["patrol"], k)
            if k >= 2:
                back = g["patrol"][k - 2]
                if back not in trap_pos and not visible(
                        grid, w, facing, g["vision"],
                        math.radians(g["half"]), back):
                    seen_by_other = False
                    for oj, (opos, ofacing, ovr, ohalf) in enumerate(snap):
                        if oj == gi:
                            continue
                        if visible(grid, opos, ofacing, ovr, ohalf, back):
                            seen_by_other = True
                            break
                    if not seen_by_other:
                        has_window = True
                        break
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nb = (w[0] + dx, w[1] + dy)
                if not walkable(grid, nb):
                    continue
                if nb in all_route or nb in trap_pos:
                    continue
                seen_by_any = False
                if visible(grid, w, facing, g["vision"],
                           math.radians(g["half"]), nb):
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


def _scatter_blocks(g, rng, t, count):
    sizes = [(2, 1), (1, 2), (2, 2), (3, 1), (1, 3)]
    for _ in range(count):
        w, h = sizes[rng.randrange(len(sizes))]
        x = rng.randint(1, COLS - 1 - w)
        y = rng.randint(1, ROWS - 1 - h)
        for dy in range(h):
            for dx in range(w):
                g[y + dy][x + dx] = "#"


def arch_hall(rng, t):
    g = base_grid()
    _scatter_blocks(g, rng, t, 6 + round(t * 4))
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
    _scatter_blocks(g, rng, t, 3 + round(t * 3))
    return g


def arch_maze(rng, t):
    g = base_grid()
    for row in (3, 6, 9, 12):
        for x in range(1, 10):
            g[row][x] = "#"
        for gap in rng.sample(range(1, 10), 2 if row in (3, 12) else 3):
            g[row][gap] = "."
    _scatter_blocks(g, rng, t, 3 + round(t * 3))
    return g


def arch_crossroads(rng, t):
    g = base_grid()
    for cx, cy in ((3, 3), (7, 3), (3, 12), (7, 12)):
        for dy in range(2):
            for dx in range(2):
                g[cy + dy][cx + dx] = "#"
    g[3][4] = "."
    g[12][7] = "."
    _scatter_blocks(g, rng, t, 4 + round(t * 3))
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
    _scatter_blocks(g, rng, t, 3 + round(t * 3))
    return g


ARCHES = [arch_hall, arch_corridors, arch_maze, arch_crossroads, arch_ring]
ARCH_NAMES = ["Hall", "Corridors", "Maze", "Crossroads", "Ring"]


# ---------------------------------------------------------------- densify
def repair_connectivity(grid, rng):
    """Carve floor until every walkable tile is reachable from the first
    walkable tile. Returns True when fully connected."""
    dirs = ((1, 0), (-1, 0), (0, 1), (0, -1))
    for _ in range(200):
        walk = [(x, y) for y in range(1, 16) for x in range(1, 10)
                if walkable(grid, (x, y))]
        if not walk:
            return False
        seen = bfs_seen(grid, walk[0])
        if len(seen) == len(walk):
            return True
        disconnected = [t for t in walk if t not in seen]
        rng.shuffle(disconnected)
        carved = False
        for d in disconnected:
            for dx, dy in dirs:
                w = (d[0] + dx, d[1] + dy)
                if not (1 <= w[0] <= 9 and 1 <= w[1] <= 15):
                    continue
                if grid[w[1]][w[0]] not in "#X":
                    continue
                if any((w[0] + ax, w[1] + ay) in seen for ax, ay in dirs):
                    grid[w[1]][w[0]] = "."
                    carved = True
                    break
            if carved:
                break
        if not carved:
            # Grow the disconnected region one tile at a time until it
            # touches the main region.
            d = disconnected[0]
            for dx, dy in dirs:
                w = (d[0] + dx, d[1] + dy)
                if (1 <= w[0] <= 9 and 1 <= w[1] <= 15
                        and grid[w[1]][w[0]] in "#X"):
                    grid[w[1]][w[0]] = "."
                    carved = True
                    break
            if not carved:
                return False
    return False


def break_open_squares(grid, rng):
    """Drop a crate in the middle of every 3x3 all-floor square."""
    for _ in range(40):
        sq = open_3x3(grid)
        if sq is None:
            return True
        grid[sq[1] + 1][sq[0] + 1] = "X"
    return False


def _fully_connected(grid) -> bool:
    walk = [(x, y) for y in range(1, 16) for x in range(1, 10)
            if walkable(grid, (x, y))]
    return bool(walk) and len(bfs_seen(grid, walk[0])) == len(walk)


def _top_up_safe(grid, rng, target):
    """Place crates only on tiles that are NOT articulation points, so
    connectivity is preserved. Returns True when the target is met."""
    for _ in range(300):
        if blocked_fraction(grid) >= target:
            return True
        x, y = rng.randint(1, 9), rng.randint(1, 15)
        if grid[y][x] != ".":
            continue
        grid[y][x] = "X"
        if _fully_connected(grid):
            continue
        grid[y][x] = "."  # it was a bridge -- revert
    return blocked_fraction(grid) >= target


def _top_up_random(grid, rng, target):
    for _ in range(300):
        if blocked_fraction(grid) >= target:
            return
        x, y = rng.randint(1, 9), rng.randint(1, 15)
        if grid[y][x] == ".":
            grid[y][x] = "X"


def densify(grid, rng, target):
    """Crates + wall blocks up to the blocked-fraction target, then no
    3x3 open floor and full connectivity. Random crates seal 1-wide
    corridors, so the connectivity repair carves floor back out and
    drops the blocked fraction -- top it back up (safe crates first,
    then random ones + another repair) until all three hold at once."""
    tries = 0
    while blocked_fraction(grid) < target and tries < 600:
        tries += 1
        x, y = rng.randint(1, 9), rng.randint(1, 15)
        if grid[y][x] != ".":
            continue
        if rng.random() < 0.4:
            dx, dy = rng.choice([(1, 0), (0, 1)])
            nx, ny = x + dx, y + dy
            if 1 <= nx <= 9 and 1 <= ny <= 15 and grid[ny][nx] == ".":
                grid[ny][nx] = "X"
        grid[y][x] = "X"
    tries = 0
    while blocked_fraction(grid) < target and tries < 600:
        tries += 1
        w, h = rng.choice([(2, 1), (1, 2)])
        x = rng.randint(1, COLS - 1 - w)
        y = rng.randint(1, ROWS - 1 - h)
        if all(grid[y + dy][x + dx] == "." for dy in range(h) for dx in range(w)):
            for dy in range(h):
                for dx in range(w):
                    grid[y + dy][x + dx] = "#"
    for _ in range(10):
        if not break_open_squares(grid, rng):
            return False
        if not repair_connectivity(grid, rng):
            return False
        if (open_3x3(grid) is None
                and blocked_fraction(grid) >= target - 0.01):
            return True
        if not _top_up_safe(grid, rng, target):
            _top_up_random(grid, rng, target)
    return (open_3x3(grid) is None and repair_connectivity(grid, rng)
            and blocked_fraction(grid) >= target - 0.02)


# ---------------------------------------------------------------- generation
def _guard_dict(pos, patrol, speed, gtype, vision, half):
    return {
        "pos": pos,
        "patrol": patrol,
        "speed": round(speed, 2),
        "color": TYPE_COLORS[gtype],
        "type": gtype,
        "vision": vision,
        "half": half,
    }


def _place_double_kill(grid, rng, speed, vision, half):
    """Level 3: two rifle guards patrolling side by side in one corridor
    (adjacent rows, same x-range, same direction) -- walk through the
    line and both go down for a Double Kill. Returns (guardA, guardB,
    route_tiles) or None when no parallel corridor exists."""
    cands = []
    for y in range(1, 15):
        for x0 in range(1, 7):
            if all(walkable(grid, (x, y)) and walkable(grid, (x, y + 1))
                   for x in range(x0, x0 + 4)):
                cands.append((x0, y))
    if not cands:
        return None
    rng.shuffle(cands)
    x0, y = cands[0]
    a = [(x, y) for x in range(x0, x0 + 4)]
    b = [(x, y + 1) for x in range(x0, x0 + 4)]
    guards = [
        _guard_dict(a[0], a, speed, "rifle", vision, half),
        _guard_dict(b[0], b, speed, "rifle", vision, half),
    ]
    return guards, route_tiles(a) + route_tiles(b)


def gen_level(n: int, seed: int, target_override=None):
    """Generate level n (1..50) with the given seed.
    Returns (grid, player, guards, traps) or None."""
    rng = random.Random(seed)
    t = (n - 1) / 49.0
    target = target_override if target_override is not None else density_target(n)
    arch = ARCHES[(n - 1) % len(ARCHES)]
    grid = arch(rng, t)
    if not densify(grid, rng, target):
        globals()["FAIL_REASON"] = "densify"
        return None
    speed = base_speed(n)
    vision = base_vision(n)
    half = base_half(n)
    types = assign_types(n, guard_count(n))
    guards = []
    route_set = set()
    # Level 3: Double Kill pair first, then the remaining guard.
    start_gi = 0
    if n == 3:
        dk = _place_double_kill(grid, rng, speed, vision, half)
        if dk is None:
            globals()["FAIL_REASON"] = "double-kill"
            return None
        dk_guards, dk_route = dk
        guards.extend(dk_guards)
        route_set.update(dk_route)
        start_gi = 2
    bands = [(1, 5), (6, 10), (11, 15)]
    # Patrol length scales with guard count so the map is never paved
    # over: few guards roam far (up to 16 tiles), many guards roam
    # shorter loops (down to 5) — still 2-4x the old 2-6 tile segments,
    # and together they cover the whole map.
    gc = guard_count(n)
    max_patrol = 16 if gc <= 4 else 12 if gc <= 6 else 10 if gc <= 7 else 8
    min_patrol = 7 if gc <= 6 else 5
    for gi in range(start_gi, gc):
        gtype = types[gi]
        gvision = round(vision + 1.6, 2) if gtype == "sniper" else vision
        ghalf = max(30.0, half - 10.0) if gtype == "sniper" else half
        band = bands[gi % len(bands)]
        got = False
        for _ in range(400):
            # Long patrol: pick a start tile (prefer this guard's band so
            # guards spread over the whole map), then a far end tile and
            # walk the BFS shortest path between them. The guard
            # ping-pongs along the path, so one patrol covers a long
            # swath of the map instead of one small corridor.
            if rng.random() < 0.7:
                sx, sy = rng.randint(1, 9), rng.randint(band[0], band[1])
            else:
                sx, sy = rng.randint(1, 9), rng.randint(1, 15)
            s = (sx, sy)
            if not walkable(grid, s) or s in route_set:
                continue
            dist = bfs_dist_map(grid, s)
            far = [t for t, d in dist.items()
                   if min_patrol <= d <= max_patrol and t not in route_set]
            if not far:
                continue
            # Prefer the farthest ends (longest patrols) but vary it.
            # Routes may cross each other freely — guards criss-crossing
            # the same corridors is the point (overlapping cones, timed
            # moves); the game pushes guards apart if they meet, and the
            # approach-window check below still guarantees every guard
            # can be struck from behind.
            far.sort(key=lambda t: -dist[t])
            rng.shuffle(far[:20])
            path = None
            for end in far[:20]:
                cand = bfs_path(grid, s, end)
                if cand is None or not min_patrol <= len(cand) <= max_patrol:
                    continue
                path = cand
                break
            if path is None:
                continue
            guards.append(_guard_dict(
                path[0], path,
                speed + rng.choice([0.0, 0.05, -0.05]),
                gtype, gvision, ghalf))
            route_set.update(path)
            got = True
            break
        if not got:
            globals()["FAIL_REASON"] = f"guard-placement gi={gi}"
            return None
    # player start: prefer the bottom rows. Clean-start rule (mirrored
    # in check_level and ShadowLevels.validate): not ON a patrol route,
    # >= 3 tiles from every guard spawn (no guard walks past in the
    # opening seconds), and outside every vision cone at t=0. (The old
    # "not adjacent to any route tile" rule is unworkable now that long
    # patrols cover most of the floor — and unnecessary: a guard takes
    # seconds to walk its route to the start, and the player moves at
    # once.)
    player = None
    snap = [(g["pos"], patrol_facing(g["patrol"], 0), g["vision"],
             math.radians(g["half"])) for g in guards]
    for _ in range(400):
        if _ < 200:
            px, py = rng.randint(1, 9), rng.randint(13, 15)
        else:
            px, py = rng.randint(1, 9), rng.randint(1, 15)
        if not walkable(grid, (px, py)):
            continue
        if (px, py) in route_set:
            continue
        if any(manhattan((px, py), g["pos"]) < 3 for g in guards):
            continue
        if any(visible(grid, pos, facing, vr, hf, (px, py))
               for pos, facing, vr, hf in snap):
            continue
        player = (px, py)
        break
    if player is None:
        globals()["FAIL_REASON"] = "player-start"
        return None
    # KEY + EXIT (win condition): placed before bushes/coins/gems claim
    # tiles, so nothing overwrites them.
    # Key: 1-3 tiles from a patrol route, closest to the patrol centroid,
    # >= 4 tiles from the player start — reaching it means dealing with
    # the guards.
    route_list = sorted(route_set)
    rcx = sum(t[0] for t in route_list) / len(route_list)
    rcy = sum(t[1] for t in route_list) / len(route_list)
    key_cands = []
    for y in range(1, 16):
        for x in range(1, 10):
            if grid[y][x] != ".":
                continue
            if manhattan((x, y), player) < 4:
                continue
            dmin = min(manhattan((x, y), rt) for rt in route_list)
            if 1 <= dmin <= 3:
                key_cands.append((math.hypot(x - rcx, y - rcy), x, y))
    if not key_cands:
        globals()["FAIL_REASON"] = "key"
        return None
    key_cands.sort()
    key = (key_cands[0][1], key_cands[0][2])
    grid[key[1]][key[0]] = "K"
    # Exit: the farthest reachable tile from the player start (BFS),
    # preferring the top of the map — the far/opposite side of the level,
    # never on a patrol route.
    dist_map = bfs_dist_map(grid, player)
    exit_cands = []
    for (x, y), d in dist_map.items():
        if grid[y][x] != ".":
            continue
        if (x, y) in route_set:
            continue
        if manhattan((x, y), player) >= 8 and d >= 10:
            exit_cands.append((-d, y, x, y))
    if not exit_cands:
        for (x, y), d in dist_map.items():
            if grid[y][x] != "." or (x, y) in route_set:
                continue
            if manhattan((x, y), player) >= 6 and d >= 8:
                exit_cands.append((-d, y, x, y))
    if not exit_cands:
        globals()["FAIL_REASON"] = "exit"
        return None
    exit_cands.sort()
    exit_tile = (exit_cands[0][2], exit_cands[0][3])
    grid[exit_tile[1]][exit_tile[0]] = "E"
    # traps from level 15: placed BEFORE bushes/coins/gems claim tiles,
    # so pickups cannot eat the few off-route floor tiles traps need.
    # Sparse, never on a route, never next to the player start, never
    # next to another trap. Fairness: every route tile, the key and the
    # exit stay reachable on a path that avoids all trap tiles.
    # (Pickups are placed afterwards, only on tiles reachable from the
    # player without stepping on a trap — see safe_tiles below.)
    traps = []
    ntrap = trap_count(n)
    trap_pos = set()
    for ti in range(ntrap):
        kind = "bomb" if ti % 2 == 0 else "cryo"
        got = False
        for _ in range(300):
            x, y = rng.randint(1, 9), rng.randint(1, 15)
            if grid[y][x] != ".":
                continue
            if (x, y) in route_set:
                continue
            if chebyshev((x, y), player) <= 1:
                continue
            if any(manhattan((x, y), tr["pos"]) < 3 for tr in traps):
                continue
            blocked = trap_pos | {(x, y)}
            seen_safe = bfs_seen(grid, player, blocked_extra=blocked)
            trap_goals = sorted(route_set) + [key, exit_tile]
            if any(g not in seen_safe for g in trap_goals):
                continue
            traps.append({"pos": (x, y), "kind": kind})
            trap_pos.add((x, y))
            got = True
            break
        if not got:
            globals()["FAIL_REASON"] = "traps"
            return None
    # From here on, bushes/pickups only go on tiles reachable from the
    # player without stepping on a trap tile.
    safe_tiles = bfs_seen(grid, player, blocked_extra=trap_pos)
    # bushes (walkable 'B' hiding spots) before coins/gems claim tiles
    for _ in range(bush_count(n, rng)):
        for _ in range(50):
            x, y = rng.randint(1, 9), rng.randint(1, 15)
            if grid[y][x] != ".":
                continue
            if (x, y) in route_set or manhattan((x, y), player) < 2:
                continue
            if (x, y) not in safe_tiles:
                continue
            grid[y][x] = "B"
            break
    # coins on random walkable tiles, away from the start. Coins MAY sit
    # on a patrol route — grabbing one then means stepping into a guard's
    # path, which is the risk/reward of the stealth loop (long patrols
    # cover most of the floor, so excluding routes would leave no room).
    ncoins = coin_count(n)
    placed = 0
    tries = 0
    while placed < ncoins and tries < 800:
        tries += 1
        x, y = rng.randint(1, 9), rng.randint(1, 15)
        if grid[y][x] != ".":
            continue
        if manhattan((x, y), player) < 2:
            continue
        if (x, y) not in safe_tiles:
            continue
        grid[y][x] = "C"
        placed += 1
    if placed < ncoins:
        globals()["FAIL_REASON"] = "coins"
        return None
    # gems: riskier -- prefer tiles 1-2 away from a patrol route, else any
    ngems = gem_count(n)
    risky = [(x, y) for y in range(1, 16) for x in range(1, 10)
             if grid[y][x] == "."
             and 1 <= min((manhattan((x, y), rt) for rt in route_set),
                          default=99) <= 2
             and manhattan((x, y), player) >= 2
             and (x, y) in safe_tiles]
    rng.shuffle(risky)
    placed = 0
    for x, y in risky:
        if placed >= ngems:
            break
        grid[y][x] = "J"
        placed += 1
    tries = 0
    while placed < ngems and tries < 800:
        tries += 1
        x, y = rng.randint(1, 9), rng.randint(1, 15)
        if grid[y][x] != ".":
            continue
        if manhattan((x, y), player) < 2:
            continue
        if (x, y) not in safe_tiles:
            continue
        grid[y][x] = "J"
        placed += 1
    if placed < ngems:
        globals()["FAIL_REASON"] = "gems"
        return None
    grid[player[1]][player[0]] = "P"
    return grid, player, guards, traps

# ---------------------------------------------------------------- output
def gd_level_lines(lv) -> list:
    lines = []
    lines.append("\t\t{")
    lines.append(f'\t\t\t"name": "{lv["name"]}",')
    lines.append(f'\t\t\t"hint": "{lv["hint"]}",')
    lines.append(f'\t\t\t"theme": "{lv["theme"]}",')
    lines.append('\t\t\t"map": [')
    for row in lv["map"]:
        lines.append(f'\t\t\t\t"{row}",')
    lines.append("\t\t\t],")
    lines.append('\t\t\t"guards": [')
    for g in lv["guards"]:
        patrol = ", ".join(f"Vector2i({x}, {y})" for x, y in g["patrol"])
        lines.append(
            f'\t\t\t\t{{"pos": Vector2i({g["pos"][0]}, {g["pos"][1]}), '
            f'"patrol": [{patrol}], "speed": {g["speed"]}, '
            f'"color": "{g["color"]}", "type": "{g["type"]}", '
            f'"vision": {g["vision"]}, "half": {g["half"]}}},'
        )
    lines.append("\t\t\t],")
    lines.append(f'\t\t\t"key": Vector2i({lv["key"][0]}, {lv["key"][1]}),')
    lines.append(f'\t\t\t"exit": Vector2i({lv["exit"][0]}, {lv["exit"][1]}),')
    if lv["traps"]:
        traps = ", ".join(
            f'{{"pos": Vector2i({t["pos"][0]}, {t["pos"][1]}), '
            f'"kind": "{t["kind"]}"}}' for t in lv["traps"])
        lines.append(f'\t\t\t"traps": [{traps}],')
    lines.append("\t\t},")
    return lines


def to_gdscript(levels) -> str:
    out = []
    out.append("class_name ShadowLevelsGen")
    out.append("## Levels 11-50 for Shadow Assassin, generated by tools/gen_levels.py")
    out.append("## (deterministic seeds; every level passed the solvability checks in")
    out.append("## gen_levels.py and in ShadowLevels.validate()).")
    out.append("## Optional fields: level \"theme\", guard \"type\", level \"traps\"")
    out.append("## (see tools/gen_levels.py for the schema).")
    out.append("")
    out.append("")
    out.append("static func get_extra_levels() -> Array:")
    out.append("\treturn [")
    for lv in levels:
        out.extend(gd_level_lines(lv))
    out.append("\t]")
    return "\n".join(out) + "\n"


def level_name_hint(n: int):
    if n <= 10:
        return NAMES_1_10[n - 1], HINTS_1_10[n - 1]
    return NAMES[n - 11], HINTS[(n - 11) % len(HINTS)]


def main():
    root = Path(__file__).resolve().parent.parent
    levels = []
    summary = []
    for n in range(1, 51):
        result = None
        tries = 0
        last_problems = []
        while tries < 400 and result is None:
            tries += 1
            seed = 1000 + n * 97 + tries * 7919
            target = density_target(n)
            if tries > 250:
                target -= 0.04
            elif tries > 150:
                target -= 0.02
            target = max(0.28, target)
            gen = gen_level(n, seed, target_override=target)
            if gen is None:
                last_problems = ["generation failed"]
                continue
            grid, player, guards, traps = gen
            problems = check_level(grid, player, guards, traps, target)
            if problems:
                last_problems = problems
                continue
            result = (grid, player, guards, traps)
        if result is None:
            print(f"LEVEL {n}: FAILED after 400 tries: {last_problems}")
            sys.exit(1)
        grid, player, guards, traps = result
        name, hint = level_name_hint(n)
        rows = ["".join(row) for row in grid]
        key_t = next((x, y) for y in range(ROWS) for x in range(COLS) if rows[y][x] == "K")
        exit_t = next((x, y) for y in range(ROWS) for x in range(COLS) if rows[y][x] == "E")
        levels.append({
            "name": name,
            "hint": hint,
            "theme": theme(n),
            "map": rows,
            "guards": guards,
            "traps": traps,
            "key": key_t,
            "exit": exit_t,
        })
        summary.append({
            "level": n,
            "name": name,
            "archetype": ARCH_NAMES[(n - 1) % len(ARCH_NAMES)],
            "theme": theme(n),
            "guards": len(guards),
            "types": [g["type"] for g in guards],
            "speed": base_speed(n),
            "vision_tiles": base_vision(n),
            "vision_half_deg": base_half(n),
            "coins": sum(r.count("C") for r in rows),
            "gems": sum(r.count("J") for r in rows),
            "bushes": sum(r.count("B") for r in rows),
            "traps": len(traps),
            "trap_kinds": [t["kind"] for t in traps],
            "density": round(blocked_fraction(grid), 3),
            "tries": tries,
            "patrol_lengths": [len(g["patrol"]) for g in guards],
            "key": list(key_t),
            "exit": list(exit_t),
        })
        print(f"LEVEL {n:2d} {name:18s} {ARCH_NAMES[(n-1)%5]:10s} "
              f"{theme(n):9s} guards={len(guards)} "
              f"types={','.join(sorted(set(summary[-1]['types'])))} "
              f"coins={summary[-1]['coins']} gems={summary[-1]['gems']} "
              f"bushes={summary[-1]['bushes']} traps={len(traps)} "
              f"density={summary[-1]['density']} tries={tries} "
              f"patrols={summary[-1]['patrol_lengths']} key={key_t} exit={exit_t}")
    # levels 11-50 -> scripts/levels_gen.gd
    out_path = root / "scripts" / "levels_gen.gd"
    out_path.write_text(to_gdscript(levels[10:]))
    # levels 1-10 -> fragment to paste into scripts/levels.gd (a .txt so
    # the editor never tries to parse the fragment as a script)
    frag_path = root / "tools" / "levels_1_10_fragment.gd.txt"
    frag_lines = []
    for lv in levels[:10]:
        frag_lines.extend(gd_level_lines(lv))
    frag_path.write_text("\n".join(frag_lines) + "\n")
    (root / "tools" / "levels_gen_summary.json").write_text(
        json.dumps(summary, indent=2))
    print(f"\nWrote {out_path} ({len(levels[10:])} levels)")
    print(f"Wrote {frag_path} (levels 1-10 fragment)")
    print(f"Total retries across all levels: {sum(s['tries'] for s in summary)}")


if __name__ == "__main__":
    main()
