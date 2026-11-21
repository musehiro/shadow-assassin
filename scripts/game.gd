class_name ShadowGame
extends Node2D
## Shadow Assassin — top-down 2D stealth game controller.
## Tap a floor tile to move. Tap a guard to sneak up behind them.
## Stay out of the yellow vision cones. Eliminate every guard to win.

signal exit_to_menu
signal retry_level
signal next_level

enum State { PLAYING, WON, LOST, PAUSED }

const TILE := 64
const COLS := 11
const ROWS := 17
const CATCH_DIST := 34.0
const ELIM_DIST := 48.0
const PICKUP_DIST := 28.0

const TEX := {
	"floor_teal": "res://art/floor_teal.png",
	"floor_teal_star": "res://art/floor_teal_star.png",
	"floor_green": "res://art/floor_green.png",
	"floor_green_dot": "res://art/floor_green_dot.png",
	"floor_sand": "res://art/floor_sand.png",
	"wall": "res://art/wall.png",
	"crate": "res://art/crate.png",
	"plant": "res://art/plant.png",
	"coin": "res://art/coin.png",
	"gem_cyan": "res://art/gem_cyan.png",
	"gem_pink": "res://art/gem_pink.png",
	"gem_purple": "res://art/gem_purple.png",
	"star": "res://art/star.png",
	"poof": "res://art/poof.png",
}

var state: int = State.PLAYING
var level_index := 0
var level: Dictionary = {}
var save: Dictionary = {}
var sfx: Sfx

var grid: Array = [] # bool walkable, index y * COLS + x
var astar: AStar2D
var origin := Vector2.ZERO
var player: Player
var guards: Array = []
var coins: Array = [] # {node, tile, is_gem, value, taken, phase}
var targets_left := 0
var coins_collected := 0
var coins_total := 0
var alerts := 0

var _board: Node2D
var _fx: Node2D
var _hud: CanvasLayer
var _coin_label: Label
var _target_label: Label
var _alert_banner: Label
var _hint_label: Label
var _overlay: CanvasLayer
var _time := 0.0
var _hunt_repath := 0.0


func setup(p_level_index: int, p_save: Dictionary, p_sfx: Sfx) -> void:
	level_index = p_level_index
	save = p_save
	sfx = p_sfx
	level = ShadowLevels.get_levels()[level_index]
	_build_board()
	_build_hud()
	state = State.PLAYING


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


func find_path(from_tile: Vector2i, to_tile: Vector2i) -> Array:
	if not is_walkable(from_tile) or not is_walkable(to_tile):
		return []
	var from_id: int = from_tile.y * COLS + from_tile.x
	var to_id: int = to_tile.y * COLS + to_tile.x
	var ids: PackedInt64Array = astar.get_id_path(from_id, to_id)
	var points: Array = []
	for id in ids:
		points.append(tile_to_world(Vector2i(int(id) % COLS, int(id) / COLS)))
	return points


func register_alert() -> void:
	alerts += 1
	_alert_banner.visible = true


func _build_board() -> void:
	var view: Vector2 = get_viewport_rect().size
	origin = Vector2((view.x - COLS * TILE) * 0.5, 150.0)
	# backdrop
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.16, 0.18)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	# ColorRect is a Control; add it to a CanvasLayer behind everything
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -2
	bg_layer.add_child(bg)
	add_child(bg_layer)
	_board = Node2D.new()
	add_child(_board)
	_fx = Node2D.new()
	_fx.z_index = 20
	add_child(_fx)
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
				_add_sprite(_board, TEX["wall"], wpos, 1.0)
			else:
				var tex: String = TEX["floor_teal"] if (x + y) % 2 == 0 else TEX["floor_green"]
				var roll: float = rng.randf()
				if roll < 0.06:
					tex = TEX["floor_teal_star"]
				elif roll < 0.12:
					tex = TEX["floor_green_dot"]
				elif roll < 0.16:
					tex = TEX["floor_sand"]
				_add_sprite(_board, tex, wpos, 1.0)
				if ch == "X":
					_add_sprite(_board, TEX["crate"], wpos, 1.0)
				elif ch == "B":
					_add_sprite(_board, TEX["plant"], wpos, 1.0)
				elif ch == "P":
					start_tile = t
				elif ch == "C":
					_add_pickup(t, false)
				elif ch == "J":
					_add_pickup(t, true)
	# AStar graph over walkable tiles
	for y in range(ROWS):
		for x in range(COLS):
			var t := Vector2i(x, y)
			if not is_walkable(t):
				continue
			var id: int = y * COLS + x
			astar.add_point(id, Vector2(x, y))
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
	# player
	player = Player.new()
	_board.add_child(player)
	player.setup(self, start_tile)
	# guards
	for g in level["guards"]:
		var guard := Guard.new()
		_board.add_child(guard)
		guard.setup(self, g["pos"], g["patrol"], float(g["speed"]), String(g["color"]),
			float(g.get("vision", 3.67)), float(g.get("half", 45.0)))
		guards.append(guard)
	targets_left = guards.size()
	coins_total = coins_collected + _pickup_value_total()


