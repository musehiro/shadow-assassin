extends SceneTree
## Test for the Shadow Assassin v5 contact-kill rule (Buddhika's playtest,
## 2026-11-21 20:11: ANY touch killed the guard for free — even standing
## still, facing away, or a guard walking up from behind).
## Run UNDER xvfb-run (NOT --headless): xvfb-run -a godot --path . -s res://tests/kill_logic_test.gd
## The v5 rule: the player kills a guard ONLY when the PLAYER walks into
## the guard (a stealth kill, best from behind). If a GUARD walks into
## the player, or the player walks into a guard who faces him, or the
## guard is alerted and hunting, the GUARD hurts the player instead.
## Exercises (level 1, restarted between cases):
##   (a) Standing player + guard walks into him -> player loses a heart,
##       guard stays alive, no kill.
##   (b) Player walks into a guard from behind -> guard dies, player unhurt.
##   (c) Player walks into a guard from the front (guard faces him) ->
##       player takes damage, NO free kill, guard stays alive.
##   (d1) A guard bullet aimed at the player actually damages him.
##   (d2) An alerted guard who spots the player chases, shoots and can
##       KILL him (3 hearts -> death) — the player must be able to die
##       when caught, not auto-win by standing still.

var main: Node
var frame := 0
var phase := 0
var wait_until := 0
var _guard: Guard
var _health_before := 3


func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	root.add_child(main)
	print("[KILL] main scene loaded")


func _freeze_all_guards(game) -> void:
	for g in game.guards:
		g.freeze(120.0)


func _behind_tile(game, g: Guard, dist_tiles: float) -> Vector2i:
	var t: Vector2i = game.world_to_tile(g.position - Vector2(cos(g.facing), sin(g.facing)) * game.tile * dist_tiles)
	return game._nearest_walkable(t)


