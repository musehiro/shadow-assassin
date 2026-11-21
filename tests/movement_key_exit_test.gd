extends SceneTree
## Headless test for Shadow Assassin v3 movement + key/exit win condition.
## Run UNDER xvfb-run (NOT --headless): xvfb-run -a godot --path . -s res://tests/movement_key_exit_test.gd
## (In --headless the dummy window is 0x0, so the engine scales injected
## input positions by 1/0.05 = 20x and taps land off the board. Under a
## real window — xvfb or a phone — coordinates arrive unscaled.)
## Exercises, with REAL injected input (Input.parse_input_event):
##   1. A simulated screen touch on a floor tile moves the player at once
##      (path set within a few frames, orange path line drawn, player
##      walks to the destination) — the v2 phone failure, reproduced
##      before the fix by a full-screen backdrop Control eating the tap.
##   2. A simulated drag (touch press + ScreenDrag events) steers the
##      player along the drawn line to the destination.
##   3. A simulated mouse click (desktop path) also moves the player.
##   4. Taps on the HUD strip and on the bottom control bar do NOT move the player.
##   5. Key + exit win condition: reaching the exit WITHOUT the key does
##      NOT win; collecting the key then reaching the exit DOES win.
##   6. Level data: key 1-3 tiles from a patrol route, exit far from the
##      player start, guards on long patrols.
## Guards are frozen during the movement phases: this test isolates
## input -> movement, not stealth (a frozen guard never shoots).

var main: Node
var frame := 0
var phase := 0
var wait_until := 0
var _start_pos := Vector2.ZERO
var _dest := Vector2i.ZERO
var _dest_world := Vector2.ZERO
var _drag_points: Array = []
var _drag_i := 0
var _grace_until := 0


func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	root.add_child(main)
	print("[MOVEKEY] main scene loaded")


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


