class_name ShadowGame
extends Node2D
## Shadow Assassin — top-down 2D stealth game controller.
## Tap a floor tile to move; drag to steer (draw a line and the assassin
## walks along it). Walk into a guard to kill him.
## Stay out of the white vision cones — a guard who sees you turns and SHOOTS.
## Win = collect the KEY (near the guards), then reach the bright-green
## EXIT square. Killing guards is how you get to the key safely. No stars;
## cash + gems are the reward.

signal exit_to_menu
signal retry_level
signal next_level

enum State { PLAYING, WON, LOST, PAUSED }

const TILE := 64
const COLS := 11
const ROWS := 17
const ELIM_DIST := 48.0
const PICKUP_DIST := 28.0
const REVIVE_COST := 50
const MULTIKILL_WINDOW := 2.5

const TEX := {
	"floor_concrete": "res://art/floor_concrete.png",
	"floor_concrete_dark": "res://art/floor_concrete_dark.png",
	"wall": "res://art/wall.png",
	"crate": "res://art/crate.png",
	"plant": "res://art/plant.png",
	"bush": "res://art/bush.png",
	"blood": "res://art/blood.png",
	"cash": "res://art/cash.png",
	"target_icon": "res://art/target_icon.png",
	"bomb": "res://art/bomb.png",
	"cryo": "res://art/cryo_mine.png",
	"coin": "res://art/coin.png",
	"gem_cyan": "res://art/gem_cyan.png",
	"gem_pink": "res://art/gem_pink.png",
	"gem_purple": "res://art/gem_purple.png",
	"star": "res://art/star.png",
	"poof": "res://art/poof.png",
	"key": "res://art/key.png",
	"exit": "res://art/exit.png",
}

## Themes per level band — one art set, four tints.
## level.get("theme") wins; otherwise derived from the level number.
const THEMES := {
	"warehouse": {"floor": Color(1.0, 1.0, 1.0), "floor_alt": Color(0.96, 0.96, 0.97), "wall": Color(1.0, 1.0, 1.0), "crate": Color(1, 1, 1), "bg": Color(0.05, 0.05, 0.06)},
	"cyber": {"floor": Color(0.42, 0.48, 0.95), "floor_alt": Color(0.36, 0.4, 0.85), "wall": Color(0.55, 0.42, 1.0), "crate": Color(0.7, 0.8, 1.0), "bg": Color(0.04, 0.03, 0.12)},
	"lab": {"floor": Color(1.25, 1.28, 1.3), "floor_alt": Color(1.1, 1.14, 1.16), "wall": Color(0.95, 0.97, 1.0), "crate": Color(0.9, 0.95, 1.0), "bg": Color(0.7, 0.73, 0.76)},
	"prison": {"floor": Color(0.5, 0.52, 0.58), "floor_alt": Color(0.42, 0.44, 0.5), "wall": Color(0.38, 0.4, 0.46), "crate": Color(0.6, 0.62, 0.68), "bg": Color(0.03, 0.03, 0.04)},
}

var state: int = State.PLAYING
var level_index := 0
var level: Dictionary = {}
var save: Dictionary = {}
var sfx: Sfx
var theme := "warehouse"

var grid: Array = [] # bool walkable, index y * COLS + x
var astar: AStar2D
var origin := Vector2.ZERO
var player: Player
var guards: Array = []
var coins: Array = [] # {node, tile, is_gem, value, taken, phase}
var crates: Dictionary = {} # Vector2i -> Sprite2D (destructible)
var bushes: Dictionary = {} # Vector2i -> Sprite2D (hiding spots)
var traps: Array = [] # {node, tile, kind, state, timer}
var targets_left := 0
var targets_total := 0
var kills := 0
var coins_collected := 0
var coins_total := 0
var cash_earned := 0
var gems_earned := 0
var alerts := 0
var max_health := 3
var health := 3
var bullets_fired := 0
var blood_pools := 0

var _board: Node2D
var _fx: Node2D
var _hud: CanvasLayer
var _coin_label: Label
var _target_label: Label
var _health_label: Label
var _gems_label: Label
var _key_icon: Sprite2D
var _banner_label: Label
var _opening_label: Label
var _overlay: CanvasLayer
var _blip_layer: CanvasLayer
var _blips: Array = []
var _path_line: Line2D
var _path_arrow: Polygon2D
var _tap_ring: Line2D
var _tap_ring_pos := Vector2.ZERO
var _tap_ring_t := 0.0
var _bullets: Array = [] # {node, pos, dir, speed, damage, kind, fuse, blast, destroy_crates, life}
var _time := 0.0
var _invuln := 0.0
var _shake := 0.0
var _kill_chain := 0
var _kill_chain_timer := 0.0
var _drag_repath := 0.0
var _revive_time_left := 0.0
var _revive_button: Button
var _start_tile := Vector2i(1, 1)
# v3 weapons + ads
var _weapon_ui: WeaponUI
var _gun_cooldown := 0.0
var _gun_target: Guard = null
var _coins_doubled := false
var _double_button: Button
var _overlay_body_label: Label
var _shop_paused := false
var _ad_connected := false
var player_shots_fired := 0
# v3 key + exit win condition
var key_tile := Vector2i(-1, -1)
var exit_tile := Vector2i(-1, -1)
var key_collected := false
var _key_node: Sprite2D
var _exit_node: Sprite2D
var _exit_arrow: Polygon2D
var _exit_glow: Polygon2D
var _exit_locked_cd := 0.0
var _touch_down := false


func setup(p_level_index: int, p_save: Dictionary, p_sfx: Sfx) -> void:
	# Defensive guard clause: invalid level numbers never reach get_levels().
	var count := ShadowLevels.get_levels().size()
	if p_level_index < 0 or p_level_index >= count:
		push_warning("ShadowGame.setup: invalid level index %d (0..%d)" % [p_level_index, count - 1])
		p_level_index = clampi(p_level_index, 0, count - 1)
	level_index = p_level_index
	save = p_save
	sfx = p_sfx
	level = ShadowLevels.get_levels()[level_index]
	theme = String(level.get("theme", _theme_for_level(level_index)))
	max_health = ShadowCharacters.max_health(String(save.get("selected_character", "shadow")))
	health = max_health
	_build_board()
	_build_hud()
	_build_weapon_ui()
	_connect_admob_signals()
	_coins_doubled = false
	_gun_cooldown = 0.0
	_gun_target = null
	_show_opening_banner()
	sfx.start_music()
	state = State.PLAYING


static func _theme_for_level(idx: int) -> String:
	var n := idx + 1
	if n <= 12:
		return "warehouse"
	if n <= 25:
		return "cyber"
	if n <= 37:
		return "lab"
	return "prison"


func tile_to_world(t: Vector2i) -> Vector2:
	return origin + Vector2(t) * TILE + Vector2(TILE, TILE) * 0.5


func world_to_tile(w: Vector2) -> Vector2i:
	return Vector2i(((w - origin) / TILE).floor())


func is_walkable(t: Vector2i) -> bool:
	if t.x < 0 or t.y < 0 or t.x >= COLS or t.y >= ROWS:
		return false
	return grid[t.y * COLS + t.x]


func is_blocking_world(w: Vector2) -> bool:
	return not is_walkable(world_to_tile(w))


func has_los(a: Vector2, b: Vector2) -> bool:
	var total := a.distance_to(b)
	var steps := int(total / 8.0) + 1
	for i in range(1, steps):
		var p: Vector2 = a.lerp(b, float(i) / float(steps))
		if is_blocking_world(p):
			return false
	return true


func is_player_hidden() -> bool:
	if player == null:
		return false
	var t := world_to_tile(player.position)
	if not bushes.has(t):
		return false
	# A guard standing right next to the bush still spots you.
	for g in guards:
		if g.alive and g.position.distance_to(player.position) < TILE * 1.1:
			return false
	return true


