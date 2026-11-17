extends CanvasLayer
## Grid inventory: waste items grouped with counts, gear overview, details.

signal closed

var _root: Control
var _panel: Panel
var _grid: GridContainer
var _title: Label
var _cap_bar: ProgressBar
var _detail: Label
var _gear: Label
var _selected := ""


func _ready() -> void:
	layer = 22
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()
	Inventory.changed.connect(_on_inv_changed)


func _on_inv_changed() -> void:
	if visible:
		refresh()


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.theme = UI.theme()
	add_child(root)
	_root = root
	root.resized.connect(_layout)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	_panel = Panel.new()
	_panel.position = Vector2(40, 24)
	_panel.size = Vector2(400, 222)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.1, 0.97)
	sb.border_color = Color(0.45, 0.62, 0.4)
	sb.set_border_width_all(1)
	_panel.add_theme_stylebox_override("panel", sb)
	root.add_child(_panel)

	_title = Label.new()
	_title.position = Vector2(10, 6)
	_title.size = Vector2(250, 15)
	_title.add_theme_font_size_override("font_size", 13)
	_title.add_theme_color_override("font_color", Color("8ad02a"))
	_panel.add_child(_title)

	var capacity_lbl := Label.new()
	capacity_lbl.text = "ความจุกระเป๋า"
	capacity_lbl.position = Vector2(256, 10)
	capacity_lbl.add_theme_font_size_override("font_size", 8)
	capacity_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.7))
	_panel.add_child(capacity_lbl)

	_cap_bar = ProgressBar.new()
	_cap_bar.position = Vector2(258, 22)
	_cap_bar.size = Vector2(132, 6)
	_cap_bar.show_percentage = false
	_cap_bar.max_value = 100
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.13, 0.14, 0.16)
	bg.set_border_width_all(1)
	bg.border_color = Color(0, 0, 0, 0.8)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color("8ad02a")
	_cap_bar.add_theme_stylebox_override("background", bg)
	_cap_bar.add_theme_stylebox_override("fill", fg)
	_panel.add_child(_cap_bar)

	var grid_panel := Panel.new()
	grid_panel.position = Vector2(8, 32)
	grid_panel.size = Vector2(246, 158)
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = Color(0.1, 0.11, 0.13, 0.95)
	gsb.border_color = Color(0.22, 0.26, 0.28)
	gsb.set_border_width_all(1)
	grid_panel.add_theme_stylebox_override("panel", gsb)
	_panel.add_child(grid_panel)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(6, 6)
	scroll.size = Vector2(234, 146)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	grid_panel.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 2)
	_grid.add_theme_constant_override("v_separation", 2)
	scroll.add_child(_grid)

	_detail = Label.new()
	_detail.position = Vector2(262, 36)
	_detail.size = Vector2(132, 76)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_theme_font_size_override("font_size", 8)
	_detail.add_theme_color_override("font_color", Color(0.8, 0.83, 0.78))
	_panel.add_child(_detail)

	_gear = Label.new()
	_gear.position = Vector2(262, 116)
	_gear.size = Vector2(132, 64)
	_gear.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gear.add_theme_font_size_override("font_size", 8)
	_gear.add_theme_color_override("font_color", Color("8ab6e8"))
	_panel.add_child(_gear)

	var hint := Label.new()
	hint.text = "คลิกกองขยะเพื่อดูรายละเอียด · กด E ที่ถังเพื่อคัดแยก"
	hint.position = Vector2(8, 196)
	hint.size = Vector2(280, 12)
	hint.clip_text = true
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", Color(0.65, 0.7, 0.65))
	_panel.add_child(hint)

	var close := Button.new()
	close.text = "ปิด (I)"
	close.position = Vector2(326, 168)
	close.size = Vector2(66, 46)
	close.add_theme_font_size_override("font_size", 9)
	close.pressed.connect(_on_close)
	_panel.add_child(close)
	_layout()


