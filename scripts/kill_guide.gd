class_name KillGuide
extends CanvasLayer
## v6 visual HOW-TO-KILL guide (Buddhika, 2026-11-21 21:40: "when two
## guards stand close together, how do we kill them? Show it with
## pictures before the first play").
## Two small centred windows in sequence, each with an X to close:
##   1. HOW TO KILL — kill from behind = GOOD, face to face = YOU DIE.
##   2. TWO GUARDS TOGETHER — wait in a bush until they split up, or
##      shoot one from far away with the gun.
## Pictures only (drawn images, no emoji, no long text) so anyone
## understands at a glance. Shows before the first level play only;
## seen persists in save["kill_guide_seen"] and it never shows again.
## While open the game is PAUSED; after the second window closes, play
## begins. Tests set KillGuide.force_skip = true to bypass the guide.

static var force_skip := false

const PIC_1 := "res://art/guide_kill_1.png"
const PIC_2 := "res://art/guide_kill_2.png"

const TITLES := {1: "HOW TO KILL", 2: "TWO GUARDS TOGETHER"}
const PICS := {1: PIC_1, 2: PIC_2}
const CAPTIONS := {
	1: "Sneak up BEHIND a guard to kill him. Meet him face to face — and YOU die.",
	2: "Two guards together? Wait in a bush until they split up — or shoot one from far away with the gun.",
}

var game: ShadowGame
var current_window := 0 # 0 = none, 1 = first, 2 = second
var xbtn1: Button
var xbtn2: Button

var _dim: ColorRect
var _panel: PanelContainer


## Show the guide if this is the first ever play. Returns true when a
## window is open (the game is PAUSED until the second one closes).
func show_if_needed(p_game: ShadowGame) -> bool:
	game = p_game
	if force_skip or bool(game.save.get("kill_guide_seen", false)):
		return false
	layer = 30
	_build_window(1)
	game.state = ShadowGame.State.PAUSED
	return true


func is_open() -> bool:
	return current_window != 0


func _style_button(b: Button, bg: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg
	normal.set_corner_radius_all(12)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	b.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = bg.lightened(0.15)
	b.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = bg.darkened(0.2)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_color_override("font_color", Color(1, 1, 1))


func _build_window(num: int) -> void:
	current_window = num
	if _dim == null:
		_dim = ColorRect.new()
		_dim.color = Color(0, 0, 0, 0.6)
		_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_dim)
	if _panel != null:
		_panel.queue_free()
	# Small centred window — a small box in the middle of the screen,
	# like the How to Play window (never a full-screen panel).
	var view: Vector2 = game._view_size
	var w := 540.0
	var h := 540.0
	_panel = PanelContainer.new()
	_panel.position = Vector2((view.x - w) * 0.5, (view.y - h) * 0.5)
	_panel.size = Vector2(w, h)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.2, 0.22)
	style.border_color = Color(1, 0.8, 0.25)
	style.set_border_width_all(4)
	style.set_corner_radius_all(20)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(vbox)
	# Title row: centred title + the X close button at the top-right.
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_row)
	var title := Label.new()
	title.text = String(TITLES[num])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(title)
	var xbtn := Button.new()
	xbtn.text = "X"
	xbtn.custom_minimum_size = Vector2(56, 56)
	xbtn.add_theme_font_size_override("font_size", 28)
	_style_button(xbtn, Color(0.65, 0.15, 0.15))
	xbtn.pressed.connect(close_current)
	title_row.add_child(xbtn)
	if num == 1:
		xbtn1 = xbtn
	else:
		xbtn2 = xbtn
	# The picture — drawn images, no emoji, no long text.
	var pic := TextureRect.new()
	pic.texture = load(String(PICS[num]))
	pic.custom_minimum_size = Vector2(480, 266)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(pic)
	var caption := Label.new()
	caption.text = String(CAPTIONS[num])
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 22)
	caption.add_theme_color_override("font_color", Color(1, 1, 1))
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(caption)
	var page := Label.new()
	page.text = "%d of 2" % num
	page.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_theme_font_size_override("font_size", 18)
	page.add_theme_color_override("font_color", Color(0.7, 0.8, 0.8))
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(page)


## The X button: window 1 -> window 2; window 2 -> play begins.
func close_current() -> void:
	if current_window == 1:
		game.sfx.play("click")
		_build_window(2)
	elif current_window == 2:
		game.sfx.play("click")
		current_window = 0
		game.save["kill_guide_seen"] = true
		ShadowSave.save_data(game.save)
		if _dim != null:
			_dim.queue_free()
			_dim = null
		if _panel != null:
			_panel.queue_free()
			_panel = null
		game.state = ShadowGame.State.PLAYING
