class_name ShadowLevels
## Original level definitions for Shadow Assassin.
## Maps are 11 columns x 20 rows, DENSE mazes: crates/walls everywhere,
## corridors 1-2 tiles wide, no 3x3 open floor. Legend:
##   '#' wall   'X' crate (blocks movement + sight)   '.' floor
##   'P' player start   'C' coin   'J' gem (worth 5)   'B' bush/plant (walkable hiding spot)
##   'K' key (collect it, then reach the exit)   'E' exit (bright green square)
## Guards are defined separately with spawn tile, patrol waypoints, speed, colour.
## Patrols are LONG A*-routed paths (see tools/gen_levels.py): each guard
## roams a long swath of the map out and back, routes may cross each other.
## Win condition: collect the key, then reach the exit — killing guards
## is how you get to the key safely, but it is not the win trigger.
## Optional fields (safe defaults -- old levels still load):
##   level "theme": "warehouse" (L1-12) | "cyber" (L13-25) | "lab" (L26-37)
##     | "prison" (L38-50). Guard "type": "basic" (L1-2) | "rifle" (from L3)
##     | "shotgun" (from L5) | "grenade" (from L8) | "sniper" (from L20,
##     longer narrower cone) | "shielded" (from L30). Level "traps" (from
##     L15): [{"pos": Vector2i, "kind": "bomb"|"cryo"}] -- sparse, never
##     unavoidable. Levels 1-10 below were produced by tools/gen_levels.py
##     (deterministic seeds; fragment in tools/levels_1_10_fragment.gd).