func _front_tile(game, g: Guard, dist_tiles: float) -> Vector2i:
	var t: Vector2i = game.world_to_tile(g.position + Vector2(cos(g.facing), sin(g.facing)) * game.tile * dist_tiles)
	return game._nearest_walkable(t)


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
			# --- (a) STANDING player, guard walks into him ---
			# Blind every guard (vision 0: no sight, no shooting) so
			# only the contact rule is under test, then stand the
			# player on guard 0's next patrol waypoint and wait for
			# the guard to walk into him.
			for g in game.guards:
				g.vision_range = 0.0
			_guard = game.guards[0]
			var wp: Vector2i = _guard.patrol[_guard.patrol_index]
			game.debug_teleport_to_tile(wp)
			game.player.stop()
			_health_before = game.health
			print("[KILL] (a) player standing on guard 0's waypoint %s; guard walks in" % str(wp))
			phase = 2
			wait_until = frame + 600
		2:
			var game = main.game
			if game.health < _health_before:
				if not _guard.alive:
					return _fail("(a) the guard DIED when he walked into the standing player (must stay alive)")
				if game.kills != 0:
					return _fail("(a) a kill was scored while the player stood still (kills=%d)" % game.kills)
				print("[KILL] (a) PASS: guard walked into the standing player -> player hurt (hp %d -> %d), guard alive, no kill" % [_health_before, game.health])
				main.start_level(0)
				phase = 3
				wait_until = frame + 30
			elif frame >= wait_until:
				return _fail("(a) the guard never reached the standing player (hp still %d)" % game.health)
		3:
			if frame < wait_until:
				return false
			var game = main.game
			# --- (b) PLAYER walks into a guard FROM BEHIND ---
			_guard = game.guards[0]
			game.debug_freeze_guard_patrol(0)
			var behind := _behind_tile(game, _guard, 2.0)
			game.debug_teleport_to_tile(behind)
			game.debug_move_to_tile(game.world_to_tile(_guard.position))
			print("[KILL] (b) player walking in from behind (from tile %s)" % str(behind))
			phase = 4
			wait_until = frame + 300
		4:
			var game = main.game
			if game.kills >= 1:
				if game.health != 3:
					return _fail("(b) the stealth kill cost the player health (hp=%d, want 3)" % game.health)
				if game.targets_left != 1:
					return _fail("(b) targets_left must be 1 after one kill, got %d" % game.targets_left)
				print("[KILL] (b) PASS: player walked into the guard from behind -> guard died, player unhurt")
				main.start_level(0)
				phase = 5
				wait_until = frame + 30
			elif frame >= wait_until:
				return _fail("(b) the stealth kill never happened (kills=%d, hp=%d)" % [game.kills, game.health])
		5:
			if frame < wait_until:
				return false
			var game = main.game
			# --- (c) PLAYER walks into a guard FROM THE FRONT ---
			_guard = game.guards[0]
			game.debug_freeze_guard_patrol(0)
			var front := _front_tile(game, _guard, 2.0)
			game.debug_teleport_to_tile(front)
			_health_before = game.health
			game.debug_move_to_tile(game.world_to_tile(_guard.position))
			print("[KILL] (c) player walking in from the front (from tile %s)" % str(front))
			phase = 6
			wait_until = frame + 180
		6:
			var game = main.game
			if game.health < _health_before:
				if not _guard.alive:
					return _fail("(c) the guard DIED when the player walked into his front (must stay alive)")
				if game.kills != 0:
					return _fail("(c) a free kill was scored from the front (kills=%d)" % game.kills)
				print("[KILL] (c) PASS: player walked into the guard's front -> player hurt (hp %d -> %d), guard alive, no kill" % [_health_before, game.health])
				main.start_level(0)
				phase = 7
				wait_until = frame + 30
			elif frame >= wait_until:
				return _fail("(c) the frontal walk-in never hurt the player (hp still %d)" % game.health)
		7:
			if frame < wait_until:
				return false
			var game = main.game
			# --- (d1) A guard bullet aimed at the player DAMAGES him ---
			_guard = game.guards[0]
			game.debug_freeze_guard_patrol(0)
			# Spawn a guard bullet 120px from the player, aimed straight
			# at him, along a clear line (pick a direction with LOS).
			var dirs := [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]
			var spawned := false
			for d in dirs:
				var from: Vector2 = game.player.position + d * 120.0
				if game.has_los(from, game.player.position) and not game.is_blocking_world(from):
					game.spawn_bullet(from, -d, 520.0, 1, false)
					spawned = true
					break
			if not spawned:
				return _fail("(d1) no clear line to spawn a test bullet at the player")
			_health_before = game.health
			print("[KILL] (d1) guard bullet spawned at the player; hp=%d" % _health_before)
			phase = 8
			wait_until = frame + 90
		8:
			var game = main.game
			if game.health < _health_before:
				print("[KILL] (d1) PASS: the bullet hit -> player hurt (hp %d -> %d)" % [_health_before, game.health])
				main.start_level(0)
				phase = 9
				wait_until = frame + 30
			elif frame >= wait_until:
				return _fail("(d1) the bullet never damaged the player (hp still %d)" % game.health)
		9:
			if frame < wait_until:
				return false
			var game = main.game
			# --- (d2) An ALERTED guard chases, shoots and can KILL ---
			# Place the player on a LOS-clear tile 2-4 tiles from guard
			# 0, stand still, force the guard alert, and wait for the
			# player to die (bullets + contact). He must be able to
			# die when caught — not auto-win by standing still.
			_guard = game.guards[0]
			var g_tile: Vector2i = game.world_to_tile(_guard.position)
			var placed := false
			var seen := {g_tile: 0}
			var queue: Array = [g_tile]
			while not queue.is_empty() and not placed:
				var cur: Vector2i = queue.pop_front()
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nb: Vector2i = cur + d
					if seen.has(nb) or not game.is_walkable(nb):
						continue
					seen[nb] = seen[cur] + 1
					queue.append(nb)
					if seen[nb] >= 2 and seen[nb] <= 4:
						var cand: Vector2 = game.tile_to_world(nb)
						if cand.distance_to(_guard.position) <= _guard.vision_range * 0.8 and game.has_los(_guard.position, cand):
							game.player.position = cand
							placed = true
							break
			if not placed:
				return _fail("(d2) no LOS-clear tile near guard 0 to place the player on")
			game.player.stop()
			game.debug_force_alert(0)
			print("[KILL] (d2) player standing %dpx from the alerted guard; he must die" % int(game.player.position.distance_to(_guard.position)))
			phase = 10
			wait_until = frame + 600
		10:
			var game = main.game
			if game.state == game.State.LOST:
				if game.health != 0:
					return _fail("(d2) state is LOST but health is %d (want 0)" % game.health)
				if game.bullets_fired <= 0:
					return _fail("(d2) the player died but the guard never fired (bullets_fired=0)")
				print("[KILL] (d2) PASS: the alerted guard chased, shot (bullets=%d) and killed the player" % game.bullets_fired)
				print("[KILL] ALL CHECKS PASS")
				quit(0)
				return true
			elif frame >= wait_until:
				return _fail("(d2) the alerted guard never killed the standing player (hp=%d, state=%d, bullets=%d)" % [game.health, game.state, game.bullets_fired])
	if frame > 5400:
		return _fail("kill logic test timed out (phase %d)" % phase)
	return false


func _fail(msg: String) -> bool:
	print("[KILL] FAIL: " + msg)
	quit(1)
	return true
