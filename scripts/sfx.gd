class_name Sfx
extends Node
## Sound-effect player (original sounds, generated as WAVs).
## Every sound is optional: a missing file is skipped silently, never a crash.
## The audio agent produces these in parallel; until then the game runs silent.

const SOUND_PATHS := {
	"click": "res://audio/click.wav",
	"coin": "res://audio/coin.wav",
	"gem": "res://audio/gem.wav",
	"poof": "res://audio/poof.wav",
	"alert": "res://audio/alert.wav",
	"caught": "res://audio/caught.wav",
	"win": "res://audio/win.wav",
	"step": "res://audio/step.wav",
	"kill": "res://audio/kill.wav",
	"shoot": "res://audio/shoot.wav",
	"cash": "res://audio/cash.wav",
	"multikill": "res://audio/multikill.wav",
	"lose": "res://audio/lose.wav",
	"hurt": "res://audio/hurt.wav",
	"explode": "res://audio/explode.wav",
	"freeze": "res://audio/freeze.wav",
}

const MUSIC_PATH := "res://audio/music_loop.wav"

var muted := false
var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _music_wanted := false


func _ready() -> void:
	for key in SOUND_PATHS.keys():
		var path: String = SOUND_PATHS[key]
		if ResourceLoader.exists(path):
			_streams[key] = load(path)
	for i in range(8):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = -14.0
	add_child(_music_player)
	_music_player.finished.connect(_on_music_finished)
	if ResourceLoader.exists(MUSIC_PATH):
		_music_player.stream = load(MUSIC_PATH)


func play(sound_name: String) -> void:
	if muted:
		return
	if not _streams.has(sound_name):
		return
	var stream: AudioStream = _streams[sound_name]
	if stream == null:
		return
	for p in _players:
		if not p.playing:
			p.stream = stream
			p.play()
			return
	_players[0].stream = stream
	_players[0].play()


func start_music() -> void:
	_music_wanted = true
	if muted or _music_player.stream == null:
		return
	if not _music_player.playing:
		_music_player.play()


func stop_music() -> void:
	_music_wanted = false
	if _music_player.playing:
		_music_player.stop()


func _on_music_finished() -> void:
	# Loop the track by replaying it (works for any WAV, no loop metadata needed).
	if _music_wanted and not muted and _music_player.stream != null:
		_music_player.play()
