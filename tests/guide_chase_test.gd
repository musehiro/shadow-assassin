extends SceneTree
## Test for the Shadow Assassin v6 fixes (Buddhika's v5 playtest,
## 2026-11-21 21:40):
##   1. VISUAL KILL GUIDE — two small picture windows in sequence before
##      the first play (X closes each; after the second, play begins);
##      never shows again once seen (persisted in save).
##   2. WALL-CHASE FIX — an alerted guard (and a SUSPECT guard converging
##      on noise) must pathfind AROUND walls, never straight through.
##   3. TWO GUARDS SEPARATE — the two L1 guards patrol separate loops
##      and drift apart, so the player can wait for them to split up.
##   4. NOISE RANGE — a kill alerts only guards within hearing range
##      (280px); a guard far away keeps patrolling.
## Run UNDER xvfb-run (NOT --headless): xvfb-run -a godot --path . -s res://tests/guide_chase_test.gd
## L1 wall used for the chase test: the crate wall x=3..5 at y=8..9
## separates tile (2,8) from tile (6,8); the way around is via y=7
## (or y=10). A straight-line chaser would cut through the crates.

var main: Node
var frame := 0
var phase := 0
var wait_until := 0
var _guard: Guard
var _max_sep := 0.0
var _chase_min_dist := 9999.0


func _initialize() -> void:
	KillGuide.force_skip = false
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	root.add_child(main)
	print("[GUIDE] main scene loaded")


func _fail(msg: String) -> bool:
	print("[GUIDE] FAIL: " + msg)
	quit(1)
	return true


func _wall_tile_ok(game, g: Guard) -> bool:
	return game.is_walkable(game.world_to_tile(g.position))