func _pickup_value_total() -> int:
	var total := 0
	for c in coins:
		total += int(c["value"])
	return total


func _add_sprite(parent: Node, tex_path: String, wpos: Vector2, p_scale: float) -> Sprite2D:
	var s := Sprite2D.new()
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


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 10
	add_child(_hud)
	var top := ColorRect.new()
	top.color = Color(0.04, 0.13, 0.15, 0.92)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.custom_minimum_size = Vector2(0, 108)
	_hud.add_child(top)
	var title := Label.new()
	title.text = "Level %d  •  %s" % [level_index + 1, String(level["name"])]
	title.position = Vector2(16, 14)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	_hud.add_child(title)
	var coin_icon := Sprite2D.new()
	coin_icon.texture = load(TEX["coin"])
	coin_icon.position = Vector2(30, 78)
	coin_icon.scale = Vector2(0.32, 0.32)
	_hud.add_child(coin_icon)
	_coin_label = Label.new()
	_coin_label.position = Vector2(56, 62)
	_coin_label.add_theme_font_size_override("font_size", 26)
	_coin_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_hud.add_child(_coin_label)
	var target_icon := Sprite2D.new()
	target_icon.texture = load(TEX["star"])
	target_icon.position = Vector2(230, 78)
	target_icon.scale = Vector2(0.32, 0.32)
	target_icon.modulate = Color(1, 0.3, 0.35)
	_hud.add_child(target_icon)
	_target_label = Label.new()
	_target_label.position = Vector2(256, 62)
	_target_label.add_theme_font_size_override("font_size", 26)
	_target_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_hud.add_child(_target_label)
	_alert_banner = Label.new()
	_alert_banner.text = "!  SPOTTED  !"
	_alert_banner.position = Vector2(430, 58)
	_alert_banner.add_theme_font_size_override("font_size", 26)
	_alert_banner.add_theme_color_override("font_color", Color(1, 0.25, 0.2))
	_alert_banner.visible = false
	_hud.add_child(_alert_banner)
	var pause_btn := _make_button("II", Vector2(640, 16), Vector2(64, 64), 26)
	pause_btn.pressed.connect(_on_pause_pressed)
	_hud.add_child(pause_btn)
	_hint_label = Label.new()
	_hint_label.text = String(level["hint"])
	_hint_label.position = Vector2(16, get_viewport_rect().size.y - 34)
	_hint_label.add_theme_font_size_override("font_size", 20)
	_hint_label.add_theme_color_override("font_color", Color(0.75, 0.9, 0.9))
	_hud.add_child(_hint_label)
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
	_coin_label.text = "%d / %d" % [coins_collected, coins_total]
	_target_label.text = "%d left" % targets_left


func _unhandled_input(event: InputEvent) -> void:
	if state != State.PLAYING:
		return
	var pos := Vector2.ZERO
	var tapped := false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			pos = mb.position
			tapped = true
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			pos = st.position
			tapped = true
	if not tapped:
		return
	# tapped a guard? -> hunt them
	for g in guards:
		if g.alive and g.position.distance_to(pos) < 46.0:
			_hunt_guard(g)
			return
	var tile := world_to_tile(pos)
	if is_walkable(tile):
		player.hunting = null
		player.set_path(find_path(world_to_tile(player.position), tile))
		sfx.play("click")


func _hunt_guard(g: Guard, quiet: bool = false) -> void:
	var guard_tile := world_to_tile(g.position)
	var back_dir := Vector2(cos(g.facing), sin(g.facing))
	var best_tile := Vector2i(-1, -1)
	var best_score := INF
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nb: Vector2i = guard_tile + d
		if not is_walkable(nb):
			continue
		var path: Array = find_path(world_to_tile(player.position), nb)
		if path.is_empty():
			continue
		# Prefer tiles behind the guard (out of the vision cone) and near the player.
		var to_tile: Vector2 = tile_to_world(nb) - g.position
		var behind: float = -to_tile.normalized().dot(back_dir) # +1 = directly behind
		var dist: float = player.position.distance_to(tile_to_world(nb))
		var score: float = dist - behind * 120.0
		if score < best_score:
			best_score = score
			best_tile = nb
	if best_tile.x < 0:
		return
	player.hunting = g
	player.set_path(find_path(world_to_tile(player.position), best_tile))
	if not quiet:
		sfx.play("click")


