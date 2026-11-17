extends Node
## Pollution meter, toxic zone spreading and hazard bookkeeping.

signal changed(pct: float, level_name: String, level_index: int)
signal critical_outbreak()

const LEVELS := ["Clean Environment", "Moderate Pollution", "High Pollution Warning", "Toxic Outbreak"]
const LEVELS_TH := ["สิ่งแวดล้อมสะอาด", "มลพิษปานกลาง", "มลพิษสูง - เฝ้าระวัง", "พิษระบาด"]
const ZONE_SCENE := preload("res://ToxicZone.tscn")

var day: int = 1
var world: Node2D
var zones: Array = []
var pct: float = 0.0
var penalty: float = 0.0

var _spread_timer := 4.0
var _critical_armed := true


func reset() -> void:
	for z in zones.duplicate():
		if is_instance_valid(z):
			z.queue_free()
	zones.clear()
	penalty = 0.0
	pct = 0.0
	_spread_timer = 4.0
	_critical_armed = true
	changed.emit(0.0, LEVELS[0], 0)


func capacity() -> float:
	return 60.0 + float(day) * 12.0


func score() -> float:
	var s := 0.0
	for g in Garbage.items:
		if is_instance_valid(g):
			s += float(g.weight)
	for entry in Inventory.garbage:
		s += ItemDB.waste_weight(String(entry["id"])) * 0.55
	s += float(zones.size()) * 3.0
	s += penalty
	return s


func recalc() -> void:
	var cap := capacity()
	var next := clampf(score() / cap * 100.0, 0.0, 100.0)
	pct = next
	changed.emit(pct, level_name(), level_index())
	if pct >= 99.0 and _critical_armed:
		_critical_armed = false
		critical_outbreak.emit()
	elif pct < 92.0:
		_critical_armed = true


func level_index() -> int:
	if pct <= 30.0:
		return 0
	if pct <= 60.0:
		return 1
	if pct <= 80.0:
		return 2
	return 3


func level_name() -> String:
	return LEVELS[level_index()]


func level_name_th() -> String:
	return LEVELS_TH[level_index()]


func is_critical() -> bool:
	return pct >= 80.0


func add_penalty(amount: float) -> void:
	penalty = minf(40.0, penalty + amount)
	recalc()


func toxic_multiplier() -> float:
	var m := 1.0
	if Inventory.has_equipment("boots"):
		m *= 0.5
	if Inventory.has_equipment("mask"):
		m *= 0.65
	return m


func spawn_zone(pos: Vector2) -> Node2D:
	if world == null:
		return null
	var z: Node2D = ZONE_SCENE.instantiate()
	world.add_child(z)
	z.global_position = pos
	z.scale = Vector2.ONE * randf_range(0.7, 1.15)
	zones.append(z)
	recalc()
	return z


func remove_zone(z: Node2D) -> void:
	zones.erase(z)
	if is_instance_valid(z):
		z.queue_free()
	recalc()


func _process(delta: float) -> void:
	if penalty > 0.0:
		penalty = maxf(0.0, penalty - delta * 0.6)
	_spread_timer -= delta
	if _spread_timer <= 0.0:
		_spread_timer = 3.5
		_try_spread()
		recalc()


func _try_spread() -> void:
	var max_zones := 6
	if pct > 60.0:
		max_zones = 10
	if pct > 85.0:
		max_zones = 16
	if pct <= 45.0 or zones.size() >= max_zones:
		return
	var anchor: Vector2
	if not Garbage.items.is_empty():
		var pick = Garbage.items[randi() % Garbage.items.size()]
		if is_instance_valid(pick):
			anchor = pick.global_position
		else:
			return
	elif not zones.is_empty():
		anchor = (zones[randi() % zones.size()] as Node2D).global_position
	else:
		return
	var off := Vector2(randf_range(-40.0, 40.0), randf_range(-40.0, 40.0))
	spawn_zone(anchor + off)