func _drag_to(world_pos: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.position = world_pos
	ev.index = 0
	Input.parse_input_event(ev)


func _click(world_pos: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.pressed = true
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.position = world_pos
	Input.parse_input_event(ev)
	var up := InputEventMouseButton.new()
	up.pressed = false
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = world_pos
	Input.parse_input_event(up)


func _freeze_guards(game) -> void:
	for g in game.guards:
		g.freeze(120.0)


func _far_walkable_tile(game, min_dist: int) -> Vector2i:
	# A walkable tile min_dist+ tiles away from the player by BFS path.
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


func _process(_delta: float) -> bool:
	frame += 1
	match phase:
		0:
			if frame >= 5:
				main.start_level(0)
				phase = 1
				wait_until = frame + 30
		1:
			if frame < wait_until:
				return false
			var game = main.game
			if game == null:
				return _fail("game is null after start_level")
			# --- level data: key/exit placement rules ---
			if game.key_tile.x < 0 or game.exit_tile.x < 0:
				return _fail("level 1 has no key/exit tiles (key=%s exit=%s)" % [str(game.key_tile), str(game.exit_tile)])
			var route_tiles: Array = []
			for g in game.level["guards"]:
				for wp in ShadowLevels._patrol_route_tiles(g["patrol"]):
					if not route_tiles.has(wp):
						route_tiles.append(wp)
			var key_dmin := 99
			for rt in route_tiles:
				key_dmin = mini(key_dmin, absi(rt.x - game.key_tile.x) + absi(rt.y - game.key_tile.y))
			if key_dmin < 1 or key_dmin > 3:
				return _fail("key %d tiles from nearest patrol route (want 1..3)" % key_dmin)
			var start_t: Vector2i = game.world_to_tile(game.player.position)
			var exit_d: int = absi(game.exit_tile.x - start_t.x) + absi(game.exit_tile.y - start_t.y)
			if exit_d < 7:
				return _fail("exit only %d tiles from player start (want >= 7)" % exit_d)
			if route_tiles.has(game.exit_tile):
				return _fail("exit sits on a patrol route")
			if game._exit_arrow == null or not game._exit_arrow.visible:
				return _fail("exit arrow indicator missing/invisible")
			if game._key_node == null or not game._key_node.visible:
				return _fail("key node missing/invisible")
			if game._key_icon == null:
				return _fail("HUD key icon missing")
			# --- guards on LONG patrols (v2: 2-4 tiles; v3: much longer) ---
			for gi in range(game.guards.size()):
				var plen: int = (game.level["guards"][gi] as Dictionary)["patrol"].size()
				if plen < 8:
					return _fail("level 1 guard %d patrol is only %d tiles (want >= 8)" % [gi, plen])
			print("[MOVEKEY] key/exit placement OK (key %s, %d from route; exit %s, %d from start; patrols %d+%d tiles)" % [
				str(game.key_tile), key_dmin, str(game.exit_tile), exit_d,
				(game.level["guards"][0] as Dictionary)["patrol"].size(),
				(game.level["guards"][1] as Dictionary)["patrol"].size()])
			# --- HUD strip tap must NOT move the player ---
			_start_pos = game.player.position
			_tap(Vector2(360, 50))
			_release(Vector2(360, 50))
			phase = 2
			wait_until = frame + 12
		2:
			var game = main.game
			if not game.player.path.is_empty():
				return _fail("tap on the HUD strip moved the player (path=%d)" % game.player.path.size())
			# --- bottom control bar tap must NOT move the player ---
			# Tap the bar's empty left gap (inside the bar rect, but
			# left of the centred buttons — tapping a button would
			# switch weapons / open the shop / pause, which is correct
			# behaviour, not movement).
			var bar_pos := Vector2(60.0, game._view_size.y - ShadowGame.BAR_H * 0.5)
			_tap(bar_pos)
			_release(bar_pos)
			phase = 3
			wait_until = frame + 12
		3:
			var game = main.game
			if not game.player.path.is_empty():
				return _fail("tap on the bottom bar moved the player (path=%d)" % game.player.path.size())
			if game._weapon_ui._shop_layer.visible:
				return _fail("bar tap opened the shop (tapped a button, not the empty gap)")
			if game.state != game.State.PLAYING:
				return _fail("game left PLAYING state before the touch test (state=%d)" % game.state)
			print("[MOVEKEY] HUD + bottom-bar taps correctly ignored")
			# --- TOUCH: tap a far floor tile; player must move AT ONCE ---
			# Freeze the guards AND clear them out of the level: under
			# the v5 contact rule a guard the path bumps into (frontal
			# contact) hurts the player and stops him, which would end
			# the walk. The guards are frozen to isolate movement from
			# stealth in the first place; removing them is the same
			# isolation one step further (patrol lengths were already
			# verified from level data in phase 1).
			_freeze_guards(game)
			game.debug_eliminate_all()
			_dest = _far_walkable_tile(game, 4)
			if _dest.x < 0:
				return _fail("no walkable tile 4+ away from the player")
			_dest_world = game.tile_to_world(_dest)
			_start_pos = game.player.position
			_tap(_dest_world)
			print("[MOVEKEY] touch injected at tile %s (%s); player at %s" % [str(_dest), str(_dest_world), str(_start_pos)])
			phase = 4
			wait_until = frame + 8
		4:
			# Give the game a few frames: input is dispatched at the start
			# of the next iteration, and the path line is drawn by the
			# game's own _process (which runs after this script's).
			if frame < wait_until:
				return false
			var game = main.game
			if game.player.path.is_empty():
				return _fail("touch did NOT set a path within 8 frames (v2 bug is back)")
			if game._path_line.points.is_empty():
				return _fail("touch set a path but no orange path line is drawn")
			print("[MOVEKEY] path set at once (%d waypoints), orange line drawn" % game.player.path.size())
			phase = 5
			wait_until = frame + 600
		5:
			var game = main.game
			if game.player.position.distance_to(_dest_world) < 40.0:
				var moved: float = game.player.position.distance_to(_start_pos)
				print("[MOVEKEY] touch-walk reached tile %s (moved %.0fpx)" % [str(_dest), moved])
				_release(_dest_world)
				phase = 6
				wait_until = frame + 10
			elif frame >= wait_until:
				return _fail("player never reached the tapped tile (at %s, want %s)" % [str(game.player.position), str(_dest_world)])
		6:
			if frame < wait_until:
				return false
			var game = main.game
			# --- DRAG: press, then drag along a drawn line to a new tile ---
			_dest = _far_walkable_tile(game, 5)
			_dest_world = game.tile_to_world(_dest)
			_start_pos = game.player.position
			var path: Array = game.find_path(game.world_to_tile(_start_pos), _dest)
			_drag_points = path
			_drag_i = 0
			_tap(_start_pos + Vector2(10, 0))
			print("[MOVEKEY] drag test: drawing a line to tile %s (%d path points)" % [str(_dest), path.size()])
			phase = 7
			wait_until = frame + 600
		7:
			var game = main.game
			# Feed the drag points one per frame: finger down, drawing.
			# Then hold the drag on the destination a few extra frames so
			# the throttled repath definitely lands on the final point.
			if _drag_i < _drag_points.size():
				_drag_to(_drag_points[_drag_i])
				_drag_i += 1
				return false
			if _drag_i < _drag_points.size() + 10:
				_drag_to(_dest_world)
				_drag_i += 1
				return false
			if game.player.position.distance_to(_dest_world) < 40.0:
				print("[MOVEKEY] drag-walk reached tile %s (moved %.0fpx along the drawn line)" % [str(_dest), game.player.position.distance_to(_start_pos)])
				_release(_dest_world)
				phase = 8
				wait_until = frame + 10
			elif frame >= wait_until:
				return _fail("player never reached the dragged-to tile (at %s, want %s)" % [str(game.player.position), str(_dest_world)])
		8:
			if frame < wait_until:
				return false
			var game = main.game
			# --- MOUSE (desktop path): click a floor tile ---
			_dest = _far_walkable_tile(game, 4)
			_dest_world = game.tile_to_world(_dest)
			_start_pos = game.player.position
			_click(_dest_world)
			_grace_until = frame + 15
			phase = 9
			wait_until = frame + 600
		9:
			var game = main.game
			if game.player.path.is_empty() and game.player.position.distance_to(_dest_world) >= 40.0 and frame >= _grace_until:
				return _fail("mouse click did NOT set a path")
			if game.player.position.distance_to(_dest_world) < 40.0:
				print("[MOVEKEY] mouse-click walk reached tile %s (moved %.0fpx)" % [str(_dest), game.player.position.distance_to(_start_pos)])
				phase = 10
				wait_until = frame + 10
			elif frame >= wait_until:
				return _fail("player never reached the clicked tile (at %s, want %s)" % [str(game.player.position), str(_dest_world)])
		10:
			if frame < wait_until:
				return false
			var game = main.game
			# --- KEY GATES THE EXIT: exit without the key must NOT win ---
			# (The earlier walks may have crossed the key tile and
			# collected it already — walking over the key collects it, as
			# it should. Reset it here so the gate itself is tested.)
			_freeze_guards(game)
			game.key_collected = false
			if game._key_node != null:
				game._key_node.visible = true
			game._update_hud()
			game.debug_teleport_to_tile(game.exit_tile)
			print("[MOVEKEY] teleported to exit WITHOUT the key; state must stay PLAYING")
			phase = 11
			wait_until = frame + 90
		11:
			var game = main.game
			if game.state != game.State.PLAYING:
				return _fail("reaching the exit WITHOUT the key won the level (state=%d)" % game.state)
			if frame >= wait_until:
				print("[MOVEKEY] exit without key correctly did NOT win (still PLAYING after 90 frames)")
				game.debug_teleport_to_tile(game.key_tile)
				phase = 12
				wait_until = frame + 120
		12:
			var game = main.game
			if game.key_collected:
				print("[MOVEKEY] key collected; HUD icon gold=%s" % str(game._key_icon.modulate))
				game.debug_teleport_to_tile(game.exit_tile)
				phase = 13
				wait_until = frame + 120
			elif frame >= wait_until:
				return _fail("key was not collected on reaching its tile")
		13:
			var game = main.game
			if game.state == game.State.WON:
				print("[MOVEKEY] key + exit -> WON; PASS")
				quit(0)
				return true
			elif frame >= wait_until:
				return _fail("state did not become WON at the exit WITH the key (state=%d)" % game.state)
	if frame > 5400:
		return _fail("movement/key/exit test timed out (phase %d)" % phase)
	return false


func _fail(msg: String) -> bool:
	print("[MOVEKEY] FAIL: " + msg)
	quit(1)
	return true
