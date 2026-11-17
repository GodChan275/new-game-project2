extends Camera2D
## Smooth follow camera with mouse-wheel zoom, clamped to the playable map.

const ZOOM_MIN := 0.8
const ZOOM_MAX := 1.85
const ZOOM_STEP := 0.12
const FOLLOW_SPEED := 7.0
const ZOOM_SPEED := 9.0
const LOOK_AHEAD := Vector2(0, -6)

var target: Node2D = null
var _zoom_target := 1.0


func setup(t: Node2D, bounds: Vector2) -> void:
	target = t
	limit_left = 0
	limit_top = 0
	limit_right = int(bounds.x)
	limit_bottom = int(bounds.y)
	position_smoothing_enabled = false
	_zoom_target = 1.0
	zoom = Vector2.ONE
	if target != null and is_instance_valid(target):
		global_position = target.global_position + LOOK_AHEAD
	make_current()


func zoom_ratio() -> float:
	return clampf((zoom.x - ZOOM_MIN) / maxf(ZOOM_MAX - ZOOM_MIN, 0.001), 0.0, 1.0)


func _process(delta: float) -> void:
	if target != null and is_instance_valid(target):
		var goal: Vector2 = (target as Node2D).global_position + LOOK_AHEAD
		global_position = global_position.lerp(goal, clampf(FOLLOW_SPEED * delta, 0.0, 1.0))
	var z := clampf(ZOOM_SPEED * delta, 0.0, 1.0)
	zoom = zoom.lerp(Vector2(_zoom_target, _zoom_target), z)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	var hud: Node = GameManager.hud
	if hud != null and is_instance_valid(hud) and hud.has_method("ui_open") and hud.ui_open():
		return
	var b := (event as InputEventMouseButton).button_index
	if b == MOUSE_BUTTON_WHEEL_UP:
		_zoom_target = clampf(_zoom_target + ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
		get_viewport().set_input_as_handled()
	elif b == MOUSE_BUTTON_WHEEL_DOWN:
		_zoom_target = clampf(_zoom_target - ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
		get_viewport().set_input_as_handled()
