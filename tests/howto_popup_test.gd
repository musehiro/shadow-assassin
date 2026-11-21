extends SceneTree
## Headless test for the How to Play popup fix (Buddhika, 2026-11-21).
## Run UNDER xvfb-run (NOT --headless): xvfb-run -a godot --path . -s res://tests/howto_popup_test.gd
## Regression: the old popup's long text pushed the "Got it!" close button
## off the bottom of the panel, so there was NO way to close it — the
## player was stuck on the menu and could never reach Play.
## Checks:
##   1. Popup opens; the "Got it!" button is fully inside the viewport
##      (visible and tappable) and a close (X) button exists.
##   2. A tap on the panel body (not on any button) dismisses the popup.
##   3. A tap on the dim outside the panel dismisses the popup.
##   4. A tap on the X button dismisses the popup.
##   5. A tap on "Got it!" dismisses the popup.

var main: Node
var frame := 0
var phase := 0
var wait_until := 0
var _panel: Control
var _dim: Control


func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	root.add_child(main)
	print("[HOWTO] main scene loaded")


func _tap(world_pos: Vector2) -> void:
	var ev := InputEventScreenTouch.new()
	ev.pressed = true
	ev.position = world_pos
	ev.index = 0
	Input.parse_input_event(ev)


func _release(world_pos: Vector2) -> void:
	var ev := InputEventScreenTouch.new()
	ev.pressed = false
	ev.position = world_pos
	ev.index = 0
	Input.parse_input_event(ev)


func _find_popup() -> bool:
	_panel = null
	_dim = null
	if main.menu_layer == null:
		return false
	for c in main.menu_layer.get_children():
		if c is PanelContainer:
			_panel = c
		elif c is ColorRect and (c as ColorRect).color == Color(0, 0, 0, 0.6):
			_dim = c
	return _panel != null and _dim != null


func _find_button(text: String) -> Button:
	if _panel == null:
		return null
	for b in _panel.find_children("*", "Button", true, false):
		if (b as Button).text == text:
			return b
	return null


func _process(_delta: float) -> bool:
	frame += 1
	match phase:
		0:
			if frame >= 5:
				main._show_howto()
				phase = 1
				wait_until = frame + 5
		1:
			if frame < wait_until:
				return false
			if not _find_popup():
				return _fail("popup did not open (no PanelContainer/dim in menu_layer)")
			var gotit := _find_button("Got it!")
			if gotit == null:
				return _fail("'Got it!' button missing from popup")
			var xbtn := _find_button("X")
			if xbtn == null:
				return _fail("close (X) button missing from popup")
			var vr := Rect2(Vector2.ZERO, Vector2(720, 1280))
			var gr := gotit.get_global_rect()
			if not vr.encloses(gr):
				return _fail("'Got it!' button not fully on screen: %s (viewport %s)" % [str(gr), str(vr)])
			var xr := xbtn.get_global_rect()
			if not vr.encloses(xr):
				return _fail("X button not fully on screen: %s" % str(xr))
			print("[HOWTO] popup opens; 'Got it!' %s and X %s both on screen" % [str(gr), str(xr)])
			# --- tap the panel body (not a button) -> must dismiss ---
			var body: Label = null
			for l in _panel.find_children("*", "Label", true, false):
				if (l as Label).text.begins_with("• Tap a tile"):
					body = l
			if body == null:
				return _fail("howto body label missing")
			var bc := body.get_global_rect().get_center()
			_tap(bc)
			_release(bc)
			phase = 2
			wait_until = frame + 10
		2:
			if frame < wait_until:
				return false
			if _find_popup():
				return _fail("tap on the panel body did NOT dismiss the popup")
			print("[HOWTO] tap on panel body dismisses: PASS")
			main._show_howto()
			phase = 3
			wait_until = frame + 5
		3:
			if frame < wait_until:
				return false
			if not _find_popup():
				return _fail("popup did not reopen for the dim-tap check")
			_tap(Vector2(40, 60))
			_release(Vector2(40, 60))
			phase = 4
			wait_until = frame + 10
		4:
			if frame < wait_until:
				return false
			if _find_popup():
				return _fail("tap on the dim outside the panel did NOT dismiss the popup")
			print("[HOWTO] tap on dim dismisses: PASS")
			main._show_howto()
			phase = 5
			wait_until = frame + 5
		5:
			if frame < wait_until:
				return false
			if not _find_popup():
				return _fail("popup did not reopen for the X-button check")
			var xbtn := _find_button("X")
			if xbtn == null:
				return _fail("X button missing on reopen")
			var c := xbtn.get_global_rect().get_center()
			_tap(c)
			_release(c)
			phase = 6
			wait_until = frame + 10
		6:
			if frame < wait_until:
				return false
			if _find_popup():
				return _fail("tap on the X button did NOT dismiss the popup")
			print("[HOWTO] tap on X button dismisses: PASS")
			main._show_howto()
			phase = 7
			wait_until = frame + 5
		7:
			if frame < wait_until:
				return false
			if not _find_popup():
				return _fail("popup did not reopen for the Got-it check")
			var gotit := _find_button("Got it!")
			if gotit == null:
				return _fail("'Got it!' button missing on reopen")
			var c := gotit.get_global_rect().get_center()
			_tap(c)
			_release(c)
			phase = 8
			wait_until = frame + 10
		8:
			if frame < wait_until:
				return false
			if _find_popup():
				return _fail("tap on 'Got it!' did NOT dismiss the popup")
			print("[HOWTO] tap on 'Got it!' dismisses: PASS")
			print("[HOWTO] ALL CHECKS PASS")
			quit(0)
			return true
	if frame > 1200:
		return _fail("howto popup test timed out (phase %d)" % phase)
	return false


func _fail(msg: String) -> bool:
	print("[HOWTO] FAIL: " + msg)
	quit(1)
	return true
