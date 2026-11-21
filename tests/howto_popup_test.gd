extends SceneTree
## Test for the How to Play popup — SMALL SQUARE WINDOW (Buddhika, 2026-11-21 18:15).
## Run UNDER xvfb-run (NOT --headless): xvfb-run -a godot --path . -s res://tests/howto_popup_test.gd
## Replaces the tall-panel design (v3-admob: 560x680, 5 lines + X + Got it!):
## the window must now be a SMALL SQUARE (480x480, centred), with a brief
## short description and an X close button at the top-right. The old bug
## this guards against: a popup with NO working way out (long text pushed
## the close button off the panel, trapping the player on the menu).
## Checks:
##   1. Popup opens as a small square window (480x480, centred); the X
##      button sits at the top-right of the window and is fully on screen;
##      the text is brief (5 short bullets, no long paragraphs).
##   2. A tap on the panel body (not on any button) dismisses the popup.
##   3. A tap on the dim outside the panel dismisses the popup.
##   4. A tap on the X button dismisses the popup on the FIRST tap.

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
			# --- small SQUARE window, centred ---
			if _panel.size != Vector2(480, 480):
				return _fail("popup must be a small 480x480 square window, got size %s" % str(_panel.size))
			var want_pos := Vector2((720 - 480) * 0.5, (1280 - 480) * 0.5)
			if _panel.position.distance_to(want_pos) > 2.0:
				return _fail("popup must be centred at %s, got %s" % [str(want_pos), str(_panel.position)])
			# --- X button: top-right of the window, fully on screen ---
			var xbtn := _find_button("X")
			if xbtn == null:
				return _fail("close (X) button missing from popup")
			var vr := Rect2(Vector2.ZERO, Vector2(720, 1280))
			var xr := xbtn.get_global_rect()
			if not vr.encloses(xr):
				return _fail("X button not fully on screen: %s" % str(xr))
			var pr := _panel.get_global_rect()
			if absf(xr.end.x - pr.end.x) > 32.0 or absf(xr.position.y - pr.position.y) > 32.0:
				return _fail("X button must sit at the top-right of the window (X %s, panel %s)" % [str(xr), str(pr)])
			# --- brief text: 5 short bullets, no long paragraphs ---
			var body: Label = null
			for l in _panel.find_children("*", "Label", true, false):
				if (l as Label).text.begins_with("• Tap a tile"):
					body = l
			if body == null:
				return _fail("howto body label missing")
			if body.text.count("•") != 5:
				return _fail("howto text must be 5 short bullets, got %d" % body.text.count("•"))
			if body.text.length() > 320:
				return _fail("howto text must stay brief, got %d chars" % body.text.length())
			if not body.text.contains("KEY") or not body.text.contains("EXIT"):
				return _fail("howto text must still teach KEY + EXIT")
			print("[HOWTO] small square window OK (480x480 centred, X top-right %s, %d chars)" % [str(xr), body.text.length()])
			# --- tap the panel body (not a button) -> must dismiss ---
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
			wait_until = frame + 4
		6:
			if frame < wait_until:
				return false
			if _find_popup():
				return _fail("tap on the X button did NOT dismiss the popup on the first tap")
			print("[HOWTO] tap on X button dismisses on first tap: PASS")
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
