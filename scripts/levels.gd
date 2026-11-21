class_name ShadowLevels
## Original level definitions for Shadow Assassin.
## Maps are 11 columns x 17 rows. Legend:
##   '#' wall   'X' crate (blocks movement + sight)   '.' floor
##   'P' player start   'C' coin   'J' gem (worth 5)   'B' plant (decor, walkable)
## Guards are defined separately with spawn tile, patrol waypoints, speed, colour.

static func get_levels() -> Array:
	var all: Array = [
		{
			"name": "First Shadows",
			"hint": "Tap a floor tile to move. Tap a guard to sneak up behind them!",
			"map": [
				"###########",
				"#.........#",
				"#..C......#",
				"#.........#",
				"#....#....#",
				"#....#..C.#",
				"#.........#",
				"#..P......#",
				"#.........#",
				"#.........#",
				"#..C......#",
				"#....#....#",
				"#....#....#",
				"#.........#",
				"#......C..#",
				"#.........#",
				"###########",
			],
			"guards": [
				{"pos": Vector2i(5, 9), "patrol": [Vector2i(5, 9), Vector2i(8, 9), Vector2i(8, 6), Vector2i(5, 6)], "speed": 1.1, "color": "orange"},
			],
		},
		{
			"name": "Two Watchers",
			"hint": "Two guards now. Watch the yellow vision cones!",
			"map": [
				"###########",
				"#....C....#",
				"#.###.###.#",
				"#.........#",
				"#.C.....C.#",
				"#..#####..#",
				"#.........#",
				"#..P...J..#",
				"#.........#",
				"#.#######.#",
				"#.........#",
				"#..C....C.#",
				"#.........#",
				"#..###.##.#",
				"#.........#",
				"#....C....#",
				"###########",
			],
			"guards": [
				{"pos": Vector2i(2, 3), "patrol": [Vector2i(2, 3), Vector2i(8, 3)], "speed": 1.2, "color": "orange"},
				{"pos": Vector2i(8, 15), "patrol": [Vector2i(8, 15), Vector2i(2, 15)], "speed": 1.2, "color": "purple"},
			],
		},
		{
			"name": "Garden Patrol",
			"hint": "Crates block sight. Hide behind them!",
			"map": [
				"###########",
				"#..C...C..#",
				"#.B.....B.#",
				"#.........#",
				"#..XX...X.#",
				"#.........#",
				"#....C....#",
				"#..P......#",
				"#....#....#",
				"#....#..C.#",
				"#.........#",
				"#.X.....X.#",
				"#.........#",
				"#..C...C..#",
				"#.B.....B.#",
				"#....J....#",
				"###########",
			],
			"guards": [
				{"pos": Vector2i(3, 5), "patrol": [Vector2i(3, 5), Vector2i(8, 5)], "speed": 1.3, "color": "blue"},
				{"pos": Vector2i(8, 12), "patrol": [Vector2i(8, 12), Vector2i(3, 12)], "speed": 1.3, "color": "green"},
			],
		},
		{
			"name": "The Courtyard",
			"hint": "Three guards. Strike when a guard walks away from you.",
			"map": [
				"###########",
				"#..C...C..#",
				"#.........#",
				"#.##...##.#",
				"#.........#",
				"#..C...C..#",
				"#....#....#",
				"#..P..#...#",
				"#....#....#",
				"#.........#",
				"#.##...##.#",
				"#.........#",
				"#..C...C..#",
				"#.........#",
				"#..J...J..#",
				"#.........#",
				"###########",
			],
			"guards": [
				{"pos": Vector2i(2, 4), "patrol": [Vector2i(2, 4), Vector2i(8, 4)], "speed": 1.3, "color": "orange"},
				{"pos": Vector2i(8, 9), "patrol": [Vector2i(8, 9), Vector2i(2, 9)], "speed": 1.3, "color": "purple"},
				{"pos": Vector2i(5, 13), "patrol": [Vector2i(5, 13), Vector2i(5, 15)], "speed": 1.4, "color": "blue"},
			],
		},
		{
			"name": "Crossroads",
			"hint": "Faster guards. If one spots you, break line of sight!",
			"map": [
				"###########",
				"#..C...C..#",
				"#....X....#",
				"#.X.....X.#",
				"#.........#",
				"#..##.##..#",
				"#....C....#",
				"#..P...J..#",
				"#.........#",
				"#..##.##..#",
				"#.........#",
				"#.X.....X.#",
				"#....X....#",
				"#..C...C..#",
				"#....C....#",
				"#..J...C..#",
				"###########",
			],
			"guards": [
				{"pos": Vector2i(2, 4), "patrol": [Vector2i(2, 4), Vector2i(8, 4)], "speed": 1.4, "color": "orange"},
				{"pos": Vector2i(3, 11), "patrol": [Vector2i(3, 11), Vector2i(7, 11)], "speed": 1.4, "color": "purple"},
				{"pos": Vector2i(8, 7), "patrol": [Vector2i(8, 7), Vector2i(8, 4)], "speed": 1.5, "color": "blue"},
			],
		},
		{
			"name": "Golden Hall",
			"hint": "Four guards guard the gold. Patience wins.",
			"map": [
				"###########",
				"#..C...C..#",
				"#.##...##.#",
				"#.........#",
				"#..C...C..#",
				"#....X....#",
				"#....X..J.#",
				"#..P......#",
				"#....X....#",
				"#....X....#",
				"#..C...C..#",
				"#.........#",
				"#.##...##.#",
				"#..C...C..#",
				"#....J....#",
				"#.........#",
				"###########",
			],
			"guards": [
				{"pos": Vector2i(2, 3), "patrol": [Vector2i(2, 3), Vector2i(8, 3)], "speed": 1.4, "color": "orange"},
				{"pos": Vector2i(8, 10), "patrol": [Vector2i(8, 10), Vector2i(2, 10)], "speed": 1.4, "color": "purple"},
				{"pos": Vector2i(5, 13), "patrol": [Vector2i(5, 13), Vector2i(5, 15)], "speed": 1.5, "color": "blue"},
				{"pos": Vector2i(8, 7), "patrol": [Vector2i(8, 7), Vector2i(8, 3)], "speed": 1.5, "color": "green"},
			],
		},
		{
			"name": "The Maze",
			"hint": "A maze of walls. Use corners to stay unseen.",
			"map": [
				"###########",
				"#..C...C..#",
				"#.#####.#.#",
				"#.....#...#",
				"#.###.#.###",
				"#...#..C..#",
				"#.###.###.#",
				"#.....#...#",
				"#.P...#.J.#",
				"#..##.#...#",
				"#..C..###.#",
				"#.####....#",
				"#..C.#.##.#",
				"#..C...#C.#",
				"#..J....C.#",
				"#....#....#",
				"###########",
			],
			"guards": [
				{"pos": Vector2i(2, 7), "patrol": [Vector2i(2, 7), Vector2i(5, 7)], "speed": 1.5, "color": "orange"},
				{"pos": Vector2i(8, 9), "patrol": [Vector2i(8, 9), Vector2i(8, 7)], "speed": 1.5, "color": "purple"},
				{"pos": Vector2i(3, 13), "patrol": [Vector2i(3, 13), Vector2i(3, 15)], "speed": 1.6, "color": "blue"},
				{"pos": Vector2i(8, 1), "patrol": [Vector2i(8, 1), Vector2i(3, 1)], "speed": 1.6, "color": "green"},
			],
		},
		{
			"name": "Night Watch",
			"hint": "Five guards on night watch. Move like a shadow.",
			"map": [
				"###########",
				"#..C...C..#",
				"#.........#",
				"#.##.#.##.#",
				"#.........#",
				"#..C...C..#",
				"#.C..X....#",
				"#..P..X...#",
				"#....X....#",
				"#.........#",
				"#.##.#.##.#",
				"#.........#",
				"#..C...C..#",
				"#....J....#",
				"#..C...JC.#",
				"#....J....#",
				"###########",
			],
			"guards": [
				{"pos": Vector2i(2, 4), "patrol": [Vector2i(2, 4), Vector2i(8, 4)], "speed": 1.5, "color": "orange"},
				{"pos": Vector2i(8, 9), "patrol": [Vector2i(8, 9), Vector2i(2, 9)], "speed": 1.5, "color": "purple"},
				{"pos": Vector2i(5, 12), "patrol": [Vector2i(5, 12), Vector2i(5, 14)], "speed": 1.6, "color": "blue"},
				{"pos": Vector2i(8, 1), "patrol": [Vector2i(8, 1), Vector2i(2, 1)], "speed": 1.6, "color": "green"},
				{"pos": Vector2i(2, 15), "patrol": [Vector2i(2, 15), Vector2i(8, 15)], "speed": 1.7, "color": "pink"},
			],
		},
		{
			"name": "Royal Guard",
			"hint": "The royal guard never rests. Time every step.",
			"map": [
				"###########",
				"#..C...C..#",
				"#.#####.#.#",
				"#.......#.#",
				"#.###.#..J#",
				"#...#.#.###",
				"#.###.#...#",
				"#.C...###.#",
				"#..P..#...#",
				"#..###.##.#",
				"#.......#.#",
				"#.####.#..#",
				"#.C..#..C.#",
				"#..C...C..#",
				"#..J...J..#",
				"#..C...CC.#",
				"###########",
			],
			"guards": [
				{"pos": Vector2i(2, 3), "patrol": [Vector2i(2, 3), Vector2i(7, 3)], "speed": 1.6, "color": "orange"},
				{"pos": Vector2i(8, 6), "patrol": [Vector2i(8, 6), Vector2i(5, 6)], "speed": 1.6, "color": "purple"},
				{"pos": Vector2i(2, 10), "patrol": [Vector2i(2, 10), Vector2i(7, 10)], "speed": 1.7, "color": "blue"},
				{"pos": Vector2i(5, 13), "patrol": [Vector2i(5, 13), Vector2i(5, 15)], "speed": 1.7, "color": "green"},
				{"pos": Vector2i(8, 1), "patrol": [Vector2i(8, 1), Vector2i(3, 1)], "speed": 1.8, "color": "pink"},
			],
		},
		{
			"name": "Shadow Master",
			"hint": "Six guards. One shadow. Prove you are the master.",
			"map": [
				"###########",
				"#..C...C..#",
				"#.##...##.#",
				"#.........#",
				"#..C...C..#",
				"#..#####..#",
				"#.C.....C.#",
				"#..P..J...#",
				"#.........#",
				"#..#####..#",
				"#.C.....C.#",
				"#.##...##.#",
				"#..C...C..#",
				"#..J...J..#",
				"#..C...C..#",
				"#....J....#",
				"###########",
			],
			"guards": [
				{"pos": Vector2i(2, 3), "patrol": [Vector2i(2, 3), Vector2i(8, 3)], "speed": 1.7, "color": "orange"},
				{"pos": Vector2i(8, 7), "patrol": [Vector2i(8, 7), Vector2i(2, 7)], "speed": 1.7, "color": "purple"},
				{"pos": Vector2i(2, 12), "patrol": [Vector2i(2, 12), Vector2i(8, 12)], "speed": 1.8, "color": "blue"},
				{"pos": Vector2i(5, 13), "patrol": [Vector2i(5, 13), Vector2i(5, 15)], "speed": 1.8, "color": "green"},
				{"pos": Vector2i(8, 1), "patrol": [Vector2i(8, 1), Vector2i(2, 1)], "speed": 1.9, "color": "pink"},
				{"pos": Vector2i(8, 14), "patrol": [Vector2i(8, 14), Vector2i(2, 14)], "speed": 1.9, "color": "orange"},
			],
		},
	]
	# Levels 11-50: generated by tools/gen_levels.py (deterministic seeds).
	all.append_array(ShadowLevelsGen.get_extra_levels())
	return all


