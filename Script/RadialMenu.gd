extends CanvasLayer
## TOXEN radial quick-menu: six icon segments around a live centre readout.
##
## Everything is laid out in screen space and scaled from the shorter viewport
## edge, so the wheel stays centred and circular on 4:3, 16:9 and 21:9 displays.
## Hover is resolved from the pointer angle around the hub, which works for the
## mouse, touch and (through the arrow keys) gamepad-style navigation alike.

signal action(id: String)
signal closed

const SEGMENTS := 7
const ICON_DIR := "res://Assets/image/icon/"
const GOLD := Color("f2b84b")
const TEAL := Color("2f575a")
const BG := Color("101718")
const PANEL := Color("1b2526")
const TEXT := Color("e8e8df")
const MUTED := Color("8fa3a0")
const GLASS := Color(0.91, 0.91, 0.87, 0.82)

## id is handed to the HUD, name/desc feed the centre readout.
const ITEMS := [
	{"id": "inventory", "name": "INVENTORY", "desc": "ดูไอเทมทั้งหมดที่มี", "icon": "Inventory.png"},
	{"id": "quests", "name": "QUEST", "desc": "ดูภารกิจที่กำลังทำ", "icon": "Quest.png"},
	{"id": "equipment", "name": "EQUIPMENT", "desc": "ดูอุปกรณ์ที่ซื้อแล้ว", "icon": "Equipment.png"},
	{"id": "weapons", "name": "WEAPONS", "desc": "ดูอาวุธที่ซื้อแล้ว", "icon": "Weapons.png"},
	{"id": "settings", "name": "SETTING", "desc": "ปรับการตั้งค่าเกม", "icon": "Setting.png"},
	{"id": "menu", "name": "MAIN MENU", "desc": "กลับสู่เมนูหลัก", "icon": "Back to MainMenu.png"},
	{"id": "close", "name": "CLOSE", "desc": "กลับสู่เกม", "icon": "Close.png"},
]

