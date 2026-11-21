extends SceneTree
## Test for the Shadow Assassin v6 per-mission colours (Buddhika,
## 2026-11-21 21:44: "the colours must change from mission to mission
## — different background colours for different missions, so each
## mission looks different").
## Checks:
##   1. The four band palettes (warehouse / cyber / lab / prison) have
##      clearly different floor colours (pairwise distance > 0.35).
##   2. Floors stay LIGHT (every channel >= 0.5) so guards, cones, the
##      key and the exit stay readable on every mission.
##   3. The palette varies per level within a band (L1 vs L2 differ).
##   4. Runtime: the board actually renders different colours — L1
##      (warehouse) vs L13 (cyber) wall/floor tints differ a lot.
## Run UNDER xvfb-run (NOT --headless): xvfb-run -a godot --path . -s res://tests/theme_test.gd

var main: Node
var frame := 0
var phase := 0
var wait_until := 0
var _mod_l1 := Color(0, 0, 0)


func _initialize() -> void:
	KillGuide.force_skip = true
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	root.add_child(main)
	print("[THEME] main scene loaded")


func _cdist(a: Color, b: Color) -> float:
	return sqrt((a.r - b.r) * (a.r - b.r) + (a.g - b.g) * (a.g - b.g) + (a.b - b.b) * (a.b - b.b))


func _fail(msg: String) -> bool:
	print("[THEME] FAIL: " + msg)
	quit(1)
	return true


func _board_tint(game) -> Color:
	for c in game._board.get_children():
		if c is Sprite2D:
			return (c as Sprite2D).modulate
	return Color(0, 0, 0)


func _process(_delta: float) -> bool:
	frame += 1
	match phase:
		0:
			if frame < 5:
				return false
			# --- (1) band palettes are clearly different ---
			var bands := ["warehouse", "cyber", "lab", "prison"]
			var floors := {}
			for b in bands:
				floors[b] = (ShadowGame.THEMES[b] as Dictionary)["floor"]
			for i in range(bands.size()):
				for j in range(i + 1, bands.size()):
					var d: float = _cdist(floors[bands[i]], floors[bands[j]])
					if d < 0.35:
						return _fail("(1) band floors %s vs %s are too close (distance %.2f)" % [bands[i], bands[j], d])
			print("[THEME] (1) PASS: all four band floor colours are clearly different")
			# --- (2) floors stay light (readable) ---
			for b in bands:
				var f: Color = floors[b]
				if f.r < 0.5 or f.g < 0.5 or f.b < 0.5:
					return _fail("(2) %s floor is too dark (%s) — guards/cones must stay readable" % [b, str(f)])
			print("[THEME] (2) PASS: all floors stay light and readable")
			# --- (3) palette varies per level within a band ---
			var p1: Dictionary = ShadowGame.theme_palette_for_theme("warehouse", 0)
			var p2: Dictionary = ShadowGame.theme_palette_for_theme("warehouse", 1)
			var p13: Dictionary = ShadowGame.theme_palette_for_theme("cyber", 12)
			if _cdist(p1["floor"], p2["floor"]) < 0.02:
				return _fail("(3) L1 vs L2 palettes are identical — missions in one band must vary")
			if _cdist(p1["floor"], p13["floor"]) < 0.3:
				return _fail("(3) L1 (warehouse) vs L13 (cyber) palettes are too close")
			print("[THEME] (3) PASS: palette varies per level and per band")
			# --- (4) runtime: the board renders the mission colours ---
			main.start_level(0)
			phase = 1
			wait_until = frame + 15
		1:
			if frame < wait_until:
				return false
			var game = main.game
			if game == null:
				return _fail("game is null after start_level(0)")
			_mod_l1 = _board_tint(game)
			print("[THEME] (4) L1 board tint: %s" % str(_mod_l1))
			main.start_level(12)
			phase = 2
			wait_until = frame + 15
		2:
			if frame < wait_until:
				return false
			var game = main.game
			if game == null:
				return _fail("game is null after start_level(12)")
			var mod_l13: Color = _board_tint(game)
			print("[THEME] (4) L13 board tint: %s" % str(mod_l13))
			if _cdist(_mod_l1, mod_l13) < 0.3:
				return _fail("(4) L1 vs L13 boards render too similarly (%s vs %s)" % [str(_mod_l1), str(mod_l13)])
			print("[THEME] (4) PASS: L1 and L13 boards look clearly different")
			print("[THEME] ALL CHECKS PASS")
			quit(0)
			return true
	if frame > 1200:
		return _fail("theme test timed out (phase %d)" % phase)
	return false
