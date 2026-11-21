extends SceneTree
## Screenshot harness for Shadow Assassin v5 verification.
## Run UNDER xvfb-run: xvfb-run -a godot --path . --resolution 720x1640 -s res://tests/shot_harness_v5.gd
## Env vars: SHOT_LEVEL (level index, default 0), OUTDIR (default
## res://verification/shots-v5), SHOT_MENU (1 = shoot the redesigned
## homepage instead of a level), SHOT_COIN (1 = collect a coin first so
## the HUD coin counter shows a value), SHOT_TUTORIAL (1 = fresh hints
## so the L1 move coach mark shows), SHOT_NAME (output file name).
## Waits for the board/menu to build, then saves a PNG and quits.

var main: Node
var frame := 0
var _level := 0
var _outdir := "res://verification/shots-v5"
var _tutorial := false
var _menu := false
var _coin := false
var _name := ""


func _initialize() -> void:
	_level = int(OS.get_environment("SHOT_LEVEL")) if OS.get_environment("SHOT_LEVEL") != "" else 0
	_outdir = OS.get_environment("OUTDIR") if OS.get_environment("OUTDIR") != "" else "res://verification/shots-v5"
	_tutorial = OS.get_environment("SHOT_TUTORIAL") == "1"
	_menu = OS.get_environment("SHOT_MENU") == "1"
	_coin = OS.get_environment("SHOT_COIN") == "1"
	_name = OS.get_environment("SHOT_NAME") if OS.get_environment("SHOT_NAME") != "" else "level_%d.png" % (_level + 1)
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	root.add_child(main)
	print("[SHOT5] menu=%s coin=%s level=%d out=%s/%s" % [str(_menu), str(_coin), _level + 1, _outdir, _name])


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 3:
		if _tutorial:
			main.save["hints_seen"] = []
			main.save["total_coins"] = 0
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
					print("[SHOT5] collected a coin for the HUD shot (tile %s)" % str(c["tile"]))
					break
	if frame == 45:
		var dir := DirAccess.open(_outdir)
		if dir == null:
			DirAccess.make_dir_recursive_absolute(_outdir)
		var img: Image = root.get_texture().get_image()
		var err := img.save_png(_outdir + "/" + _name)
		if err != OK:
			print("[SHOT5] FAIL: save_png returned %d" % err)
			quit(1)
			return true
		print("[SHOT5] saved %s/%s (%dx%d)" % [_outdir, _name, img.get_width(), img.get_height()])
		quit(0)
		return true
	if frame > 300:
		print("[SHOT5] FAIL: timed out")
		quit(1)
		return true
	return false