## Keeps the fixed-size panel centred on non-16:9 windows and HD/4K displays.
func _layout() -> void:
	if _panel == null or _root == null:
		return
	var area: Vector2 = _root.size
	if area.x <= 1.0:
		area = Vector2(480, 270)
	_panel.position = ((area - _panel.size) * 0.5).floor().max(Vector2.ZERO)


func open() -> void:
	visible = true
	_selected = ""
	refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _on_close() -> void:
	Sfx.play("click")
	close()


func refresh() -> void:
	_title.text = "กระเป๋า   %d/%d" % [Inventory.count(), Inventory.capacity()]
	_cap_bar.value = clampf(float(Inventory.count()) / maxf(float(Inventory.capacity()), 1.0) * 100.0, 0.0, 100.0)
	for c in _grid.get_children():
		c.queue_free()

	var grouped := {}
	var order: Array = []
	for entry in Inventory.garbage:
		var id := String(entry["id"])
		if not grouped.has(id):
			grouped[id] = 0
			order.append(id)
		grouped[id] = int(grouped[id]) + 1
	if order.is_empty():
		var empty := Label.new()
		empty.text = "กระเป๋าว่าง — กด E เก็บขยะ"
		empty.add_theme_font_size_override("font_size", 8)
		empty.add_theme_color_override("font_color", Color(0.6, 0.65, 0.6))
		_grid.add_child(empty)
	for id in order:
		_grid.add_child(_slot(id, int(grouped[id])))

	var weapon_name := String(Inventory.weapon_def()["name"])
	var gear_lines := "\nอาวุธ\n%s\nอุปกรณ์ (%d)\n" % [weapon_name, Inventory.owned.size() - 1]
	var names: Array = []
	for id in Inventory.owned.keys():
		if String(id) == "baton":
			continue
		names.append(String(ItemDB.item_name(String(id))))
	if names.is_empty():
		gear_lines += "ยังไม่มี"
	else:
		gear_lines += ", ".join(names)
	_gear.text = gear_lines
	_detail.text = _detail_text()


## One stack: real item icon, real Thai item name and quantity.
func _slot(id: String, count: int) -> Control:
	var cell := Control.new()
	cell.custom_minimum_size = Vector2(76, 36)
	cell.size = Vector2(76, 36)
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	cell.tooltip_text = "%s ×%d" % [String(ItemDB.item_name(id)), count]

	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.16, 0.14, 0.95) if id != _selected else Color(0.2, 0.3, 0.2, 0.95)
	sb.border_color = Color("8ad02a") if id == _selected else Color(0.24, 0.28, 0.24)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	bg.add_theme_stylebox_override("panel", sb)
	cell.add_child(bg)

	var icon := TextureRect.new()
	icon.texture = ItemDB.waste_icon(id)
	icon.position = Vector2(2, 7)
	icon.size = Vector2(21, 21)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(icon)

	var nm := UI.label(cell, String(ItemDB.item_name(id)), 6, Color("e8e4d6"))
	nm.position = Vector2(25, 2)
	nm.size = Vector2(49, 24)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.max_lines_visible = 3
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var qty := UI.label(cell, "×%d" % count, 7, Color("f0c860"))
	qty.position = Vector2(25, 26)
	qty.size = Vector2(49, 9)
	qty.mouse_filter = Control.MOUSE_FILTER_IGNORE

	cell.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_on_slot(id))
	return cell


func _on_slot(id: String) -> void:
	_selected = id
	Sfx.play("click", 1.0, -14.0)
	_detail.text = _detail_text()
	refresh()


func _detail_text() -> String:
	if _selected == "":
		return "เลือกกองขยะเพื่อดูรายละเอียด"
	var def := ItemDB.waste_def(_selected)
	var cat := int(def["cat"])
	return "\n\n%s%s\nประเภท: %s\nมูลค่า: ~฿%d\nมลพิษ: %.1f" % [
		String(def["name"]), String(def["desc"]), ItemDB.cat_name(cat),
		Sorting.reward_for(_selected), float(def["weight"]),
	]
