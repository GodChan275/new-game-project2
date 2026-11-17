extends Control
## Touch overlay for Mobile mode: an analog joystick in the lower-left and
## tap buttons in the lower-right. Input is hit-tested manually so multi-touch
## (move + attack at once) works in the browser and on device.

const DEADZONE := 0.16
const BUTTONS := [
	{"action": "attack", "icon": "icon_baton", "label": "", "r": 22.0},
	{"action": "interact", "icon": "icon_grabber", "label": "", "r": 17.0},
	{"action": "skill", "icon": "icon_broom", "label": "สกิล", "r": 12.0},
	{"action": "map_toggle", "icon": "icon_map", "label": "แผน", "r": 12.0},
	{"action": "inspect", "icon": "icon_quest", "label": "ตรวจ", "r": 12.0},
	{"action": "radial", "icon": "", "tex": "res://Assets/image/icon/Radial.png", "label": "Menu", "r": 12.0},
]

var _joy_center := Vector2(44, 222)
var _joy_radius := 30.0
var _joy_touch := -1
var _joy_vec := Vector2.ZERO

var _buttons: Array = []
var _touch_action: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in BUTTONS.size():
		_buttons.append(_make_button(BUTTONS[i]))
	layout(size)


func _make_button(def: Dictionary) -> Dictionary:
	var edge := maxf(float(def["r"]) * 2.0, 20.0)
	var p := Panel.new()
	p.size = Vector2(edge, edge)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.tooltip_text = String(def["action"])
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.09, 0.06, 0.60)
	sb.border_color = Color(0.95, 0.90, 0.78, 0.35)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(int(edge * 0.5))
	p.add_theme_stylebox_override("panel", sb)
	add_child(p)

	var label := String(def["label"])
	var icon := String(def["icon"])
	var t: Texture2D = null
	if def.has("tex"):
		t = load(String(def["tex"])) as Texture2D
	elif icon != "":
		t = Art.tex(icon)
	if t != null:
		var ic := TextureRect.new()
		ic.texture = t
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if label == "":
			ic.position = Vector2(edge * 0.2, edge * 0.2)
			ic.size = Vector2(edge * 0.6, edge * 0.6)
		else:
			ic.position = Vector2(edge * 0.24, edge * 0.1)
			ic.size = Vector2(edge * 0.52, edge * 0.52)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(ic)

	if label != "":
		var l := UI.label(p, label, 8, UI.CREAM)
		l.position = Vector2(0, edge - 3)
		l.size = Vector2(edge, 7)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.clip_text = true
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
		l.add_theme_constant_override("outline_size", 2)

	return {"action": String(def["action"]), "node": p, "rect": Rect2()}


func layout(sz: Vector2) -> void:
	size = sz
	_joy_radius = clampf(30.0 * Platform.joystick_scale, 19.0, 46.0)
	_joy_center = Vector2(14.0 + _joy_radius, sz.y - 16.0 - _joy_radius)

	var right := sz.x - 12.0
	var bottom := sz.y - 14.0
	var attack_r := clampf(22.0 * Platform.joystick_scale, 14.0, 30.0)
	var interact_r := clampf(17.0 * Platform.joystick_scale, 11.0, 24.0)
	var small_r := clampf(12.0 * Platform.joystick_scale, 9.0, 16.0)
	var attack_c := Vector2(right - attack_r, bottom - attack_r)
	var interact_c := Vector2(right - attack_r * 2.0 - interact_r - 2.0, bottom - interact_r)
	var row_y := bottom - maxf(attack_r, interact_r) * 2.0 - small_r * 2.0 - 6.0

	for i in _buttons.size():
		var b: Dictionary = _buttons[i]
		var p: Panel = b["node"]
		var r := small_r
		var c := Vector2.ZERO
		match String(b["action"]):
			"attack":
				r = attack_r
				c = attack_c
			"interact":
				r = interact_r
				c = interact_c
			"radial":
				r = small_r
				c = Vector2(14.0 + small_r, _joy_center.y - _joy_radius - small_r - 8.0)
			_:
				var col := float(i - 2)
				c = Vector2(right - small_r - col * (small_r * 2.0 + 4.0), row_y)
		p.size = Vector2(r * 2.0, r * 2.0)
		p.position = c - Vector2(r, r)
		p.pivot_offset = Vector2(r, r)
		p.modulate.a = Platform.button_opacity
		b["rect"] = Rect2(c - Vector2(r, r), Vector2(r * 2.0, r * 2.0))

	queue_redraw()


