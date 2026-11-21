extends SceneTree
## Screenshot harness for the How to Play popup (small square window).
## Run UNDER xvfb-run: xvfb-run -a godot --path . --resolution 720x1280 -s res://tests/howto_shot.gd
## Env vars: OUTDIR (default res://verification/shots-v4), SHOT_NAME
## (default howto_720x1280.png). Opens the menu, shows the popup, saves
## a PNG of the viewport and quits.

var main: Node
var frame := 0
var _outdir := "res://verification/shots-v4"
var _name := "howto_720x1280.png"


func _initialize() -> void:
	_outdir = OS.get_environment("OUTDIR") if OS.get_environment("OUTDIR") != "" else "res://verification/shots-v4"
	_name = OS.get_environment("SHOT_NAME") if OS.get_environment("SHOT_NAME") != "" else "howto_720x1280.png"
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	root.add_child(main)
	print("[HOWTO-SHOT] out=%s/%s" % [_outdir, _name])


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 10:
		main._show_howto()
	if frame == 30:
		if DirAccess.open(_outdir) == null:
			DirAccess.make_dir_recursive_absolute(_outdir)
		var img: Image = root.get_texture().get_image()
		var err := img.save_png(_outdir + "/" + _name)
		if err != OK:
			print("[HOWTO-SHOT] FAIL: save_png returned %d" % err)
			quit(1)
			return true
		print("[HOWTO-SHOT] saved %s/%s (%dx%d)" % [_outdir, _name, img.get_width(), img.get_height()])
		quit(0)
		return true
	if frame > 300:
		print("[HOWTO-SHOT] FAIL: timed out")
		quit(1)
		return true
	return false
