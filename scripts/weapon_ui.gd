class_name WeaponUI
extends CanvasLayer
## Bottom control bar + gun unlock shop (Shadow Assassin v4).
##
## A row of three picture buttons sits in a bar along the BOTTOM of the
## screen, in the space below the board: Pause | Knife | Gun. The icons
## are real drawn pictures (art/icon_*.png) — never emoji, which do not
## render on some phones. A locked weapon shows the locked picture
## (greyed gun + padlock) and the price under the name; tapping it opens
## the unlock shop. The active weapon gets a gold border. Tapping an
## owned weapon switches it mid-level.
##
## The game (ShadowGame) owns all logic: this UI only emits signals.
## AdMob is never touched here — the game calls it defensively and
## reports back through refresh() / show_note() / show_shop_note().

signal weapon_selected(weapon_id: String)
signal unlock_with_coins(weapon_id: String)
signal unlock_with_ad(weapon_id: String)
signal shop_opened
signal shop_closed
signal pause_pressed

const SLOT_BTN := 84.0

var game: ShadowGame

var _bar: PanelContainer
var _pause_button: Button
var _slot_buttons := {} # weapon_id -> Button
var _slot_labels := {} # weapon_id -> Label
var _note_label: Label
var _note_tween: Tween
var _shop_layer: Control
var _shop_weapon := ""
var _shop_note: Label
var _shop_buy_btn: Button
var _shop_ad_btn: Button


static func _load_icon(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null


func setup(p_game: ShadowGame) -> void:
	game = p_game
	layer = 12
	var view: Vector2 = game._view_size
	_bar = PanelContainer.new()
	_bar.position = Vector2(0, view.y - ShadowGame.BAR_H)
	_bar.size = Vector2(view.x, ShadowGame.BAR_H)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.06, 0.95)
	style.border_color = Color(1, 0.85, 0.4, 0.45)
	style.border_width_top = 2
	style.content_margin_top = 10
	style.content_margin_bottom = 8
	_bar.add_theme_stylebox_override("panel", style)
	add_child(_bar)
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 44)
	_bar.add_child(hbox)
	# Pause slot (picture icon, left of the weapons).
	var pause_slot := _make_slot(hbox, "Pause")
	_pause_button = pause_slot["btn"]
	_pause_button.icon = _load_icon("res://art/icon_pause.png")
	if _pause_button.icon == null:
		_pause_button.text = "II"
	_style_slot_button(_pause_button, Color(0.11, 0.55, 0.5))
	_pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	# Weapon slots.
	for w in ShadowWeapons.WEAPONS:
		var wid := String(w["id"])
		var slot := _make_slot(hbox, String(w["name"]))
		_slot_buttons[wid] = slot["btn"]
		_slot_labels[wid] = slot["lbl"]
		slot["btn"].pressed.connect(_on_slot_pressed.bind(wid))
	# Fading note above the bar ("Gun unlocked!", "No ad right now"...).
	_note_label = Label.new()
	_note_label.position = Vector2(view.x * 0.5 - 150.0, view.y - ShadowGame.BAR_H - 44.0)
	_note_label.size = Vector2(300, 40)
	_note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note_label.add_theme_font_size_override("font_size", 20)
	_note_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	_note_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_note_label.add_theme_constant_override("outline_size", 5)
	_note_label.visible = false
	add_child(_note_label)
	_build_shop()
	refresh()


func _make_slot(parent: Control, label_text: String) -> Dictionary:
	var slot := VBoxContainer.new()
	slot.add_theme_constant_override("separation", 4)
	parent.add_child(slot)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(SLOT_BTN, SLOT_BTN)
	btn.expand_icon = true
	slot.add_child(btn)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	slot.add_child(lbl)
	return {"btn": btn, "lbl": lbl}