static func get_levels() -> Array:
	var all: Array = [
		{
			"name": "First Shadows",
			"hint": "Tap a floor tile to move. Strike a guard from behind!",
			"theme": "warehouse",
			"map": [
				"###########",
				"#X..X..C.E#",
				"#.....X.XX#",
				"#XX.....X.#",
				"#..##..XX.#",
				"#.###...B.#",
				"#.#...X.X.#",
				"#.......XX#",
				"#..XXX..CC#",
				"#..###.X..#",
				"#.C...XXX.#",
				"#.XX..XX..#",
				"#..K...XX##",
				"#..X.XX...#",
				"#J...X....#",
				"#...CXXX..#",
				"#XX.....XB#",
				"#..##.P..B#",
				"#X..C.X.XC#",
				"###########",
			],
			"guards": [
				{"pos": Vector2i(5, 7), "patrol": [Vector2i(5, 7), Vector2i(4, 7), Vector2i(3, 7), Vector2i(2, 7), Vector2i(1, 7), Vector2i(1, 8), Vector2i(1, 9), Vector2i(1, 10), Vector2i(1, 11), Vector2i(1, 12), Vector2i(2, 12), Vector2i(2, 13), Vector2i(2, 14), Vector2i(3, 14), Vector2i(3, 15), Vector2i(3, 16)], "speed": 1.15, "color": "green", "type": "basic", "vision": 3.0, "half": 40.0},
				{"pos": Vector2i(4, 6), "patrol": [Vector2i(4, 6), Vector2i(3, 6), Vector2i(3, 7), Vector2i(2, 7), Vector2i(2, 8), Vector2i(2, 9), Vector2i(2, 10), Vector2i(3, 10), Vector2i(4, 10), Vector2i(4, 11), Vector2i(4, 12), Vector2i(4, 13), Vector2i(4, 14), Vector2i(4, 15), Vector2i(4, 16), Vector2i(5, 16)], "speed": 1.1, "color": "green", "type": "basic", "vision": 3.0, "half": 40.0},
			],
			"key": Vector2i(3, 12),
			"exit": Vector2i(9, 1),
		},
		{
			"name": "Two Watchers",
			"hint": "Three guards now. Watch the yellow vision cones!",
			"theme": "warehouse",
			"map": [
				"###########",
				"#........E#",
				"#CX..X.#.X#",
				"#X.#...#CB#",
				"#X.#......#",
				"#..#..X#.C#",
				"#CX#..X#..#",
				"#.##.BC#..#",
				"#.##...#..#",
				"#....X...X#",
				"#.###..X#.#",
				"#..#K###.C#",
				"#X.#.###B.#",
				"#..#...#..#",
				"#....X.#..#",
				"#..#......#",
				"#..#...#..#",
				"#.P#.X.#..#",
				"#C..JXX..X#",
				"###########",
			],
			"guards": [
				{"pos": Vector2i(5, 6), "patrol": [Vector2i(5, 6), Vector2i(4, 6), Vector2i(4, 7), Vector2i(4, 8), Vector2i(4, 9), Vector2i(3, 9), Vector2i(2, 9), Vector2i(1, 9), Vector2i(1, 10), Vector2i(1, 11), Vector2i(2, 11), Vector2i(2, 12), Vector2i(2, 13), Vector2i(1, 13), Vector2i(1, 14), Vector2i(1, 15)], "speed": 1.22, "color": "green", "type": "basic", "vision": 3.03, "half": 40.3},
				{"pos": Vector2i(6, 9), "patrol": [Vector2i(6, 9), Vector2i(6, 8), Vector2i(5, 8), Vector2i(4, 8), Vector2i(4, 9), Vector2i(3, 9), Vector2i(2, 9), Vector2i(1, 9), Vector2i(1, 10), Vector2i(1, 11), Vector2i(2, 11), Vector2i(2, 12), Vector2i(2, 13), Vector2i(2, 14), Vector2i(3, 14), Vector2i(4, 14)], "speed": 1.22, "color": "green", "type": "basic", "vision": 3.03, "half": 40.3},
				{"pos": Vector2i(6, 16), "patrol": [Vector2i(6, 16), Vector2i(5, 16), Vector2i(4, 16), Vector2i(4, 15), Vector2i(4, 14), Vector2i(3, 14), Vector2i(2, 14), Vector2i(2, 13), Vector2i(2, 12), Vector2i(2, 11), Vector2i(1, 11), Vector2i(1, 10), Vector2i(1, 9), Vector2i(1, 8), Vector2i(1, 7), Vector2i(1, 6)], "speed": 1.22, "color": "green", "type": "basic", "vision": 3.03, "half": 40.3},
			],
			"key": Vector2i(4, 11),
			"exit": Vector2i(9, 1),
		},
		{
			"name": "Garden Patrol",
			"hint": "Two guards patrol side by side. Strike them both for a Double Kill!",
			"theme": "warehouse",
			"map": [
				"###########",
				"#E......C.#",
				"#...X...###",
				"###.#.#####",
				"#.B.......#",
				"#C......J.#",
				"##.#####X.#",
				"#....XX...#",
				"#..XX...X.#",
				"##XX#####.#",
				"#..XCX....#",
				"#...KXX...#",
				"#.######.##",
				"#....X#.B.#",
				"#..X.X#CX.#",
				"#X....#...#",
				"#..X.X.C..#",
				"#.......X.#",
				"#.C..#P.C.#",
				"###########",
			],
			"guards": [
				{"pos": Vector2i(3, 4), "patrol": [Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4)], "speed": 1.23, "color": "orange", "type": "rifle", "vision": 3.07, "half": 40.6},
				{"pos": Vector2i(3, 5), "patrol": [Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5)], "speed": 1.23, "color": "orange", "type": "rifle", "vision": 3.07, "half": 40.6},
				{"pos": Vector2i(2, 13), "patrol": [Vector2i(2, 13), Vector2i(3, 13), Vector2i(4, 13), Vector2i(4, 14), Vector2i(4, 15), Vector2i(4, 16), Vector2i(4, 17), Vector2i(5, 17), Vector2i(6, 17), Vector2i(7, 17), Vector2i(7, 16), Vector2i(8, 16), Vector2i(9, 16), Vector2i(9, 15), Vector2i(9, 14), Vector2i(9, 13)], "speed": 1.23, "color": "orange", "type": "rifle", "vision": 3.07, "half": 40.6},
			],
			"key": Vector2i(4, 11),
			"exit": Vector2i(1, 1),
		},
		{
			"name": "The Courtyard",
			"hint": "Four guards. Strike when a guard walks away from you.",
			"theme": "warehouse",
			"map": [
				"###########",
				"####.CX.EX#",
				"#.C..CB...#",
				"#..#...##.#",
				"#J.##.X##.#",
				"#..C.XXX..#",
				"#.X..X....#",
				"#........##",
				"#...X.CX.##",
				"#XX..CXXX##",
				"#XX.X.X...#",
				"#...K#..X.#",
				"#..###..#.#",
				"#..###.##.#",
				"#........C#",
				"#X.X..XX###",
				"#..CB.PX###",
				"#BX..X....#",
				"#...X....X#",
				"###########",
			],
			"guards": [
				{"pos": Vector2i(9, 5), "patrol": [Vector2i(9, 5), Vector2i(8, 5), Vector2i(8, 6), Vector2i(7, 6), Vector2i(6, 6), Vector2i(6, 7), Vector2i(5, 7), Vector2i(4, 7), Vector2i(3, 7), Vector2i(3, 8), Vector2i(3, 9), Vector2i(3, 10), Vector2i(3, 11), Vector2i(2, 11), Vector2i(1, 11), Vector2i(1, 12)], "speed": 1.25, "color": "orange", "type": "rifle", "vision": 3.1, "half": 40.9},
				{"pos": Vector2i(5, 9), "patrol": [Vector2i(5, 9), Vector2i(4, 9), Vector2i(3, 9), Vector2i(3, 10), Vector2i(3, 11), Vector2i(2, 11), Vector2i(2, 12), Vector2i(2, 13), Vector2i(2, 14), Vector2i(3, 14), Vector2i(4, 14), Vector2i(5, 14), Vector2i(6, 14), Vector2i(7, 14), Vector2i(8, 14), Vector2i(9, 14)], "speed": 1.35, "color": "orange", "type": "rifle", "vision": 3.1, "half": 40.9},
				{"pos": Vector2i(4, 17), "patrol": [Vector2i(4, 17), Vector2i(3, 17), Vector2i(3, 16), Vector2i(2, 16), Vector2i(2, 15), Vector2i(2, 14), Vector2i(2, 13), Vector2i(2, 12), Vector2i(2, 11), Vector2i(3, 11), Vector2i(3, 10), Vector2i(3, 9), Vector2i(4, 9), Vector2i(5, 9), Vector2i(5, 8), Vector2i(6, 8)], "speed": 1.35, "color": "orange", "type": "rifle", "vision": 3.1, "half": 40.9},
				{"pos": Vector2i(4, 1), "patrol": [Vector2i(4, 1), Vector2i(4, 2), Vector2i(3, 2), Vector2i(2, 2), Vector2i(2, 3), Vector2i(2, 4), Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5), Vector2i(4, 6), Vector2i(4, 7), Vector2i(5, 7), Vector2i(5, 8), Vector2i(5, 9), Vector2i(5, 10)], "speed": 1.3, "color": "orange", "type": "rifle", "vision": 3.1, "half": 40.9},
			],
			"key": Vector2i(4, 11),
			"exit": Vector2i(8, 1),
		},
		{
			"name": "Crossroads",
			"hint": "Faster guards. If one spots you, break line of sight!",
			"theme": "warehouse",
			"map": [
				"###########",
				"#X...##...#",
				"#E.X.X..C.#",
				"#.......X.#",
				"#.J...CX.X#",
				"#..#C#.#..#",
				"#XX#...#.X#",
				"#.........#",
				"#C.#XXX#.X#",
				"#...#...C.#",
				"#..##.X#.X#",
				"#X.###K#..#",
				"#X..X....X#",
				"#...BXX..X#",
				"#.##XX.C..#",
				"#.##..XX.X#",
				"#..XX.....#",
				"#XXC..X..B#",
				"#.P.....CX#",
				"###########",
			],
			"guards": [
				{"pos": Vector2i(2, 1), "patrol": [Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1), Vector2i(4, 2), Vector2i(4, 3), Vector2i(5, 3), Vector2i(6, 3), Vector2i(6, 4), Vector2i(6, 5), Vector2i(6, 6), Vector2i(6, 7), Vector2i(7, 7), Vector2i(8, 7), Vector2i(8, 8), Vector2i(8, 9), Vector2i(9, 9)], "speed": 1.41, "color": "orange", "type": "rifle", "vision": 3.13, "half": 41.2},
				{"pos": Vector2i(6, 2), "patrol": [Vector2i(6, 2), Vector2i(6, 3), Vector2i(5, 3), Vector2i(4, 3), Vector2i(4, 4), Vector2i(4, 5), Vector2i(4, 6), Vector2i(4, 7), Vector2i(3, 7), Vector2i(2, 7), Vector2i(2, 8), Vector2i(2, 9), Vector2i(2, 10), Vector2i(2, 11), Vector2i(2, 12), Vector2i(3, 12)], "speed": 1.41, "color": "pink", "type": "shotgun", "vision": 3.13, "half": 41.2},
				{"pos": Vector2i(5, 10), "patrol": [Vector2i(5, 10), Vector2i(5, 9), Vector2i(6, 9), Vector2i(7, 9), Vector2i(8, 9), Vector2i(8, 10), Vector2i(8, 11), Vector2i(8, 12), Vector2i(8, 13), Vector2i(8, 14), Vector2i(8, 15), Vector2i(8, 16), Vector2i(7, 16), Vector2i(6, 16), Vector2i(5, 16), Vector2i(5, 17)], "speed": 1.41, "color": "orange", "type": "rifle", "vision": 3.13, "half": 41.2},
				{"pos": Vector2i(8, 18), "patrol": [Vector2i(8, 18), Vector2i(8, 17), Vector2i(8, 16), Vector2i(8, 15), Vector2i(8, 14), Vector2i(8, 13), Vector2i(8, 12), Vector2i(8, 11), Vector2i(8, 10), Vector2i(8, 9), Vector2i(8, 8), Vector2i(8, 7), Vector2i(7, 7), Vector2i(6, 7), Vector2i(5, 7), Vector2i(5, 6)], "speed": 1.41, "color": "pink", "type": "shotgun", "vision": 3.13, "half": 41.2},
			],
			"key": Vector2i(6, 11),
			"exit": Vector2i(1, 2),
		},
		{
			"name": "Golden Hall",
			"hint": "Four guards guard the gold. Patience wins.",
			"theme": "warehouse",
			"map": [
				"###########",
				"#.XJ.....E#",
				"#.XXX....X#",
				"#.....X#X.#",
				"#.X.X..#..#",
				"#B.C...C..#",
				"#...XX.X..#",
				"#X..XC.B..#",
				"#C..X.XXX.#",
				"#.X.XK.XXX#",
				"#.....X...#",
				"#C......###",
				"#C.X..X.XX#",
				"#...##X...#",
				"#.#C..XXX.#",
				"#.##XXC...#",
				"#...X##..X#",
				"#.#..##.XX#",
				"#.PXX.....#",
				"###########",
			],
			"guards": [
				{"pos": Vector2i(8, 5), "patrol": [Vector2i(8, 5), Vector2i(7, 5), Vector2i(6, 5), Vector2i(5, 5), Vector2i(4, 5), Vector2i(3, 5), Vector2i(2, 5), Vector2i(2, 6), Vector2i(2, 7), Vector2i(2, 8), Vector2i(1, 8), Vector2i(1, 9), Vector2i(1, 10), Vector2i(1, 11), Vector2i(1, 12), Vector2i(1, 13)], "speed": 1.48, "color": "orange", "type": "rifle", "vision": 3.17, "half": 41.5},
				{"pos": Vector2i(7, 10), "patrol": [Vector2i(7, 10), Vector2i(7, 11), Vector2i(6, 11), Vector2i(5, 11), Vector2i(4, 11), Vector2i(3, 11), Vector2i(2, 11), Vector2i(1, 11), Vector2i(1, 12), Vector2i(1, 13), Vector2i(1, 14), Vector2i(1, 15), Vector2i(1, 16), Vector2i(2, 16), Vector2i(3, 16), Vector2i(3, 17)], "speed": 1.48, "color": "pink", "type": "shotgun", "vision": 3.17, "half": 41.5},
				{"pos": Vector2i(8, 16), "patrol": [Vector2i(8, 16), Vector2i(8, 15), Vector2i(9, 15), Vector2i(9, 14), Vector2i(9, 13), Vector2i(8, 13), Vector2i(7, 13), Vector2i(7, 12), Vector2i(7, 11), Vector2i(6, 11), Vector2i(5, 11), Vector2i(4, 11), Vector2i(3, 11), Vector2i(2, 11), Vector2i(2, 12), Vector2i(2, 13)], "speed": 1.38, "color": "orange", "type": "rifle", "vision": 3.17, "half": 41.5},
				{"pos": Vector2i(1, 1), "patrol": [Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3), Vector2i(5, 4), Vector2i(6, 4), Vector2i(6, 5), Vector2i(7, 5), Vector2i(8, 5), Vector2i(9, 5), Vector2i(9, 6), Vector2i(9, 7), Vector2i(9, 8)], "speed": 1.38, "color": "pink", "type": "shotgun", "vision": 3.17, "half": 41.5},
			],
			"key": Vector2i(5, 9),
			"exit": Vector2i(9, 1),
		},
		{
			"name": "The Maze",
			"hint": "A maze of walls. Use corners to stay unseen.",
			"theme": "warehouse",
			"map": [
				"###########",
				"#BX.....C.#",
				"#.C#..B#X.#",
				"#..#.###..#",
				"#.X#.XE#..#",
				"#....X.#..#",
				"#..#...#..#",
				"#...###X..#",
				"#....#K#..#",
				"#.C#C..#X.#",
				"#.###C.##.#",
				"#..#C.X#..#",
				"#..#......#",
				"#..#XXJ#.X#",
				"#..#XX.#.C#",
				"#..#..XXX.#",
				"#.X#P..#.C#",
				"#..#.X.#..#",
				"#.XB..C..X#",
				"###########",
			],
			"guards": [
				{"pos": Vector2i(8, 4), "patrol": [Vector2i(8, 4), Vector2i(9, 4), Vector2i(9, 5), Vector2i(9, 6), Vector2i(9, 7), Vector2i(9, 8), Vector2i(9, 9), Vector2i(9, 10), Vector2i(9, 11), Vector2i(8, 11), Vector2i(8, 12), Vector2i(7, 12)], "speed": 1.44, "color": "orange", "type": "rifle", "vision": 3.2, "half": 41.9},
				{"pos": Vector2i(5, 9), "patrol": [Vector2i(5, 9), Vector2i(4, 9), Vector2i(4, 8), Vector2i(3, 8), Vector2i(2, 8), Vector2i(1, 8), Vector2i(1, 9), Vector2i(1, 10), Vector2i(1, 11), Vector2i(2, 11), Vector2i(2, 12), Vector2i(2, 13)], "speed": 1.49, "color": "pink", "type": "shotgun", "vision": 3.2, "half": 41.9},
				{"pos": Vector2i(9, 17), "patrol": [Vector2i(9, 17), Vector2i(9, 16), Vector2i(9, 15), Vector2i(9, 14), Vector2i(8, 14), Vector2i(8, 13), Vector2i(8, 12), Vector2i(7, 12), Vector2i(6, 12), Vector2i(5, 12), Vector2i(4, 12), Vector2i(4, 11)], "speed": 1.54, "color": "orange", "type": "rifle", "vision": 3.2, "half": 41.9},
				{"pos": Vector2i(4, 5), "patrol": [Vector2i(4, 5), Vector2i(3, 5), Vector2i(2, 5), Vector2i(1, 5), Vector2i(1, 6), Vector2i(1, 7), Vector2i(1, 8), Vector2i(1, 9), Vector2i(1, 10), Vector2i(1, 11), Vector2i(1, 12), Vector2i(1, 13)], "speed": 1.44, "color": "pink", "type": "shotgun", "vision": 3.2, "half": 41.9},
				{"pos": Vector2i(6, 1), "patrol": [Vector2i(6, 1), Vector2i(7, 1), Vector2i(8, 1), Vector2i(9, 1), Vector2i(9, 2), Vector2i(9, 3), Vector2i(8, 3), Vector2i(8, 4), Vector2i(8, 5), Vector2i(8, 6), Vector2i(8, 7), Vector2i(8, 8)], "speed": 1.49, "color": "orange", "type": "rifle", "vision": 3.2, "half": 41.9},
			],
			"key": Vector2i(6, 8),
			"exit": Vector2i(6, 4),
		},
		{
			"name": "Night Watch",
			"hint": "Five guards on night watch. Move like a shadow.",
			"theme": "warehouse",
			"map": [
				"###########",
				"#X.XC...JX#",
				"#X....X...#",
				"##.X#####.#",
				"#....XXXE.#",
				"#..B....#.#",
				"####...####",
				"#....XBX#.#",
				"#.........#",
				"#.###K.####",
				"#.CX..X.C.#",
				"###.CC...C#",
				"#####.###.#",
				"#........X#",
				"#.C..C.X.X#",
				"#..XX...X.#",
				"#...X.XCX.#",
				"#BX..P....#",
				"#...X.X.X.#",
				"###########",
			],
			"guards": [
				{"pos": Vector2i(6, 1), "patrol": [Vector2i(6, 1), Vector2i(5, 1), Vector2i(4, 1), Vector2i(4, 2), Vector2i(3, 2), Vector2i(2, 2), Vector2i(2, 3), Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4), Vector2i(4, 5), Vector2i(5, 5)], "speed": 1.56, "color": "orange", "type": "rifle", "vision": 3.23, "half": 42.2},
				{"pos": Vector2i(8, 10), "patrol": [Vector2i(8, 10), Vector2i(7, 10), Vector2i(7, 11), Vector2i(6, 11), Vector2i(5, 11), Vector2i(5, 12), Vector2i(5, 13), Vector2i(6, 13), Vector2i(6, 14), Vector2i(6, 15), Vector2i(7, 15), Vector2i(7, 16)], "speed": 1.61, "color": "pink", "type": "shotgun", "vision": 3.23, "half": 42.2},
				{"pos": Vector2i(2, 13), "patrol": [Vector2i(2, 13), Vector2i(3, 13), Vector2i(4, 13), Vector2i(5, 13), Vector2i(6, 13), Vector2i(6, 14), Vector2i(6, 15), Vector2i(7, 15), Vector2i(7, 16), Vector2i(7, 17), Vector2i(8, 17), Vector2i(9, 17)], "speed": 1.56, "color": "blue", "type": "grenade", "vision": 3.23, "half": 42.2},
				{"pos": Vector2i(8, 2), "patrol": [Vector2i(8, 2), Vector2i(7, 2), Vector2i(7, 1), Vector2i(6, 1), Vector2i(5, 1), Vector2i(4, 1), Vector2i(4, 2), Vector2i(3, 2), Vector2i(2, 2), Vector2i(2, 3), Vector2i(2, 4), Vector2i(1, 4)], "speed": 1.56, "color": "orange", "type": "rifle", "vision": 3.23, "half": 42.2},
				{"pos": Vector2i(8, 11), "patrol": [Vector2i(8, 11), Vector2i(7, 11), Vector2i(6, 11), Vector2i(5, 11), Vector2i(5, 12), Vector2i(5, 13), Vector2i(4, 13), Vector2i(3, 13), Vector2i(2, 13), Vector2i(1, 13), Vector2i(1, 14), Vector2i(1, 15)], "speed": 1.56, "color": "pink", "type": "shotgun", "vision": 3.23, "half": 42.2},
			],
			"key": Vector2i(5, 9),
			"exit": Vector2i(8, 4),
		},
		{
			"name": "Royal Guard",
			"hint": "The royal guard never rests. Time every step.",
			"theme": "warehouse",
			"map": [
				"###########",
				"#...C.EXXX#",
				"#........X#",
				"#.X#..X##.#",
				"#C.##X.##C#",
				"#X..X..B..#",
				"#.X.C..CX.#",
				"#...#.##X.#",
				"#.X.#XXXX.#",
				"#...#CK...#",
				"#.....X...#",
				"#.X...BX..#",
				"#XX##...#.#",
				"#X.##.X##.#",
				"#X.CXJ....#",
				"#XX..C....#",
				"#P.##.X.X.#",
				"#X..#.X...#",
				"#X....CX.J#",
				"###########",
			],
			"guards": [
				{"pos": Vector2i(2, 2), "patrol": [Vector2i(2, 2), Vector2i(1, 2), Vector2i(1, 3), Vector2i(1, 4), Vector2i(2, 4), Vector2i(2, 5), Vector2i(3, 5), Vector2i(3, 6), Vector2i(4, 6), Vector2i(5, 6), Vector2i(6, 6), Vector2i(7, 6)], "speed": 1.57, "color": "orange", "type": "rifle", "vision": 3.26, "half": 42.5},
				{"pos": Vector2i(7, 9), "patrol": [Vector2i(7, 9), Vector2i(8, 9), Vector2i(9, 9), Vector2i(9, 10), Vector2i(9, 11), Vector2i(9, 12), Vector2i(9, 13), Vector2i(9, 14), Vector2i(8, 14), Vector2i(7, 14), Vector2i(7, 15), Vector2i(7, 16)], "speed": 1.62, "color": "pink", "type": "shotgun", "vision": 3.26, "half": 42.5},
				{"pos": Vector2i(3, 18), "patrol": [Vector2i(3, 18), Vector2i(4, 18), Vector2i(5, 18), Vector2i(5, 17), Vector2i(5, 16), Vector2i(5, 15), Vector2i(6, 15), Vector2i(7, 15), Vector2i(8, 15), Vector2i(9, 15), Vector2i(9, 16), Vector2i(9, 17)], "speed": 1.67, "color": "blue", "type": "grenade", "vision": 3.26, "half": 42.5},
				{"pos": Vector2i(8, 17), "patrol": [Vector2i(8, 17), Vector2i(9, 17), Vector2i(9, 16), Vector2i(9, 15), Vector2i(9, 14), Vector2i(9, 13), Vector2i(9, 12), Vector2i(9, 11), Vector2i(9, 10), Vector2i(9, 9), Vector2i(9, 8), Vector2i(9, 7)], "speed": 1.67, "color": "orange", "type": "rifle", "vision": 3.26, "half": 42.5},
				{"pos": Vector2i(8, 2), "patrol": [Vector2i(8, 2), Vector2i(7, 2), Vector2i(6, 2), Vector2i(5, 2), Vector2i(4, 2), Vector2i(3, 2), Vector2i(2, 2), Vector2i(1, 2), Vector2i(1, 1)], "speed": 1.67, "color": "pink", "type": "shotgun", "vision": 3.26, "half": 42.5},
			],
			"key": Vector2i(6, 9),
			"exit": Vector2i(6, 1),
		},
		{
			"name": "Shadow Master",
			"hint": "Six guards. One shadow. Prove you are the master.",
			"theme": "warehouse",
			"map": [
				"###########",
				"#C...X..C.#",
				"#.BX.XX.X.#",
				"#..X...C..#",
				"#..X.X.#.X#",
				"#B.#.###.X#",
				"#.C#.C.####",
				"#JX..X..###",
				"#EX.......#",
				"#XX#...#X.#",
				"#C.#.KX#..#",
				"#C.#.##XXX#",
				"#......XXX#",
				"#.X.X..#X.#",
				"#...B..##.#",
				"#...CXC.#.#",
				"#X..XX.XP.#",
				"#X........#",
				"#C.XXXXJ.X#",
				"###########",
			],
			"guards": [
				{"pos": Vector2i(9, 1), "patrol": [Vector2i(9, 1), Vector2i(8, 1), Vector2i(7, 1), Vector2i(7, 2), Vector2i(7, 3), Vector2i(6, 3), Vector2i(5, 3), Vector2i(4, 3), Vector2i(4, 4), Vector2i(4, 5), Vector2i(4, 6), Vector2i(5, 6)], "speed": 1.69, "color": "orange", "type": "rifle", "vision": 3.3, "half": 42.8},
				{"pos": Vector2i(9, 10), "patrol": [Vector2i(9, 10), Vector2i(9, 9), Vector2i(9, 8), Vector2i(8, 8), Vector2i(7, 8), Vector2i(6, 8), Vector2i(5, 8), Vector2i(4, 8), Vector2i(4, 9), Vector2i(4, 10), Vector2i(4, 11), Vector2i(4, 12)], "speed": 1.64, "color": "pink", "type": "shotgun", "vision": 3.3, "half": 42.8},
				{"pos": Vector2i(6, 15), "patrol": [Vector2i(6, 15), Vector2i(6, 14), Vector2i(5, 14), Vector2i(5, 13), Vector2i(5, 12), Vector2i(4, 12), Vector2i(4, 11), Vector2i(4, 10), Vector2i(4, 9), Vector2i(4, 8), Vector2i(3, 8), Vector2i(3, 7)], "speed": 1.74, "color": "blue", "type": "grenade", "vision": 3.3, "half": 42.8},
				{"pos": Vector2i(1, 1), "patrol": [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1), Vector2i(4, 2), Vector2i(4, 3), Vector2i(5, 3), Vector2i(6, 3), Vector2i(7, 3), Vector2i(8, 3), Vector2i(9, 3), Vector2i(9, 2)], "speed": 1.74, "color": "orange", "type": "rifle", "vision": 3.3, "half": 42.8},
				{"pos": Vector2i(2, 10), "patrol": [Vector2i(2, 10), Vector2i(1, 10), Vector2i(1, 11), Vector2i(1, 12), Vector2i(1, 13), Vector2i(1, 14), Vector2i(2, 14), Vector2i(2, 15), Vector2i(2, 16), Vector2i(2, 17), Vector2i(2, 18), Vector2i(1, 18)], "speed": 1.74, "color": "pink", "type": "shotgun", "vision": 3.3, "half": 42.8},
				{"pos": Vector2i(3, 16), "patrol": [Vector2i(3, 16), Vector2i(3, 17), Vector2i(4, 17), Vector2i(5, 17), Vector2i(6, 17), Vector2i(7, 17), Vector2i(8, 17), Vector2i(9, 17), Vector2i(9, 16), Vector2i(9, 15), Vector2i(9, 14), Vector2i(9, 13)], "speed": 1.64, "color": "blue", "type": "grenade", "vision": 3.3, "half": 42.8},
			],
			"key": Vector2i(5, 10),
			"exit": Vector2i(1, 8),
		},
	]
	# Levels 11-50: generated by tools/gen_levels.py (deterministic seeds).
	all.append_array(ShadowLevelsGen.get_extra_levels())
	return all


