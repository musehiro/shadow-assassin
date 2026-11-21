extends SceneTree
## Screenshot harness for Shadow Assassin v4 verification.
## Run UNDER xvfb-run: xvfb-run -a godot --path . --resolution 720x1640 -s res://tests/shot_harness_v4.gd
## Env vars: SHOT_LEVEL (level index, default 0), OUTDIR (default
## res://verification/shots-v4), SHOT_TUTORIAL (1 = fresh hints so the
## L1 move coach mark shows), SHOT_NAME (output file name, default
## level_<n>.png). Waits for the board to build, then saves a PNG of
## the viewport and quits.

var main: Node
var frame := 0
var _level := 0
var _outdir := "res://verification/shots-v4"
var _tutorial := false
var _name := ""


func _initialize() -> void:
	_level = int(OS.get_environment("SHOT_LEVEL")) if OS.get_environment("SHOT_LEVEL") != "" else 0
	_outdir = OS.get_environment("OUTDIR") if OS.get_environment("OUTDIR") != "" else "res://verification/shots-v4"
	_tutorial = OS.get_environment("SHOT_TUTORIAL") == "1"
	_name = OS.get_environment("SHOT_NAME") if OS.get_environment("SHOT_NAME") != "" else "level_%d.png" % (_level + 1)
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	root.add_child(main)
	print("[SHOT] level %d, tutorial=%s, out=%s/%s" % [_level + 1, str(_tutorial), _outdir, _name])


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 3:
		if _tutorial:
			main.save["hints_seen"] = []
			main.save["total_coins"] = 0
		main.start_level(_level)
	if frame == 45:
		var dir := DirAccess.open(_outdir)
		if dir == null:
			DirAccess.make_dir_recursive_absolute(_outdir)
		var img: Image = root.get_texture().get_image()
		var err := img.save_png(_outdir + "/" + _name)
		if err != OK:
			print("[SHOT] FAIL: save_png returned %d" % err)
			quit(1)
			return true
		print("[SHOT] saved %s/%s (%dx%d)" % [_outdir, _name, img.get_width(), img.get_height()])
		quit(0)
		return true
	if frame > 300:
		print("[SHOT] FAIL: timed out")
		quit(1)
		return true
	return false