func _style_slot_button(b: Button, bg: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg
	normal.corner_radius_top_left = 12
	normal.corner_radius_top_right = 12
	normal.corner_radius_bottom_left = 12
	normal.corner_radius_bottom_right = 12
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	b.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = bg.lightened(0.15)
	b.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = bg.darkened(0.2)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_color_override("font_color", Color(1, 1, 1))


## Screen rects, for the tutorial coach marks and the input guard.
func bar_rect() -> Rect2:
	return Rect2(0, game._view_size.y - ShadowGame.BAR_H, game._view_size.x, ShadowGame.BAR_H)


func pause_rect() -> Rect2:
	return _pause_button.get_global_rect()


func slot_rect(weapon_id: String) -> Rect2:
	if _slot_buttons.has(weapon_id):
		return (_slot_buttons[weapon_id] as Button).get_global_rect()
	return Rect2()


## Rebuild slot visuals from the current save (ownership, active weapon).
func refresh() -> void:
	if game == null:
		return
	var active := ShadowWeapons.active_weapon(game.save)
	for w in ShadowWeapons.WEAPONS:
		var wid := String(w["id"])
		var btn: Button = _slot_buttons[wid]
		var lbl: Label = _slot_labels[wid]
		var owned := ShadowWeapons.is_owned(game.save, wid)
		var is_active := active == wid
		var normal := StyleBoxFlat.new()
		normal.corner_radius_top_left = 10
		normal.corner_radius_top_right = 10
		normal.corner_radius_bottom_left = 10
		normal.corner_radius_bottom_right = 10
		if is_active:
			normal.bg_color = Color(0.45, 0.35, 0.05)
			normal.border_color = Color(1, 0.85, 0.4)
			normal.set_border_width_all(3)
		elif owned:
			normal.bg_color = Color(0.11, 0.55, 0.5)
			normal.border_color = Color(0.3, 0.35, 0.4)
			normal.set_border_width_all(2)
		else:
			normal.bg_color = Color(0.2, 0.22, 0.24)
			normal.border_color = Color(0.35, 0.38, 0.4)
			normal.set_border_width_all(2)
		btn.add_theme_stylebox_override("normal", normal)
		var hover := normal.duplicate()
		hover.bg_color = normal.bg_color.lightened(0.15)
		btn.add_theme_stylebox_override("hover", hover)
		var pressed := normal.duplicate()
		pressed.bg_color = normal.bg_color.darkened(0.2)
		btn.add_theme_stylebox_override("pressed", pressed)
		btn.modulate = Color(1, 1, 1) if owned else Color(0.55, 0.55, 0.55)
		# Picture icon (never emoji): a locked weapon shows the locked
		# picture (greyed gun + padlock drawn on it).
		var tex_path: String = String(w.get("icon_tex", ""))
		if not owned and w.has("icon_locked_tex"):
			tex_path = String(w["icon_locked_tex"])
		var tex := _load_icon(tex_path)
		if tex != null:
			btn.icon = tex
			btn.text = ""
		else:
			btn.icon = null
			btn.text = String(w["name"])
		if owned:
			lbl.text = String(w["name"])
		else:
			lbl.text = "%s\n%d coins" % [String(w["name"]), ShadowWeapons.price_of(wid)]
	if _shop_layer.visible:
		_refresh_shop()


func show_note(text: String) -> void:
	_note_label.text = text
	_note_label.visible = true
	_note_label.modulate.a = 1.0
	if _note_tween != null and _note_tween.is_valid():
		_note_tween.kill()
	_note_tween = _note_label.create_tween()
	_note_tween.tween_interval(1.8)
	_note_tween.tween_property(_note_label, "modulate:a", 0.0, 0.6)
	_note_tween.tween_callback(func() -> void: _note_label.visible = false)


func show_shop_note(text: String) -> void:
	if _shop_note != null:
		_shop_note.text = text


func open_shop(weapon_id: String) -> void:
	_shop_weapon = weapon_id
	_refresh_shop()
	_shop_layer.visible = true
	shop_opened.emit()


func close_shop() -> void:
	_shop_layer.visible = false
	_shop_weapon = ""
	shop_closed.emit()


func _on_slot_pressed(weapon_id: String) -> void:
	if game == null or game.state != ShadowGame.State.PLAYING:
		return
	if ShadowWeapons.is_owned(game.save, weapon_id):
		weapon_selected.emit(weapon_id)
	else:
		game.sfx.play("click")
		open_shop(weapon_id)


func _build_shop() -> void:
	_shop_layer = Control.new()
	_shop_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop_layer.visible = false
	add_child(_shop_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop_layer.add_child(dim)
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
	_shop_layer.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "UNLOCK GUN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	vbox.add_child(title)
	var body := Label.new()
	body.text = "Shoot guards from a distance!\nLoud — every shot alerts nearby guards.\n0.9s between shots. No contact kill\nwhile the gun is equipped."
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 24)
	body.add_theme_color_override("font_color", Color(1, 1, 1))
	vbox.add_child(body)
	_shop_note = Label.new()
	_shop_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_shop_note.add_theme_font_size_override("font_size", 22)
	_shop_note.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	vbox.add_child(_shop_note)
	_shop_buy_btn = Button.new()
	_shop_buy_btn.custom_minimum_size = Vector2(0, 72)
	_shop_buy_btn.add_theme_font_size_override("font_size", 28)
	_shop_buy_btn.pressed.connect(func() -> void: unlock_with_coins.emit(_shop_weapon))
	vbox.add_child(_shop_buy_btn)
	_shop_ad_btn = Button.new()
	_shop_ad_btn.text = "Watch ad to unlock  (FREE)"
	_shop_ad_btn.custom_minimum_size = Vector2(0, 72)
	_shop_ad_btn.add_theme_font_size_override("font_size", 28)
	_shop_ad_btn.pressed.connect(func() -> void: unlock_with_ad.emit(_shop_weapon))
	vbox.add_child(_shop_ad_btn)
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(0, 64)
	close_btn.add_theme_font_size_override("font_size", 26)
	close_btn.pressed.connect(close_shop)
	vbox.add_child(close_btn)
	_style_shop_button(_shop_buy_btn, Color(0.55, 0.4, 0.1))
	_style_shop_button(_shop_ad_btn, Color(0.11, 0.55, 0.5))
	_style_shop_button(close_btn, Color(0.35, 0.35, 0.4))


func _style_shop_button(b: Button, bg: Color) -> void:
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


func _refresh_shop() -> void:
	if _shop_weapon == "" or game == null:
		return
	var def := ShadowWeapons.weapon_def(_shop_weapon)
	_shop_note.text = "Your coins: %d" % int(game.save.get("total_coins", 0))
	_shop_buy_btn.text = "Buy — %d coins" % ShadowWeapons.price_of(_shop_weapon)
	_shop_buy_btn.disabled = int(game.save.get("total_coins", 0)) < ShadowWeapons.price_of(_shop_weapon)
	_shop_ad_btn.disabled = false
	_shop_ad_btn.text = "Watch ad to unlock  (FREE)"
