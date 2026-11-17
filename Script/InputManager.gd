extends Node
## Unified gameplay input. Desktop reads the keyboard/mouse InputMap; Mobile
## reads the virtual joystick and tap buttons, so player code never branches on
## the platform itself.

var _move := Vector2.ZERO
var _touch_move := false
var _taps: Dictionary = {}


func set_move(v: Vector2) -> void:
	_move = v.limit_length(1.0)
	_touch_move = _move.length() > 0.01


func clear_move() -> void:
	_move = Vector2.ZERO
	_touch_move = false


## Analog in Mobile mode, normalised keyboard vector in PC mode.
func move_vector() -> Vector2:
	if Platform.mobile() and _touch_move:
		return _move * Platform.sensitivity
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func is_held(action: String) -> bool:
	return Input.is_action_pressed(action)


## Queue a virtual press; consumed exactly once by `was_pressed`.
func tap(action: String) -> void:
	_taps[action] = int(_taps.get(action, 0)) + 1


func was_pressed(action: String) -> bool:
	if Input.is_action_just_pressed(action):
		return true
	if int(_taps.get(action, 0)) > 0:
		_taps[action] = int(_taps[action]) - 1
		return true
	return false


func clear_taps() -> void:
	_taps.clear()