func find_path(from_tile: Vector2i, to_tile: Vector2i) -> Array:
	if not is_walkable(from_tile):
		return []
	to_tile = _nearest_walkable(to_tile)
	if not is_walkable(to_tile):
		return []
	var from_id: int = from_tile.y * COLS + from_tile.x
	var to_id: int = to_tile.y * COLS + to_tile.x
	var ids: PackedInt64Array = astar.get_id_path(from_id, to_id)
	var points: Array = []
	for id in ids:
		points.append(tile_to_world(Vector2i(int(id) % COLS, int(id) / COLS)))
	return points


func _nearest_walkable(t: Vector2i) -> Vector2i:
	if is_walkable(t):
		return t
	for r in range(1, 4):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var cand := t + Vector2i(dx, dy)
				if is_walkable(cand):
					return cand
	return t


func register_alert() -> void:
	alerts += 1


## A kill makes noise — nearby guards converge on the kill spot.
func noise_at(at: Vector2, radius: float = 280.0) -> void:
	for g in guards:
		if g.alive and g.position.distance_to(at) < radius:
			g.hear_noise(at)


func _build_board() -> void:
	var view: Vector2 = get_viewport_rect().size
	origin = Vector2((view.x - COLS * TILE) * 0.5, 150.0)
	var th: Dictionary = THEMES[theme]
	# backdrop — mouse_filter IGNORE: a full-screen Control with the
	# default STOP filter swallows every tap before _unhandled_input
	# ever runs. That is exactly why v2 never moved on a real phone.
	var bg := ColorRect.new()
	bg.color = th["bg"]
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -2
	bg_layer.add_child(bg)
	add_child(bg_layer)
	_board = Node2D.new()
	add_child(_board)
	_fx = Node2D.new()
	_fx.z_index = 20
	add_child(_fx)
	# orange path line + destination arrow + tap ring (world space, above cones)
	_path_line = Line2D.new()
	_path_line.width = 12.0
	_path_line.default_color = Color(1, 0.55, 0.1, 0.9)
	_path_line.z_index = 15
	_board.add_child(_path_line)
	_path_arrow = Polygon2D.new()
	_path_arrow.polygon = PackedVector2Array([Vector2(0, -16), Vector2(12, 10), Vector2(-12, 10)])
	_path_arrow.color = Color(1, 0.55, 0.1, 0.95)
	_path_arrow.z_index = 15
	_path_arrow.visible = false
	_board.add_child(_path_arrow)
	_tap_ring = Line2D.new()
	_tap_ring.width = 4.0
	_tap_ring.default_color = Color(1, 0.55, 0.1, 0.9)
	_tap_ring.z_index = 15
	_tap_ring.closed = true
	_tap_ring.visible = false
	_board.add_child(_tap_ring)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234 + level_index * 777
	var map: PackedStringArray = level["map"]
	grid.resize(COLS * ROWS)
	astar = AStar2D.new()
	var start_tile := Vector2i(1, 1)
	for y in range(ROWS):
		var row: String = map[y]
		for x in range(COLS):
			var t := Vector2i(x, y)
			var ch: String = row[x]
			var walkable: bool = ch != "#" and ch != "X"
			grid[y * COLS + x] = walkable
			var wpos: Vector2 = tile_to_world(t)
			if ch == "#":
				var wall := _add_sprite(_board, TEX["wall"], wpos, 1.0)
				wall.modulate = th["wall"]
			else:
				var tex: String = TEX["floor_concrete"] if (x + y) % 2 == 0 else TEX["floor_concrete_dark"]
				var roll: float = rng.randf()
				if roll < 0.06:
					tex = TEX["floor_concrete_dark"]
				elif roll < 0.12:
					tex = TEX["floor_concrete"]
				elif roll < 0.16:
					tex = TEX["floor_concrete_dark"]
				var floor := _add_sprite(_board, tex, wpos, 1.0)
				floor.modulate = th["floor"] if tex == TEX["floor_concrete"] else th["floor_alt"]
				if ch == "X":
					var crate := _add_sprite(_board, TEX["crate"], wpos, 1.0)
					crate.modulate = th["crate"]
					crate.z_index = 2
					crates[t] = crate
				elif ch == "B":
					_add_bush(t)
				elif ch == "O":
					_add_trap(t, "bomb")
				elif ch == "F":
					_add_trap(t, "cryo")
				elif ch == "P":
					start_tile = t
				elif ch == "C":
					_add_pickup(t, false)
				elif ch == "J":
					_add_pickup(t, true)
				elif ch == "K":
					key_tile = t
					_add_key(t)
				elif ch == "E":
					exit_tile = t
					_add_exit(t)
	_start_tile = start_tile
	# AStar graph over walkable tiles
	_rebuild_astar()
	# Levels without K/E in the map (old data): compute them from the
	# guards + player start with the same rules the generator uses.
	if key_tile.x < 0 or exit_tile.x < 0:
		_compute_key_exit_fallback()
	# player
	player = Player.new()
	_board.add_child(player)
	player.setup(self, start_tile)
	# guards
	for g in level["guards"]:
		var guard := Guard.new()
		_board.add_child(guard)
		guard.setup(self, g["pos"], g["patrol"], float(g["speed"]), String(g["color"]),
			float(g.get("vision", 3.67)), float(g.get("half", 45.0)), String(g.get("type", "basic")))
		guards.append(guard)
	targets_total = guards.size()
	targets_left = guards.size()
	coins_total = coins_collected + _pickup_value_total()
	# traps declared in level data (the levels agent places these)
	for tr in level.get("traps", []):
		_add_trap(tr["pos"], String(tr.get("kind", "bomb")))


func _rebuild_astar() -> void:
	astar.clear()
	for y in range(ROWS):
		for x in range(COLS):
			var t := Vector2i(x, y)
			if not is_walkable(t):
				continue
			astar.add_point(y * COLS + x, Vector2(x, y))
	for y in range(ROWS):
		for x in range(COLS):
			var t := Vector2i(x, y)
			if not is_walkable(t):
				continue
			var id: int = y * COLS + x
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var nb: Vector2i = t + d
				if is_walkable(nb):
					astar.connect_points(id, nb.y * COLS + nb.x)


func _pickup_value_total() -> int:
	var total := 0
	for c in coins:
		total += int(c["value"])
	return total


func _add_sprite(parent: Node, tex_path: String, wpos: Vector2, p_scale: float) -> Sprite2D:
	var s := Sprite2D.new()
	if ResourceLoader.exists(tex_path):
		s.texture = load(tex_path)
	s.position = wpos
	s.scale = Vector2(0.5 * p_scale, 0.5 * p_scale)
	parent.add_child(s)
	return s


func _add_pickup(t: Vector2i, is_gem: bool) -> void:
	var tex := TEX["coin"]
	var value := 1
	if is_gem:
		value = 5
		tex = [TEX["gem_cyan"], TEX["gem_pink"], TEX["gem_purple"]][coins.size() % 3]
	var node := _add_sprite(_board, tex, tile_to_world(t), 0.62)
	node.z_index = 2
	coins.append({"node": node, "tile": t, "is_gem": is_gem, "value": value, "taken": false, "phase": randf() * TAU})


func _add_key(t: Vector2i) -> void:
	_key_node = _add_sprite(_board, TEX["key"], tile_to_world(t), 0.62)
	_key_node.z_index = 3


