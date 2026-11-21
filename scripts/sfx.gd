class_name Sfx
extends Node
## Tiny synthesized sound-effect player (original sounds, generated as WAVs).

const SOUND_PATHS := {
	"click": "res://audio/click.wav",
	"coin": "res://audio/coin.wav",
	"gem": "res://audio/gem.wav",
	"poof": "res://audio/poof.wav",
	"alert": "res://audio/alert.wav",
	"caught": "res://audio/caught.wav",
	"win": "res://audio/win.wav",
	"step": "res://audio/step.wav",
}

var muted := false
var _streams := {}
var _players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	for key in SOUND_PATHS.keys():
		_streams[key] = load(SOUND_PATHS[key])
	for i in range(6):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func play(sound_name: String) -> void:
	if muted:
		return
	if not _streams.has(sound_name):
		return
	for p in _players:
		if not p.playing:
			p.stream = _streams[sound_name]
			p.play()
			return
	_players[0].stream = _streams[sound_name]
	_players[0].play()
