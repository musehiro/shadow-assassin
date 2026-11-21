extends SceneTree
## Test for Shadow Assassin v4 tutorial coach marks.
## Run UNDER xvfb-run (NOT --headless): xvfb-run -a godot --path . -s res://tests/tutorial_test.gd
## (Injected input needs a real window; see movement_key_exit_test.gd.)
## Exercises, with a FRESH hints list (restored at the end):
##   1. L1: the move hint appears at level start (drawn hand + short text
##      + Skip button); a tap while it is visible still moves the player
##      (hint never blocks play) and dismisses the hint for good.
##   2. L1: weapons hint, then pause hint — Skip dismisses each for good.
##   3. L1: key hint when the player walks near the key; exit hint once
##      the key is collected; winning the level marks the exit hint seen.
##   4. Restarting L1 shows NO hint again (all seen).
##   5. L3 shows NO hint (hints are L1/L2 only).
##   6. Gun hint appears when the player banks 500 coins even on L3;
##      Skip dismisses it and it never comes back.
## Guards are frozen: this test isolates the tutorial, not stealth.

var main: Node
var frame := 0
var phase := 0
var wait_until := 0

var _snap_hints: Array = []
var _snap_coins := 0
var _snap_weapons: Array = []
var _snap_active := "knife"
var _dest := Vector2i.ZERO
var _dest_world := Vector2.ZERO


func _initialize() -> void:
	KillGuide.force_skip = true # v6: the first-play kill guide would pause the game
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	root.add_child(main)
	print("[TUTORIAL] main scene loaded")


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


func _freeze_guards(game) -> void:
	for g in game.guards:
		g.freeze(120.0)


func _far_walkable_tile(game, min_dist: int) -> Vector2i:
	var start: Vector2i = game.world_to_tile(game.player.position)
	var seen := {start: 0}
	var queue: Array = [start]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = cur + d
			if seen.has(nb) or not game.is_walkable(nb):
				continue
			seen[nb] = seen[cur] + 1
			queue.append(nb)
	var best := Vector2i(-1, -1)
	var best_d := -1
	for t in seen:
		if seen[t] >= min_dist and seen[t] > best_d:
			best_d = seen[t]
			best = t
	return best


func _tile_near_key(game, want_d: int) -> Vector2i:
	# A walkable tile `want_d` steps from the key tile (not the key tile
	# itself): close enough to trigger the key hint (<= 4 tiles), far
	# enough not to collect the key on arrival.
	var start: Vector2i = game.key_tile
	var seen := {start: 0}
	var queue: Array = [start]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = cur + d
			if seen.has(nb) or not game.is_walkable(nb):
				continue
			seen[nb] = seen[cur] + 1
			queue.append(nb)
	for t in seen:
		if seen[t] == want_d:
			return t
	return Vector2i(-1, -1)


func _tut(game) -> Node:
	return game._tutorial


func _seen(game, hint_id: String) -> bool:
	return String(hint_id) in Array(main.save.get("hints_seen", []))


func _skip_current(game) -> void:
	var tut = _tut(game)
	if tut._skip_btn != null:
		tut._skip_btn.pressed.emit()


func _check_hint(game, hint_id: String, must_contain: String) -> bool:
	var tut = _tut(game)
	if tut == null:
		return _fail("tutorial node missing")
	if tut._current != hint_id:
		return _fail("expected hint '%s', got '%s'" % [hint_id, tut._current])
	if not tut._hand.visible or not tut._bubble.visible or not tut._skip_btn.visible:
		return _fail("hint '%s' must show hand + bubble + Skip" % hint_id)
	if tut._hand.texture == null:
		return _fail("hint '%s' hand must be a drawn picture, not an emoji" % hint_id)
	if not String(tut._bubble_label.text).contains(must_contain):
		return _fail("hint '%s' text must contain '%s', got '%s'" % [hint_id, must_contain, tut._bubble_label.text])
	return false