func _add_exit(t: Vector2i) -> void:
	# Bright-green exit tile: visibly different from everything else.
	_exit_node = _add_sprite(_board, TEX["exit"], tile_to_world(t), 1.0)
	_exit_node.z_index = 2
	# Pulsing glow ring under the tile.
	var glow_pts := PackedVector2Array()
	for i in range(24):
		var a: float = TAU * float(i) / 24.0
		glow_pts.append(Vector2(cos(a), sin(a)) * 40.0)
	_exit_glow = Polygon2D.new()
	_exit_glow.polygon = glow_pts
	_exit_glow.color = Color(0.2, 1.0, 0.35, 0.35)
	_exit_glow.position = tile_to_world(t)
	_exit_glow.z_index = 1
	_board.add_child(_exit_glow)
	# Big bouncing arrow above the exit, pointing down at it — the
	# player always knows where to go.
	_exit_arrow = Polygon2D.new()
	_exit_arrow.polygon = PackedVector2Array([
		Vector2(-22, -14), Vector2(22, -14), Vector2(0, 16)])
	_exit_arrow.color = Color(0.25, 1.0, 0.4, 0.95)
	_exit_arrow.position = tile_to_world(t) + Vector2(0, -58)
	_exit_arrow.z_index = 15
	_board.add_child(_exit_arrow)


func _compute_key_exit_fallback() -> void:
	# Same rules as tools/gen_levels.py, computed live from the board:
	# key 1-3 tiles from a patrol route near the patrol centroid (and
	# >= 4 from the start); exit = farthest walkable tile from the start.
	var route_tiles: Array = []
	var all_route := {}
	for g in level["guards"]:
		for wp in ShadowLevels._patrol_route_tiles(g["patrol"]):
			all_route[wp] = true
			route_tiles.append(wp)
	if route_tiles.is_empty():
		return
	var rc := Vector2.ZERO
	for rt in route_tiles:
		rc += Vector2(rt)
	rc /= float(route_tiles.size())
	var best_key := Vector2i(-1, -1)
	var best_kd := INF
	for y in range(ROWS):
		for x in range(COLS):
			var t := Vector2i(x, y)
			if not is_walkable(t):
				continue
			if t == _start_tile:
				continue
			var dmin := INF
			for rt in route_tiles:
				dmin = minf(dmin, float(absi(rt.x - x) + absi(rt.y - y)))
			if dmin < 1.0 or dmin > 3.0:
				continue
			if absi(x - _start_tile.x) + absi(y - _start_tile.y) < 4:
				continue
			var dc: float = Vector2(t).distance_to(rc)
			if dc < best_kd:
				best_kd = dc
				best_key = t
	var best_exit := Vector2i(-1, -1)
	var best_ed := -1
	for y in range(ROWS):
		for x in range(COLS):
			var t := Vector2i(x, y)
			if not is_walkable(t) or all_route.has(t):
				continue
			var path: Array = find_path(_start_tile, t)
			if path.is_empty():
				continue
			if path.size() > best_ed:
				best_ed = path.size()
				best_exit = t
	if key_tile.x < 0 and best_key.x >= 0:
		key_tile = best_key
		_add_key(best_key)
	if exit_tile.x < 0 and best_exit.x >= 0:
		exit_tile = best_exit
		_add_exit(best_exit)


func _add_bush(t: Vector2i) -> void:
	var node := _add_sprite(_board, TEX["bush"], tile_to_world(t), 1.0)
	if node.texture == null:
		node.texture = load(TEX["plant"])
	node.z_index = 12 # drawn over the assassin: you hide INSIDE the bush
	node.modulate = Color(0.75, 1.0, 0.75)
	bushes[t] = node


func _add_trap(t: Vector2i, kind: String) -> void:
	var tex: String = TEX["bomb"] if kind == "bomb" else TEX["cryo"]
	var node := _add_sprite(_board, tex, tile_to_world(t), 0.7)
	node.z_index = 2
	if node.texture == null:
		# Code-drawn fallback so traps always read on screen.
		var dot := Polygon2D.new()
		var pts := PackedVector2Array()
		for i in range(16):
			var a: float = TAU * float(i) / 16.0
			pts.append(Vector2(cos(a), sin(a)) * 18.0)
		dot.polygon = pts
		dot.color = Color(0.15, 0.15, 0.15) if kind == "bomb" else Color(0.4, 0.85, 1.0)
		dot.position = tile_to_world(t)
		dot.z_index = 2
		_board.add_child(dot)
		node.queue_free()
		traps.append({"node": dot, "tile": t, "kind": kind, "state": "idle", "timer": 0.0})
	else:
		traps.append({"node": node, "tile": t, "kind": kind, "state": "idle", "timer": 0.0})


func destroy_crate(t: Vector2i) -> void:
	if not crates.has(t):
		return
	var node: Sprite2D = crates[t]
	node.queue_free()
	crates.erase(t)
	grid[t.y * COLS + t.x] = true
	_rebuild_astar()
	_spawn_poof(tile_to_world(t), 0.8)


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 10
	add_child(_hud)
	var top := ColorRect.new()
	top.color = Color(0.04, 0.05, 0.06, 0.92)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.custom_minimum_size = Vector2(0, 108)
	_hud.add_child(top)
	# Kill counter, top-left: green target icon + "0/N", big white bold + black outline.
	var target_icon := Sprite2D.new()
	if ResourceLoader.exists(TEX["target_icon"]):
		target_icon.texture = load(TEX["target_icon"])
	else:
		target_icon.texture = load(TEX["star"])
		target_icon.modulate = Color(0.3, 1, 0.4)
	target_icon.position = Vector2(34, 78)
	target_icon.scale = Vector2(0.4, 0.4)
	_hud.add_child(target_icon)
	_target_label = Label.new()
	_target_label.position = Vector2(64, 52)
	_target_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target_label.add_theme_font_size_override("font_size", 38)
	_target_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_target_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_target_label.add_theme_constant_override("outline_size", 8)
	_hud.add_child(_target_label)
	# Health: hearts, centre of the top bar.
	_health_label = Label.new()
	_health_label.position = Vector2(300, 58)
	_health_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_label.add_theme_font_size_override("font_size", 32)
	_health_label.add_theme_color_override("font_color", Color(1, 0.25, 0.3))
	_health_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_health_label.add_theme_constant_override("outline_size", 6)
	_hud.add_child(_health_label)
	# Gems, right of the hearts.
	_gems_label = Label.new()
	_gems_label.position = Vector2(470, 62)
	_gems_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gems_label.add_theme_font_size_override("font_size", 26)
	_gems_label.add_theme_color_override("font_color", Color(0.5, 0.9, 1))
	_gems_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_gems_label.add_theme_constant_override("outline_size", 6)
	_hud.add_child(_gems_label)
	# Key status, right of the gems: grey key until collected, gold after.
	_key_icon = Sprite2D.new()
	if ResourceLoader.exists(TEX["key"]):
		_key_icon.texture = load(TEX["key"])
	_key_icon.position = Vector2(600, 78)
	_key_icon.scale = Vector2(0.34, 0.34)
	_key_icon.modulate = Color(0.45, 0.45, 0.45, 0.9)
	_hud.add_child(_key_icon)
	var pause_btn := _make_button("II", Vector2(640, 16), Vector2(64, 64), 26)
	pause_btn.pressed.connect(_on_pause_pressed)
	_hud.add_child(pause_btn)
	# Multikill / announcement banner, centre screen.
	_banner_label = Label.new()
	_banner_label.position = Vector2(0, 420)
	_banner_label.size = Vector2(720, 90)
	_banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.add_theme_font_size_override("font_size", 52)
	_banner_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	_banner_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_banner_label.add_theme_constant_override("outline_size", 10)
	_banner_label.visible = false
	_hud.add_child(_banner_label)
	_opening_label = Label.new()
	_opening_label.position = Vector2(0, 460)
	_opening_label.size = Vector2(720, 90)
	_opening_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_opening_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_opening_label.add_theme_font_size_override("font_size", 36)
	_opening_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_opening_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_opening_label.add_theme_constant_override("outline_size", 8)
	_opening_label.visible = false
	_hud.add_child(_opening_label)
	# Red edge blips pointing at off-screen enemies.
	_blip_layer = CanvasLayer.new()
	_blip_layer.layer = 15
	add_child(_blip_layer)
	for i in range(12):
		var tri := Polygon2D.new()
		tri.polygon = PackedVector2Array([Vector2(0, -16), Vector2(12, 12), Vector2(-12, 12)])
		tri.color = Color(1, 0.15, 0.15, 0.9)
		tri.visible = false
		_blip_layer.add_child(tri)
		_blips.append(tri)
	_update_hud()


