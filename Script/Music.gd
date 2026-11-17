extends Node
## Background music: a calm day loop and a darker night loop.
## GameManager.phase_changed switches between them with a 2 s crossfade, and the
## autoload survives scene changes so the menu and the game share one session.

const DAY_TRACK := "res://Assets/Music/Day_Song.mp3"
const NIGHT_TRACK := "res://Assets/Music/Night_song.mp3"

const VOLUME_DB := -19.0
const SILENT_DB := -60.0
const CROSSFADE := 2.0

var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _muted := false
var _current_track := ""
var _fade: Tween
var _volume_tween: Tween
var _token := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Two players so the outgoing and incoming tracks can overlap.
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.name = "BGM%d" % i
		p.bus = "Master"
		p.volume_db = SILENT_DB
		add_child(p)
		_players.append(p)

	call_deferred("_bind_game")


func _bind_game() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm != null and not gm.is_connected("phase_changed", Callable(self, "_on_phase_changed")):
		gm.connect("phase_changed", Callable(self, "_on_phase_changed"))
	_on_phase_changed(gm.phase if gm != null else 0)


func _on_phase_changed(phase: int) -> void:
	# 0 = MORNING, 1 = INVASION; OVER / VICTORY keep whatever is playing.
	if phase == 1:
		play_night()
	elif phase == 0:
		play_day()


func _configure_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	elif stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamMP3:
		stream.loop = true
		stream.loop_offset = 0.0


func play_music(track_path: String) -> void:
	if _players.is_empty():
		return
	if track_path == _current_track and _players[_active].playing:
		return

	if not ResourceLoader.exists(track_path):
		push_warning("BGM not found: " + track_path)
		return

	var stream: AudioStream = load(track_path)
	if stream == null:
		push_warning("Unable to load BGM: " + track_path)
		return

	_configure_loop(stream)

	_active = 1 - _active
	var next := _players[_active]
	next.stream = stream
	next.volume_db = SILENT_DB
	next.play()
	_current_track = track_path

	_token += 1
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.set_parallel(true)
	for p in _players:
		var target := VOLUME_DB if (p == next and not _muted) else SILENT_DB
		_fade.tween_property(p, "volume_db", target, CROSSFADE)
	_fade.set_parallel(false)
	_fade.tween_callback(_silence_old.bind(_token))


func _silence_old(token: int) -> void:
	if token != _token:
		return
	for p in _players:
		if p != _players[_active]:
			p.stop()
			p.volume_db = SILENT_DB


func play_day() -> void:
	play_music(DAY_TRACK)


func play_night() -> void:
	play_music(NIGHT_TRACK)


func set_muted(muted: bool) -> void:
	_muted = muted
	if _players.is_empty():
		return
	if _volume_tween != null and _volume_tween.is_valid():
		_volume_tween.kill()
	_volume_tween = create_tween()
	_volume_tween.tween_property(
		_players[_active], "volume_db", SILENT_DB if muted else VOLUME_DB, 0.35
	)


func toggle() -> bool:
	set_muted(not _muted)
	return _muted


func is_muted() -> bool:
	return _muted


func is_playing() -> bool:
	return not _players.is_empty() and _players[_active].playing
