extends Node
## Phase state machine: morning preparation, enemy invasion, game over, victory.

signal phase_changed(phase: int)
signal day_changed(day: int)
signal time_changed(left: float, total: float)
signal state_changed(state: String)

enum Phase { MORNING = 0, INVASION = 1, OVER = 2, VICTORY = 3 }

const TOTAL_DAYS := 7

var phase: int = Phase.MORNING
var day: int = 1
var time_left: float = 0.0
var total_time: float = 1.0
var running := false

var main: Node = null
var hud: Node = null
var player: Node = null
var map: Node = null

## Session / menu navigation state (the autoload survives scene changes).
var session_active := false
var resume_requested := false

var _spawn_queue := 0
var _spawn_timer := 0.0
var _spawn_interval := 2.5


func morning_duration() -> float:
	return maxf(50.0, 85.0 - float(day - 1) * 5.0)


func invasion_duration() -> float:
	return minf(80.0, 38.0 + float(day) * 4.0)


func start_new_game() -> void:
	session_active = true
	resume_requested = false
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Main.tscn")


## Continue: keeps day, money, gear and level, then restarts that morning.
func continue_game() -> void:
	if not session_active:
		start_new_game()
		return
	resume_requested = true
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Main.tscn")


func back_to_menu() -> void:
	get_tree().paused = false
	running = false
	Music.play_day()
	if hud != null and is_instance_valid(hud):
		hud.hide_overlays()
	get_tree().change_scene_to_file("res://GameEntry.tscn")


func start_game() -> void:
	session_active = true
	day = 1
	phase = Phase.MORNING
	Economy.reset()
	Inventory.reset()
	Garbage.reset()
	Combat.reset()
	Pollution.reset()
	Quests.reset()
	Pollution.day = day
	running = true
	begin_morning()


func begin_morning() -> void:
	phase = Phase.MORNING
	total_time = morning_duration()
	time_left = total_time
	Pollution.day = day
	Quests.start_day(day)
	Sorting.start_day(day)
	day_changed.emit(day)
	phase_changed.emit(phase)
	DayNight.apply_phase(phase)
	if main != null and main.has_method("on_morning_start"):
		main.on_morning_start(day)
	if hud != null and is_instance_valid(hud):
		hud.on_phase_changed(phase, day)
	state_changed.emit("morning")
	Pollution.recalc()


func begin_invasion() -> void:
	phase = Phase.INVASION
	total_time = invasion_duration()
	time_left = total_time
	_spawn_queue = 5 + day * 2
	_spawn_timer = 1.0
	_spawn_interval = maxf(0.9, 2.6 - float(day) * 0.18)
	phase_changed.emit(phase)
	DayNight.apply_phase(phase)
	Sfx.play("alarm")
	if hud != null and is_instance_valid(hud):
		hud.on_phase_changed(phase, day)
		hud.banner("การบุกรุก!", Color("e04a4a"))
	if main != null and main.has_method("on_invasion_start"):
		main.on_invasion_start(day)
	state_changed.emit("invasion")
	# The day's sorting window just ended: show the educational summary.
	if hud != null and is_instance_valid(hud) and hud.has_method("show_sorting_report"):
		hud.show_sorting_report()


func end_invasion() -> void:
	if main != null and main.has_method("clear_enemies"):
		main.clear_enemies(true)
	Quests.report("survive", 1)
	Sfx.play("phase")
	if day >= TOTAL_DAYS:
		victory()
		return
	day += 1
	if hud != null and is_instance_valid(hud):
		hud.toast("อรุณรุ่ง - วันที่ %d" % day, Color("8ad02a"))
	begin_morning()


func victory() -> void:
	phase = Phase.VICTORY
	running = false
	state_changed.emit("victory")
	if hud != null and is_instance_valid(hud):
		hud.show_victory()


func player_died() -> void:
	if phase == Phase.OVER or phase == Phase.VICTORY:
		return
	phase = Phase.OVER
	running = false
	Sfx.play("die")
	state_changed.emit("over")
	if hud != null and is_instance_valid(hud):
		hud.show_game_over()
	get_tree().paused = true


func respawn() -> void:
	get_tree().paused = false
	var loss := int(Economy.money * 0.25)
	Economy.add_money(-loss)
	phase = Phase.MORNING
	day = maxi(1, day)
	time_left = maxf(30.0, time_left)
	if player != null and is_instance_valid(player) and player.has_method("revive"):
		player.revive()
	Pollution.recalc()
	begin_morning()
	if hud != null and is_instance_valid(hud):
		hud.hide_overlays()
		hud.toast("เกิดใหม่ที่เขตปลอดภัย  (-฿%d)" % loss, Color("e8c832"))


func restart() -> void:
	get_tree().paused = false
	running = false
	if hud != null and is_instance_valid(hud):
		hud.hide_overlays()
	get_tree().reload_current_scene()


func set_paused(paused: bool) -> void:
	get_tree().paused = paused


func is_morning() -> bool:
	return phase == Phase.MORNING


func is_invasion() -> bool:
	return phase == Phase.INVASION


func time_ratio() -> float:
	return clampf(time_left / maxf(total_time, 0.01), 0.0, 1.0)


func free_spot(center: Vector2, radius: float) -> Vector2:
	if main != null and main.has_method("find_free_spot"):
		return main.find_free_spot(center, radius)
	return center + Vector2(randf_range(-radius, radius), randf_range(-radius, radius))


func map_regions() -> Array:
	if map != null and is_instance_valid(map):
		return map.regions_centers()
	return []


func _process(delta: float) -> void:
	if not running:
		return
	if phase != Phase.MORNING and phase != Phase.INVASION:
		return
	time_left -= delta
	if phase == Phase.INVASION:
		_tick_spawns(delta)
	time_changed.emit(maxf(time_left, 0.0), total_time)
	if time_left <= 0.0:
		if phase == Phase.MORNING:
			begin_invasion()
		else:
			end_invasion()


func _tick_spawns(delta: float) -> void:
	if _spawn_queue <= 0:
		return
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	_spawn_timer = _spawn_interval
	var batch := 1
	if day >= 4 and randf() < 0.4:
		batch = 2
	for i in batch:
		if _spawn_queue <= 0:
			break
		_spawn_queue -= 1
		if main != null and main.has_method("spawn_invader"):
			main.spawn_invader(day)