static func validate() -> Array:
	"""Check every level: 17 rows of 11 chars, one P, all coins/gems and
	guard patrol waypoints reachable from P. Returns a list of problems."""
	var problems: Array = []
	var levels: Array = get_levels()
	for li in range(levels.size()):
		var lv: Dictionary = levels[li]
		var map: PackedStringArray = lv["map"]
		if map.size() != 17:
			problems.append("L%d: %d rows (want 17)" % [li + 1, map.size()])
			continue
		var start := Vector2i(-1, -1)
		var goals: Array = []
		for y in range(17):
			var row: String = map[y]
			if row.length() != 11:
				problems.append("L%d row %d: %d chars (want 11)" % [li + 1, y, row.length()])
			for x in range(mini(row.length(), 11)):
				var ch: String = row[x]
				if ch == "P":
					start = Vector2i(x, y)
				elif ch == "C" or ch == "J":
					goals.append(Vector2i(x, y))
		if start.x < 0:
			problems.append("L%d: no player start" % [li + 1])
			continue
		for g in lv["guards"]:
			goals.append(g["pos"])
			for wp in g["patrol"]:
				goals.append(wp)
		# BFS over walkable tiles ('#' and 'X' block)
		var seen := {}
		var queue: Array = [start]
		seen[start] = true
		while not queue.is_empty():
			var cur: Vector2i = queue.pop_front()
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nb: Vector2i = cur + d
				if nb.x < 0 or nb.y < 0 or nb.x >= 11 or nb.y >= 17:
					continue
				if seen.has(nb):
					continue
				var ch: String = map[nb.y][nb.x]
				if ch == "#" or ch == "X":
					continue
				seen[nb] = true
				queue.append(nb)
		for goal in goals:
			if not seen.has(goal):
				problems.append("L%d: unreachable tile %s" % [li + 1, str(goal)])
		# Vision-cone checks (mirror of tools/gen_levels.py):
		#  - clean start: player start outside every cone at t=0
		#  - approach window: every guard has a patrol waypoint where a
		#    walkable neighbour tile is outside EVERY guard's cone, so the
		#    player always has a timing window to strike from behind.
		var snap: Array = []
		for g in lv["guards"]:
			var patrol: Array = g["patrol"]
			snap.append({
				"pos": g["pos"],
				"facing": _patrol_facing(patrol, 0),
				"vision": float(g.get("vision", 3.67)),
				"half": deg_to_rad(float(g.get("half", 45.0))),
			})
		for s in snap:
			if _tile_visible(map, s["pos"], s["facing"], s["vision"], s["half"], start):
				problems.append("L%d: player start inside a vision cone at t=0" % [li + 1])
				break
		for gi in range(lv["guards"].size()):
			var g: Dictionary = lv["guards"][gi]
			var patrol: Array = g["patrol"]
			var g_vision: float = float(g.get("vision", 3.67))
			var g_half: float = deg_to_rad(float(g.get("half", 45.0)))
			var has_window := false
			for k in range(patrol.size()):
				var w: Vector2i = patrol[k]
				var facing: float = _patrol_facing(patrol, k)
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nb: Vector2i = w + d
					if nb.x < 0 or nb.y < 0 or nb.x >= 11 or nb.y >= 17:
						continue
					var ch: String = map[nb.y][nb.x]
					if ch == "#" or ch == "X":
						continue
					if _tile_visible(map, w, facing, g_vision, g_half, nb):
						continue
					var seen_by_any := false
					for oj in range(snap.size()):
						if oj == gi:
							continue
						var o: Dictionary = snap[oj]
						if _tile_visible(map, o["pos"], o["facing"], o["vision"], o["half"], nb):
							seen_by_any = true
							break
					if not seen_by_any:
						has_window = true
						break
				if has_window:
					break
			if not has_window:
				problems.append("L%d: guard %d has no approach window" % [li + 1, gi])
	return problems