func _process(_delta: float) -> bool:
	frame += 1
	match phase:
		0:
			if frame >= 5:
				_snap_hints = Array(main.save.get("hints_seen", [])).duplicate()
				_snap_coins = int(main.save.get("total_coins", 0))
				_snap_weapons = Array(main.save.get("weapons_owned", ["knife"])).duplicate()
				_snap_active = String(main.save.get("active_weapon", "knife"))
				main.save["hints_seen"] = []
				main.save["total_coins"] = 0
				main.start_level(0)
				print("[TUTORIAL] level 1 started with a fresh hints list")
				phase = 1
				wait_until = frame + 20
		1:
			if frame < wait_until:
				return false
			var game = main.game
			if game == null:
				return _fail("game is null after start_level")
			_freeze_guards(game)
			if _check_hint(game, "move", "Tap a tile"):
				return true
			# --- a tap while the hint is visible must still move the player ---
			_dest = _far_walkable_tile(game, 4)
			if _dest.x < 0:
				return _fail("no walkable tile 4+ away from the player")
			_dest_world = game.tile_to_world(_dest)
			_tap(_dest_world)
			_release(_dest_world)
			phase = 2
			wait_until = frame + 12
		2:
			var game = main.game
			if game.player.path.is_empty():
				return _fail("tap while the move hint was visible did NOT set a path (hint blocked play)")
			if not _seen(game, "move"):
				return _fail("moving must mark the move hint seen")
			print("[TUTORIAL] move hint OK (tap moved the player, hint dismissed for good)")
			phase = 3
			wait_until = frame + 20
		3:
			if frame < wait_until:
				return false
			var game = main.game
			if _check_hint(game, "weapons", "switch weapons"):
				return true
			_skip_current(game)
			phase = 4
			wait_until = frame + 12
		4:
			var game = main.game
			if not _seen(game, "weapons"):
				return _fail("Skip must mark the weapons hint seen")
			print("[TUTORIAL] weapons hint OK (Skip dismissed it for good)")
			phase = 5
			wait_until = frame + 20
		5:
			if frame < wait_until:
				return false
			var game = main.game
			if _check_hint(game, "pause", "Pause"):
				return true
			_skip_current(game)
			phase = 6
			wait_until = frame + 12
		6:
			var game = main.game
			if not _seen(game, "pause"):
				return _fail("Skip must mark the pause hint seen")
			print("[TUTORIAL] pause hint OK (Skip dismissed it for good)")
			# --- walk near the key: the key hint must appear ---
			_dest = _tile_near_key(game, 2)
			if _dest.x < 0:
				return _fail("no walkable tile 2 steps from the key")
			game.debug_teleport_to_tile(_dest)
			phase = 7
			wait_until = frame + 20
		7:
			if frame < wait_until:
				return false
			var game = main.game
			if _check_hint(game, "key", "KEY"):
				return true
			print("[TUTORIAL] key hint OK (appeared near the key)")
			# --- collect the key: the exit hint must appear ---
			game.debug_teleport_to_tile(game.key_tile)
			phase = 8
			wait_until = frame + 20
		8:
			if frame < wait_until:
				return false
			var game = main.game
			if not game.key_collected:
				return _fail("key was not collected on reaching its tile")
			if _check_hint(game, "exit", "EXIT"):
				return true
			print("[TUTORIAL] exit hint OK (appeared after collecting the key)")
			# --- reach the exit: win marks the exit hint seen ---
			game.debug_teleport_to_tile(game.exit_tile)
			phase = 9
			wait_until = frame + 60
		9:
			var game = main.game
			if game.state == game.State.WON:
				if not _seen(game, "exit"):
					return _fail("winning must mark the exit hint seen")
				print("[TUTORIAL] exit hint OK (won the level, hint marked seen)")
				# --- restart L1: NO hint may appear again ---
				main.save["total_coins"] = 0
				main.start_level(0)
				phase = 10
				wait_until = frame + 60
			elif frame >= wait_until:
				return _fail("state did not become WON at the exit WITH the key (state=%d)" % game.state)
		10:
			if frame < wait_until:
				return false
			var game = main.game
			if _tut(game)._current != "":
				return _fail("restarted L1 must show NO hint (got '%s')" % _tut(game)._current)
			print("[TUTORIAL] L1 restart OK (no hint reappeared)")
			# --- L3: NO hint (hints are L1/L2 only) ---
			main.start_level(2)
			phase = 11
			wait_until = frame + 60
		11:
			if frame < wait_until:
				return false
			var game = main.game
			if _tut(game)._current != "":
				return _fail("L3 must show NO hint (got '%s')" % _tut(game)._current)
			print("[TUTORIAL] L3 OK (no hint)")
			# --- bank 500 coins on L3: the gun hint must appear now ---
			main.save["total_coins"] = 500
			phase = 12
			wait_until = frame + 20
		12:
			if frame < wait_until:
				return false
			var game = main.game
			if _check_hint(game, "gun", "unlock the Gun"):
				return true
			print("[TUTORIAL] gun hint OK (appeared at 500 coins on L3)")
			_skip_current(game)
			phase = 13
			wait_until = frame + 12
		13:
			var game = main.game
			if not _seen(game, "gun"):
				return _fail("Skip must mark the gun hint seen")
			# --- 500 coins again: the gun hint must NEVER come back ---
			main.save["total_coins"] = 500
			phase = 14
			wait_until = frame + 60
		14:
			if frame < wait_until:
				return false
			var game = main.game
			if _tut(game)._current != "":
				return _fail("gun hint must never reappear after Skip (got '%s')" % _tut(game)._current)
			print("[TUTORIAL] gun hint OK (never reappeared after Skip)")
			_restore()
			print("[TUTORIAL] PASS")
			quit(0)
			return true
	if frame > 5400:
		return _fail("tutorial test timed out (phase %d)" % phase)
	return false


func _restore() -> void:
	main.save["hints_seen"] = _snap_hints
	main.save["total_coins"] = _snap_coins
	main.save["weapons_owned"] = _snap_weapons
	main.save["active_weapon"] = _snap_active
	ShadowSave.save_data(main.save)


func _fail(msg: String) -> bool:
	_restore()
	print("[TUTORIAL] FAIL: " + msg)
	quit(1)
	return true