func _make_button(text: String, pos: Vector2, size: Vector2, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.add_theme_font_size_override("font_size", font_size)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.11, 0.55, 0.5)
	normal.corner_radius_top_left = 12
	normal.corner_radius_top_right = 12
	normal.corner_radius_bottom_left = 12
	normal.corner_radius_bottom_right = 12
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	b.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.16, 0.68, 0.62)
	b.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.08, 0.42, 0.39)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_color_override("font_color", Color(1, 1, 1))
	return b


func _update_hud() -> void:
	_target_label.text = "%d/%d" % [kills, targets_total]
	var hearts := ""
	for i in range(max_health):
		hearts += "♥" if i < health else "♡"
	_health_label.text = hearts
	_gems_label.text = "◆ %d" % (int(save.get("total_gems", 0)) + gems_earned)
	if _key_icon != null:
		_key_icon.modulate = Color(1, 0.85, 0.25) if key_collected else Color(0.45, 0.45, 0.45, 0.9)


func _show_opening_banner() -> void:
	# The objective, big and obvious at level start (this replaces the
	# old tiny hint text at the bottom of the screen).
	_opening_label.text = "Get the KEY, then reach the EXIT!"
	_opening_label.visible = true
	_opening_label.modulate.a = 1.0
	var tw := _opening_label.create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(_opening_label, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func() -> void: _opening_label.visible = false)


func _show_banner(text: String, color: Color = Color(1, 0.85, 0.3)) -> void:
	_banner_label.text = text
	_banner_label.add_theme_color_override("font_color", color)
	_banner_label.visible = true
	_banner_label.modulate.a = 1.0
	_banner_label.scale = Vector2(0.7, 0.7)
	_banner_label.pivot_offset = Vector2(360, 45)
	var tw := _banner_label.create_tween()
	tw.tween_property(_banner_label, "scale", Vector2(1.05, 1.05), 0.18)
	tw.tween_property(_banner_label, "scale", Vector2(1.0, 1.0), 0.1)
	tw.tween_interval(0.9)
	tw.tween_property(_banner_label, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func() -> void: _banner_label.visible = false)


func _input(event: InputEvent) -> void:
	# Board input runs through _input (NOT _unhandled_input) on purpose.
	# ROOT CAUSE of the v2 phone failure: the board backdrop is a
	# full-screen ColorRect whose default mouse_filter (STOP) swallows
	# every tap before _unhandled_input ever runs — the handler existed
	# but never fired on a real phone. _input runs before GUI dispatch,
	# so taps always reach the game; the guards below keep HUD/dock
	# taps from moving the player, and the event still flows on to the
	# buttons (we never consume it).
	if state != State.PLAYING:
		return
	if event is InputEventScreenTouch:
		_touch_down = (event as InputEventScreenTouch).pressed
	# A real touch also arrives as an emulated mouse event; the touch
	# branch below already handled it, so skip the mouse twin while a
	# finger is down (otherwise every touch-shot would double-fire and
	# show a spurious "Reloading…" popup).
	if _touch_down and (event is InputEventMouseButton or event is InputEventMouseMotion):
		return
	var pos := Vector2.ZERO
	var tapped := false
	var dragging := false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			pos = mb.position
			tapped = true
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_LEFT:
			pos = mm.position
			dragging = true
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			pos = st.position
			tapped = true
	elif event is InputEventScreenDrag:
		pos = (event as InputEventScreenDrag).position
		dragging = true
	if not tapped and not dragging:
		return
	if pos.y < 110.0:
		return # top HUD bar — buttons own this strip
	if _in_weapon_dock(pos):
		return # weapon dock buttons own this strip
	if tapped:
		_issue_move(pos)
	elif dragging:
		# Drag-to-steer: continuously re-target movement (throttled in
		# _issue_move). The tap that started the drag already moved the
		# player at once — no need to lift the finger.
		_issue_move(pos, true)


func _in_weapon_dock(pos: Vector2) -> bool:
	# Same rect WeaponUI docks into (right edge, over the wall column).
	var dock := Rect2(
		Vector2(origin.x + COLS * TILE - 64.0, origin.y + ROWS * TILE * 0.5 - 105.0),
		Vector2(60.0, 210.0))
	return dock.has_point(pos)


func _issue_move(pos: Vector2, is_drag: bool = false) -> void:
	if is_drag:
		if _drag_repath > 0.0:
			return
		_drag_repath = 0.08
	var tile := world_to_tile(pos)
	# Forgiving taps: a tap within a full tile of a guard targets the guard.
	var best_guard: Guard = null
	var best_d := TILE * 1.0
	for g in guards:
		if g.alive:
			var d: float = g.position.distance_to(pos)
			if d < best_d:
				best_d = d
				best_guard = g
	if best_guard != null and ShadowWeapons.active_weapon(save) == ShadowWeapons.GUN_ID:
		# Gun equipped: tapping a guard shoots instead of walking to him.
		var gd: float = player.position.distance_to(best_guard.position)
		if gd <= ShadowWeapons.GUN_RANGE and has_los(player.position, best_guard.position):
			if _gun_cooldown <= 0.0:
				_fire_gun(best_guard)
			else:
				_spawn_popup(player.position + Vector2(0, -60), "Reloading…", Color(1, 0.85, 0.3))
			_gun_target = null
			return
		# Out of range / no line of sight: walk toward the guard so the
		# shot can be taken on arrival (auto-fire, see _process).
		_gun_target = best_guard
		_tap_ring_pos = best_guard.position
		_tap_ring_t = 0.0
		_tap_ring.visible = true
		player.set_path(find_path(world_to_tile(player.position), world_to_tile(best_guard.position)))
		sfx.play("click")
		return
	_gun_target = null
	if best_guard != null:
		tile = world_to_tile(best_guard.position)
		_tap_ring_pos = best_guard.position
	else:
		_tap_ring_pos = tile_to_world(tile)
	_tap_ring_t = 0.0
	_tap_ring.visible = true
	player.set_path(find_path(world_to_tile(player.position), tile))
	sfx.play("click")


