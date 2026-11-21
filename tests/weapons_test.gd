extends SceneTree
## Headless test for Shadow Assassin v3 weapons + unlock + ads.
## Run: godot --headless -s res://tests/weapons_test.gd
## Exercises: save defaults (knife owned / gun locked), bottom control
## bar (full width at the bottom, picture icons, locked gun shows the
## locked-gun picture + 500), coin unlock (fail when
## broke, succeed at 500), gun fire (tracer, kill, cooldown gate),
## no contact kill while the gun is equipped, knife contact kill still
## works, double-coins ad flow, interstitial bookkeeping, and every
## AdMob call with NO AdMob autoload present (must never crash —
## falls back to coins / a note). Restores the save at the end.

var main: Node
var frame := 0
var phase := 0
var wait_until := 0

var _snap_coins := 0
var _snap_gems := 0
var _snap_weapons: Array = []
var _snap_active := "knife"
var _snap_completed := 0
var _snap_unlocked := 0
var _targets_before := 0
var _coins_before_collect := 0


func _initialize() -> void:
	KillGuide.force_skip = true # v6: the first-play kill guide would pause the game
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	root.add_child(main)
	print("[WEAPONS] main scene loaded")


func _process(_delta: float) -> bool:
	frame += 1
	match phase:
		0:
			if frame >= 5:
				_snap_coins = int(main.save.get("total_coins", 0))
				_snap_gems = int(main.save.get("total_gems", 0))
				_snap_weapons = Array(main.save.get("weapons_owned", ["knife"])).duplicate()
				_snap_active = String(main.save.get("active_weapon", "knife"))
				_snap_completed = int(main.save.get("levels_completed", 0))
				_snap_unlocked = int(main.save.get("unlocked", 0))
				main.start_level(0)
				print("[WEAPONS] level 0 started, save snapshotted")
				phase = 1
				wait_until = frame + 30
		1:
			if frame < wait_until:
				return false
			var game = main.game
			if game == null:
				return _fail("game is null after start_level")
			# --- save defaults: knife owned, gun locked, knife active ---
			if not ShadowWeapons.is_owned(main.save, "knife"):
				return _fail("knife must be owned by default")
			if ShadowWeapons.is_owned(main.save, "gun"):
				return _fail("gun must be LOCKED by default")
			if ShadowWeapons.active_weapon(main.save) != "knife":
				return _fail("active weapon must default to knife")
			if ShadowWeapons.GUN_PRICE != 500:
				return _fail("gun price must be 500 coins, got %d" % ShadowWeapons.GUN_PRICE)
			# --- bottom control bar: full width, at the bottom, picture icons ---
			var ui = game._weapon_ui
			if ui == null:
				return _fail("weapon UI was not built")
			if ui._slot_buttons.size() != 2:
				return _fail("bar must have 2 weapon slots, got %d" % ui._slot_buttons.size())
			var view: Vector2 = game._view_size
			if ui._bar.position.y < view.y - ShadowGame.BAR_H - 1.0:
				return _fail("bar must sit at the bottom, y=%s view=%s" % [str(ui._bar.position.y), str(view)])
			if ui._bar.size.x < view.x - 1.0 or ui._bar.size.y < ShadowGame.BAR_H - 1.0:
				return _fail("bar must span the full width, size=%s view=%s" % [str(ui._bar.size), str(view)])
			# Picture icons, never emoji: locked gun shows the locked-gun
			# picture, knife shows the knife picture, pause the pause picture.
			var knife_btn: Button = ui._slot_buttons["knife"]
			if knife_btn.icon == null or not String(knife_btn.icon.resource_path).contains("icon_knife"):
				return _fail("knife slot must show the knife picture icon")
			var gun_btn: Button = ui._slot_buttons["gun"]
			if gun_btn.icon == null or not String(gun_btn.icon.resource_path).contains("icon_gun_locked"):
				return _fail("locked gun slot must show the locked-gun picture icon")
			if gun_btn.text.contains("🔒") or gun_btn.text.contains("🔫") or knife_btn.text.contains("🔪"):
				return _fail("no emoji allowed on weapon buttons")
			var gun_lbl: Label = ui._slot_labels["gun"]
			if not String(gun_lbl.text).contains("500"):
				return _fail("locked gun slot must show the 500 price, got '%s'" % gun_lbl.text)
			if ui._pause_button.icon == null or not String(ui._pause_button.icon.resource_path).contains("icon_pause"):
				return _fail("pause button must show the pause picture icon")
			print("[WEAPONS] defaults + bottom bar OK (bar at y=%s, gun locked, 500 coins)" % str(ui._bar.position.y))
			# --- coin unlock: broke -> fail, 500 coins -> succeed ---
			main.save["total_coins"] = 0
			if ShadowWeapons.unlock_with_coins(main.save, "gun"):
				return _fail("gun unlock must FAIL with 0 coins")
			if ShadowWeapons.is_owned(main.save, "gun"):
				return _fail("gun must still be locked after failed purchase")
			main.save["total_coins"] = 500
			if not ShadowWeapons.unlock_with_coins(main.save, "gun"):
				return _fail("gun unlock must SUCCEED with 500 coins")
			if int(main.save.get("total_coins", -1)) != 0:
				return _fail("unlock must deduct all 500 coins, left %s" % str(main.save.get("total_coins")))
			if not ShadowWeapons.is_owned(main.save, "gun"):
				return _fail("gun must be owned after purchase")
			if not ShadowWeapons.set_active(main.save, "gun"):
				return _fail("switching to the owned gun must succeed")
			game._weapon_ui.refresh()
			if ui._slot_buttons["gun"].icon == null or not String(ui._slot_buttons["gun"].icon.resource_path).contains("icon_gun.png"):
				return _fail("unlocked gun slot must show the gun picture icon")
			print("[WEAPONS] coin unlock OK (500 deducted, gun owned + equipped)")
			# --- gun fire: cooldown gate, then a real shot ---
			# Stage 1 tile behind on a walkable tile (the raw teleport
			# can land inside a wall, which would eat the bullet; and
			# from 2 tiles out a single shot can miss a moving guard).
			game.debug_stage_behind_guard(0, 1.0)
			game._gun_cooldown = 0.5
			var shots_before: int = game.player_shots_fired
			game._issue_move(game.guards[0].position)
			if game.player_shots_fired != shots_before:
				return _fail("gun must NOT fire while cooling down")
			game._gun_cooldown = 0.0
			game._issue_move(game.guards[0].position)
			if game.player_shots_fired != shots_before + 1:
				return _fail("gun must fire once the cooldown clears")
			print("[WEAPONS] cooldown gate OK (blocked at 0.5s, fired at 0.0s)")
			phase = 2
			wait_until = frame + 120
		2:
			var game = main.game
			if game.kills >= 1:
				print("[WEAPONS] gun kill OK (kills=%d, cash=%d)" % [game.kills, game.cash_earned])
				if game.targets_left != 1:
					return _fail("level 1 has 2 guards; after 1 gun kill targets_left must be 1, got %d" % game.targets_left)
				game.debug_stage_behind_guard(0, 1.0)
				game._gun_cooldown = 0.0
				game._issue_move(game.guards[0].position)
				phase = 3
				wait_until = frame + 240
			elif frame >= wait_until:
				return _fail("gun bullet never killed guard 0 (kills=%d)" % game.kills)
		3:
			var game = main.game
			if game.targets_left == 0:
				print("[WEAPONS] both guards down by gunfire; walking key -> exit to win")
				game.debug_move_to_tile(game.key_tile)
				phase = 9
				wait_until = frame + 900
			elif frame >= wait_until:
				return _fail("2nd gun kill never happened (targets_left=%d, kills=%d)" % [game.targets_left, game.kills])
		9:
			var game = main.game
			if game.key_collected:
				game.debug_move_to_tile(game.exit_tile)
				phase = 10
				wait_until = frame + 900
			elif frame >= wait_until:
				return _fail("key was not collected after the gun kills")
		10:
			var game = main.game
			if game.state == game.State.WON:
				print("[WEAPONS] level won by gunfire + key + exit; waiting for Completed overlay")
				phase = 4
				wait_until = frame + 300
			elif frame >= wait_until:
				return _fail("state never became WON at the exit (state=%d, kills=%d)" % [game.state, game.kills])
		4:
			var game = main.game
			if game._double_button != null:
				print("[WEAPONS] Completed overlay shown with 2x-coins button")
				# --- double-coins with NO AdMob: button says so, no crash ---
				game._on_double_coins_pressed()
				if game._double_button.text != "No ad right now":
					return _fail("with no AdMob, 2x button must say 'No ad right now', got '%s'" % game._double_button.text)
				# --- simulate the rewarded callback (as if an ad played) ---
				game._on_rewarded_earned("double_coins")
				if not game._coins_doubled:
					return _fail("rewarded_earned(double_coins) must set _coins_doubled")
				if not String(game._overlay_body_label.text).contains("2x"):
					return _fail("overlay body must show the 2x bonus after the ad reward")
				if game._double_button.text != "2x APPLIED ✓":
					return _fail("2x button must read '2x APPLIED ✓' after reward, got '%s'" % game._double_button.text)
				print("[WEAPONS] double-coins flow OK (no-AdMob note + reward applies 2x)")
				_coins_before_collect = int(main.save.get("total_coins", 0))
				var cash: int = game.cash_earned
				game.debug_collect()
				if int(main.save.get("total_coins", -1)) != _coins_before_collect + cash * 2:
					return _fail("Collect must bank DOUBLE cash (%d x 2), total_coins=%s" % [cash, str(main.save.get("total_coins"))])
				print("[WEAPONS] Collect banked 2x cash (%d -> %d)" % [cash, cash * 2])
				phase = 5
				wait_until = frame + 60
			elif frame >= wait_until:
				return _fail("Completed overlay never appeared (no 2x button)")
		5:
			var game = main.game
			if frame < wait_until:
				return false
			if game == null or game.level_index != 1:
				return _fail("after Collect expected level 2 (index 1), got %s" % str(game.level_index if game != null else "null"))
			if ShadowWeapons.active_weapon(main.save) != "gun":
				return _fail("active weapon must persist as gun into level 2")
			# --- no contact kill while the gun is equipped ---
			_targets_before = game.targets_left
			game.debug_teleport_behind_guard(0)
			phase = 6
			wait_until = frame + 60
		6:
			var game = main.game
			if game.targets_left != _targets_before:
				return _fail("walking into a guard with the GUN must NOT kill (targets_left changed %d -> %d)" % [_targets_before, game.targets_left])
			print("[WEAPONS] gun has no contact kill OK (targets_left stayed %d)" % _targets_before)
			# --- switch to knife: contact kill works again ---
			# v5 contact rule: standing still never kills — the player
			# must WALK into the guard from behind. Freeze ALL guards
			# (the others must not interfere) and stage a genuine
			# behind-approach so the stealth kill is deterministic.
			game._on_weapon_selected("knife")
			if ShadowWeapons.active_weapon(main.save) != "knife":
				return _fail("switching back to knife must work")
			if game._key_icon == null:
				return _fail("HUD key icon must exist after weapon switch")
			for g in game.guards:
				g.freeze(120.0)
			game.debug_stage_behind_guard(0)
			game.debug_freeze_guard_patrol(0)
			game.debug_move_to_tile(game.world_to_tile(game.guards[0].position))
			phase = 7
			wait_until = frame + 180
		7:
			var game = main.game
			if game.targets_left < _targets_before:
				print("[WEAPONS] knife contact kill OK (targets_left %d -> %d)" % [_targets_before, game.targets_left])
				# --- AdMob fallback paths (autoload present, ads unavailable
				# on Linux — must degrade gracefully, never crash) ---
				game._show_rewarded("unlock_gun") # emits rewarded_failed at once
				if not String(game._weapon_ui._shop_note.text).contains("Ad failed"):
					return _fail("failed ad must set the shop note, got '%s'" % game._weapon_ui._shop_note.text)
				game._on_unlock_with_ad("gun") # not ready -> coin fallback note
				if not String(game._weapon_ui._shop_note.text).contains("No ad right now"):
					return _fail("unready ad must say 'No ad right now', got '%s'" % game._weapon_ui._shop_note.text)
				game._on_rewarded_failed("unlock_gun") # no crash
				# Simulate an unlock-gun reward with no AdMob present.
				main.save["weapons_owned"] = ["knife"]
				main.save["active_weapon"] = "knife"
				game._on_rewarded_earned("unlock_gun")
				if not ShadowWeapons.is_owned(main.save, "gun"):
					return _fail("rewarded_earned(unlock_gun) must unlock the gun")
				if ShadowWeapons.active_weapon(main.save) != "gun":
					return _fail("gun must auto-equip after the ad unlock")
				print("[WEAPONS] AdMob-absent paths OK (fallbacks, no crash)")
				# --- interstitial bookkeeping: every 2nd completed level ---
				game._coins_doubled = false
				main.save["levels_completed"] = 1
				var coins_before: int = int(main.save.get("total_coins", 0))
				var cash: int = game.cash_earned
				game._bank_rewards() # levels_completed 1 -> 2: interstitial attempted, no AdMob -> no-op
				if int(main.save.get("levels_completed", -1)) != 2:
					return _fail("levels_completed must be 2 after banking, got %s" % str(main.save.get("levels_completed")))
				if int(main.save.get("total_coins", -1)) != coins_before + cash:
					return _fail("banking without the 2x bonus must add exactly cash_earned (%d)" % cash)
				print("[WEAPONS] interstitial bookkeeping OK (level 2 completed, no crash without AdMob)")
				# --- persistence round-trip ---
				ShadowSave.save_data(main.save)
				var loaded := ShadowSave.load_data()
				if not Array(loaded.get("weapons_owned", [])).has("gun"):
					return _fail("save round-trip lost the gun unlock")
				if String(loaded.get("active_weapon", "")) != "gun":
					return _fail("save round-trip lost the active weapon")
				if int(loaded.get("levels_completed", -1)) != 2:
					return _fail("save round-trip lost levels_completed")
				print("[WEAPONS] save round-trip OK (gun owned + active, levels_completed=2)")
				phase = 8
			elif frame >= wait_until:
				return _fail("knife contact kill never happened (targets_left=%d)" % game.targets_left)
		8:
			# Restore the save exactly as found, then pass.
			main.save["total_coins"] = _snap_coins
			main.save["total_gems"] = _snap_gems
			main.save["weapons_owned"] = _snap_weapons
			main.save["active_weapon"] = _snap_active
			main.save["levels_completed"] = _snap_completed
			main.save["unlocked"] = _snap_unlocked
			ShadowSave.save_data(main.save)
			print("[WEAPONS] save restored; PASS")
			quit(0)
			return true
	if frame > 5400:
		return _fail("weapons test timed out (phase %d)" % phase)
	return false


func _fail(msg: String) -> bool:
	print("[WEAPONS] FAIL: " + msg)
	quit(1)
	return true
