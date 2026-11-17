extends Node
## Small pooled SFX player.

const POOL := 10

var _players: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var _next := 0


func _ready() -> void:
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)


func play(sound: String, pitch: float = 1.0, volume_db: float = -6.0) -> void:
	if not _cache.has(sound):
		var path := "res://Assets/Sfx/%s.wav" % sound
		_cache[sound] = load(path) if ResourceLoader.exists(path) else null
	var stream: AudioStream = _cache[sound]
	if stream == null or _players.is_empty():
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()