## The provided icons are black silhouettes, so their alpha is recoloured per
## state instead of multiplying the (black) RGB values.
const ICON_SHADER := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.91, 0.91, 0.87, 1.0);
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(tint.rgb, tex.a * tint.a);
}
"""

var _canvas: Control
var _back: ColorRect
var _wheel: Control
var _icons: Array[TextureRect] = []
var _mats: Array[ShaderMaterial] = []
var _center_box: VBoxContainer
var _title: Label
var _desc: Label
var _foot: Label
var _confirm: Control
var _shader: Shader

var _center := Vector2.ZERO
var _inner := 46.0
var _outer := 104.0
var _hover := 0
var _open := false
var _busy := false
var _touch_index := -1
## Touch that opened the wheel: its release belongs to the toggle tap, so it is
## ignored instead of being read as a selection/dismiss.
var _ignore_touch := -1
## Touch-opened sessions ignore the mouse, because Godot also emulates mouse
## events from every touch and the two streams would fight over the wheel.
var _touch_mode := false
var _last_click_ms := 0


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_shader = Shader.new()
	_shader.code = ICON_SHADER
	_build()
	_layout()
	get_viewport().size_changed.connect(_layout)


# ---------------------------------------------------------------- build
func _build() -> void:
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.theme = UI.theme()
	add_child(_canvas)

	_back = ColorRect.new()
	_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	_back.color = Color(0.02, 0.04, 0.045, 0.0)
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_back)

	_wheel = Control.new()
	_wheel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wheel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_wheel)
	_wheel.draw.connect(_draw_wheel)

	for i in ITEMS.size():
		# Most icons are black silhouettes recoloured by the shader; the quest
		# journal already has its own pixel-art palette, so it keeps its colours
		# and only brightens on hover.
		var native := bool(ITEMS[i].get("native", false))
		var mat: ShaderMaterial = null
		if not native:
			mat = ShaderMaterial.new()
			mat.shader = _shader
			mat.set_shader_parameter("tint", GLASS)
		_mats.append(mat)

		var ic := TextureRect.new()
		ic.name = "Icon_" + String(ITEMS[i]["id"])
		if native:
			ic.texture = Art.tex(String(ITEMS[i]["icon"]))
		else:
			ic.texture = load(ICON_DIR + String(ITEMS[i]["icon"])) as Texture2D
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.material = mat
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_wheel.add_child(ic)
		_icons.append(ic)

	_center_box = VBoxContainer.new()
	_center_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_center_box.add_theme_constant_override("separation", 1)
	_center_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wheel.add_child(_center_box)

	_title = Label.new()
	_title.text = String(ITEMS[0]["name"])
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", UI.title_font)
	_title.add_theme_color_override("font_color", GOLD)
	_title.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.05, 0.95))
	_title.add_theme_constant_override("outline_size", 3)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_box.add_child(_title)

	_desc = Label.new()
	_desc.text = String(ITEMS[0]["desc"])
	_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.add_theme_color_override("font_color", TEXT)
	_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_box.add_child(_desc)

	_foot = Label.new()
	_foot.text = "ENTER · ยืนยัน      R / ESC · ปิด"
	_foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_foot.add_theme_font_size_override("font_size", 5)
	_foot.add_theme_color_override("font_color", MUTED)
	_foot.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_foot.add_theme_constant_override("outline_size", 2)
	_foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_foot)


func _layout() -> void:
	if _wheel == null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if vp.x <= 1.0:
		vp = Vector2(480, 270)
	_canvas.size = vp
	_center = (vp * 0.5).floor()
	var span := minf(vp.x, vp.y)
	_outer = clampf(span * 0.375, 64.0, 420.0)
	_inner = _outer * 0.44
	_wheel.pivot_offset = _center

	var icon_px := clampf(_outer * 0.27, 14.0, 66.0)
	for i in _icons.size():
		var a := -PI * 0.5 + TAU * float(i) / float(SEGMENTS)
		var p := _center + Vector2(cos(a), sin(a)) * (_inner + (_outer - _inner) * 0.55)
		var ic := _icons[i]
		ic.size = Vector2(icon_px, icon_px)
		ic.position = (p - Vector2(icon_px, icon_px) * 0.5).floor()
		ic.pivot_offset = Vector2(icon_px, icon_px) * 0.5

	var title_px := int(clampf(_inner * 0.225, 7.0, 22.0))
	_title.add_theme_font_size_override("font_size", title_px)
	var desc_px := int(clampf(_inner * 0.140, 5.0, 14.0))
	_desc.add_theme_font_size_override("font_size", desc_px)
	var box := Vector2(_inner * 1.62, _inner * 1.12)
	_center_box.size = box
	_center_box.position = (_center - box * 0.5 + Vector2(0, _inner * 0.10)).floor()
	_desc.custom_minimum_size = Vector2(_inner * 1.5, 0)

	_foot.size = Vector2(vp.x, 8)
	_foot.position = Vector2(0, floor(_center.y + _outer + 9.0))
	_wheel.queue_redraw()


# ---------------------------------------------------------------- drawing
func _seg_points(a0: float, a1: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 12
	for k in n + 1:
		var a := lerpf(a0, a1, float(k) / float(n))
		pts.append(_center + Vector2(cos(a), sin(a)) * _inner)
	for k in n + 1:
		var a := lerpf(a1, a0, float(k) / float(n))
		pts.append(_center + Vector2(cos(a), sin(a)) * _outer)
	return pts


func _draw_wheel() -> void:
	var c := _center
	var step := TAU / float(SEGMENTS)

	# ambient plate + thin outer frame
	_wheel.draw_circle(c, _outer + 10.0, Color(0.02, 0.04, 0.045, 0.52))
	_wheel.draw_arc(c, _outer + 10.0, 0.0, TAU, 72, Color(TEAL.r, TEAL.g, TEAL.b, 0.55), 1.0, false)

	# pixel tick marks on the segment borders
	for i in SEGMENTS:
		var a := -PI * 0.5 + step * (float(i) + 0.5)
		var dir := Vector2(cos(a), sin(a))
		_wheel.draw_line(c + dir * (_outer + 5.0), c + dir * (_outer + 11.0),
			Color(TEAL.r, TEAL.g, TEAL.b, 0.8), 1.0, false)

	for i in SEGMENTS:
		var hovered := i == _hover
		var a0 := -PI * 0.5 + step * float(i) - step * 0.5 + 0.035
		var a1 := -PI * 0.5 + step * float(i) + step * 0.5 - 0.035
		var pts := _seg_points(a0, a1)
		var fill := Color(PANEL.r, PANEL.g, PANEL.b, 0.86)
		if hovered:
			fill = Color(GOLD.r, GOLD.g, GOLD.b, 0.20)
		elif i % 2 == 1:
			fill = Color(PANEL.r * 0.86, PANEL.g * 0.86, PANEL.b * 0.86, 0.86)
		_wheel.draw_colored_polygon(pts, fill)
		var outline := pts.duplicate()
		outline.append(pts[0])
		_wheel.draw_polyline(outline, GOLD if hovered else Color(TEAL.r, TEAL.g, TEAL.b, 0.95), 1.0, false)
		if hovered:
			_wheel.draw_arc(c, _outer + 2.0, a0 + 0.05, a1 - 0.05, 18,
				Color(GOLD.r, GOLD.g, GOLD.b, 0.55), 2.0, false)
			_wheel.draw_arc(c, _outer + 6.0, a0 + 0.09, a1 - 0.09, 18,
				Color(GOLD.r, GOLD.g, GOLD.b, 0.20), 3.0, false)

	# hub
	_wheel.draw_circle(c, _inner * 0.94, Color(BG.r, BG.g, BG.b, 0.97))
	_wheel.draw_arc(c, _inner * 0.94, 0.0, TAU, 48, Color(TEAL.r, TEAL.g, TEAL.b, 0.95), 1.0, false)
	var ha := -PI * 0.5 + step * float(_hover)
	_wheel.draw_arc(c, _inner * 0.94 - 3.0, ha - step * 0.30, ha + step * 0.30, 16,
		Color(GOLD.r, GOLD.g, GOLD.b, 0.85), 1.0, false)

	# small pixel indicator above the readout
	var dy := c.y - _inner * 0.60
	for k in 3:
		var x := c.x + (float(k) - 1.0) * 5.0
		var col := GOLD if k == 1 else Color(TEAL.r, TEAL.g, TEAL.b, 0.9)
		_wheel.draw_rect(Rect2(Vector2(x - 1.0, dy - 1.0), Vector2(2, 2)), col)


# ---------------------------------------------------------------- selection
func _segment_at(p: Vector2) -> int:
	var v := p - _center
	var d := v.length()
	if d < _inner * 0.98 or d > _outer * 1.01:
		return -1
	var step := TAU / float(SEGMENTS)
	var a := v.angle() + PI * 0.5 + step * 0.5
	a = fmod(a, TAU)
	if a < 0.0:
		a += TAU
	return int(floor(a / step)) % SEGMENTS


func _set_hover(i: int) -> void:
	if i < 0 or i >= ITEMS.size():
		return
	var changed := i != _hover
	_hover = i
	_title.text = String(ITEMS[i]["name"])
	_desc.text = String(ITEMS[i]["desc"])
	for k in _icons.size():
		var on := k == i
		if _mats[k] != null:
			_mats[k].set_shader_parameter("tint", GOLD if on else GLASS)
		else:
			_icons[k].modulate = Color(1.22, 1.20, 1.12, 1.0) if on else Color(1, 1, 1, 0.95)
		var target := Vector2(1.18, 1.18) if on else Vector2.ONE
		if changed:
			var tw := create_tween()
			tw.tween_property(_icons[k], "scale", target, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			_icons[k].scale = target
	_wheel.queue_redraw()


func _process(_delta: float) -> void:
	if not _open or _busy or _confirm != null or _touch_mode:
		return
	var idx := _segment_at(_canvas.get_local_mouse_position())
	if idx >= 0 and idx != _hover:
		_set_hover(idx)


# ---------------------------------------------------------------- open / close
func is_open() -> bool:
	return _open


## `touch_id` is the finger that pressed the toggle button (-1 when opened by
## keyboard or mouse). See _input(): that finger's release must not dismiss.
func open(touch_id: int = -1) -> void:
	if _open:
		return
	_open = true
	_busy = false
	_touch_index = -1
	_ignore_touch = touch_id
	_touch_mode = touch_id >= 0
	visible = true
	_layout()
	_hover = 0
	_set_hover(0)
	_back.color.a = 0.0
	_wheel.modulate.a = 0.0
	_wheel.scale = Vector2(0.9, 0.9)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_back, "color:a", 0.66, 0.16)
	tw.tween_property(_wheel, "modulate:a", 1.0, 0.18)
	tw.tween_property(_wheel, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("click", 1.35, -18.0)


func close() -> void:
	if not _open:
		return
	_set_hover(_hover)
	_dismiss()


func _dismiss() -> void:
	if _busy or not _open:
		return
	await _hide_wheel()


func _hide_wheel() -> void:
	_open = false
	_busy = true
	_touch_index = -1
	_hide_confirm()
	Sfx.play("click", 0.9, -18.0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_back, "color:a", 0.0, 0.16)
	tw.tween_property(_wheel, "modulate:a", 0.0, 0.15)
	tw.tween_property(_wheel, "scale", Vector2(0.93, 0.93), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	visible = false
	_wheel.modulate.a = 1.0
	_wheel.scale = Vector2.ONE
	_busy = false
	closed.emit()


func _activate(i: int) -> void:
	if not _open or _busy or _confirm != null:
		return
	var now := Time.get_ticks_msec()
	if now - _last_click_ms < 120:
		return
	_last_click_ms = now
	_set_hover(i)
	Sfx.play("click", 1.15, -9.0)
	var ic := _icons[i]
	var tw := create_tween()
	tw.tween_property(ic, "scale", Vector2(0.84, 0.84), 0.06)
	tw.tween_property(ic, "scale", Vector2(1.18, 1.18), 0.08)
	tw.tween_callback(_commit.bind(i))


func _commit(i: int) -> void:
	var id := String(ITEMS[i]["id"])
	if id == "menu":
		_show_confirm()
		return
	if id == "quests":
		await _hide_wheel()
		_open_quests()
		return
	await _hide_wheel()
	action.emit(id)


## Reuses the quest book the HUD already owns (same scene, same Quests data);
## no second quest screen is created and the book pauses the game itself.
func _open_quests() -> void:
	var hud = GameManager.hud
	if hud == null or not is_instance_valid(hud) or not hud.has_method("open_quests"):
		return
	hud.call("open_quests")
	GameManager.set_paused(true)


# ---------------------------------------------------------------- confirm
func _show_confirm() -> void:
	if _confirm != null:
		return
	_confirm = Control.new()
	_confirm.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm.theme = UI.theme()
	_canvas.add_child(_confirm)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.03, 0.03, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm.add_child(dim)

	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(BG.r, BG.g, BG.b, 0.98)
	sb.border_color = GOLD
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 3
	box.add_theme_stylebox_override("panel", sb)
	_confirm.add_child(box)

	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 8)
	box.add_child(m)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	m.add_child(vb)

	var title := UI.label(vb, "กลับเมนูหลัก?", 9, GOLD)
	title.add_theme_font_override("font", UI.title_font)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var body := UI.label(vb, "เกมจะหยุดชั่วคราว\nกลับมาเล่นต่อได้จากเมนูหลัก", 6, TEXT)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	vb.add_child(row)
	var cancel := Button.new()
	cancel.text = "ยกเลิก"
	cancel.add_theme_font_size_override("font_size", 7)
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.add_theme_stylebox_override("normal", UI.btn_box(Color(PANEL.r, PANEL.g, PANEL.b, 0.98), TEAL))
	cancel.pressed.connect(_hide_confirm)
	row.add_child(cancel)
	var ok := Button.new()
	ok.text = "กลับเมนูหลัก"
	ok.add_theme_font_size_override("font_size", 7)
	ok.focus_mode = Control.FOCUS_NONE
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.add_theme_stylebox_override("normal", UI.btn_box(Color(0.20, 0.16, 0.09, 0.98), GOLD))
	ok.pressed.connect(_confirm_menu)
	row.add_child(ok)

	var box_size := Vector2(190, 86)
	box.size = box_size
	box.position = (_center - box_size * 0.5).floor()
	box.pivot_offset = box_size * 0.5
	box.scale = Vector2(0.94, 0.94)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(dim, "color:a", 0.6, 0.14)
	tw.tween_property(box, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("click", 1.2, -16.0)


func _hide_confirm() -> void:
	if _confirm == null:
		return
	_confirm.queue_free()
	_confirm = null


func _confirm_menu() -> void:
	Sfx.play("phase", 1.0, -12.0)
	visible = false
	_open = false
	_hide_confirm()
	GameManager.back_to_menu()


# ---------------------------------------------------------------- input
func _input(event: InputEvent) -> void:
	if not _open:
		return
	if _confirm != null:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("radial"):
			_hide_confirm()
			get_viewport().set_input_as_handled()
		return

	# On a touch-opened wheel every tap also arrives as an emulated mouse event;
	# only the touch stream may drive it, otherwise one tap acts twice.
	if _touch_mode and (event is InputEventMouseButton or event is InputEventMouseMotion):
		return
	if event is InputEventMouseMotion:
		var idx := _segment_at(_canvas.get_local_mouse_position())
		if idx >= 0:
			_set_hover(idx)
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var idx := _segment_at(_canvas.get_local_mouse_position())
			if idx >= 0:
				_activate(idx)
			else:
				_dismiss()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_dismiss()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		# The finger that tapped the toggle is still down when the wheel appears:
		# swallow its release (and any drag) instead of dismissing on it.
		if touch.index == _ignore_touch:
			if not touch.pressed:
				_ignore_touch = -1
			get_viewport().set_input_as_handled()
			return
		var p: Vector2 = _canvas.get_global_transform_with_canvas().affine_inverse() * touch.position
		if touch.pressed:
			_touch_index = touch.index
			var idx := _segment_at(p)
			if idx >= 0:
				_set_hover(idx)
		else:
			if touch.index == _touch_index:
				_touch_index = -1
				var idx := _segment_at(p)
				if idx >= 0:
					_activate(idx)
				# Releasing away from the wheel no longer dismisses: the toggle
				# button, Esc/R or the CLOSE segment are the only ways out.
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _ignore_touch:
			return
		var p: Vector2 = _canvas.get_global_transform_with_canvas().affine_inverse() * drag.position
		var idx := _segment_at(p)
		if idx >= 0:
			_set_hover(idx)
		return

	if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		_set_hover((_hover + 1) % SEGMENTS)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		_set_hover((_hover - 1 + SEGMENTS) % SEGMENTS)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_activate(_hover)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("radial"):
		_dismiss()
		get_viewport().set_input_as_handled()
