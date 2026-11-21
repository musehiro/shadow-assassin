extends SceneTree
## Headless smoke test for Shadow Assassin (remake mechanics).
## Run: godot --headless -s res://tests/smoke_test.gd
## Exercises: level load + cone visibility, move to a coin, contact-kill a
## guard from behind, win flow + Collect, guards shooting, death, and the
## start_level(-1) guard clause.

var main: Node
var frame := 0
var phase := 0
var wait_until := 0
var _second_staged := false


func _initialize() -> void:
	KillGuide.force_skip = true # v6: the first-play kill guide would pause the game
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	root.add_child(main)
	print("[SMOKE] main scene loaded")


func _process(_delta: float) -> bool:
	frame += 1
	match phase:
		0:
			if frame >= 5:
				main.start_level(0)
				print("[SMOKE] level 0 started")
				phase = 1
				wait_until = frame + 30
		1:
			if frame >= wait_until:
				var game = main.game
				if game == null:
					return _fail("game is null after start_level")
				if game.theme != "warehouse":
					return _fail("level 1 theme should be warehouse, got %s" % game.theme)
				if game.guards.size() != 2:
					return _fail("level 1 should have 2 guards, got %d" % game.guards.size())
				var cone_z: int = game.guards[0].get("_cone").z_index
				if cone_z <= 0:
					return _fail("vision cone z_index must be > 0 (above floor), got %d" % cone_z)
				var chase_px: float = game.guards[0].patrol_speed * 64.0 * 1.6
				if game.player.BASE_SPEED <= chase_px:
					return _fail("player must be faster than guard chase speed")
				print("[SMOKE] theme/cone/speed OK (cone z=%d)" % cone_z)
				var coin_tile: Vector2i = game.coins[0]["tile"]
				game.debug_move_to_tile(coin_tile)
				print("[SMOKE] moving to coin ", coin_tile)
				phase = 2
				wait_until = frame + 900
		2:
			var game = main.game
			if game.coins_collected > 0:
				print("[SMOKE] coin collected (", game.coins_collected, "), cash=", game.cash_earned)
				# v5 contact rule: standing still never kills — the player
				# must WALK into the guard from behind. Stage the player
				# on a walkable tile 2 tiles behind (the raw teleport can
				# land inside a wall, leaving no path) and freeze + calm
				# the guard so the stealth kill is deterministic.
				game.debug_stage_behind_guard(0)
				game.debug_freeze_guard_patrol(0)
				game.debug_move_to_tile(game.world_to_tile(game.guards[0].position))
				print("[SMOKE] teleported behind guard 0, walking in for the stealth kill")
				phase = 3
				wait_until = frame + 300
			elif frame >= wait_until:
				return _fail("coin was not collected in time")
		3:
			var game = main.game
			if game.targets_left == 0:
				print("[SMOKE] contact kills worked: targets_left=0 kills=", game.kills,
					" blood_pools=", game.blood_pools, " cash=", game.cash_earned)
				if game.blood_pools < 2:
					return _fail("kills left too few blood pools (%d)" % game.blood_pools)
				if game.cash_earned < 60:
					return _fail("kills paid too little cash (cash_earned=%d)" % game.cash_earned)
				# Killing all guards no longer wins by itself (v3 win =
				# key + exit): walk to the key, then to the exit.
				game.debug_move_to_tile(game.key_tile)
				print("[SMOKE] all guards down; moving to key ", game.key_tile)
				phase = 8
				wait_until = frame + 900
			elif frame >= wait_until:
				return _fail("guards were not contact-killed in time (targets_left=%d)" % game.targets_left)
			elif game.kills == 1 and game.targets_left == 1 and not _second_staged:
				# First guard down — move on to the second (noise may have alerted it).
				# Stage the walk-in ONCE: re-teleporting every frame would
				# reset the player's position and path, so he never arrives.
				_second_staged = true
				game.debug_stage_behind_guard(0)
				game.debug_freeze_guard_patrol(0)
				game.debug_move_to_tile(game.world_to_tile(game.guards[0].position))
				print("[SMOKE] first kill done, teleported behind remaining guard, walking in")
		8:
			var game = main.game
			if game.key_collected:
				print("[SMOKE] key collected; moving to exit ", game.exit_tile)
				game.debug_move_to_tile(game.exit_tile)
				phase = 9
				wait_until = frame + 900
			elif frame >= wait_until:
				return _fail("key was not collected in time")
		9:
			var game = main.game
			if game.state == game.State.WON:
				print("[SMOKE] key + exit -> state is WON (Cleared banner shown)")
				var gems_before: int = int(main.save.get("total_gems", 0))
				game.debug_collect()
				print("[SMOKE] Collect banked rewards; gems ", gems_before, " -> ", main.save.get("total_gems", 0))
				phase = 5
				wait_until = frame + 60
			elif frame >= wait_until:
				return _fail("state did not become WON at the exit (state=%d)" % game.state)
		4:
			return _fail("smoke phase 4 is unreachable (win flow moved to phases 8-9)")
		5:
			# Collect advanced to level 2; now test shooting + death there.
			var game = main.game
			if game == null or game.level_index != 1:
				return _fail("after Collect expected level 2 (index 1), got %s" % str(game.level_index if game != null else "null"))
			if frame < wait_until:
				return false
			# Put the player on a walkable tile with a CLEAR line of sight
			# to guard 0 (v4 mazes are denser: a fixed 120px spot in front
			# of the guard can land inside a wall, and then the guard
			# can never see the player). The guard turns to face the
			# player once alerted, so any LOS-clear tile in range works.
			var g = game.guards[0]
			var placed := false
			var g_tile: Vector2i = game.world_to_tile(g.position)
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
					if seen[nb] >= 1 and seen[nb] <= 5:
						var cand: Vector2 = game.tile_to_world(nb)
						if cand.distance_to(g.position) <= g.vision_range * 0.8 and game.has_los(g.position, cand):
							game.player.position = cand
							placed = true
							break
			if not placed:
				return _fail("no LOS-clear tile near guard 0 to place the player on")
			game.player.stop()
			game.debug_force_alert(0)
			print("[SMOKE] player placed at %s, %dpx from guard 0, ALERT forced" % [str(game.player.position), int(game.player.position.distance_to(g.position))])
			phase = 6
			wait_until = frame + 600
		6:
			var game = main.game
			if game.bullets_fired > 0:
				print("[SMOKE] guard shot at player (bullets_fired=", game.bullets_fired,
					" hp=", game.health, "/", game.max_health, ")")
				game.debug_damage_player(99)
				phase = 7
				wait_until = frame + 60
			elif frame >= wait_until:
				return _fail("alerted guard never fired (bullets_fired=0)")
		7:
			var game = main.game
			if game.state == game.State.LOST:
				print("[SMOKE] player died -> LOST state, revive offered: ", game._revive_time_left > 0.0)
				# start_level(-1) must be ignored, never wrap to the last level.
				var idx_before: int = game.level_index
				main.start_level(-1)
				if main.game == null or main.game.level_index != idx_before:
					return _fail("start_level(-1) changed the game (was level %d)" % idx_before)
				if main.game.state != main.game.State.LOST:
					return _fail("start_level(-1) disturbed the running game")
				print("[SMOKE] start_level(-1) correctly ignored")
				# ... and a bogus large index too.
				main.start_level(999)
				if main.game.level_index != idx_before:
					return _fail("start_level(999) changed the game")
				print("[SMOKE] start_level(999) correctly ignored")
				print("[SMOKE] PASS")
				quit(0)
				return true
			elif frame >= wait_until:
				return _fail("state did not become LOST after fatal damage (state=%d)" % game.state)
	if frame > 3600:
		return _fail("smoke test timed out")
	return false


func _fail(msg: String) -> bool:
	print("[SMOKE] FAIL: " + msg)
	quit(1)
	return true
