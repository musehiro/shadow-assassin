extends Node
## Shadow Assassin — root node. Main menu, character roster, level select,
## screen switching.

var sfx: Sfx
var save: Dictionary = {}
var menu_layer: CanvasLayer
var game: ShadowGame


func _ready() -> void:
	sfx = Sfx.new()
	add_child(sfx)
	save = ShadowSave.load_data()
	sfx.muted = bool(save.get("muted", false))
	show_menu()


func show_menu() -> void:
	if game != null:
		game.queue_free()
		game = null
	if menu_layer != null:
		menu_layer.queue_free()
	menu_layer = CanvasLayer.new()
	add_child(menu_layer)
	_build_menu()


func start_level(index: int) -> void:
	# Guard clause: negative or out-of-range level numbers are ignored.
	# (GDScript Array[-1] wraps to the last element — start_level(-1) used
	# to silently start the final level.)
	var count := ShadowLevels.get_levels().size()
	if index < 0 or index >= count:
		push_warning("start_level: invalid level index %d (0..%d) — ignoring" % [index, count - 1])
		return
	if menu_layer != null:
		menu_layer.queue_free()
		menu_layer = null
	if game != null:
		game.queue_free()
	game = ShadowGame.new()
	add_child(game)
	game.setup(index, save, sfx)
	game.exit_to_menu.connect(show_menu)
	game.retry_level.connect(_on_retry)
	game.next_level.connect(_on_next)


func _on_retry() -> void:
	if game == null:
		return
	var idx: int = game.level_index
	start_level(idx)


func _on_next() -> void:
	if game == null:
		return
	var idx: int = mini(game.level_index + 1, ShadowLevels.get_levels().size() - 1)
	start_level(idx)


func _style_button(b: Button, bg: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg
	normal.corner_radius_top_left = 14
	normal.corner_radius_top_right = 14
	normal.corner_radius_bottom_left = 14
	normal.corner_radius_bottom_right = 14
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	b.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = bg.lightened(0.15)
	b.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = bg.darkened(0.2)
	b.add_theme_stylebox_override("pressed", pressed)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.25, 0.28, 0.3)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_color_override("font_color", Color(1, 1, 1))
	b.add_theme_color_override("font_disabled_color", Color(0.6, 0.6, 0.6))


func _wallet_chip(icon_tex: String, text: String, color: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.35)
	style.border_color = Color(color.r, color.g, color.b, 0.7)
	style.set_border_width_all(2)
	style.set_corner_radius_all(28)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	chip.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	chip.add_child(row)
	var icon := TextureRect.new()
	icon.texture = load(icon_tex)
	icon.custom_minimum_size = Vector2(36, 36)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", color)
	row.add_child(label)
	return chip