func _process(delta: float) -> void:
	if _drag_repath > 0.0:
		_drag_repath -= delta
	if _exit_locked_cd > 0.0:
		_exit_locked_cd -= delta
	if _revive_time_left > 0.0 and state == State.LOST and _revive_button != null:
		_revive_time_left -= delta
		if _revive_time_left <= 0.0:
			_revive_button.disabled = true
			_revive_button.text = "Revive — too late"
		else:
			_revive_button.text = "Revive — %d ◆ (%ds)" % [REVIVE_COST, int(ceil(_revive_time_left))]
	if state != State.PLAYING:
		return
	_time += delta
	if _invuln > 0.0:
		_invuln -= delta
	if _gun_cooldown > 0.0:
		_gun_cooldown -= delta
	# Gun auto-fire: tapped a guard while out of range, walked into range.
	if _gun_target != null:
		if not is_instance_valid(_gun_target) or not _gun_target.alive:
			_gun_target = null
		elif ShadowWeapons.active_weapon(save) == ShadowWeapons.GUN_ID and _gun_cooldown <= 0.0:
			if player.position.distance_to(_gun_target.position) <= ShadowWeapons.GUN_RANGE and has_los(player.position, _gun_target.position):
				_fire_gun(_gun_target)
				_gun_target = null
	if _kill_chain_timer > 0.0:
		_kill_chain_timer -= delta
		if _kill_chain_timer <= 0.0:
			_kill_chain = 0
	# screen shake decay
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 30.0)
		_board.position = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
	else:
		_board.position = Vector2.ZERO
	# coin bobbing + pickup
	for c in coins:
		if bool(c["taken"]):
			continue
		var node: Sprite2D = c["node"]
		node.position.y = tile_to_world(c["tile"]).y + sin(_time * 3.0 + float(c["phase"])) * 4.0
		if player.position.distance_to(tile_to_world(c["tile"])) < PICKUP_DIST:
			c["taken"] = true
			node.visible = false
			coins_collected += int(c["value"])
			if bool(c["is_gem"]):
				gems_earned += 1
				cash_earned += 10
				sfx.play("gem")
			else:
				cash_earned += 5
				sfx.play("coin")
			_spawn_poof(tile_to_world(c["tile"]), 0.5)
			_update_hud()
	# CONTACT KILL — walking into a guard kills him instantly.
	# Knife only: with the gun equipped there is no contact kill, so the
	# gun is a real trade-off (ranged + loud, helpless up close).
	var knife_active := ShadowWeapons.active_weapon(save) == ShadowWeapons.KNIFE_ID
	for g in guards.duplicate():
		if not g.alive:
			continue
		if player.position.distance_to(g.position) < ELIM_DIST:
			if not knife_active:
				continue
			if not g.can_be_killed_from(player.position):
				if g.shield_block_cd <= 0.0:
					g.shield_block_cd = 0.8
					_spawn_popup(g.position + Vector2(0, -60), "BLOCKED!", Color(0.6, 0.8, 1.0))
					# bounce the assassin back off the shield
					var away: Vector2 = (player.position - g.position).normalized()
					player.position += away * 30.0
					player.stop()
					sfx.play("click")
				continue
			_kill_guard(g)
	# traps
	_update_traps(delta)
	# bullets / grenades
	_update_bullets(delta)
	# guard separation: guards have collision, they cannot pass each other
	for i in range(guards.size()):
		for j in range(i + 1, guards.size()):
			var a: Guard = guards[i]
			var b: Guard = guards[j]
			if not a.alive or not b.alive:
				continue
			var d: Vector2 = b.position - a.position
			var dist := d.length()
			if dist > 0.5 and dist < 44.0:
				var push: Vector2 = d.normalized() * (44.0 - dist) * 0.5
				a.position -= push
				b.position += push
	# orange path line / arrow / tap ring
	_update_path_visuals(delta)
	# red edge blips toward off-screen enemies
	_update_blips()
	# KEY pickup (bobbing key, collected on touch).
	if _key_node != null and not key_collected:
		_key_node.position.y = tile_to_world(key_tile).y + sin(_time * 3.0) * 4.0
		if player.position.distance_to(tile_to_world(key_tile)) < 40.0:
			key_collected = true
			_key_node.visible = false
			_spawn_poof(tile_to_world(key_tile), 0.6)
			sfx.play("gem")
			_show_banner("KEY COLLECTED!", Color(1, 0.85, 0.25))
			_update_hud()
	# EXIT arrow bob + pulse so the way out always reads.
	if _exit_arrow != null:
		_exit_arrow.position = tile_to_world(exit_tile) + Vector2(0, -58 + sin(_time * 3.0) * 5.0)
		_exit_arrow.modulate.a = 0.75 + sin(_time * 4.0) * 0.25
	if _exit_glow != null:
		var gs: float = 1.0 + sin(_time * 2.0) * 0.08
		_exit_glow.scale = Vector2(gs, gs)
	# WIN = collect the key, then reach the exit square. Killing guards
	# is how you get to the key safely — it is no longer the win
	# trigger. Reaching the exit without the key only reminds you
	# (throttled so it cannot spam).
	if exit_tile.x >= 0 and player.position.distance_to(tile_to_world(exit_tile)) < 34.0:
		if key_collected:
			_start_win()
		elif _exit_locked_cd <= 0.0:
			_exit_locked_cd = 2.5
			_spawn_popup(player.position + Vector2(0, -60), "LOCKED — get the KEY first!", Color(1, 0.6, 0.2))
			sfx.play("click")


func _update_path_visuals(delta: float) -> void:
	if player.path.is_empty():
		_path_line.points = PackedVector2Array()
		_path_arrow.visible = false
	else:
		var pts := PackedVector2Array()
		pts.append(player.position)
		for p in player.path:
			pts.append(p)
		_path_line.points = pts
		var dest: Vector2 = player.path[player.path.size() - 1]
		_path_arrow.visible = true
		_path_arrow.position = dest
		var prev: Vector2 = player.path[player.path.size() - 2] if player.path.size() > 1 else player.position
		var dir: Vector2 = (dest - prev)
		if dir.length() > 1.0:
			_path_arrow.rotation = dir.angle() + PI / 2.0
	if _tap_ring.visible:
		_tap_ring_t += delta
		var r: float = 26.0 + sin(_tap_ring_t * 6.0) * 4.0
		var pts := PackedVector2Array()
		for i in range(24):
			var a: float = TAU * float(i) / 24.0
			pts.append(_tap_ring_pos + Vector2(cos(a), sin(a)) * r)
		_tap_ring.points = pts
		if _tap_ring_t > 0.9:
			_tap_ring.visible = false


func _update_blips() -> void:
	var view: Vector2 = get_viewport_rect().size
	var idx := 0
	for g in guards:
		if not g.alive:
			continue
		var p: Vector2 = g.position
		var margin := 24.0
		if p.x > margin and p.x < view.x - margin and p.y > margin and p.y < view.y - margin:
			continue # on screen — no blip needed
		if idx >= _blips.size():
			break
		var tri: Polygon2D = _blips[idx]
		idx += 1
		var clamped := Vector2(clampf(p.x, 28.0, view.x - 28.0), clampf(p.y, 130.0, view.y - 28.0))
		tri.position = clamped
		tri.rotation = (p - clamped).angle() + PI / 2.0
		tri.visible = true
	for i in range(idx, _blips.size()):
		_blips[i].visible = false


# ------------------------------------------------------------------ combat

func spawn_bullet(from: Vector2, dir: Vector2, speed: float, damage: int, destroy_crates: bool, owner: String = "guard") -> void:
	var node := Polygon2D.new()
	# Player tracer: longer, brighter yellow-white so your shots read
	# differently from guard fire at a glance.
	var half_len := 14.0 if owner == "player" else 9.0
	node.polygon = PackedVector2Array([Vector2(-half_len, -2.5), Vector2(half_len, -2.5), Vector2(half_len, 2.5), Vector2(-half_len, 2.5)])
	node.color = Color(1, 0.95, 0.45) if owner == "player" else Color(1, 0.9, 0.4)
	node.position = from
	node.rotation = dir.angle()
	node.z_index = 30
	_fx.add_child(node)
	_bullets.append({"node": node, "pos": from, "dir": dir, "speed": speed,
		"damage": damage, "kind": "bullet", "fuse": 0.0, "blast": 0.0,
		"destroy_crates": destroy_crates, "life": 2.0, "owner": owner})
	if owner == "guard":
		bullets_fired += 1
	else:
		player_shots_fired += 1


