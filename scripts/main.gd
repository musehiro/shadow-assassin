extends Node
## Shadow Assassin — root node. Main menu, level select, screen switching.

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


func _build_menu() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.16, 0.18)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_layer.add_child(bg)
	# decorative coins and stars
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in range(10):
		var s := Sprite2D.new()
		s.texture = load("res://art/coin.png" if i % 2 == 0 else "res://art/star.png")
		s.position = Vector2(rng.randf_range(30, 690), rng.randf_range(80, 1180))
		s.scale = Vector2(0.3, 0.3)
		s.modulate = Color(1, 1, 1, 0.35)
		s.rotation = rng.randf_range(0, TAU)
		menu_layer.add_child(s)
	var title1 := Label.new()
	title1.text = "SHADOW"
	title1.position = Vector2(0, 150)
	title1.size = Vector2(720, 110)
	title1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title1.add_theme_font_size_override("font_size", 96)
	title1.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	title1.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title1.add_theme_constant_override("outline_size", 10)
	menu_layer.add_child(title1)
	var title2 := Label.new()
	title2.text = "ASSASSIN"
	title2.position = Vector2(0, 260)
	title2.size = Vector2(720, 110)
	title2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title2.add_theme_font_size_override("font_size", 96)
	title2.add_theme_color_override("font_color", Color(0.35, 0.95, 0.85))
	title2.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title2.add_theme_constant_override("outline_size", 10)
	menu_layer.add_child(title2)
	var sub := Label.new()
	sub.text = "A tiny stealth adventure  •  50 levels"
	sub.position = Vector2(0, 380)
	sub.size = Vector2(720, 40)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 26)
	sub.add_theme_color_override("font_color", Color(0.85, 0.95, 0.95))
	menu_layer.add_child(sub)
	var unlocked: int = int(save.get("unlocked", 0))
	var play := Button.new()
	play.text = "▶  PLAY  —  Level %d" % (mini(unlocked, ShadowLevels.get_levels().size() - 1) + 1)
	play.position = Vector2(160, 470)
	play.size = Vector2(400, 92)
	play.add_theme_font_size_override("font_size", 32)
	_style_button(play, Color(0.11, 0.55, 0.5))
	play.pressed.connect(func() -> void: sfx.play("click"); start_level(mini(unlocked, ShadowLevels.get_levels().size() - 1)))
	menu_layer.add_child(play)
	var grid_label := Label.new()
	grid_label.text = "LEVELS"
	grid_label.position = Vector2(0, 600)
	grid_label.size = Vector2(720, 36)
	grid_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grid_label.add_theme_font_size_override("font_size", 24)
	grid_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	menu_layer.add_child(grid_label)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(90, 650)
	scroll.size = Vector2(540, 270)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_layer.add_child(scroll)
	var grid := GridContainer.new()
	grid.size = Vector2(540, 1208)
	grid.custom_minimum_size = Vector2(540, 1208)
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	var stars_dict: Dictionary = save.get("stars", {})
	for i in range(ShadowLevels.get_levels().size()):
		var b := Button.new()
		b.text = "%d\n%s" % [i + 1, ShadowSave.stars_string(stars_dict, i)]
		b.custom_minimum_size = Vector2(96, 110)
		b.add_theme_font_size_override("font_size", 26)
		_style_button(b, Color(0.14, 0.42, 0.62) if i <= unlocked else Color(0.25, 0.28, 0.3))
		if i > unlocked:
			b.disabled = true
		var idx := i
		b.pressed.connect(func() -> void: sfx.play("click"); start_level(idx))
		grid.add_child(b)
	var howto := Button.new()
	howto.text = "How to Play"
	howto.position = Vector2(160, 960)
	howto.size = Vector2(400, 72)
	howto.add_theme_font_size_override("font_size", 28)
	_style_button(howto, Color(0.55, 0.35, 0.65))
	howto.pressed.connect(_show_howto)
	menu_layer.add_child(howto)
	var mute := Button.new()
	mute.text = "Sound: OFF" if sfx.muted else "Sound: ON"
	mute.position = Vector2(160, 1050)
	mute.size = Vector2(400, 72)
	mute.add_theme_font_size_override("font_size", 28)
	_style_button(mute, Color(0.35, 0.35, 0.4))
	mute.pressed.connect(func() -> void:
		sfx.muted = not sfx.muted
		save["muted"] = sfx.muted
		ShadowSave.save_data(save)
		mute.text = "Sound: OFF" if sfx.muted else "Sound: ON"
		sfx.play("click")
	)
	menu_layer.add_child(mute)
	var foot := Label.new()
	foot.text = "An original game  •  v1.0"
	foot.position = Vector2(0, 1210)
	foot.size = Vector2(720, 36)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_theme_font_size_override("font_size", 20)
	foot.add_theme_color_override("font_color", Color(0.6, 0.75, 0.75))
	menu_layer.add_child(foot)


func _show_howto() -> void:
	sfx.play("click")
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_layer.add_child(dim)
	var panel := PanelContainer.new()
	panel.position = Vector2(80, 300)
	panel.size = Vector2(560, 680)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.2, 0.22)
	style.border_color = Color(1, 0.8, 0.25)
	style.set_border_width_all(4)
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", style)
	menu_layer.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "HOW TO PLAY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	vbox.add_child(title)
	var body := Label.new()
	body.text = "• Tap a floor tile to move.\n\n• Tap a guard to sneak up behind them and take them out.\n\n• Stay out of the yellow vision cones. If a guard spots you, they chase you — break line of sight behind walls and crates!\n\n• Grab coins and gems for extra stars.\n\n• Eliminate every guard to clear the level.\n\n• 3 stars: clear the level + collect everything + never get spotted."
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 24)
	body.add_theme_color_override("font_color", Color(1, 1, 1))
	vbox.add_child(body)
	var close := Button.new()
	close.text = "Got it!"
	close.custom_minimum_size = Vector2(0, 72)
	close.add_theme_font_size_override("font_size", 28)
	_style_button(close, Color(0.11, 0.55, 0.5))
	close.pressed.connect(func() -> void: sfx.play("click"); dim.queue_free(); panel.queue_free())
	vbox.add_child(close)