static func validate() -> Array:
	"""Check every level: 20 rows of 11 chars, one P, all coins/gems and
	guard patrol-route tiles reachable from P, clean player start, an
	approach window for every guard, dense-maze shape, fair traps, and
	valid optional type/theme fields. Returns a list of problems."""
	var problems: Array = []
	var levels: Array = get_levels()
	for li in range(levels.size()):
		var lv: Dictionary = levels[li]
		var map: PackedStringArray = lv["map"]
		if map.size() != 20:
			problems.append("L%d: %d rows (want 20)" % [li + 1, map.size()])
			continue
		# Optional fields: theme + guard types must be known values.
		var theme: String = String(lv.get("theme", "warehouse"))
		if theme not in ["warehouse", "cyber", "lab", "prison"]:
			problems.append("L%d: unknown theme %s" % [li + 1, theme])
		for g in lv["guards"]:
			var gtype: String = String(g.get("type", "basic"))
			if gtype not in ["basic", "rifle", "shotgun", "grenade", "sniper", "shielded"]:
				problems.append("L%d: unknown guard type %s" % [li + 1, gtype])
		# Patrol routes (full walked segments, not just waypoints).
		var all_route := {}
		for g in lv["guards"]:
			for t in _patrol_route_tiles(g["patrol"]):
				all_route[t] = true
		var trap_tiles := {}
		for t in lv.get("traps", []):
			trap_tiles[t["pos"]] = true
		var start := Vector2i(-1, -1)
		var goals: Array = []
		var key_tile := Vector2i(-1, -1)
		var exit_tile := Vector2i(-1, -1)
		for y in range(20):
			var row: String = map[y]
			if row.length() != 11:
				problems.append("L%d row %d: %d chars (want 11)" % [li + 1, y, row.length()])
			for x in range(mini(row.length(), 11)):
				var ch: String = row[x]
				if ch == "P":
					start = Vector2i(x, y)
				elif ch == "C" or ch == "J":
					goals.append(Vector2i(x, y))
				elif ch == "K":
					key_tile = Vector2i(x, y)
					goals.append(key_tile)
				elif ch == "E":
					exit_tile = Vector2i(x, y)
					goals.append(exit_tile)
		if key_tile.x < 0:
			problems.append("L%d: no key tile" % [li + 1])
		if exit_tile.x < 0:
			problems.append("L%d: no exit tile" % [li + 1])
		# The "key"/"exit" dict fields must agree with the map chars.
		if lv.has("key") and key_tile.x >= 0 and lv["key"] != key_tile:
			problems.append("L%d: key field %s != map key %s" % [li + 1, str(lv["key"]), str(key_tile)])
		if lv.has("exit") and exit_tile.x >= 0 and lv["exit"] != exit_tile:
			problems.append("L%d: exit field %s != map exit %s" % [li + 1, str(lv["exit"]), str(exit_tile)])
		if not lv.has("key") or not lv.has("exit"):
			problems.append("L%d: missing key/exit fields" % [li + 1])
		if start.x < 0:
			problems.append("L%d: no player start" % [li + 1])
			continue
		for g in lv["guards"]:
			goals.append(g["pos"])
			for wp in _patrol_route_tiles(g["patrol"]):
				goals.append(wp)
		# BFS over walkable tiles ('#' and 'X' block)
		var seen := {}
		var queue: Array = [start]
		seen[start] = true
		while not queue.is_empty():
			var cur: Vector2i = queue.pop_front()
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nb: Vector2i = cur + d
				if nb.x < 0 or nb.y < 0 or nb.x >= 11 or nb.y >= 20:
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
		# Dense-maze shape: blocked fraction >= 0.30 and no 3x3 open floor.
		var blocked := 0
		for y in range(1, 19):
			for x in range(1, 10):
				if map[y][x] == "#" or map[y][x] == "X":
					blocked += 1
		if float(blocked) / 162.0 < 0.30:
			problems.append("L%d: density %.2f < 0.30" % [li + 1, float(blocked) / 162.0])
		var open_found := false
		for y in range(1, 17):
			for x in range(1, 8):
				var all_open := true
				for dy in range(3):
					for dx in range(3):
						if map[y + dy][x + dx] == "#" or map[y + dy][x + dx] == "X":
							all_open = false
				if all_open:
					problems.append("L%d: 3x3 open floor at (%d, %d)" % [li + 1, x, y])
					open_found = true
					break
			if open_found:
				break
		# Trap fairness: traps on walkable floor, off routes, away from
		# the start, and every goal still reachable avoiding all traps.
		for t in lv.get("traps", []):
			var tp: Vector2i = t["pos"]
			if map[tp.y][tp.x] == "#" or map[tp.y][tp.x] == "X":
				problems.append("L%d: trap on unwalkable tile %s" % [li + 1, str(tp)])
			if all_route.has(tp):
				problems.append("L%d: trap on patrol route %s" % [li + 1, str(tp)])
			if maxi(absi(tp.x - start.x), absi(tp.y - start.y)) <= 1:
				problems.append("L%d: trap next to player start %s" % [li + 1, str(tp)])
		if not trap_tiles.is_empty():
			var seen_safe := {}
			var q2: Array = [start]
			seen_safe[start] = true
			while not q2.is_empty():
				var cur2: Vector2i = q2.pop_front()
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nb2: Vector2i = cur2 + d
					if nb2.x < 0 or nb2.y < 0 or nb2.x >= 11 or nb2.y >= 20:
						continue
					if seen_safe.has(nb2) or trap_tiles.has(nb2):
						continue
					var ch2: String = map[nb2.y][nb2.x]
					if ch2 == "#" or ch2 == "X":
						continue
					seen_safe[nb2] = true
					q2.append(nb2)
			for goal in goals:
				if not seen_safe.has(goal):
					problems.append("L%d: goal %s only reachable through a trap" % [li + 1, str(goal)])
					break
		# Vision-cone checks (mirror of tools/gen_levels.py):
		#  - clean start: player start outside every cone at t=0, NOT on
		#    a patrol route, and >= 3 tiles from every guard spawn (no
		#    guard walks past in the opening seconds)
		#  - approach window: every guard has a patrol waypoint where the
		#    player can strike from behind — either a walkable neighbour
		#    tile (not on any route, not a trap) outside EVERY guard's
		#    cone, or the tile two steps back along the guard's own
		#    patrol (the guard just walked away from it, outside his
		#    forward cone and every other guard's cone)
		#  - key/exit placement: key 1-3 tiles from a patrol route and
		#    >= 4 from the player start; exit far from the start and
		#    never on a patrol route.
		var snap: Array = []
		for g in lv["guards"]:
			var patrol: Array = g["patrol"]
			snap.append({
				"pos": g["pos"],
				"facing": _patrol_facing(patrol, 0),
				"vision": float(g.get("vision", 3.67)),
				"half": deg_to_rad(float(g.get("half", 45.0))),
			})
		for sn in snap:
			if _tile_visible(map, sn["pos"], sn["facing"], sn["vision"], sn["half"], start):
				problems.append("L%d: player start inside a vision cone at t=0" % [li + 1])
				break
		if all_route.has(start):
			problems.append("L%d: player start on patrol route at %s" % [li + 1, str(start)])
		for g in lv["guards"]:
			if absi(int(g["pos"].x) - start.x) + absi(int(g["pos"].y) - start.y) < 3:
				problems.append("L%d: player start < 3 tiles from a guard spawn" % [li + 1])
				break
		if key_tile.x >= 0:
			var key_dmin := 99
			for rt in all_route:
				key_dmin = mini(key_dmin, absi(rt.x - key_tile.x) + absi(rt.y - key_tile.y))
			if key_dmin < 1 or key_dmin > 3:
				problems.append("L%d: key %d tiles from nearest patrol route (want 1..3)" % [li + 1, key_dmin])
			if absi(key_tile.x - start.x) + absi(key_tile.y - start.y) < 4:
				problems.append("L%d: key too close to player start" % [li + 1])
		if exit_tile.x >= 0:
			if absi(exit_tile.x - start.x) + absi(exit_tile.y - start.y) < 7:
				problems.append("L%d: exit too close to player start" % [li + 1])
			if all_route.has(exit_tile):
				problems.append("L%d: exit on a patrol route" % [li + 1])
		for gi in range(lv["guards"].size()):
			var g: Dictionary = lv["guards"][gi]
			var patrol: Array = g["patrol"]
			var g_vision: float = float(g.get("vision", 3.67))
			var g_half: float = deg_to_rad(float(g.get("half", 45.0)))
			var has_window := false
			for k in range(patrol.size()):
				var w: Vector2i = patrol[k]
				var facing: float = _patrol_facing(patrol, k)
				# "Sneak up behind": the tile two steps back along this
				# guard's own patrol — he just walked away from it, so
				# it is outside his forward cone; it must also be
				# outside every other guard's cone and off traps.
				if k >= 2:
					var back: Vector2i = patrol[k - 2]
					if not trap_tiles.has(back) and not _tile_visible(map, w, facing, g_vision, g_half, back):
						var seen_by_other := false
						for oj in range(snap.size()):
							if oj == gi:
								continue
							var o2: Dictionary = snap[oj]
							if _tile_visible(map, o2["pos"], o2["facing"], o2["vision"], o2["half"], back):
								seen_by_other = true
								break
						if not seen_by_other:
							has_window = true
							break
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nb: Vector2i = w + d
					if nb.x < 0 or nb.y < 0 or nb.x >= 11 or nb.y >= 20:
						continue
					var ch: String = map[nb.y][nb.x]
					if ch == "#" or ch == "X":
						continue
					if all_route.has(nb) or trap_tiles.has(nb):
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


static func _patrol_route_tiles(patrol: Array) -> Array:
	"""Every tile a guard walks on: the straight segments between
	consecutive waypoints (the guard ping-pongs along them)."""
	var tiles: Array = []
	var seen := {}
	for k in range(patrol.size() - 1):
		var a: Vector2i = patrol[k]
		var b: Vector2i = patrol[k + 1]
		if a.x == b.x:
			var step: int = 1 if b.y > a.y else -1
			var y: int = a.y
			while true:
				var t := Vector2i(a.x, y)
				if not seen.has(t):
					seen[t] = true
					tiles.append(t)
				if y == b.y:
					break
				y += step
		else:
			var step: int = 1 if b.x > a.x else -1
			var x: int = a.x
			while true:
				var t := Vector2i(x, a.y)
				if not seen.has(t):
					seen[t] = true
					tiles.append(t)
				if x == b.x:
					break
				x += step
	return tiles


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