func spawn_grenade(from: Vector2, target: Vector2) -> void:
	var node := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(12):
		var a: float = TAU * float(i) / 12.0
		pts.append(Vector2(cos(a), sin(a)) * 9.0)
	node.polygon = pts
	node.color = Color(0.2, 0.3, 0.2)
	node.position = from
	node.z_index = 30
	_fx.add_child(node)
	var dir: Vector2 = (target - from).normalized()
	_bullets.append({"node": node, "pos": from, "dir": dir, "speed": 170.0,
		"damage": 3, "kind": "grenade", "fuse": 1.1, "blast": 110.0,
		"destroy_crates": true, "life": 3.0})


func _update_bullets(delta: float) -> void:
	for b in _bullets.duplicate():
		var node: Polygon2D = b["node"]
		b["life"] = float(b["life"]) - delta
		if float(b["life"]) <= 0.0:
			_remove_bullet(b)
			continue
		if String(b["kind"]) == "grenade":
			b["fuse"] = float(b["fuse"]) - delta
			b["pos"] = (b["pos"] as Vector2) + (b["dir"] as Vector2) * float(b["speed"]) * delta
			node.position = b["pos"]
			if float(b["fuse"]) <= 0.0 or is_blocking_world(b["pos"]):
				_explode(b["pos"], float(b["blast"]), int(b["damage"]), false, true)
				_remove_bullet(b)
			continue
		b["pos"] = (b["pos"] as Vector2) + (b["dir"] as Vector2) * float(b["speed"]) * delta
		node.position = b["pos"]
		var tile := world_to_tile(b["pos"])
		if is_blocking_world(b["pos"]):
			if bool(b["destroy_crates"]) and crates.has(tile):
				destroy_crate(tile)
			_spawn_poof(b["pos"], 0.3)
			_remove_bullet(b)
			continue
		if String(b.get("owner", "guard")) == "player":
			# Your shot: it kills the guard it hits — unless a shielded
			# guard faces you (his shield blocks bullets like contact
			# kills). Shoot shielded guards from behind.
			for g in guards.duplicate():
				if not g.alive:
					continue
				if g.position.distance_to(b["pos"]) < 30.0:
					if not g.can_be_killed_from(player.position):
						_spawn_popup(g.position + Vector2(0, -60), "BLOCKED!", Color(0.6, 0.8, 1.0))
						sfx.play("click")
					else:
						_kill_guard(g)
					_remove_bullet(b)
					break
			continue
		if player.position.distance_to(b["pos"]) < 24.0:
			damage_player(int(b["damage"]))
			_remove_bullet(b)


func _remove_bullet(b: Dictionary) -> void:
	_bullets.erase(b)
	var node: Polygon2D = b["node"]
	if is_instance_valid(node):
		node.queue_free()


func damage_player(dmg: int) -> void:
	if state != State.PLAYING or _invuln > 0.0:
		return
	health -= dmg
	_invuln = 0.7
	_shake = maxf(_shake, 7.0)
	sfx.play("hurt")
	_update_hud()
	if health <= 0:
		health = 0
		_update_hud()
		_die()


func _update_traps(delta: float) -> void:
	for tr in traps:
		var tile: Vector2i = tr["tile"]
		var center: Vector2 = tile_to_world(tile)
		if String(tr["state"]) == "idle":
			var tripped := player.position.distance_to(center) < 46.0
			if not tripped:
				for g in guards:
					if g.alive and g.position.distance_to(center) < 46.0:
						tripped = true
						break
			if tripped:
				if String(tr["kind"]) == "bomb":
					tr["state"] = "armed"
					tr["timer"] = 0.8
					sfx.play("alert")
				else:
					_trigger_cryo(tr, center)
		elif String(tr["state"]) == "armed":
			tr["timer"] = float(tr["timer"]) - delta
			var node: Node2D = tr["node"]
			if is_instance_valid(node):
				node.modulate = Color(1, 0.4, 0.4) if int(_time * 10.0) % 2 == 0 else Color(1, 1, 1)
			if float(tr["timer"]) <= 0.0:
				_trigger_bomb(tr, center)


func _trigger_bomb(tr: Dictionary, center: Vector2) -> void:
	tr["state"] = "done"
	var node: Node2D = tr["node"]
	if is_instance_valid(node):
		node.queue_free()
	_explode(center, 120.0, 2, true, true)
	sfx.play("explode")


func _trigger_cryo(tr: Dictionary, center: Vector2) -> void:
	tr["state"] = "done"
	var node: Node2D = tr["node"]
	if is_instance_valid(node):
		node.queue_free()
	_spawn_ring(center, Color(0.4, 0.85, 1.0), 150.0)
	sfx.play("freeze")
	for g in guards:
		if g.alive and g.position.distance_to(center) < 150.0:
			g.freeze(3.0)
	if player.position.distance_to(center) < 150.0:
		player.freeze(1.2)


func _explode(center: Vector2, radius: float, player_dmg: int, kill_guards: bool, destroy_crates: bool) -> void:
	_spawn_ring(center, Color(1, 0.55, 0.1), radius)
	_shake = maxf(_shake, 12.0)
	if kill_guards:
		for g in guards.duplicate():
			if g.alive and g.position.distance_to(center) < radius:
				_kill_guard(g, true) # blasts kill even shielded guards
	if destroy_crates:
		for t in crates.keys():
			if tile_to_world(t).distance_to(center) < radius:
				destroy_crate(t)
	if player.position.distance_to(center) < radius:
		damage_player(player_dmg)


func _spawn_ring(center: Vector2, color: Color, radius: float) -> void:
	var ring := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(24):
		var a: float = TAU * float(i) / 24.0
		pts.append(Vector2(cos(a), sin(a)) * radius)
	ring.polygon = pts
	ring.color = Color(color.r, color.g, color.b, 0.45)
	ring.position = center
	ring.z_index = 25
	_fx.add_child(ring)
	var tw := ring.create_tween()
	tw.tween_property(ring, "modulate:a", 0.0, 0.5)
	tw.tween_callback(ring.queue_free)


func _kill_guard(g: Guard, by_blast: bool = false) -> void:
	if not g.alive:
		return
	var pos: Vector2 = g.position
	var cash: int = g.cash_value
	var gem_n: int = g.gem_value
	# Blood pool stays on the floor + green cash pops out + floating "+30".
	_spawn_blood(pos)
	_spawn_cash_pop(pos)
	_spawn_popup(pos + Vector2(0, -52), "+%d" % cash, Color(0.4, 1, 0.4))
	_spawn_poof(pos, 0.8)
	# Hit-stop + small screen shake for weight.
	_shake = maxf(_shake, 6.0)
	Engine.time_scale = 0.08
	get_tree().create_timer(0.09, true, false, true).timeout.connect(
		func() -> void: Engine.time_scale = 1.0)
	sfx.play("kill")
	sfx.play("cash")
	g.eliminate()
	g.queue_free()
	guards.erase(g)
	kills += 1
	targets_left -= 1
	cash_earned += cash
	gems_earned += gem_n
	# Multikill chain: kills inside the window stack up.
	if _kill_chain_timer > 0.0:
		_kill_chain += 1
	else:
		_kill_chain = 1
	_kill_chain_timer = MULTIKILL_WINDOW
	if _kill_chain == 2:
		_show_banner("DOUBLE KILL!")
		sfx.play("multikill")
	elif _kill_chain == 3:
		_show_banner("TRIPLE KILL!")
		sfx.play("multikill")
	elif _kill_chain >= 4:
		_show_banner("RAMPAGE! x%d" % _kill_chain)
		sfx.play("multikill")
	# The kill makes noise — nearby guards converge on the spot.
	if not by_blast:
		noise_at(pos)
	_update_hud()


