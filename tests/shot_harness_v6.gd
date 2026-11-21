extends SceneTree
## Screenshot harness for Shadow Assassin v6 verification.
## Run UNDER xvfb-run: xvfb-run -a godot --path . --resolution 720x1640 -s res://tests/shot_harness_v6.gd
## Env vars: SHOT_LEVEL (level index, default 0), OUTDIR (default
## res://verification/shots-v6), SHOT_MENU (1 = shoot the redesigned
## homepage), SHOT_GUIDE (1 = guide window 1, 2 = guide window 2),
## SHOT_CHASE (1 = alerted guard chasing around the wall), SHOT_COIN
## (1 = collect a coin first so the HUD coin counter shows a value),
## SHOT_TUTORIAL (1 = fresh hints so the L1 move coach mark shows),
## SHOT_FRAME (frame to shoot at, default 45), SHOT_NAME (file name).
## Waits for the board/menu to build, then saves a PNG and quits.

var main: Node
var frame := 0
var _level := 0
var _outdir := "res://verification/shots-v6"
var _tutorial := false
var _menu := false
var _coin := false
var _guide := 0
var _chase := false
var _shot_frame := 45
var _name := ""


func _initialize() -> void:
	KillGuide.force_skip = true
	_level = int(OS.get_environment("SHOT_LEVEL")) if OS.get_environment("SHOT_LEVEL") != "" else 0
	_outdir = OS.get_environment("OUTDIR") if OS.get_environment("OUTDIR") != "" else "res://verification/shots-v6"
	_tutorial = OS.get_environment("SHOT_TUTORIAL") == "1"
	_menu = OS.get_environment("SHOT_MENU") == "1"
	_coin = OS.get_environment("SHOT_COIN") == "1"
	_guide = int(OS.get_environment("SHOT_GUIDE")) if OS.get_environment("SHOT_GUIDE") != "" else 0
	_chase = OS.get_environment("SHOT_CHASE") == "1"
	_shot_frame = int(OS.get_environment("SHOT_FRAME")) if OS.get_environment("SHOT_FRAME") != "" else 45
	_name = OS.get_environment("SHOT_NAME") if OS.get_environment("SHOT_NAME") != "" else "level_%d.png" % (_level + 1)
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	root.add_child(main)
	print("[SHOT6] menu=%s guide=%d chase=%s level=%d out=%s/%s" % [str(_menu), _guide, str(_chase), _level + 1, _outdir, _name])


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 3:
		if _tutorial:
			main.save["hints_seen"] = []
		if _chase:
			main.save["hints_seen"] = ["move", "weapons", "pause", "key", "exit", "gun"]
			main.save["total_coins"] = 0
		if _guide > 0:
			KillGuide.force_skip = false
			main.save["kill_guide_seen"] = false
		if not _menu:
			main.start_level(_level)
	if frame == 12 and not _menu:
		var game = main.game
		if game != null and _coin:
			for g in game.guards:
				g.freeze(120.0)
			for c in game.coins:
				if not bool(c["is_gem"]) and not bool(c["taken"]):
					game.debug_teleport_to_tile(c["tile"])
					print("[SHOT6] collected a coin for the HUD shot (tile %s)" % str(c["tile"]))
					break
		if game != null and _chase:
			for g in game.guards:
				g.vision_range = 0.0
			game.guards[1].freeze(120.0)
			var g0: Guard = game.guards[0]
			g0.position = game.tile_to_world(Vector2i(2, 8))
			game.debug_teleport_to_tile(Vector2i(6, 8))
			game.player.stop()
			g0.state = Guard.State.ALERT
			g0._last_seen_pos = game.tile_to_world(Vector2i(6, 8))
			g0._chase_path.clear()
			g0._chase_target_tile = Vector2i(-999, -999)
			print("[SHOT6] chase staged: guard at (2,8) hunting the player at (6,8)")
	if frame == 14 and _guide == 2:
		var game = main.game
		if game != null and game._kill_guide != null:
			game._kill_guide.xbtn1.emit_signal("pressed")
			print("[SHOT6] closed guide window 1 -> window 2")
	if frame == _shot_frame:
		var dir := DirAccess.open(_outdir)
		if dir == null:
			DirAccess.make_dir_recursive_absolute(_outdir)
		var img: Image = root.get_texture().get_image()
		var err := img.save_png(_outdir + "/" + _name)
		if err != OK:
			print("[SHOT6] FAIL: save_png returned %d" % err)
			quit(1)
			return true
		print("[SHOT6] saved %s/%s (%dx%d)" % [_outdir, _name, img.get_width(), img.get_height()])
		quit(0)
		return true
	if frame > 300:
		print("[SHOT6] FAIL: timed out")
		quit(1)
		return true
	return false
