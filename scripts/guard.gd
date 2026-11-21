class_name Guard
extends Node2D
## A patrolling guard with a visible white flashlight vision cone.
## States: PATROL -> ALERT (sees you: turns and SHOOTS immediately)
##          -> SUSPECT (heard a kill: converges on the noise) -> RETURN.
## Enemy types (colour-coded, read the threat from the colour):
##   basic    — pistol.            rifle   — orange, auto-rifle, destroys crates.
##   shotgun  — red helmet, deadly up close. grenade — blue tracksuit, throws grenades.
##   sniper   — much longer vision cone.    shielded — front kills bounce off.

enum State { PATROL, SUSPECT, ALERT, RETURN }

const DEFAULT_VISION_RANGE := 235.0 # px (~3.67 tiles), levels 1-10
const DEFAULT_VISION_HALF := 0.78539816339 # 45 degrees, levels 1-10
const CHASE_MULT := 1.6
const CONE_RAYS := 13

const TYPE_STATS := {
	"basic": {"vision_mult": 1.0, "half_mult": 1.0, "fire_interval": 0.9, "damage": 1, "bullet_speed": 520.0, "shoot_range_mult": 1.0, "cash": 30, "gems": 1, "tint": Color(1, 1, 1)},
	"rifle": {"vision_mult": 1.0, "half_mult": 1.0, "fire_interval": 0.5, "damage": 1, "bullet_speed": 640.0, "shoot_range_mult": 1.1, "cash": 40, "gems": 1, "tint": Color(1, 0.78, 0.5), "burst": 3, "destroy_crates": true},
	"shotgun": {"vision_mult": 0.9, "half_mult": 1.15, "fire_interval": 1.4, "damage": 2, "bullet_speed": 480.0, "shoot_range_mult": 0.8, "cash": 50, "gems": 1, "tint": Color(1, 0.55, 0.55), "pellets": 5},
	"grenade": {"vision_mult": 1.0, "half_mult": 1.0, "fire_interval": 1.2, "damage": 1, "bullet_speed": 520.0, "shoot_range_mult": 1.0, "cash": 45, "gems": 1, "tint": Color(0.6, 0.8, 1.0), "throws_grenades": true},
	"sniper": {"vision_mult": 1.8, "half_mult": 0.8, "fire_interval": 1.8, "damage": 2, "bullet_speed": 900.0, "shoot_range_mult": 1.8, "cash": 60, "gems": 2, "tint": Color(0.8, 0.6, 1.0)},
	"shielded": {"vision_mult": 1.0, "half_mult": 1.0, "fire_interval": 1.0, "damage": 1, "bullet_speed": 520.0, "shoot_range_mult": 1.0, "cash": 70, "gems": 2, "tint": Color(0.75, 0.8, 0.85)},
}

const TYPE_TEXTURES := {
	"rifle": "res://art/guard_orange.png",
	"shotgun": "res://art/guard_red.png",
	"grenade": "res://art/guard_blue.png",
	"sniper": "res://art/guard_sniper.png",
	"shielded": "res://art/guard_shield.png",
}

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
var type := "basic"
var cash_value := 30
var gem_value := 1
var investigate_target := Vector2.ZERO
var shield_block_cd := 0.0
var frozen_timer := 0.0

var _suspect_timer := 0.0
var _lose_timer := 0.0
var _bob_t := 0.0
var _was_alert := false
var _fire_timer := 0.5
var _burst_left := 0
var _burst_timer := 0.0
var _grenade_timer := 3.0
var _about_face_timer := 0.0
var _pause_timer := 0.0
var _look_timer := 0.0

var _sprite: Sprite2D
var _cone: Polygon2D
var _marker: Polygon2D
var _label: Label
var _shield_arc: Polygon2D


static func load_tex(path: String, fallback: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	if ResourceLoader.exists(fallback):
		return load(fallback)
	return null


func setup(p_game: ShadowGame, p_tile: Vector2i, p_patrol: Array, p_speed: float, color: String, p_vision_tiles: float = 3.67, p_vision_half_deg: float = 45.0, p_type: String = "basic") -> void:
	game = p_game
	patrol = p_patrol
	patrol_speed = p_speed
	type = p_type if TYPE_STATS.has(p_type) else "basic"
	var stats: Dictionary = TYPE_STATS[type]
	vision_range = p_vision_tiles * game.tile * float(stats["vision_mult"])
	vision_half = deg_to_rad(p_vision_half_deg) * float(stats["half_mult"])
	cash_value = int(stats["cash"])
	gem_value = int(stats["gems"])
	position = game.tile_to_world(p_tile)
	# Texture: type art first, then the level's colour art, then any guard art.
	var fallback: String = GUARD_TEXTURES.get(color, GUARD_TEXTURES["orange"])
	var tex_path: String = TYPE_TEXTURES.get(type, fallback)
	_sprite = Sprite2D.new()
	_sprite.texture = load_tex(tex_path, fallback)
	_sprite.scale = Vector2(0.62, 0.62) * (game.tile / 64.0)
	_sprite.modulate = stats["tint"]
	_sprite.z_index = 6
	add_child(_sprite)
	# Vision cone: a soft WHITE flashlight beam, drawn ABOVE the floor
	# (z 5 beats the floor/wall sprites at z 0) and BELOW the player (z 10).
	_cone = Polygon2D.new()
	_cone.z_index = 5
	add_child(_cone)
	if type == "shielded":
		_shield_arc = Polygon2D.new()
		var pts := PackedVector2Array()
		for i in range(9):
			var a: float = -PI / 2.0 + (float(i) / 8.0 - 0.5) * PI * 0.9
			pts.append(Vector2(cos(a), sin(a)) * 34.0 * (game.tile / 64.0))
		_shield_arc.polygon = pts
		_shield_arc.color = Color(0.6, 0.8, 1.0, 0.55)
		_shield_arc.z_index = 7
		add_child(_shield_arc)
	# red diamond target marker above the head
	_marker = Polygon2D.new()
	var _ms: float = game.tile / 64.0
	_marker.polygon = PackedVector2Array([Vector2(0, -52) * _ms, Vector2(10, -42) * _ms, Vector2(0, -32) * _ms, Vector2(-10, -42) * _ms])
	_marker.color = Color(1, 0.25, 0.3)
	_marker.z_index = 7
	add_child(_marker)
	_label = Label.new()
	_label.position = Vector2(-14, -84) * (game.tile / 64.0)
	_label.add_theme_font_size_override("font_size", 30)
	_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 6)
	_label.visible = false
	_label.z_index = 8
	add_child(_label)
	_about_face_timer = randf_range(4.0, 9.0)


