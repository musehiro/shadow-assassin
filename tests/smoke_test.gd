extends SceneTree
## Headless smoke test for Shadow Assassin.
## Run: godot --headless -s res://tests/smoke_test.gd
## Exercises: level load, move to a coin, hunt + eliminate a guard, win.

var main: Node
var frame := 0
var phase := 0
var wait_until := 0


func _initialize() -> void:
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
				var coin_tile: Vector2i = game.coins[0]["tile"]
				game.debug_move_to_tile(coin_tile)
				print("[SMOKE] moving to coin ", coin_tile)
				phase = 2
				wait_until = frame + 900
		2:
			var game = main.game
			if game.coins_collected > 0:
				print("[SMOKE] coin collected (", game.coins_collected, ")")
				game.debug_hunt_guard(0)
				print("[SMOKE] hunting guard 0")
				phase = 3
				wait_until = frame + 1500
			elif frame >= wait_until:
				return _fail("coin was not collected in time")
		3:
			var game = main.game
			if game.targets_left == 0:
				print("[SMOKE] guard eliminated, targets_left = 0")
				phase = 4
				wait_until = frame + 180
			elif game.state != game.State.PLAYING:
				return _fail("game left PLAYING state (state=%d)" % game.state)
			elif frame >= wait_until:
				return _fail("guard was not eliminated in time (targets_left=%d)" % game.targets_left)
			elif frame % 240 == 0 and game.player.hunting == null:
				# stalk was broken off (spotted) — try again like a human would
				print("[SMOKE] re-hunting guard 0")
				game.debug_hunt_guard(0)
		4:
			var game = main.game
			if game.state == game.State.WON:
				print("[SMOKE] state is WON, stars saved")
				print("[SMOKE] PASS")
				quit(0)
				return true
			elif frame >= wait_until:
				return _fail("state did not become WON (state=%d)" % game.state)
	if frame > 3600:
		return _fail("smoke test timed out")
	return false


func _fail(msg: String) -> bool:
	print("[SMOKE] FAIL: " + msg)
	quit(1)
	return true
