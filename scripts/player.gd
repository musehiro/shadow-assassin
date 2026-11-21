class_name Player
extends Node2D
## The shadow assassin. Follows a tap-to-move path; can hunt a guard.

const SPEED := 205.0

var game: ShadowGame
var path: Array = [] # world points to follow
var hunting: Guard = null
var facing := -PI / 2.0
var moving := false

var _sprite: Sprite2D
var _step_timer := 0.0


func setup(p_game: ShadowGame, start_tile: Vector2i) -> void:
	game = p_game
	position = game.tile_to_world(start_tile)
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://art/player.png")
	_sprite.scale = Vector2(0.62, 0.62)
	add_child(_sprite)


func set_path(points: Array) -> void:
	path = points.duplicate()
	# drop any point we are already standing on
	while not path.is_empty() and position.distance_to(path[0]) < 6.0:
		path.pop_front()


func stop() -> void:
	path.clear()
	hunting = null


func _process(delta: float) -> void:
	if game == null or game.state != ShadowGame.State.PLAYING:
		moving = false
		return
	moving = not path.is_empty()
	if moving:
		var target: Vector2 = path[0]
		var to: Vector2 = target - position
		var dist := to.length()
		var step: float = minf(SPEED * delta, dist)
		if dist > 0.5:
			var dir := to / dist
			position += dir * step
			facing = dir.angle()
			_sprite.rotation = facing + PI / 2.0
		if dist <= maxf(SPEED * delta, 6.0):
			path.pop_front()
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = 0.3
			game.sfx.play("step")