func _spawn_blood(at: Vector2) -> void:
	blood_pools += 1
	if ResourceLoader.exists(TEX["blood"]):
		var s := Sprite2D.new()
		s.texture = load(TEX["blood"])
		s.position = at
		s.scale = Vector2(0.5, 0.5)
		s.z_index = 2
		_fx.add_child(s)
	else:
		var pool := Polygon2D.new()
		var pts := PackedVector2Array()
		for i in range(14):
			var a: float = TAU * float(i) / 14.0
			pts.append(Vector2(cos(a), sin(a)) * randf_range(16.0, 26.0))
		pool.polygon = pts
		pool.color = Color(0.65, 0.05, 0.08, 0.9)
		pool.position = at
		pool.z_index = 2
		_fx.add_child(pool)


func _spawn_cash_pop(at: Vector2) -> void:
	var s := Sprite2D.new()
	if ResourceLoader.exists(TEX["cash"]):
		s.texture = load(TEX["cash"])
	else:
		s.texture = load(TEX["coin"])
		s.modulate = Color(0.4, 1, 0.4)
	s.position = at + Vector2(randf_range(-14, 14), -10)
	s.scale = Vector2(0.4, 0.4)
	s.z_index = 25
	_fx.add_child(s)
	var tw := s.create_tween()
	tw.tween_property(s, "position", s.position + Vector2(0, -34), 0.45)
	tw.tween_property(s, "modulate:a", 0.0, 0.3)
	tw.tween_callback(s.queue_free)


func _spawn_popup(at: Vector2, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.position = at + Vector2(-30, 0)
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 6)
	l.z_index = 30
	_fx.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position", l.position + Vector2(0, -36), 0.7)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)


func _spawn_poof(at: Vector2, p_scale: float) -> void:
	var p := CPUParticles2D.new()
	p.texture = load(TEX["poof"])
	p.position = at
	p.amount = 14
	p.lifetime = 0.6
	p.one_shot = true
	p.explosiveness = 0.9
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 140.0
	p.scale_amount_min = 0.4 * p_scale
	p.scale_amount_max = 0.9 * p_scale
	p.color = Color(1, 0.9, 0.4)
	_fx.add_child(p)
	p.emitting = true
	var timer := get_tree().create_timer(1.2)
	timer.timeout.connect(p.queue_free)


# ------------------------------------------------------------------ weapons + ads (v3)

func _build_weapon_ui() -> void:
	_weapon_ui = WeaponUI.new()
	add_child(_weapon_ui)
	_weapon_ui.setup(self)
	_weapon_ui.weapon_selected.connect(_on_weapon_selected)
	_weapon_ui.unlock_with_coins.connect(_on_unlock_with_coins)
	_weapon_ui.unlock_with_ad.connect(_on_unlock_with_ad)
	_weapon_ui.shop_opened.connect(_on_shop_opened)
	_weapon_ui.shop_closed.connect(_on_shop_closed)


func _on_weapon_selected(weapon_id: String) -> void:
	if state != State.PLAYING:
		return
	if ShadowWeapons.set_active(save, weapon_id):
		_gun_target = null
		_weapon_ui.refresh()
		sfx.play("click")


func _on_unlock_with_coins(weapon_id: String) -> void:
	if ShadowWeapons.unlock_with_coins(save, weapon_id):
		ShadowWeapons.set_active(save, weapon_id)
		_weapon_ui.refresh()
		_weapon_ui.close_shop()
		_weapon_ui.show_note("%s unlocked!" % ShadowWeapons.weapon_def(weapon_id)["name"])
		sfx.play("gem")
	else:
		_weapon_ui.show_shop_note("Not enough coins — you need %d." % ShadowWeapons.price_of(weapon_id))


func _on_unlock_with_ad(weapon_id: String) -> void:
	if not _admob_ready():
		_weapon_ui.show_shop_note("No ad right now — try coins instead.")
		return
	_weapon_ui.show_shop_note("Loading ad…")
	_connect_admob_signals()
	if not _show_rewarded("unlock_gun"):
		# No AdMob at all: never leave the shop stuck on "Loading ad…".
		_weapon_ui.show_shop_note("No ad right now — try coins instead.")


func _on_shop_opened() -> void:
	# Freeze the level while the player decides — guards must not shoot
	# them through the shop panel.
	if state == State.PLAYING:
		_shop_paused = true
		state = State.PAUSED


func _on_shop_closed() -> void:
	if _shop_paused:
		_shop_paused = false
		if state == State.PAUSED:
			state = State.PLAYING


## Fire one gun shot at a guard. LOUD: the shot itself alerts nearby
## guards (like a kill noise), even if the bullet misses or is blocked.
func _fire_gun(target: Guard) -> void:
	if state != State.PLAYING or target == null or not target.alive:
		return
	_gun_cooldown = ShadowWeapons.GUN_COOLDOWN
	var dir: Vector2 = (target.position - player.position).normalized()
	spawn_bullet(player.position + dir * 30.0, dir, ShadowWeapons.GUN_BULLET_SPEED, 1, false, "player")
	sfx.play("shoot")
	noise_at(player.position, 280.0)


# ------------------------------------------------------------------ AdMob (defensive)
# The AdMob autoload is integrated by a parallel agent. Every call here
# goes through get_node_or_null("/root/AdMob") + has_method/has_signal
# guards, so the game plays exactly the same with no AdMob present:
# rewarded buttons fall back to the coin price and a short note.
# Contract: show_rewarded(placement), show_interstitial(),
# is_rewarded_ready() -> bool, signals rewarded_earned(placement),
# rewarded_failed(placement). Placements: "unlock_gun", "double_coins".

func _admob() -> Node:
	return get_node_or_null("/root/AdMob")


func _admob_ready() -> bool:
	var adm := _admob()
	if adm == null or not adm.has_method("is_rewarded_ready"):
		return false
	return bool(adm.call("is_rewarded_ready"))


func _show_rewarded(placement: String) -> bool:
	var adm := _admob()
	if adm == null or not adm.has_method("show_rewarded"):
		return false
	adm.call("show_rewarded", placement)
	return true


func _connect_admob_signals() -> void:
	if _ad_connected:
		return
	var adm := _admob()
	if adm == null:
		return
	if adm.has_signal("rewarded_earned"):
		adm.connect("rewarded_earned", _on_rewarded_earned)
	if adm.has_signal("rewarded_failed"):
		adm.connect("rewarded_failed", _on_rewarded_failed)
	_ad_connected = true


func _on_rewarded_earned(placement: String) -> void:
	match placement:
		"unlock_gun":
			ShadowWeapons.unlock_free(save, ShadowWeapons.GUN_ID)
			ShadowWeapons.set_active(save, ShadowWeapons.GUN_ID)
			if is_instance_valid(_weapon_ui):
				_weapon_ui.refresh()
				_weapon_ui.close_shop()
				_weapon_ui.show_note("Gun unlocked!")
			sfx.play("gem")
		"double_coins":
			_coins_doubled = true
			if is_instance_valid(_overlay_body_label):
				_overlay_body_label.text = "Level %d cleared!\nCash  +%d  (2x ad bonus!)\nGems  +%d ◆" % [level_index + 1, cash_earned * 2, gems_earned]
			if is_instance_valid(_double_button):
				_double_button.text = "2x APPLIED ✓"
				_double_button.disabled = true
			sfx.play("cash")


func _on_rewarded_failed(placement: String) -> void:
	match placement:
		"unlock_gun":
			if is_instance_valid(_weapon_ui):
				_weapon_ui.show_shop_note("Ad failed — try coins instead.")
		"double_coins":
			if is_instance_valid(_double_button):
				_double_button.text = "Watch ad for 2x coins"
				_double_button.disabled = false
				if is_instance_valid(_overlay_body_label):
					_overlay_body_label.text = "Level %d cleared!\nCash  +%d\nGems  +%d ◆\n(Ad failed — try again)" % [level_index + 1, cash_earned, gems_earned]


