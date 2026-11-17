extends CanvasLayer
## In-game settings opened from the radial menu. Every control drives the same
## PlatformManager settings (and the same config keys) as the main menu, so
## there is one settings system with a second entry point.

signal closed

const PANEL_W := 252.0
const PANEL_H := 196.0
const CFG_PATH := "user://toxic_wasteland.cfg"
const GOLD := Color("f2b84b")
const TEAL := Color("2f575a")
const BG := Color("101718")
const TEXT := Color("e8e8df")
const MUTED := Color("8fa3a0")

var _root: Control
var _panel: PanelContainer
var _rows: VBoxContainer
var _volume_label: Label
var _volume := 80.0


func _ready() -> void:
	layer = 24
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_load_volume()
	_build()
	get_viewport().size_changed.connect(_layout)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = UI.theme()
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.04, 0.045, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(BG.r, BG.g, BG.b, 0.98)
	sb.border_color = Color(TEAL.r, TEAL.g, TEAL.b, 0.95)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 3
	_panel.add_theme_stylebox_override("panel", sb)
	_root.add_child(_panel)

	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 8)
	_panel.add_child(m)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	m.add_child(vb)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	vb.add_child(head)
	var title := UI.title_label(head, "ตั้งค่า", 12, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close := Button.new()
	close.text = "ปิด (ESC)"
	close.add_theme_font_size_override("font_size", 7)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(_on_close)
	head.add_child(close)

	UI.rule(vb, Color(TEAL.r, TEAL.g, TEAL.b, 0.7))

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)

	var vol_row := HBoxContainer.new()
	vol_row.add_theme_constant_override("separation", 4)
	_rows.add_child(vol_row)
	var vol_label := UI.label(vol_row, "เสียง", 6, TEXT)
	vol_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var down := _step_button("-")
	down.pressed.connect(_on_volume_step.bind(-10.0))
	vol_row.add_child(down)
	var value := UI.label(vol_row, "", 6, GOLD)
	value.custom_minimum_size = Vector2(28, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_volume_label = value
	var up := _step_button("+")
	up.pressed.connect(_on_volume_step.bind(10.0))
	vol_row.add_child(up)
	_refresh_volume()

	_rows.add_child(_cycle_button("โหมดหน้าต่าง", Platform.window_mode_label(), _on_window_mode))
	_rows.add_child(_cycle_button("ความละเอียด", Platform.resolution_label(), _on_resolution))
	_rows.add_child(_cycle_button("สเกลเรนเดอร์", Platform.render_scale_label(), _on_render_scale))
	_rows.add_child(_cycle_button("คุณภาพกราฟิก", Platform.quality_label(), _on_quality))
	_rows.add_child(_cycle_button("โหมดควบคุม", Platform.mode_label(), _on_control_mode))
	_rows.add_child(_cycle_button("ขนาด UI", Platform.ui_size_label(), _on_ui_size))
	_layout()


## Returns the button so the cycle handlers can refresh its value text.
func _cycle_button(label: String, value: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = "%s:  %s" % [label, value]
	b.add_theme_font_size_override("font_size", 7)
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 17)
	b.set_meta("label", label)
	b.pressed.connect(func() -> void:
		cb.call(b)
		Sfx.play("click", 1.2, -18.0))
	return b


func _layout() -> void:
	if _panel == null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if vp.x <= 1.0:
		vp = Vector2(480, 270)
	var size := Vector2(minf(PANEL_W, vp.x - 14.0), minf(PANEL_H, vp.y - 14.0))
	_panel.size = size
	_panel.position = ((vp - size) * 0.5).floor()


func open() -> void:
	visible = true
	_layout()
	_root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, 0.14)
	Sfx.play("click", 1.3, -18.0)


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _on_close() -> void:
	Sfx.play("click", 1.1, -16.0)
	close()


func _step_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 8)
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(22, 15)
	return b


func _on_volume_step(delta: float) -> void:
	_volume = clampf(_volume + delta, 0.0, 100.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(_volume, 1.0) / 100.0))
	Platform.write_setting("ui", "volume", _volume)
	_refresh_volume()
	Sfx.play("click", 1.25, -18.0)


func _refresh_volume() -> void:
	if _volume_label != null:
		_volume_label.text = "%d%%" % int(round(_volume))


func _load_volume() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) == OK:
		_volume = float(cfg.get_value("ui", "volume", 80.0))
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(_volume, 1.0) / 100.0))


func _set_text(b: Button, value: String) -> void:
	b.text = "%s:  %s" % [String(b.get_meta("label")), value]


func _on_window_mode(b: Button) -> void:
	Platform.cycle_window_mode()
	_set_text(b, Platform.window_mode_label())


func _on_resolution(b: Button) -> void:
	Platform.cycle_resolution()
	_set_text(b, Platform.resolution_label())


func _on_render_scale(b: Button) -> void:
	Platform.cycle_render_scale()
	_set_text(b, Platform.render_scale_label())


func _on_quality(b: Button) -> void:
	Platform.cycle_quality()
	_set_text(b, Platform.quality_label())


func _on_control_mode(b: Button) -> void:
	Platform.cycle_mode()
	_set_text(b, Platform.mode_label())


func _on_ui_size(b: Button) -> void:
	Platform.cycle_ui_size()
	_set_text(b, Platform.ui_size_label())


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("radial"):
		_on_close()
		get_viewport().set_input_as_handled()
