extends SceneTree
## Headless validation for Shadow Assassin levels.
## Run: godot --headless -s res://tests/validate_levels.gd
## Checks: 50 levels exist, ShadowLevels.validate() finds no problems,
## and the hardest level (50) loads and runs in PLAYING state.

var main: Node
var frame := 0
var phase := 0


func _initialize() -> void:
	var levels: Array = ShadowLevels.get_levels()
	print("[VALIDATE] levels: %d" % levels.size())
	if levels.size() != 50:
		print("[VALIDATE] FAIL: expected 50 levels, got %d" % levels.size())
		quit(1)
		return
	var problems: Array = ShadowLevels.validate()
	if problems.is_empty():
		print("[VALIDATE] validate(): no problems in any level")
	else:
		print("[VALIDATE] FAIL: %d problems:" % problems.size())
		for p in problems:
			print("  - " + str(p))
		quit(1)
		return
	# Guard-count curve + optional-field coverage (schema contract).
	var want_counts := {1: 2, 2: 3, 3: 3, 4: 4, 10: 6, 50: 9}
	for lv_no in want_counts:
		var got: int = (levels[lv_no - 1] as Dictionary)["guards"].size()
		if got != want_counts[lv_no]:
			print("[VALIDATE] FAIL: level %d has %d guards (want %d)" % [lv_no, got, want_counts[lv_no]])
			quit(1)
			return
	var want_themes := {1: "warehouse", 13: "cyber", 26: "lab", 38: "prison"}
	for lv_no in want_themes:
		var got_theme: String = String((levels[lv_no - 1] as Dictionary).get("theme", ""))
		if got_theme != want_themes[lv_no]:
			print("[VALIDATE] FAIL: level %d theme is %s (want %s)" % [lv_no, got_theme, want_themes[lv_no]])
			quit(1)
			return
	for li in range(levels.size()):
		var lv: Dictionary = levels[li]
		if not lv.has("theme"):
			print("[VALIDATE] FAIL: level %d has no theme" % [li + 1])
			quit(1)
			return
		for g in lv["guards"]:
			if not (g as Dictionary).has("type"):
				print("[VALIDATE] FAIL: level %d guard has no type" % [li + 1])
				quit(1)
				return
	print("[VALIDATE] guard curve + themes + types OK")
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	root.add_child(main)
	print("[VALIDATE] main scene loaded")


func _process(_delta: float) -> bool:
	frame += 1
	match phase:
		0:
			if frame >= 5:
				main.start_level(49)
				print("[VALIDATE] level 50 started")
				phase = 1
		1:
			if frame >= 65:
				var game = main.game
				if game == null:
					return _fail("game is null after start_level(49)")
				if game.state != game.State.PLAYING:
					return _fail("level 50 not in PLAYING state (state=%d)" % game.state)
				if game.guards.size() != 9:
					return _fail("level 50 has %d guards (want 9)" % game.guards.size())
				if game.targets_left != 9:
					return _fail("level 50 targets_left=%d (want 9)" % game.targets_left)
				print("[VALIDATE] level 50 running: 9 guards, %d coins, state PLAYING" % game.coins_total)
				print("[VALIDATE] PASS")
				quit(0)
				return true
	if frame > 600:
		return _fail("validation timed out")
	return false


func _fail(msg: String) -> bool:
	print("[VALIDATE] FAIL: " + msg)
	quit(1)
	return true
