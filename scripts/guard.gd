class_name Guard
extends Node2D
## A patrolling guard with a visible vision cone.
## States: PATROL -> SUSPECT (sees something) -> ALERT (chases) -> RETURN.

enum State { PATROL, SUSPECT, ALERT, RETURN }

const TILE := 64
const DEFAULT_VISION_RANGE := 235.0 # px (~3.67 tiles), levels 1-10
const DEFAULT_VISION_HALF := 0.78539816339 # 45 degrees, levels 1-10
const CHASE_MULT := 1.9
const CONE_RAYS := 13

const GUARD_TEXTURES := {
	"orange": "res://art/guard_orange.png",
	"purple": "res://art/guard_purple.png",
	"blue": "res://art/guard_blue.png",
	"green": "res://art/guard_green.png",
	"pink": "res://art/guard_pink.png",
}

var game: ShadowGame
var patrol: Array = []
var patrol_index := 0
var patrol_dir := 1
var patrol_speed := 1.2 # tiles per second
var vision_range := DEFAULT_VISION_RANGE # px; per-level, wider in later levels
var vision_half := DEFAULT_VISION_HALF # radians; per-level, wider in later levels
var state: int = State.PATROL
var facing := -PI / 2.0
var alive := true
var alert_counted := false

var _suspect_timer := 0.0
var _lose_timer := 0.0
var _bob_t := 0.0
var _was_alert := false

var _sprite: Sprite2D
var _cone: Polygon2D
var _marker: Polygon2D
var _label: Label


func setup(p_game: ShadowGame, p_tile: Vector2i, p_patrol: Array, p_speed: float, color: String, p_vision_tiles: float = 3.67, p_vision_half_deg: float = 45.0) -> void:
	game = p_game
	patrol = p_patrol
	patrol_speed = p_speed
	vision_range = p_vision_tiles * TILE
	vision_half = deg_to_rad(p_vision_half_deg)
	position = game.tile_to_world(p_tile)
	var tex_path: String = GUARD_TEXTURES.get(color, GUARD_TEXTURES["orange"])
	_sprite = Sprite2D.new()
	_sprite.texture = load(tex_path)
	_sprite.scale = Vector2(0.62, 0.62)
	add_child(_sprite)
	_cone = Polygon2D.new()
	_cone.z_index = -1
	add_child(_cone)
	# red diamond target marker above the head
	_marker = Polygon2D.new()
	_marker.polygon = PackedVector2Array([Vector2(0, -52), Vector2(10, -42), Vector2(0, -32), Vector2(-10, -42)])
	_marker.color = Color(1, 0.25, 0.3)
	add_child(_marker)
	_label = Label.new()
	_label.position = Vector2(-14, -84)
	_label.add_theme_font_size_override("font_size", 30)
	_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 6)
	_label.visible = false
	add_child(_label)


func _process(delta: float) -> void:
	if game == null or game.state != ShadowGame.State.PLAYING:
		return
	if not alive:
		return
	_bob_t += delta
	_marker.position.y = sin(_bob_t * 3.0) * 3.0
	var speed_px: float = patrol_speed * TILE
	match state:
		State.PATROL:
			_move_along_patrol(delta, speed_px)
			if can_see_player():
				state = State.SUSPECT
				_suspect_timer = 0.5
		State.SUSPECT:
			_face_point(game.player.position)
			_suspect_timer -= delta
			if can_see_player():
				if _suspect_timer <= 0.0:
					_become_alert()
			else:
				_suspect_timer -= delta * 2.0
				if _suspect_timer <= -0.3:
					state = State.PATROL
		State.ALERT:
			_face_point(game.player.position)
			_move_toward(game.player.position, delta, speed_px * CHASE_MULT)
			if can_see_player():
				_lose_timer = 0.0
			else:
				_lose_timer += delta
				if _lose_timer > 2.5:
					state = State.RETURN
		State.RETURN:
			var wp: Vector2i = _nearest_patrol_tile()
			var target: Vector2 = game.tile_to_world(wp)
			if position.distance_to(target) < 6.0:
				patrol_index = patrol.find(wp)
				state = State.PATROL
				alert_counted = false
			else:
				_move_toward(target, delta, speed_px)
	_update_cone()
	_update_label()
	if state == State.ALERT and not _was_alert:
		_was_alert = true
	elif state != State.ALERT:
		_was_alert = false


func _become_alert() -> void:
	state = State.ALERT
	_lose_timer = 0.0
	if not alert_counted:
		alert_counted = true
		game.register_alert()
	game.sfx.play("alert")


func _nearest_patrol_tile() -> Vector2i:
	var best: Vector2i = patrol[0]
	var best_d := INF
	for wp in patrol:
		var d: float = position.distance_to(game.tile_to_world(wp))
		if d < best_d:
			best_d = d
			best = wp
	return best


func _move_along_patrol(delta: float, speed_px: float) -> void:
	if patrol.size() < 2:
		return
	var target: Vector2 = game.tile_to_world(patrol[patrol_index])
	_move_toward(target, delta, speed_px)
	if position.distance_to(target) < 6.0:
		patrol_index += patrol_dir
		if patrol_index >= patrol.size():
			patrol_index = patrol.size() - 2
			patrol_dir = -1
		elif patrol_index < 0:
			patrol_index = 1
			patrol_dir = 1


func _move_toward(target: Vector2, delta: float, speed_px: float) -> void:
	var to: Vector2 = target - position
	var dist := to.length()
	if dist < 0.5:
		return
	var dir := to / dist
	var step: float = minf(speed_px * delta, dist)
	position += dir * step
	facing = dir.angle()
	_sprite.rotation = facing + PI / 2.0


func _face_point(point: Vector2) -> void:
	var to: Vector2 = point - position
	if to.length() > 1.0:
		facing = to.angle()
		_sprite.rotation = facing + PI / 2.0


func can_see_player() -> bool:
	if game == null or game.player == null:
		return false
	var to_player: Vector2 = game.player.position - position
	var dist := to_player.length()
	if dist > vision_range:
		return false
	var ang := absf(wrapf(to_player.angle() - facing, -PI, PI))
	if ang > vision_half:
		return false
	return game.has_los(position, game.player.position)


func _ray_hit(dir: Vector2) -> Vector2:
	var step := 10.0
	var d := step
	while d < vision_range:
		var p: Vector2 = dir * d
		if game.is_blocking_world(position + p):
			return dir * (d - step)
		d += step
	return dir * vision_range


func _update_cone() -> void:
	var pts := PackedVector2Array()
	pts.append(Vector2.ZERO)
	for i in range(CONE_RAYS):
		var t: float = float(i) / float(CONE_RAYS - 1)
		var ang: float = facing - vision_half + t * vision_half * 2.0
		pts.append(_ray_hit(Vector2(cos(ang), sin(ang))))
	_cone.polygon = pts
	match state:
		State.ALERT:
			_cone.color = Color(1, 0.2, 0.2, 0.30)
		State.SUSPECT:
			_cone.color = Color(1, 0.6, 0.1, 0.28)
		_:
			_cone.color = Color(1, 0.85, 0.2, 0.20)


func _update_label() -> void:
	if state == State.ALERT:
		_label.text = "!"
		_label.visible = true
	elif state == State.SUSPECT:
		_label.text = "?"
		_label.add_theme_color_override("font_color", Color(1, 0.75, 0.1))
		_label.visible = true
	else:
		_label.visible = false


func eliminate() -> void:
	alive = false
	_sprite.visible = false
	_cone.visible = false
	_marker.visible = false
	_label.visible = false