func refresh() -> void:
	layout(size)


func release_all() -> void:
	_joy_touch = -1
	_joy_vec = Vector2.ZERO
	_touch_action.clear()
	InputHub.clear_move()
	queue_redraw()


func _draw() -> void:
	draw_circle(_joy_center, _joy_radius, Color(0.05, 0.06, 0.05, 0.42))
	draw_arc(_joy_center, _joy_radius, 0.0, TAU, 28, Color(0.95, 0.90, 0.78, 0.30), 1.1, true)
	draw_circle(_joy_center, _joy_radius * 0.15, Color(0.95, 0.90, 0.78, 0.18))
	var knob := _joy_center + _joy_vec * _joy_radius
	draw_circle(knob, _joy_radius * 0.44, Color(0.82, 0.80, 0.66, 0.55))
	draw_arc(knob, _joy_radius * 0.44, 0.0, TAU, 20, Color(0.95, 0.90, 0.78, 0.5), 1.0, true)


# ---------------------------------------------------------------- touch input
func _input(event: InputEvent) -> void:
	if not visible:
		return
	# Godot emulates a mouse from every touch by default, so on a touch device the
	# same tap would be handled twice (once as touch, once as mouse). The touch
	# stream is authoritative here; the mouse path only serves desktop testing.
	if Platform.touch_available and (event is InputEventMouseButton or event is InputEventMouseMotion):
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_press(event.index, event.position)
		else:
			_release(event.index)
	elif event is InputEventScreenDrag:
		if event.index == _joy_touch:
			_steer(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press(-2, event.position)
		else:
			_release(-2)
	elif event is InputEventMouseMotion and _joy_touch == -2:
		_steer(event.position)


func _local_point(pos: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * pos


func _press(id: int, pos: Vector2) -> void:
	var p := _local_point(pos)
	if _joy_touch == -1 and p.distance_to(_joy_center) <= _joy_radius * 1.45:
		_joy_touch = id
		_steer(pos)
		get_viewport().set_input_as_handled()
		return

	var hud = GameManager.hud
	for b in _buttons:
		if not (b["rect"] as Rect2).has_point(p):
			continue
		var action := String(b["action"])
		var blocked: bool = hud != null and is_instance_valid(hud) and hud.ui_open() and action != "pause" and action != "radial"
		if blocked:
			return
		_touch_action[id] = action
		_flash(b)
		_trigger(action, id)
		get_viewport().set_input_as_handled()
		return


func _release(id: int) -> void:
	_touch_action.erase(id)
	if id == _joy_touch:
		_joy_touch = -1
		_joy_vec = Vector2.ZERO
		InputHub.clear_move()
		queue_redraw()


func _steer(pos: Vector2) -> void:
	var p := _local_point(pos)
	var v := (p - _joy_center) / maxf(_joy_radius, 1.0)
	if v.length() < DEADZONE:
		_joy_vec = Vector2.ZERO
	else:
		_joy_vec = v.limit_length(1.0)
	InputHub.set_move(_joy_vec)
	queue_redraw()


func _trigger(action: String, touch_id := -1) -> void:
	var hud = GameManager.hud
	match action:
		"inventory":
			if hud != null and is_instance_valid(hud):
				hud.open_inventory()
		"quests":
			if hud != null and is_instance_valid(hud):
				hud.open_quests()
		"map_toggle":
			if hud != null and is_instance_valid(hud):
				hud.toggle_minimap()
		"pause":
			if hud != null and is_instance_valid(hud):
				hud.toggle_pause()
		"radial":
			if hud != null and is_instance_valid(hud):
				hud.toggle_radial(touch_id if touch_id >= 0 else -1)
		_:
			InputHub.tap(action)


func _flash(b: Dictionary) -> void:
	var p: Panel = b["node"]
	p.modulate = Color(1.35, 1.3, 1.05, Platform.button_opacity)
	var tw := create_tween()
	tw.tween_property(p, "modulate", Color(1, 1, 1, Platform.button_opacity), 0.18)