func _build_menu() -> void:
	# v5 HOMEPAGE REDESIGN (Buddhika, 2026-11-21): a completely new look —
	# colourful gradient, gold trim, wallet chips, a BIG PLAY button front
	# and centre, and the How to Play button small in a corner. ASSASSINS
	# and LEVELS stay reachable. The small-square How to Play popup itself
	# is unchanged. Layout is absolute for the top half; the level grid
	# stretches to fill the rest, so tall phones look full too.
	var view: Vector2 = get_viewport().get_visible_rect().size
	var W := view.x
	var H := view.y
	# Colourful gradient background: deep purple melting into dark teal.
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0.22, 0.10, 0.45), Color(0.08, 0.16, 0.38), Color(0.02, 0.20, 0.22)])
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill_from = Vector2(0.5, 0)
	gtex.fill_to = Vector2(0.5, 1)
	gtex.width = int(W)
	gtex.height = int(H)
	var bg := TextureRect.new()
	bg.texture = gtex
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_layer.add_child(bg)
	# Gold trim frame around the whole screen.
	var frame := PanelContainer.new()
	frame.position = Vector2(14, 14)
	frame.size = Vector2(W - 28, H - 28)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fstyle := StyleBoxFlat.new()
	fstyle.bg_color = Color(0, 0, 0, 0)
	fstyle.border_color = Color(1, 0.8, 0.25, 0.55)
	fstyle.set_border_width_all(3)
	fstyle.set_corner_radius_all(24)
	frame.add_theme_stylebox_override("panel", fstyle)
	menu_layer.add_child(frame)
	# Decorative coins + gems scattered over the background.
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in range(12):
		var s := Sprite2D.new()
		s.texture = load("res://art/coin.png")
		s.position = Vector2(rng.randf_range(30, W - 30), rng.randf_range(90, H - 90))
		s.scale = Vector2(0.3, 0.3)
		s.modulate = Color(1, 1, 1, 0.4)
		s.rotation = rng.randf_range(0, TAU)
		menu_layer.add_child(s)
	for i in range(6):
		var g := Sprite2D.new()
		g.texture = load(["res://art/gem_cyan.png", "res://art/gem_pink.png", "res://art/gem_purple.png"][i % 3])
		g.position = Vector2(rng.randf_range(40, W - 40), rng.randf_range(90, H - 90))
		g.scale = Vector2(0.3, 0.3)
		g.modulate = Color(1, 1, 1, 0.5)
		g.rotation = rng.randf_range(0, TAU)
		menu_layer.add_child(g)
	# The assassin himself, large and faded, behind the title; guards
	# flanking the wallet row.
	var hero := Sprite2D.new()
	hero.texture = load("res://art/player.png")
	hero.position = Vector2(W * 0.5, 215)
	hero.scale = Vector2(1.6, 1.6)
	hero.modulate = Color(1, 1, 1, 0.3)
	menu_layer.add_child(hero)
	for pair in [["res://art/guard_orange.png", 70.0], ["res://art/guard_blue.png", W - 70.0]]:
		var gs := Sprite2D.new()
		gs.texture = load(pair[0])
		gs.position = Vector2(float(pair[1]), 355)
		gs.scale = Vector2(0.55, 0.55)
		gs.modulate = Color(1, 1, 1, 0.6)
		menu_layer.add_child(gs)
	var title1 := Label.new()
	title1.text = "SHADOW"
	title1.position = Vector2(0, 100)
	title1.size = Vector2(W, 110)
	title1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title1.add_theme_font_size_override("font_size", 96)
	title1.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	title1.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title1.add_theme_constant_override("outline_size", 10)
	menu_layer.add_child(title1)
	var title2 := Label.new()
	title2.text = "ASSASSIN"
	title2.position = Vector2(0, 205)
	title2.size = Vector2(W, 110)
	title2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title2.add_theme_font_size_override("font_size", 96)
	title2.add_theme_color_override("font_color", Color(0.35, 0.95, 0.85))
	title2.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title2.add_theme_constant_override("outline_size", 10)
	menu_layer.add_child(title2)
	# Wallet chips: coins + gems, centred under the title.
	var wallet := HBoxContainer.new()
	wallet.position = Vector2(0, 330)
	wallet.size = Vector2(W, 56)
	wallet.alignment = BoxContainer.ALIGNMENT_CENTER
	wallet.add_theme_constant_override("separation", 24)
	menu_layer.add_child(wallet)
	wallet.add_child(_wallet_chip("res://art/coin.png", "%d coins" % int(save.get("total_coins", 0)), Color(1, 0.85, 0.3)))
	wallet.add_child(_wallet_chip("res://art/gem_cyan.png", "%d gems" % int(save.get("total_gems", 0)), Color(0.5, 0.9, 1)))
	var unlocked: int = int(save.get("unlocked", 0))
	# BIG PLAY button, front and centre — tap it and the game starts.
	var play_frame := PanelContainer.new()
	play_frame.position = Vector2(102, 392)
	play_frame.size = Vector2(516, 136)
	play_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pfstyle := StyleBoxFlat.new()
	pfstyle.bg_color = Color(1, 0.8, 0.25)
	pfstyle.set_corner_radius_all(20)
	play_frame.add_theme_stylebox_override("panel", pfstyle)
	menu_layer.add_child(play_frame)
	var play := Button.new()
	play.text = "▶  PLAY"
	play.position = Vector2(110, 400)
	play.size = Vector2(500, 120)
	play.add_theme_font_size_override("font_size", 48)
	_style_button(play, Color(0.05, 0.65, 0.35))
	play.pressed.connect(func() -> void: sfx.play("click"); start_level(mini(unlocked, ShadowLevels.get_levels().size() - 1)))
	menu_layer.add_child(play)
	var cont := Label.new()
	cont.text = "Continue: Level %d" % (mini(unlocked, ShadowLevels.get_levels().size() - 1) + 1)
	cont.position = Vector2(0, 528)
	cont.size = Vector2(W, 36)
	cont.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cont.add_theme_font_size_override("font_size", 24)
	cont.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	menu_layer.add_child(cont)
	_build_roster(570)
	var grid_label := Label.new()
	grid_label.text = "LEVELS"
	grid_label.position = Vector2(0, 870)
	grid_label.size = Vector2(W, 36)
	grid_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grid_label.add_theme_font_size_override("font_size", 24)
	grid_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	menu_layer.add_child(grid_label)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(90, 905)
	scroll.size = Vector2(540, H - 905 - 40)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_layer.add_child(scroll)
	var grid := GridContainer.new()
	grid.size = Vector2(540, 1208)
	grid.custom_minimum_size = Vector2(540, 1208)
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	for i in range(ShadowLevels.get_levels().size()):
		var b := Button.new()
		b.text = "%d" % (i + 1)
		b.custom_minimum_size = Vector2(96, 96)
		b.add_theme_font_size_override("font_size", 26)
		_style_button(b, Color(0.14, 0.42, 0.62) if i <= unlocked else Color(0.25, 0.28, 0.3))
		if i > unlocked:
			b.disabled = true
		var idx := i
		b.pressed.connect(func() -> void: sfx.play("click"); start_level(idx))
		grid.add_child(b)
	# How to Play: SMALL, separate, top-right corner.
	var howto := Button.new()
	howto.text = "How to Play"
	howto.position = Vector2(W - 172, 28)
	howto.size = Vector2(152, 54)
	howto.add_theme_font_size_override("font_size", 20)
	_style_button(howto, Color(0.55, 0.35, 0.65))
	howto.pressed.connect(_show_howto)
	menu_layer.add_child(howto)
	# Sound: small, top-left corner to match.
	var mute := Button.new()
	mute.text = "Sound: OFF" if sfx.muted else "Sound: ON"
	mute.position = Vector2(20, 28)
	mute.size = Vector2(152, 54)
	mute.add_theme_font_size_override("font_size", 20)
	_style_button(mute, Color(0.35, 0.35, 0.4))
	mute.pressed.connect(func() -> void:
		sfx.muted = not sfx.muted
		save["muted"] = sfx.muted
		ShadowSave.save_data(save)
		mute.text = "Sound: OFF" if sfx.muted else "Sound: ON"
		sfx.play("click")
	)
	menu_layer.add_child(mute)


