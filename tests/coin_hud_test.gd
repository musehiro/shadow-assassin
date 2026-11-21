extends SceneTree
## Test for the Shadow Assassin v5 coin counter (Buddhika's playtest,
## 2026-11-21 20:11: the HUD showed kills, hearts, gems and the key —
## but NO coin count anywhere, even though coins were being collected).
## Run UNDER xvfb-run (NOT --headless): xvfb-run -a godot --path . -s res://tests/coin_hud_test.gd
## Exercises:
##   1. The HUD has a gold coin icon + a coin counter label, both visible
##      and fully on screen.
##   2. Collecting a coin makes the counter climb at once (by exactly the
##      coin's cash value, 5) and the label always equals the running
##      wallet balance (banked coins + this level's cash so far).

var main: Node
var frame := 0
var phase := 0
var wait_until := 0
var _wallet_before := 0
var _cash_before := 0


func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	root.add_child(main)
	print("[COINHUD] main scene loaded")


func _freeze_guards(game) -> void:
	for g in game.guards:
		g.freeze(120.0)


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
			# --- the coin counter exists, is visible, and is on screen ---
			if game._coin_icon == null:
				return _fail("HUD coin icon is missing (no gold coin in the top bar)")
			if game._coin_label == null:
				return _fail("HUD coin counter label is missing")
			if not game._coin_icon.visible:
				return _fail("HUD coin icon is not visible")
			if not game._coin_label.visible:
				return _fail("HUD coin counter label is not visible")
			var vr := Rect2(Vector2.ZERO, Vector2(720, 1280))
			if not vr.encloses(game._coin_label.get_global_rect()):
				return _fail("coin counter label is not fully on screen: %s" % str(game._coin_label.get_global_rect()))
			if not vr.encloses(Rect2(game._coin_icon.position - Vector2(24, 24), Vector2(48, 48))):
				return _fail("coin icon is not fully on screen: %s" % str(game._coin_icon.position))
			_wallet_before = int(main.save.get("total_coins", 0))
			_cash_before = game.cash_earned
			var want := "%d" % (_wallet_before + _cash_before)
			if String(game._coin_label.text) != want:
				return _fail("coin counter must read the wallet balance (%s), got '%s'" % [want, String(game._coin_label.text)])
			print("[COINHUD] coin counter present (icon + label '%s', on screen)" % String(game._coin_label.text))
			# --- walk onto a real coin and watch the counter climb ---
			_freeze_guards(game)
			var coin_tile := Vector2i(-1, -1)
			for c in game.coins:
				if not bool(c["is_gem"]) and not bool(c["taken"]):
					coin_tile = c["tile"]
					break
			if coin_tile.x < 0:
				return _fail("level 1 has no coin to collect")
			game.debug_teleport_to_tile(coin_tile)
			print("[COINHUD] teleported onto coin tile %s; counter must climb" % str(coin_tile))
			phase = 2
			wait_until = frame + 120
		2:
			var game = main.game
			if game.cash_earned > _cash_before:
				var want := "%d" % (_wallet_before + game.cash_earned)
				if String(game._coin_label.text) != want:
					return _fail("after the pickup the counter must read %s, got '%s'" % [want, String(game._coin_label.text)])
				if game.cash_earned - _cash_before != 5:
					return _fail("one coin must be worth 5 cash, cash_earned rose by %d" % (game.cash_earned - _cash_before))
				print("[COINHUD] counter climbed at once (%d -> %s) on pickup; PASS" % [_wallet_before + _cash_before, String(game._coin_label.text)])
				print("[COINHUD] ALL CHECKS PASS")
				quit(0)
				return true
			elif frame >= wait_until:
				return _fail("the coin was not collected in time (cash_earned still %d)" % game.cash_earned)
	if frame > 1200:
		return _fail("coin HUD test timed out (phase %d)" % phase)
	return false


func _fail(msg: String) -> bool:
	print("[COINHUD] FAIL: " + msg)
	quit(1)
	return true