func _on_double_coins_pressed() -> void:
	if _coins_doubled or state != State.WON:
		return
	if not _admob_ready():
		# No ad available: say so on the button, briefly, then let the
		# player try again (an ad may load) or just Collect.
		if is_instance_valid(_double_button):
			_double_button.text = "No ad right now"
			_double_button.disabled = true
			var btn := _double_button
			get_tree().create_timer(2.5).timeout.connect(func() -> void:
				if is_instance_valid(btn) and not _coins_doubled:
					btn.text = "Watch ad for 2x coins"
					btn.disabled = false
			)
		return
	if is_instance_valid(_double_button):
		_double_button.text = "Loading ad…"
		_double_button.disabled = true
	_connect_admob_signals()
	if not _show_rewarded("double_coins"):
		# No AdMob at all: restore the button instead of stranding it.
		if is_instance_valid(_double_button):
			_double_button.text = "Watch ad for 2x coins"
			_double_button.disabled = false


# ------------------------------------------------------------------ win / lose

func _start_win() -> void:
	if state != State.PLAYING:
		return
	state = State.WON
	sfx.play("win")
	_show_banner("CLEARED!", Color(1, 0.85, 0.4))
	var timer := get_tree().create_timer(1.4)
	timer.timeout.connect(_show_completed)


func _bank_rewards() -> void:
	var coins_to_bank := cash_earned
	if _coins_doubled:
		coins_to_bank *= 2
	save["total_coins"] = int(save.get("total_coins", 0)) + coins_to_bank
	save["total_gems"] = int(save.get("total_gems", 0)) + gems_earned
	save["unlocked"] = maxi(int(save.get("unlocked", 0)), mini(level_index + 1, ShadowLevels.get_levels().size() - 1))
	save["levels_completed"] = int(save.get("levels_completed", 0)) + 1
	ShadowSave.save_data(save)
	# Interstitial after every 2nd completed level. Defensive: the AdMob
	# autoload may not exist yet (parallel integration) — then nothing
	# happens and the game carries on.
	if int(save["levels_completed"]) % 2 == 0:
		var adm := _admob()
		if adm != null and adm.has_method("show_interstitial"):
			adm.call("show_interstitial")


func _show_completed() -> void:
	if state != State.WON:
		return
	_show_overlay("COMPLETED!", Color(1, 0.85, 0.4),
		"Level %d cleared!\nCash  +%d\nGems  +%d ◆" % [level_index + 1, cash_earned, gems_earned], [
		{"text": "Collect  →  Next Level", "action": "collect"},
		{"text": "Watch ad for 2x coins", "action": "double"},
		{"text": "Replay", "action": "retry"},
		{"text": "Level Menu", "action": "menu"},
	])


func _die() -> void:
	if state != State.PLAYING:
		return
	state = State.LOST
	sfx.play("lose")
	sfx.play("caught")
	_spawn_poof(player.position, 1.2)
	var have_gems: int = int(save.get("total_gems", 0))
	if have_gems >= REVIVE_COST:
		_revive_time_left = 5.0
		_show_overlay("DOWN!", Color(1, 0.3, 0.3),
			"A guard got you.\nRevive and keep fighting?", [
			{"text": "Revive — %d ◆ (5s)" % REVIVE_COST, "action": "revive"},
			{"text": "Restart", "action": "retry"},
			{"text": "Level Menu", "action": "menu"},
		])
	else:
		_show_overlay("CAUGHT!", Color(1, 0.3, 0.3),
			"A guard got you!\n(Revive costs %d ◆ — you have %d)" % [REVIVE_COST, have_gems], [
			{"text": "Try Again", "action": "retry"},
			{"text": "Level Menu", "action": "menu"},
		])


func _revive() -> void:
	if state != State.LOST:
		return
	if int(save.get("total_gems", 0)) < REVIVE_COST:
		return
	save["total_gems"] = int(save.get("total_gems", 0)) - REVIVE_COST
	ShadowSave.save_data(save)
	_revive_time_left = 0.0
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
	# Clear the danger, put the assassin back at the start, brief protection.
	for b in _bullets.duplicate():
		_remove_bullet(b)
	for g in guards:
		if g.alive and g.state != Guard.State.PATROL:
			g.state = Guard.State.RETURN
	player.position = tile_to_world(_start_tile)
	player.stop()
	health = max_health
	_invuln = 2.0
	_update_hud()
	state = State.PLAYING
	sfx.play("click")


func _on_pause_pressed() -> void:
	if state != State.PLAYING:
		return
	state = State.PAUSED
	sfx.play("click")
	_show_overlay("PAUSED", Color(0.7, 0.9, 0.9), "Take a breath, shadow.", [
		{"text": "Resume", "action": "resume"},
		{"text": "Restart", "action": "retry"},
		{"text": "Level Menu", "action": "menu"},
	])


func _show_overlay(title: String, title_color: Color, body: String, buttons: Array) -> void:
	if _overlay != null:
		_overlay.queue_free()
	_overlay = CanvasLayer.new()
	_overlay.layer = 20
	add_child(_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	var panel := PanelContainer.new()
	panel.position = Vector2(110, 380)
	panel.size = Vector2(500, 520)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.2, 0.22)
	style.border_color = Color(1, 0.8, 0.25)
	style.set_border_width_all(4)
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	_overlay.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	panel.add_child(vbox)
	var title_label := Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 44)
	title_label.add_theme_color_override("font_color", title_color)
	vbox.add_child(title_label)
	var body_label := Label.new()
	body_label.text = body
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_label.add_theme_font_size_override("font_size", 26)
	body_label.add_theme_color_override("font_color", Color(1, 1, 1))
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(body_label)
	_overlay_body_label = body_label
	for b in buttons:
		var btn := _make_button(String(b["text"]), Vector2.ZERO, Vector2(440, 72), 28)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var action: String = String(b["action"])
		if action == "retry":
			btn.pressed.connect(func() -> void: retry_level.emit())
		elif action == "menu":
			btn.pressed.connect(func() -> void: exit_to_menu.emit())
		elif action == "next":
			btn.pressed.connect(func() -> void: next_level.emit())
		elif action == "collect":
			btn.pressed.connect(func() -> void: _bank_rewards(); next_level.emit())
		elif action == "double":
			_double_button = btn
			btn.pressed.connect(_on_double_coins_pressed)
		elif action == "revive":
			_revive_button = btn
			btn.pressed.connect(_revive)
		elif action == "resume":
			btn.pressed.connect(_on_resume_pressed)
		vbox.add_child(btn)


func _on_resume_pressed() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
	state = State.PLAYING
	sfx.play("click")


# ------------------------------------------------------------------ debug hooks
func debug_move_to_tile(t: Vector2i) -> void:
	player.set_path(find_path(world_to_tile(player.position), t))


func debug_teleport_to_tile(t: Vector2i) -> void:
	player.position = tile_to_world(t)
	player.stop()


func debug_collect_key() -> void:
	if not key_collected:
		key_collected = true
		if _key_node != null:
			_key_node.visible = false
		_update_hud()


func debug_teleport_behind_guard(i: int) -> void:
	if i < 0 or i >= guards.size():
		return
	var g: Guard = guards[i]
	var behind: Vector2 = g.position - Vector2(cos(g.facing), sin(g.facing)) * (ELIM_DIST * 0.7)
	player.position = behind
	player.stop()


func debug_kill_guard(i: int) -> void:
	if i >= 0 and i < guards.size():
		_kill_guard(guards[i])


func debug_eliminate_all() -> void:
	for g in guards.duplicate():
		if g.alive:
			_kill_guard(g)


func debug_damage_player(dmg: int) -> void:
	_invuln = 0.0
	damage_player(dmg)


func debug_force_alert(i: int) -> void:
	if i >= 0 and i < guards.size() and guards[i].alive:
		guards[i]._become_alert()


func debug_collect() -> void:
	_bank_rewards()
	next_level.emit()