func freeze(seconds: float) -> void:
	frozen_timer = maxf(frozen_timer, seconds)
	_sprite.modulate = Color(0.6, 0.85, 1.0)


func is_frozen() -> bool:
	return frozen_timer > 0.0


## Can this guard be contact-killed from the attacker's position?
## Shielded guards block frontal kills — only from behind (or by traps).
func can_be_killed_from(attacker_pos: Vector2) -> bool:
	if type != "shielded":
		return true
	var to_attacker: Vector2 = (attacker_pos - position).normalized()
	# dot > 0: attacker is in front of the guard (guard faces attacker).
	return to_attacker.dot(Vector2(cos(facing), sin(facing))) < 0.2


func _process(delta: float) -> void:
	if game == null or game.state != ShadowGame.State.PLAYING:
		return
	if not alive:
		return
	if shield_block_cd > 0.0:
		shield_block_cd -= delta
	if frozen_timer > 0.0:
		frozen_timer -= delta
		if frozen_timer <= 0.0:
			_sprite.modulate = TYPE_STATS[type]["tint"]
		_update_cone()
		return
	_bob_t += delta
	_marker.position.y = sin(_bob_t * 3.0) * 3.0
	var speed_px: float = patrol_speed * game.tile
	match state:
		State.PATROL:
			if _pause_timer > 0.0:
				_pause_timer -= delta
			else:
				_move_along_patrol(delta, speed_px)
				_about_face_timer -= delta
				if _about_face_timer <= 0.0:
					# Unpredictable instant 180-degree turn, then a beat of stillness.
					_about_face_timer = randf_range(4.0, 9.0)
					facing += PI
					_sprite.rotation = facing + PI / 2.0
					_pause_timer = 0.45
			if can_see_player():
				_become_alert()
		State.SUSPECT:
			# Converging on the noise (a kill) faster than patrol speed.
			_face_point(investigate_target)
			if position.distance_to(investigate_target) > 10.0:
				_move_toward(investigate_target, delta, speed_px * 1.6)
			else:
				_look_timer -= delta
				if _look_timer <= 0.0:
					state = State.RETURN
			if can_see_player():
				_become_alert()
		State.ALERT:
			_face_point(game.player.position)
			_move_toward(game.player.position, delta, speed_px * CHASE_MULT)
			_try_fire(delta)
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


func hear_noise(at: Vector2) -> void:
	if not alive or state == State.ALERT or is_frozen():
		return
	investigate_target = at
	_look_timer = 1.2
	state = State.SUSPECT


func _try_fire(delta: float) -> void:
	if not can_see_player():
		return
	var stats: Dictionary = TYPE_STATS[type]
	var dist := position.distance_to(game.player.position)
	var shoot_range: float = vision_range * float(stats["shoot_range_mult"])
	if dist > shoot_range:
		return
	# Grenadiers occasionally lob a grenade instead of shooting.
	if bool(stats.get("throws_grenades", false)):
		_grenade_timer -= delta
		if _grenade_timer <= 0.0 and dist > 130.0:
			_grenade_timer = randf_range(3.5, 5.0)
			game.spawn_grenade(position, game.player.position)
			game.sfx.play("shoot")
			return
	# Rifle fires 3-round bursts.
	if _burst_left > 0:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_burst_timer = 0.09
			_burst_left -= 1
			_fire_once()
		return
	_fire_timer -= delta
	if _fire_timer > 0.0:
		return
	_fire_timer = float(stats["fire_interval"])
	if stats.has("burst"):
		_burst_left = int(stats["burst"]) - 1
	_fire_once()


func _fire_once() -> void:
	var stats: Dictionary = TYPE_STATS[type]
	var to_player: Vector2 = (game.player.position - position).normalized()
	var pellets: int = int(stats.get("pellets", 1))
	var spread: float = 0.22 if pellets > 1 else 0.03
	for i in range(pellets):
		var off: float = 0.0
		if pellets > 1:
			off = -spread + spread * 2.0 * float(i) / float(pellets - 1)
		var dir: Vector2 = to_player.rotated(off)
		game.spawn_bullet(position + dir * 30.0, dir,
			float(stats["bullet_speed"]), int(stats["damage"]),
			bool(stats.get("destroy_crates", false)))
	game.sfx.play("shoot")


func _become_alert() -> void:
	state = State.ALERT
	_lose_timer = 0.0
	_fire_timer = 0.25 # first shot comes fast — being seen is dangerous
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
	if game.is_player_hidden():
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
			_cone.color = Color(1, 0.2, 0.2, 0.35)
		State.SUSPECT:
			_cone.color = Color(1, 0.65, 0.1, 0.32)
		_:
			_cone.color = Color(1, 1, 1, 0.32)


func _update_label() -> void:
	if state == State.ALERT:
		_label.text = "!"
		_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
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
	if _shield_arc != null:
		_shield_arc.visible = false
