extends CanvasLayer
## Read-only loadout overview opened from the radial menu. It shows the weapons
## and equipment already owned in Inventory (bought from the existing shop) and
## lets the player swap the active weapon. No new item or economy system.

signal closed
signal equipped(label: String)

const PANEL_W := 326.0
const PANEL_H := 198.0
const GOLD := Color("f2b84b")
const TEAL := Color("2f575a")
const BG := Color("101718")
const PANEL := Color("1b2526")
const TEXT := Color("e8e8df")
const MUTED := Color("8fa3a0")

var _root: Control
var _panel: PanelContainer
var _title: Label
var _sub: Label
var _list: VBoxContainer
var _mode := "equipment"


func _ready() -> void:
	layer = 24
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
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
	_title = UI.title_label(head, "อุปกรณ์", 12, GOLD)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close := Button.new()
	close.text = "ปิด (ESC)"
	close.add_theme_font_size_override("font_size", 7)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(_on_close)
	head.add_child(close)

	_sub = UI.label(vb, "", 6, MUTED)
	UI.rule(vb, Color(TEAL.r, TEAL.g, TEAL.b, 0.7))

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 3)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_layout()


func _layout() -> void:
	if _panel == null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if vp.x <= 1.0:
		vp = Vector2(480, 270)
	var size := Vector2(minf(PANEL_W, vp.x - 14.0), minf(PANEL_H, vp.y - 14.0))
	_panel.size = size
	_panel.position = ((vp - size) * 0.5).floor()


## Shrinks the frame around short lists (weapons) and caps it when the full
## equipment list needs to scroll.
func _fit() -> void:
	if _panel == null or not visible:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if vp.x <= 1.0:
		vp = Vector2(480, 270)
	var need := _list.get_combined_minimum_size().y
	var size := Vector2(minf(PANEL_W, vp.x - 14.0),
		minf(clampf(need + 74.0, 96.0, PANEL_H), vp.y - 14.0))
	_panel.size = size
	_panel.position = ((vp - size) * 0.5).floor()


func open(mode: String) -> void:
	_mode = mode if mode in ["equipment", "weapons"] else "equipment"
	visible = true
	_layout()
	_refresh()
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


func _refresh() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()

	var weapons := _mode == "weapons"
	_title.text = "อาวุธ" if weapons else "อุปกรณ์"
	if weapons:
		var owned := 0
		for id in ItemDB.weapons.keys():
			if String(id) == "baton" or Inventory.owned.has(String(id)):
				owned += 1
		_sub.text = "ใช้งาน: %s   ·   มี %d/%d ชิ้น" % [
			String(ItemDB.weapons[Inventory.weapon]["name"]), owned, ItemDB.weapons.size()]
		for id in ItemDB.weapons.keys():
			_list.add_child(_weapon_row(String(id), ItemDB.weapons[id]))
	else:
		var owned := 0
		for id in ItemDB.equipment.keys():
			if Inventory.owned.has(String(id)):
				owned += 1
		_sub.text = "ซื้อจากร้านค้าแล้ว %d/%d ชิ้น   ·   กระเป๋า %d ช่อง" % [
			owned, ItemDB.equipment.size(), Inventory.capacity()]
		for id in ItemDB.equipment.keys():
			_list.add_child(_equipment_row(String(id), ItemDB.equipment[id]))
		if owned == 0:
			var empty := UI.label(_list, "ยังไม่มีอุปกรณ์ — ซื้อได้ที่ร้านค้าในเกม", 6, MUTED)
			empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fit.call_deferred()


func _weapon_row(id: String, d: Dictionary) -> Control:
	var owned := id == "baton" or Inventory.owned.has(id)
	var active := Inventory.weapon == id
	var right: Control
	if active:
		right = _chip("ใช้งานอยู่", GOLD)
	elif owned:
		var b := Button.new()
		b.text = "ติดตั้ง"
		b.add_theme_font_size_override("font_size", 6)
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(46, 0)
		b.pressed.connect(_equip.bind(id, String(d["name"])))
		right = b
	else:
		right = _chip("฿%d" % int(d["price"]), MUTED)
	var sub := "DMG %d · %.2fs · ระยะ %.0f" % [int(d["damage"]), float(d["cooldown"]), float(d["reach"])]
	if not owned:
		sub = "ยังไม่มี · %s" % String(d["desc"])
	var row := _row(String(d["icon"]), String(d["name"]), sub, owned, active, right)
	row.tooltip_text = String(d["desc"])
	return row


func _equipment_row(id: String, d: Dictionary) -> Control:
	var owned := Inventory.owned.has(id)
	var right: Control = _chip("มีแล้ว", GOLD) if owned else _chip("฿%d" % int(d["price"]), MUTED)
	var sub := String(d["stats"]) if owned else "ยังไม่มี · %s" % String(d["desc"])
	var row := _row(String(d["icon"]), String(d["name"]), sub, owned, false, right)
	row.tooltip_text = String(d["desc"])
	return row


func _row(icon: String, title: String, sub: String, owned: bool, active: bool, right: Control) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.20, 0.18, 0.10, 0.95) if active else Color(PANEL.r, PANEL.g, PANEL.b, 0.92)
	sb.border_color = GOLD if active else Color(TEAL.r, TEAL.g, TEAL.b, 0.9)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 4
	sb.content_margin_right = 5
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_STOP

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	p.add_child(h)

	var ic := TextureRect.new()
	ic.texture = Art.icon(icon)
	ic.custom_minimum_size = Vector2(18, 18)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.modulate = Color(1, 1, 1, 1) if owned else Color(0.55, 0.60, 0.60, 0.5)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(ic)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(vb)
	var name_label := UI.label(vb, title, 7, TEXT if owned else MUTED)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var sub_label := UI.label(vb, sub, 5, MUTED)
	sub_label.clip_text = true
	sub_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(right)
	return p


func _chip(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 6)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.custom_minimum_size = Vector2(46, 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _equip(id: String, label: String) -> void:
	Inventory.equip_weapon(id)
	Sfx.play("buy", 1.15, -18.0)
	equipped.emit(label)
	_refresh()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("radial"):
		_on_close()
		get_viewport().set_input_as_handled()
