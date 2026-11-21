extends SceneTree
## Test for the Shadow Assassin v5 homepage redesign (Buddhika, 2026-11-21
## 20:11: "redesign the homepage completely — more colours, beautiful;
## a BIG PLAY button, tap it and play at once; the How to Play button
## SMALL and separate in a corner").
## Run UNDER xvfb-run (NOT --headless): xvfb-run -a godot --path . -s res://tests/homepage_test.gd
## Exercises:
##   1. A BIG PLAY button, front and centre (>= 480x110), labelled PLAY.
##   2. The How to Play button is SMALL (<= 200px wide) and sits in a
##      corner (top-right), separate from PLAY.
##   3. Sound is a small corner button too (top-left).
##   4. ASSASSINS roster and LEVELS grid are still reachable.
##   5. Tapping PLAY starts the game at once (level 1, PLAYING state).

var main: Node
var frame := 0
var phase := 0
var wait_until := 0


func _initialize() -> void:
	KillGuide.force_skip = true # v6: the first-play kill guide would pause the game
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	root.add_child(main)
	print("[HOME] main scene loaded")


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


func _cdist(a: Color, b: Color) -> float:
	return sqrt((a.r - b.r) * (a.r - b.r) + (a.g - b.g) * (a.g - b.g) + (a.b - b.b) * (a.b - b.b))


func _find_button(text: String) -> Button:
	for c in main.menu_layer.get_children():
		if c is Button and (c as Button).text == text:
			return c
	return null


func _find_label(text: String) -> Label:
	for c in main.menu_layer.get_children():
		if c is Label and String((c as Label).text).contains(text):
			return c
	return null


func _process(_delta: float) -> bool:
	frame += 1
	match phase:
		0:
			if frame < 5:
				return false
			if main.menu_layer == null:
				return _fail("menu_layer is null — the homepage did not build")
			# v6: unlock all levels so the mission-band button colours
			# are visible, then rebuild the menu (only valid once
			# frames are running — get_viewport() is null in _initialize).
			main.save["unlocked"] = 49
			main.show_menu()
			phase = 2
			wait_until = frame + 10
		2:
			if frame < wait_until:
				return false
			if main.menu_layer == null:
				return _fail("menu_layer is null after rebuild")
			# --- BIG PLAY, front and centre ---
			var play := _find_button("▶  PLAY")
			if play == null:
				return _fail("no big PLAY button on the homepage")
			if play.size.x < 480.0 or play.size.y < 110.0:
				return _fail("PLAY must be BIG (>= 480x110), got %s" % str(play.size))
			if absf(play.position.x - (720.0 - play.size.x) * 0.5) > 5.0:
				return _fail("PLAY must be centred, x=%s (want ~%s)" % [str(play.position.x), str((720.0 - play.size.x) * 0.5)])
			print("[HOME] BIG PLAY OK (%s at %s)" % [str(play.size), str(play.position)])
			# --- How to Play: SMALL, in a corner, separate from PLAY ---
			var howto := _find_button("How to Play")
			if howto == null:
				return _fail("How to Play button is missing from the homepage")
			if howto.size.x > 200.0 or howto.size.y > 80.0:
				return _fail("How to Play must be SMALL (<= 200x80), got %s" % str(howto.size))
			if not (howto.position.x > 500.0 and howto.position.y < 120.0):
				return _fail("How to Play must sit in the top-right corner, got %s" % str(howto.position))
			if howto.get_global_rect().intersects(play.get_global_rect()):
				return _fail("How to Play must not overlap the PLAY button")
			print("[HOME] small corner How to Play OK (%s at %s)" % [str(howto.size), str(howto.position)])
			# --- Sound: small corner button too ---
			var mute: Button = null
			for c in main.menu_layer.get_children():
				if c is Button and String((c as Button).text).begins_with("Sound"):
					mute = c
			if mute == null:
				return _fail("Sound button is missing from the homepage")
			if mute.size.x > 200.0 or mute.position.y > 120.0 or mute.position.x > 200.0:
				return _fail("Sound must be a small top-left corner button, got %s at %s" % [str(mute.size), str(mute.position)])
			# --- ASSASSINS + LEVELS still reachable ---
			if _find_label("ASSASSINS") == null:
				return _fail("ASSASSINS roster is missing from the homepage")
			if _find_label("LEVELS") == null:
				return _fail("LEVELS section is missing from the homepage")
			var grid: GridContainer = null
			for c in main.menu_layer.get_children():
				if c is ScrollContainer:
					for g in (c as ScrollContainer).get_children():
						if g is GridContainer:
							grid = g
			if grid == null or grid.get_child_count() != 50:
				return _fail("LEVELS grid must have 50 level buttons, got %s" % str(grid.get_child_count() if grid != null else -1))
			print("[HOME] ASSASSINS + LEVELS (50 buttons) reachable")
			# --- v6 tagline under the title ---
			var tag := _find_label("Think with your brain")
			if tag == null:
				return _fail("the 'Think with your brain' tagline is missing from the homepage")
			print("[HOME] tagline OK: '%s'" % tag.text)
			# --- v6: level buttons colour-coded by mission band ---
			var band_idxs := [0, 12, 25, 38]
			var band_cols := {}
			for bi in band_idxs:
				var bb := grid.get_child(bi) as Button
				band_cols[bi] = (bb.get_theme_stylebox("normal") as StyleBoxFlat).bg_color
			for a in range(band_idxs.size()):
				for b in range(a + 1, band_idxs.size()):
					if _cdist(band_cols[band_idxs[a]], band_cols[band_idxs[b]]) < 0.3:
						return _fail("level buttons must be colour-coded by mission band (L%d %s vs L%d %s too close)" % [band_idxs[a] + 1, str(band_cols[band_idxs[a]]), band_idxs[b] + 1, str(band_cols[band_idxs[b]])])
			print("[HOME] mission-band colours OK (L1 %s, L13 %s, L26 %s, L39 %s)" % [str(band_cols[0]), str(band_cols[12]), str(band_cols[25]), str(band_cols[38])])
			# --- tap PLAY: the game must start at once ---
			var c := play.get_global_rect().get_center()
			_tap(c)
			_release(c)
			phase = 1
			wait_until = frame + 30
		1:
			if frame < wait_until:
				return false
			if main.game == null:
				return _fail("tapping PLAY did not start the game")
			if main.game.state != main.game.State.PLAYING:
				return _fail("game started but is not PLAYING (state=%d)" % main.game.state)
			print("[HOME] tap PLAY -> level %d playing at once; PASS" % (main.game.level_index + 1))
			print("[HOME] ALL CHECKS PASS")
			quit(0)
			return true
	if frame > 1200:
		return _fail("homepage test timed out (phase %d)" % phase)
	return false


func _fail(msg: String) -> bool:
	print("[HOME] FAIL: " + msg)
	quit(1)
	return true
