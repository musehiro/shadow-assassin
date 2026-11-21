class_name TutorialMarks
extends CanvasLayer
## First-time-player coach marks (v4). When a feature first matters, a
## drawn pointing hand + a short line + a Skip button appear next to it:
## the player taps the thing, then they know. Hints show ONLY in Level 1
## or 2 (plus the gun-unlock hint whenever 500 coins are banked), one at
## a time, and never block play: the hand and bubble never take input —
## only the Skip button does — and doing the taught action dismisses the
## hint. Seen/skipped hints persist in save["hints_seen"] and are never
## shown again. No emoji anywhere: the hand is a drawn picture.

const HAND_UP := "res://art/icon_hand_up.png"
const HAND_DOWN := "res://art/icon_hand_down.png"

const TEXTS := {
	"move": "Tap a tile to move!",
	"key": "Grab the gold KEY!",
	"exit": "Now reach the green EXIT!",
	"weapons": "Tap here to switch weapons!",
	"pause": "Pause the game here!",
	"gun": "Tap this to unlock the Gun!",
}

var game: ShadowGame

var _current := ""
var _hand: Sprite2D
var _bubble: PanelContainer
var _bubble_label: Label
var _skip_btn: Button


func setup(p_game: ShadowGame) -> void:
	game = p_game
	layer = 18
	_hand = Sprite2D.new()
	_hand.scale = Vector2(0.55, 0.55)
	_hand.visible = false
	add_child(_hand)
	_bubble = PanelContainer.new()
	_bubble.visible = false
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.custom_minimum_size = Vector2(460, 64)
	_bubble.size = Vector2(460, 64)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.2, 0.22, 0.95)
	style.border_color = Color(1, 0.85, 0.4)
	style.set_border_width_all(3)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_bubble.add_theme_stylebox_override("panel", style)
	add_child(_bubble)
	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 12)
	_bubble.add_child(hbox)
	_bubble_label = Label.new()
	_bubble_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble_label.add_theme_font_size_override("font_size", 24)
	_bubble_label.add_theme_color_override("font_color", Color(1, 1, 1))
	hbox.add_child(_bubble_label)
	_skip_btn = Button.new()
	_skip_btn.text = "Skip"
	_skip_btn.custom_minimum_size = Vector2(86, 48)
	_skip_btn.add_theme_font_size_override("font_size", 22)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.35, 0.35, 0.4)
	normal.corner_radius_top_left = 10
	normal.corner_radius_top_right = 10
	normal.corner_radius_bottom_left = 10
	normal.corner_radius_bottom_right = 10
	_skip_btn.add_theme_stylebox_override("normal", normal)
	_skip_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	_skip_btn.pressed.connect(func() -> void: dismiss(_current))
	hbox.add_child(_skip_btn)


func _seen(hint_id: String) -> bool:
	return (game.save.get("hints_seen", []) as Array).has(hint_id)


func _mark_seen(hint_id: String) -> void:
	var seen: Array = game.save.get("hints_seen", [])
	if seen.has(hint_id):
		return
	seen.append(hint_id)
	game.save["hints_seen"] = seen
	ShadowSave.save_data(game.save)


## Show one coach mark. The hand sits just off the target with its
## fingertip toward it; the bubble sits on the far side of the hand so
## neither covers the target (taps on the target still reach the game).
func show_hint(hint_id: String, target_center: Vector2, hand_down: bool) -> void:
	if _current != "" or _seen(hint_id) or game == null:
		return
	_current = hint_id
	_bubble_label.text = String(TEXTS.get(hint_id, "Tap this!"))
	var path := HAND_DOWN if hand_down else HAND_UP
	var hand_tex: Texture2D = null
	if ResourceLoader.exists(path):
		hand_tex = load(path)
	_hand.texture = hand_tex
	_hand.visible = hand_tex != null
	var view: Vector2 = game._view_size
	var t: float = game.tile
	var bw := 460.0
	var bx := clampf(target_center.x - bw * 0.5, 10.0, view.x - bw - 10.0)
	if hand_down:
		# Target is in the bottom bar: hand above it, fingertip down.
		_hand.position = target_center + Vector2(0, -t * 1.15)
		_bubble.position = Vector2(bx, maxf(10.0, target_center.y - t * 2.9))
	else:
		# Target is on the board: hand below it, fingertip up.
		_hand.position = target_center + Vector2(0, t * 0.95)
		_bubble.position = Vector2(bx, maxf(10.0, target_center.y - t * 1.9))
	_bubble.visible = true


func dismiss(hint_id: String) -> void:
	if _current != hint_id:
		return
	_current = ""
	_hand.visible = false
	_bubble.visible = false
	_mark_seen(hint_id)


func hide_current() -> void:
	_current = ""
	_hand.visible = false
	_bubble.visible = false


## One tick per frame while PLAYING: show the first trigger whose
## condition holds, one hint at a time.
func tick() -> void:
	if game == null or game.state != ShadowGame.State.PLAYING:
		return
	if _current != "":
		return
	if game.level_index == 0 and not _seen("move") and game.player.path.is_empty() and not game.player.moving:
		show_hint("move", game.tile_to_world(_move_target_tile()), false)
		return
	if game.level_index <= 1 and not _seen("weapons") and _seen("move"):
		show_hint("weapons", game._weapon_ui.slot_rect("knife").get_center(), true)
		return
	if game.level_index <= 1 and not _seen("pause") and _seen("weapons"):
		show_hint("pause", game._weapon_ui.pause_rect().get_center(), true)
		return
	if game.level_index <= 1 and not _seen("key") and not game.key_collected and _near_key():
		show_hint("key", game.tile_to_world(game.key_tile), false)
		return
	if game.level_index <= 1 and not _seen("exit") and game.key_collected:
		show_hint("exit", game.tile_to_world(game.exit_tile), false)
		return
	if not _seen("gun") and not ShadowWeapons.is_owned(game.save, ShadowWeapons.GUN_ID) and int(game.save.get("total_coins", 0)) >= 500:
		show_hint("gun", game._weapon_ui.slot_rect("gun").get_center(), true)
		return


func _near_key() -> bool:
	if game.key_tile.x < 0:
		return false
	var pt: Vector2i = game.world_to_tile(game.player.position)
	return absi(pt.x - game.key_tile.x) + absi(pt.y - game.key_tile.y) <= 4


func _move_target_tile() -> Vector2i:
	var pt: Vector2i = game.world_to_tile(game.player.position)
	for d in [Vector2i(2, 0), Vector2i(0, 2), Vector2i(-2, 0), Vector2i(0, -2), Vector2i(3, 0), Vector2i(0, 3)]:
		var cand: Vector2i = pt + d
		if game.is_walkable(cand):
			return cand
	return pt


# --- dismissal hooks: doing the taught action dismisses the hint. ---

func on_player_moved() -> void:
	if _current == "move":
		dismiss("move")


func on_key_collected() -> void:
	if _current == "key":
		dismiss("key")


func on_weapon_selected() -> void:
	if _current == "weapons":
		dismiss("weapons")


func on_shop_opened() -> void:
	if _current == "gun":
		dismiss("gun")


func on_pause_opened() -> void:
	if _current == "pause":
		dismiss("pause")


func on_level_won() -> void:
	if _current == "exit":
		dismiss("exit")
	else:
		hide_current()