func _flee_from(g: Guard) -> void:
	player.hunting = null
	var away: Vector2 = (player.position - g.position).normalized()
	var flee_tile := world_to_tile(player.position + away * TILE * 3.0)
	if not is_walkable(flee_tile):
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
				Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
			if is_walkable(flee_tile + d):
				flee_tile += d
				break
	if is_walkable(flee_tile):
		player.set_path(find_path(world_to_tile(player.position), flee_tile))
	else:
		player.stop()


func _process(delta: float) -> void:
	if state != State.PLAYING:
		return
	_time += delta
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
			sfx.play("gem" if bool(c["is_gem"]) else "coin")
			_spawn_poof(tile_to_world(c["tile"]), 0.5)
			_update_hud()
	# Re-path the hunt as the guard moves, so the player tracks the guard's back.
	if player.hunting != null and player.hunting.alive:
		_hunt_repath -= delta
		if _hunt_repath <= 0.0:
			_hunt_repath = 0.35
			_hunt_guard(player.hunting, true)
	# If the hunted guard spots us, break off and run.
	if player.hunting != null and player.hunting.alive and player.hunting.state == Guard.State.ALERT:
		_flee_from(player.hunting)
	# hunting arrival
	if player.hunting != null:
		var g: Guard = player.hunting
		if not g.alive:
			player.hunting = null
		elif player.path.is_empty():
			if g.state != Guard.State.ALERT and not g.can_see_player() and player.position.distance_to(g.position) < 95.0:
				_eliminate_guard(g)
			elif g.state == Guard.State.ALERT:
				_flee_from(g)
			# else: keep stalking — the re-path above picks a better tile
	# sneak up behind a patrolling guard
	for g in guards.duplicate():
		if g.alive and g.state != Guard.State.ALERT and player.position.distance_to(g.position) < ELIM_DIST and not g.can_see_player():
			_eliminate_guard(g)
	# caught?
	for g in guards:
		if g.alive and g.state == Guard.State.ALERT and player.position.distance_to(g.position) < CATCH_DIST:
			_game_over()
			return
	# alert banner
	var any_alert := false
	for g in guards:
		if g.alive and g.state == Guard.State.ALERT:
			any_alert = true
	_alert_banner.visible = any_alert
	# win?
	if targets_left <= 0:
		_win()


func _eliminate_guard(g: Guard) -> void:
	_spawn_poof(g.position, 1.0)
	sfx.play("poof")
	g.eliminate()
	g.queue_free()
	guards.erase(g)
	if player.hunting == g:
		player.hunting = null
	targets_left -= 1
	_update_hud()


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
	var star := Sprite2D.new()
	star.texture = load(TEX["star"])
	star.position = at
	star.scale = Vector2(0.1, 0.1)
	_fx.add_child(star)
	var tw := star.create_tween()
	tw.tween_property(star, "scale", Vector2(0.9 * p_scale, 0.9 * p_scale), 0.25)
	tw.tween_property(star, "modulate:a", 0.0, 0.35)
	tw.tween_callback(star.queue_free)
	var timer := get_tree().create_timer(1.2)
	timer.timeout.connect(p.queue_free)


func _game_over() -> void:
	if state != State.PLAYING:
		return
	state = State.LOST
	sfx.play("caught")
	_show_overlay("CAUGHT!", Color(1, 0.3, 0.3), "A guard caught you!", [
		{"text": "Try Again", "action": "retry"},
		{"text": "Level Menu", "action": "menu"},
	])


func _win() -> void:
	if state != State.PLAYING:
		return
	state = State.WON
	sfx.play("win")
	var stars := 1
	if coins_collected >= coins_total:
		stars += 1
	if alerts == 0:
		stars += 1
	var stars_dict: Dictionary = save.get("stars", {})
	var prev: int = int(stars_dict.get(level_index, 0))
	stars_dict[level_index] = maxi(prev, stars)
	save["stars"] = stars_dict
	save["unlocked"] = maxi(int(save.get("unlocked", 0)), mini(level_index + 1, ShadowLevels.get_levels().size() - 1))
	save["total_coins"] = int(save.get("total_coins", 0)) + coins_collected
	ShadowSave.save_data(save)
	var star_text := ""
	for i in range(3):
		star_text += "★" if i < stars else "☆"
	_show_overlay("LEVEL CLEAR!", Color(1, 0.85, 0.4),
		"%s\nCoins: %d / %d" % [star_text, coins_collected, coins_total], [
		{"text": "Next Level", "action": "next"},
		{"text": "Replay", "action": "retry"},
		{"text": "Level Menu", "action": "menu"},
	])


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
	player.hunting = null
	player.set_path(find_path(world_to_tile(player.position), t))


func debug_hunt_guard(i: int) -> void:
	if i >= 0 and i < guards.size():
		_hunt_guard(guards[i])


func debug_eliminate_all() -> void:
	for g in guards.duplicate():
		if g.alive:
			_eliminate_guard(g)