func _build_roster(y: float) -> void:
	var label := Label.new()
	label.text = "ASSASSINS  —  speed is everything"
	label.position = Vector2(0, y)
	label.size = Vector2(720, 34)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	menu_layer.add_child(label)
	var selected: String = String(save.get("selected_character", "shadow"))
	var x := 60.0
	for c in ShadowCharacters.CHARACTERS:
		var char_id: String = String(c["id"])
		var owned := ShadowCharacters.is_owned(save, char_id)
		var is_selected := selected == char_id
		var card := PanelContainer.new()
		card.position = Vector2(x, y + 44)
		card.size = Vector2(140, 240)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.16, 0.18) if not is_selected else Color(0.16, 0.32, 0.3)
		style.border_color = Color(1, 0.85, 0.4) if is_selected else Color(0.4, 0.45, 0.5)
		style.set_border_width_all(3)
		style.corner_radius_top_left = 14
		style.corner_radius_top_right = 14
		style.corner_radius_bottom_left = 14
		style.corner_radius_bottom_right = 14
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		card.add_theme_stylebox_override("panel", style)
		menu_layer.add_child(card)
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 6)
		card.add_child(vbox)
		var name_l := Label.new()
		name_l.text = String(c["name"])
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.add_theme_font_size_override("font_size", 24)
		name_l.add_theme_color_override("font_color", Color(1, 1, 1))
		vbox.add_child(name_l)
		var stats := Label.new()
		stats.text = "Speed  x%.2f\nHealth  %d ♥" % [float(c["speed"]), int(c["health"])]
		stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats.add_theme_font_size_override("font_size", 20)
		stats.add_theme_color_override("font_color", Color(0.85, 0.95, 0.95))
		vbox.add_child(stats)
		var desc := Label.new()
		desc.text = String(c["desc"])
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 17)
		desc.add_theme_color_override("font_color", Color(0.7, 0.8, 0.8))
		vbox.add_child(desc)
		var btn := Button.new()
		if is_selected:
			btn.text = "SELECTED"
			btn.disabled = true
		elif owned:
			btn.text = "Select"
		else:
			btn.text = "◆ %d" % int(c["cost"])
		btn.custom_minimum_size = Vector2(0, 52)
		btn.add_theme_font_size_override("font_size", 22)
		_style_button(btn, Color(0.11, 0.55, 0.5) if owned else Color(0.55, 0.4, 0.1))
		var cid := char_id
		btn.pressed.connect(func() -> void:
			sfx.play("click")
			if ShadowCharacters.is_owned(save, cid):
				save["selected_character"] = cid
				ShadowSave.save_data(save)
			elif ShadowCharacters.buy(save, cid):
				pass # buy() persists + selects; not enough gems = stays as-is
			show_menu()
		)
		vbox.add_child(btn)
		x += 150.0