func _process(_delta: float) -> bool:
	frame += 1
	match phase:
		0:
			if frame >= 5:
				# --- (1) GUIDE: fresh save, first play -> window 1 ---
				main.save["kill_guide_seen"] = false
				main.start_level(0)
				phase = 1
				wait_until = frame + 10
		1:
			if frame < wait_until:
				return false
			var game = main.game
			if game == null:
				return _fail("game is null after start_level")
			if game._kill_guide == null or not game._kill_guide.is_open():
				return _fail("(1) the kill guide did not open on first play")
			if game._kill_guide.current_window != 1:
				return _fail("(1) expected guide window 1, got %d" % game._kill_guide.current_window)
			if game.state != ShadowGame.State.PAUSED:
				return _fail("(1) the game must be PAUSED while the guide is open (state=%d)" % game.state)
			if not ResourceLoader.exists("res://art/guide_kill_1.png") or not ResourceLoader.exists("res://art/guide_kill_2.png"):
				return _fail("(1) guide picture art is missing")
			print("[GUIDE] (1) window 1 open (HOW TO KILL), game paused")
			game._kill_guide.xbtn1.emit_signal("pressed")
			phase = 2
			wait_until = frame + 5
		2:
			if frame < wait_until:
				return false
			var game = main.game
			if game._kill_guide.current_window != 2:
				return _fail("(1) pressing X on window 1 must open window 2, got %d" % game._kill_guide.current_window)
			if game.state != ShadowGame.State.PAUSED:
				return _fail("(1) the game must stay PAUSED on window 2 (state=%d)" % game.state)
			print("[GUIDE] (1) window 2 open (TWO GUARDS TOGETHER), still paused")
			game._kill_guide.xbtn2.emit_signal("pressed")
			phase = 3
			wait_until = frame + 5
		3:
			if frame < wait_until:
				return false
			var game = main.game
			if game._kill_guide.is_open():
				return _fail("(1) pressing X on window 2 must close the guide")
			if game.state != ShadowGame.State.PLAYING:
				return _fail("(1) play must begin after the second window closes (state=%d)" % game.state)
			if not bool(main.save.get("kill_guide_seen", false)):
				return _fail("(1) kill_guide_seen was not persisted after closing")
			print("[GUIDE] (1) PASS: window 1 -> window 2 -> play; seen persisted")
			# Guide must never show again on a later start.
			main.start_level(0)
			phase = 4
			wait_until = frame + 10
		4:
			if frame < wait_until:
				return false
			var game = main.game
			if game._kill_guide != null and game._kill_guide.is_open():
				return _fail("(1) the guide showed again on a second start (must be once only)")
			if game.state != ShadowGame.State.PLAYING:
				return _fail("(1) second start must be PLAYING at once (state=%d)" % game.state)
			print("[GUIDE] (1) PASS: guide never shows again")
			# --- (2) CHASE: alerted guard across a crate wall ---
			for g in game.guards:
				g.vision_range = 0.0
			game.guards[1].freeze(120.0)
			_guard = game.guards[0]
			_guard.position = game.tile_to_world(Vector2i(2, 8))
			game.debug_teleport_to_tile(Vector2i(6, 8))
			game.player.stop()
			_guard.state = Guard.State.ALERT
			_guard._last_seen_pos = game.tile_to_world(Vector2i(6, 8))
			_guard._chase_path.clear()
			_guard._chase_target_tile = Vector2i(-999, -999)
			_chase_min_dist = 9999.0
			print("[GUIDE] (2) alerted guard at (2,8) chasing the player at (6,8) across the crate wall")
			phase = 5
			wait_until = frame + 600
		5:
			var game = main.game
			if not _wall_tile_ok(game, _guard):
				return _fail("(2) the chasing guard is ON a wall/crate tile %s — he cut through the wall!" % str(game.world_to_tile(_guard.position)))
			var d: float = _guard.position.distance_to(game.player.position)
			_chase_min_dist = minf(_chase_min_dist, d)
			if game.health < 3 or d < game.tile * 1.5:
				print("[GUIDE] (2) PASS: guard went AROUND the wall (closest %.0fpx, never on a wall tile) and reached the player" % _chase_min_dist)
				main.start_level(0)
				phase = 6
				wait_until = frame + 10
			elif frame >= wait_until:
				return _fail("(2) the alerted guard never got around the wall (closest %.0fpx)" % _chase_min_dist)
		6:
			if frame < wait_until:
				return false
			var game = main.game
			# --- (2b) SUSPECT: converge on noise across the same wall ---
			for g in game.guards:
				g.vision_range = 0.0
			game.guards[1].freeze(120.0)
			_guard = game.guards[0]
			_guard.position = game.tile_to_world(Vector2i(2, 8))
			_guard.hear_noise(game.tile_to_world(Vector2i(6, 8)))
			_chase_min_dist = 9999.0
			print("[GUIDE] (2b) guard at (2,8) converging on noise at (6,8) across the wall")
			phase = 7
			wait_until = frame + 600
		7:
			var game = main.game
			if not _wall_tile_ok(game, _guard):
				return _fail("(2b) the converging guard is ON a wall/crate tile %s — he cut through the wall!" % str(game.world_to_tile(_guard.position)))
			var d2: float = _guard.position.distance_to(game.tile_to_world(Vector2i(6, 8)))
			_chase_min_dist = minf(_chase_min_dist, d2)
			if _guard.state == Guard.State.RETURN or d2 < game.tile * 0.5:
				print("[GUIDE] (2b) PASS: guard converged AROUND the wall (closest %.0fpx, never on a wall tile)" % _chase_min_dist)
				main.start_level(0)
				phase = 8
				wait_until = frame + 10
			elif frame >= wait_until:
				return _fail("(2b) the converging guard never got around the wall (closest %.0fpx)" % _chase_min_dist)
		8:
			if frame < wait_until:
				return false
			var game = main.game
			# --- (3) TWO GUARDS SEPARATE on patrol ---
			for g in game.guards:
				g.vision_range = 0.0
			if game.guards[0].patrol == game.guards[1].patrol:
				return _fail("(3) the two L1 guards share one patrol loop (must be separate loops)")
			_max_sep = 0.0
			print("[GUIDE] (3) watching the two L1 guards patrol (separate loops, different speeds)")
			phase = 9
			wait_until = frame + 400
		9:
			var game = main.game
			var sep: float = game.guards[0].position.distance_to(game.guards[1].position)
			_max_sep = maxf(_max_sep, sep)
			if frame >= wait_until:
				if _max_sep < game.tile * 1.5:
					return _fail("(3) the two guards never separated (max %.0fpx) — they must drift apart on their loops" % _max_sep)
				print("[GUIDE] (3) PASS: the two guards separated by up to %.0fpx (%.1f tiles) on their loops" % [_max_sep, _max_sep / game.tile])
				# --- (4) NOISE RANGE: only guards within 280px hear it ---
				for g in game.guards:
					g.vision_range = 0.0
				var far: Guard = game.guards[1]
				# (9,1) is the exit tile — far from both guards' patrol
				# loops (left side of the map), always > 300px away.
				far.position = game.tile_to_world(Vector2i(9, 1))
				far.patrol_index = far.patrol.find(far._nearest_patrol_tile())
				var near: Guard = game.guards[0]
				var dist: float = near.position.distance_to(far.position)
				if dist < 300.0:
					return _fail("(4) test setup: the far guard is only %.0fpx away (want > 300px)" % dist)
				game.noise_at(near.position, 280.0)
				phase = 10
				wait_until = frame + 5
		10:
			if frame < wait_until:
				return false
			var game = main.game
			var near2: Guard = game.guards[0]
			var far2: Guard = game.guards[1]
			if near2.state != Guard.State.SUSPECT:
				return _fail("(4) the guard at the noise must become SUSPECT, got state %d" % near2.state)
			if far2.state != Guard.State.PATROL:
				return _fail("(4) the far guard (%.0fpx away) must keep PATROLLING, got state %d" % [near2.position.distance_to(far2.position), far2.state])
			print("[GUIDE] (4) PASS: kill noise alerted only the nearby guard; the far guard kept patrolling")
			print("[GUIDE] ALL CHECKS PASS")
			quit(0)
			return true
	if frame > 3000:
		return _fail("guide/chase test timed out (phase %d)" % phase)
	return false
