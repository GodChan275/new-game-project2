extends Node
## Registers every input action at boot so the project file stays clean.

func _ready() -> void:
	_key("move_left", [KEY_A, KEY_LEFT])
	_key("move_right", [KEY_D, KEY_RIGHT])
	_key("move_up", [KEY_W, KEY_UP])
	_key("move_down", [KEY_S, KEY_DOWN])
	_key("sprint", [KEY_SHIFT])
	_key("interact", [KEY_E])
	_key("interact_alt", [KEY_SPACE])
	_key("use_equipment", [KEY_F])
	_key("inspect", [KEY_V])
	_key("skill", [KEY_Q])
	_key("inventory", [KEY_I, KEY_TAB])
	_key("radial", [KEY_R])
	_key("quests", [KEY_J])
	_key("map_toggle", [KEY_M])
	_key("pause", [KEY_ESCAPE])
	_key("slot_1", [KEY_1])
	_key("slot_2", [KEY_2])
	_key("slot_3", [KEY_3])
	_key("slot_4", [KEY_4])
	_key("slot_5", [KEY_5])
	_key("slot_6", [KEY_6])
	_mouse("attack", MOUSE_BUTTON_LEFT)


func _key(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)


func _mouse(action: String, button: int) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var e := InputEventMouseButton.new()
	e.button_index = button
	InputMap.action_add_event(action, e)
