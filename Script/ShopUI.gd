extends CanvasLayer
## Shop interface (morning phase). Built in code for a crisp pixel UI.

signal closed

var _body: VBoxContainer
var _money_label: Label
var _shop: Control
var _panel: Panel
var _rows: Array = []


func _ready() -> void:
	layer = 21
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func _build() -> void:
	_shop = Control.new()
	_shop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop.mouse_filter = Control.MOUSE_FILTER_STOP
	_shop.theme = UI.theme()
	add_child(_shop)
	_shop.resized.connect(_layout)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shop.add_child(dim)

	var panel := Panel.new()
	_panel = panel
	panel.position = Vector2(24, 20)
	panel.size = Vector2(432, 230)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.1, 0.97)
	sb.border_color = Color(0.45, 0.62, 0.4)
	sb.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", sb)
	_shop.add_child(panel)

	var title := Label.new()
	title.text = "ร้านค้าอุปกรณ์"
	title.position = Vector2(10, 6)
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color("e8c832"))
	panel.add_child(title)

	_money_label = Label.new()
	_money_label.position = Vector2(250, 8)
	_money_label.size = Vector2(170, 14)
	_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_money_label.add_theme_font_size_override("font_size", 11)
	_money_label.add_theme_color_override("font_color", Color("8ad02a"))
	panel.add_child(_money_label)

	var hint := Label.new()
	hint.text = "อาวุธ เกราะ และอุปกรณ์เก็บขยะ · เปิดได้ในช่วงเช้า"
	hint.position = Vector2(10, 22)
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", Color(0.7, 0.75, 0.7))
	panel.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(8, 34)
	scroll.size = Vector2(416, 172)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	_body = VBoxContainer.new()
	_body.custom_minimum_size = Vector2(400, 0)
	_body.add_theme_constant_override("separation", 3)
	scroll.add_child(_body)

	var close := Button.new()
	close.text = "ปิด (ESC)"
	close.position = Vector2(150, 208)
	close.size = Vector2(120, 16)
	close.add_theme_font_size_override("font_size", 8)
	close.pressed.connect(_on_close)
	panel.add_child(close)
	_layout()


## Centres the shop panel and keeps it inside the visible area at any aspect.
func _layout() -> void:
	if _panel == null or _shop == null:
		return
	var area: Vector2 = _shop.size
	if area.x <= 1.0:
		area = Vector2(480, 270)
	_panel.position = ((area - _panel.size) * 0.5).floor().max(Vector2.ZERO)


func open() -> void:
	visible = true
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
	_money_label.text = "฿%d" % Economy.money
	for c in _body.get_children():
		c.queue_free()
	for entry in Shop.catalog():
		_body.add_child(_row(entry))


func _row(entry: Dictionary) -> Control:
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.13, 0.16, 0.9)
	sb.border_color = Color(0.24, 0.28, 0.3)
	sb.set_border_width_all(1)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	row.add_theme_stylebox_override("panel", sb)

	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	row.add_child(box)

	var icon := TextureRect.new()
	var ico_tex := Art.tex(String(entry["icon"]))
	if ico_tex == null:
		ico_tex = Art.icon(String(entry["icon"]))
	icon.texture = ico_tex
	icon.custom_minimum_size = Vector2(26, 26)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.add_child(icon)

	var info := VBoxContainer.new()
	info.custom_minimum_size = Vector2(250, 0)
	info.add_theme_constant_override("separation", 0)
	box.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = String(entry["name"])
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.add_theme_color_override("font_color", Color("f0eee6"))
	info.add_child(name_lbl)

	var desc := Label.new()
	desc.text = String(entry["desc"])
	desc.add_theme_font_size_override("font_size", 8)
	desc.add_theme_color_override("font_color", Color(0.72, 0.75, 0.7))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(250, 0)
	info.add_child(desc)

	var stat := Label.new()
	stat.text = String(entry["stats"])
	stat.add_theme_font_size_override("font_size", 8)
	stat.add_theme_color_override("font_color", Color("8ab6e8"))
	info.add_child(stat)

	var price := Label.new()
	price.text = "฿%d" % int(entry["price"])
	price.custom_minimum_size = Vector2(34, 0)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price.add_theme_font_size_override("font_size", 10)
	price.add_theme_color_override("font_color", Color("e8c832") if Economy.can_afford(int(entry["price"])) else Color("c0392b"))
	box.add_child(price)

	var buy := Button.new()
	buy.custom_minimum_size = Vector2(50, 22)
	buy.add_theme_font_size_override("font_size", 8)
	if bool(entry["owned"]):
		buy.text = "OWNED"
		buy.disabled = true
	elif String(entry["kind"]) == "consumable":
		buy.text = "BUY"
		buy.tooltip_text = "Buy another"
	else:
		buy.text = "BUY"
	buy.pressed.connect(_on_buy.bind(String(entry["id"])))
	box.add_child(buy)
	return row


func _on_buy(id: String) -> void:
	var res := Shop.buy(id)
	Sfx.play("click", 1.0, -10.0)
	if GameManager.hud != null and is_instance_valid(GameManager.hud):
		GameManager.hud.toast(String(res["msg"]), Color("8ad02a") if bool(res.get("ok", false)) else Color("e04a4a"))
	refresh()
