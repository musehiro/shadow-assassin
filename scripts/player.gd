class_name Player
extends Node2D
## The shadow assassin. Tap-to-move (A*) plus drag-to-steer.
## Contact with a guard kills the guard — no stalk mode, no attack button.
## Clearly faster than any guard: base 260 px/s vs guard chase ~110-180 px/s.

const BASE_SPEED := 260.0

var game: ShadowGame
var path: Array = [] # world points to follow
var facing := -PI / 2.0
var moving := false
var speed_mult := 1.0
var frozen_timer := 0.0

var _sprite: Sprite2D
var _step_timer := 0.0


func setup(p_game: ShadowGame, start_tile: Vector2i) -> void:
	game = p_game
	position = game.tile_to_world(start_tile)
	speed_mult = ShadowCharacters.speed_mult(String(game.save.get("selected_character", "shadow")))
	z_index = 10 # above vision cones (z 5) so the assassin always reads clearly
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://art/player.png")
	_sprite.scale = Vector2(0.62, 0.62) * (game.tile / 64.0)
	add_child(_sprite)


func freeze(seconds: float) -> void:
	frozen_timer = maxf(frozen_timer, seconds)
	path.clear()


func set_path(points: Array) -> void:
	path = points.duplicate()
	# drop any point we are already standing on
	while not path.is_empty() and position.distance_to(path[0]) < 6.0:
		path.pop_front()


func stop() -> void:
	path.clear()


func _process(delta: float) -> void:
	if game == null or game.state != ShadowGame.State.PLAYING:
		moving = false
		return
	if frozen_timer > 0.0:
		frozen_timer -= delta
		moving = false
		return
	moving = not path.is_empty()
	if moving:
		var target: Vector2 = path[0]
		var to: Vector2 = target - position
		var dist := to.length()
		var speed: float = BASE_SPEED * speed_mult * (game.tile / 64.0)
		var step: float = minf(speed * delta, dist)
		if dist > 0.5:
			var dir := to / dist
			position += dir * step
			facing = dir.angle()
			_sprite.rotation = facing + PI / 2.0
		if dist <= maxf(speed * delta, 6.0):
			path.pop_front()
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = 0.3
			game.sfx.play("step")