static func _patrol_facing(patrol: Array, k: int) -> float:
	var n: int = patrol.size()
	var nxt: Vector2i = patrol[k + 1] if k < n - 1 else patrol[k - 1]
	var w: Vector2i = patrol[k]
	return atan2(float(nxt.y - w.y), float(nxt.x - w.x))


static func _los_clear(map: PackedStringArray, a: Vector2i, b: Vector2i) -> bool:
	var dx: float = float(b.x - a.x)
	var dy: float = float(b.y - a.y)
	var dist := sqrt(dx * dx + dy * dy)
	var steps := maxi(1, int(dist / 0.25))
	for i in range(1, steps):
		var t: float = float(i) / float(steps)
		var x := int(a.x + dx * t)
		var y := int(a.y + dy * t)
		var ch: String = map[y][x]
		if ch == "#" or ch == "X":
			return false
	return true


static func _tile_visible(map: PackedStringArray, frm: Vector2i, facing: float, range_t: float, half_rad: float, to: Vector2i) -> bool:
	var dx: float = float(to.x - frm.x)
	var dy: float = float(to.y - frm.y)
	var d := sqrt(dx * dx + dy * dy)
	if d > range_t:
		return false
	if d < 0.01:
		return true
	if absf(wrapf(atan2(dy, dx) - facing, -PI, PI)) > half_rad:
		return false
	return _los_clear(map, frm, to)