func _show_howto() -> void:
	sfx.play("click")
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_layer.add_child(dim)
	# SMALL SQUARE WINDOW only (Buddhika, 2026-11-21): 480x480, centred
	# on the screen — never the tall panel. Brief text, X top-right.
	var view: Vector2 = get_viewport().get_visible_rect().size
	var side := 480.0
	var panel := PanelContainer.new()
	panel.position = Vector2((view.x - side) * 0.5, (view.y - side) * 0.5)
	panel.size = Vector2(side, side)
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
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)
	menu_layer.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)
	# Title row: centred title + the X close button at the top-right.
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_row)
	var title := Label.new()
	title.text = "HOW TO PLAY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(title)
	var xbtn := Button.new()
	xbtn.text = "X"
	xbtn.custom_minimum_size = Vector2(56, 56)
	xbtn.add_theme_font_size_override("font_size", 28)
	_style_button(xbtn, Color(0.65, 0.15, 0.15))
	title_row.add_child(xbtn)
	var body := Label.new()
	body.text = "• Tap a tile to move — or drag a line.\n\n• Grab the gold KEY, then reach the green EXIT.\n\n• Sneak up behind guards to kill them.\n\n• Stay out of the white cones — guards SHOOT.\n\n• Knife is silent. Gun is loud."
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 20)
	body.add_theme_color_override("font_color", Color(1, 1, 1))
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(body)
	# Dismiss: the X button is the primary close (a real Button — it
	# always works); tapping ANYWHERE (dim or panel) also closes it.
	# Nothing can trap the player on this popup.
	var dismiss := func() -> void:
		sfx.play("click")
		dim.queue_free()
		panel.queue_free()
	var tap := func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			dismiss.call()
		elif event is InputEventScreenTouch and event.pressed:
			dismiss.call()
	dim.gui_input.connect(tap)
	panel.gui_input.connect(tap)
	xbtn.pressed.connect(dismiss)
