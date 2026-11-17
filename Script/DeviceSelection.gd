extends Control
## First-run platform chooser. Shows two parchment cards (PC / Mobile) with a
## recommendation based on what the device reports, then stores the choice so the
## screen is skipped on later launches.

signal chosen(mode: String)

const CARD_W := 196.0
const CARD_H := 172.0
const MODES := ["pc", "mobile"]

var _cards: Array = []
var _title: Label
var _sub: Label
var _thai: Label
var _recommend: Label
var _hint: Label
var _selected := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	resized.connect(_layout)
	_layout()
	_apply_selection()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("0b140e")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var glow := TextureRect.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([
		Color(0.35, 0.55, 0.3, 0.22),
		Color(0, 0, 0, 0)
	])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 8
	gt.height = 64
	glow.texture = gt
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)

	_title = UI.title_label(self, "CHOOSE YOUR PLATFORM", 15, UI.GOLD)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.03, 0.95))
	_title.add_theme_constant_override("outline_size", 4)

	_sub = UI.label(self, "Select how you want to explore the wasteland.", 6, Color("cfe3a8"))
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_thai = UI.label(self, "เลือกแพลตฟอร์มที่ต้องการเล่น", 6, Color("a9c48c"))
	_thai.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_recommend = UI.label(self, "", 5, UI.GOLD)
	_recommend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_recommend.text = "แนะนำ: %s" % (
		"MOBILE" if Platform.recommended == "mobile" else "PC / DESKTOP"
	)

	_cards.append(_make_card(0, "PC / DESKTOP", "Play with keyboard and mouse.", [
		"WASD - Move",
		"E - Interact",
		"I - Inventory",
		"M - Map",
		"ESC - Pause",
	], "pc"))

	_cards.append(_make_card(1, "MOBILE", "Play with touchscreen controls.", [
		"Virtual Joystick - Move",
		"Action Button - Interact",
		"Attack Button - Attack",
		"Inventory Button - Inventory",
		"Map Button - Map",
	], "mobile"))

	_hint = UI.label(self, "เปลี่ยนโหมดภายหลังได้ที่ ตั้งค่า › โหมดควบคุม  ·  แนะนำเล่นแนวนอน", 5, Color(0.72, 0.8, 0.68, 0.7))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _make_card(index: int, title: String, desc: String, lines: Array, kind: String) -> Dictionary:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_box(false))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(_on_card_input.bind(index))
	add_child(card)

	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 7)
	card.add_child(m)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	m.add_child(vb)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	vb.add_child(head)
	head.add_child(_device_icon(kind))
	var name_label := UI.title_label(head, title, 9, UI.PARCH_INK)
	name_label.clip_text = true

	var desc_label := UI.label(vb, desc, 5, UI.PARCH_INK)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	UI.rule(vb)

	var list := UI.label(vb, "\n".join(lines), 5, Color("4a4335"))
	list.custom_minimum_size = Vector2(0, 60)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)

	var sel := Button.new()
	sel.text = "SELECT"
	sel.add_theme_font_size_override("font_size", 7)
	sel.focus_mode = Control.FOCUS_NONE
	sel.pressed.connect(_choose.bind(index))
	vb.add_child(sel)

	return {"panel": card, "mode": MODES[index], "button": sel, "index": index}


func _device_icon(kind: String) -> Control:
	var c := TextureRect.new()
	c.texture = Art.tex("icon_keyboard" if kind == "pc" else "icon_phone")
	c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	c.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	c.custom_minimum_size = Vector2(22, 22)
	c.size = Vector2(22, 22)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _card_box(on: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.90, 0.85, 0.70, 0.97)
	sb.border_color = UI.GOLD if on else Color(0.35, 0.27, 0.16, 0.85)
	sb.set_border_width_all(2 if on else 1)
	sb.set_corner_radius_all(3)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 2
	return sb


func _layout() -> void:
	var sz := size
	if sz.x <= 1.0:
		sz = Vector2(480, 270)
	var glow := get_child(1) as TextureRect
	if glow != null:
		glow.position = Vector2.ZERO
		glow.size = Vector2(sz.x, sz.y * 0.6)
	_title.position = Vector2(0, 18)
	_title.size = Vector2(sz.x, 20)
	_sub.position = Vector2(0, 40)
	_sub.size = Vector2(sz.x, 9)
	_thai.position = Vector2(0, 50)
	_thai.size = Vector2(sz.x, 9)
	_recommend.position = Vector2(0, 62)
	_recommend.size = Vector2(sz.x, 8)

	var total := CARD_W * 2.0 + 12.0
	var x0 := (sz.x - total) * 0.5
	var y := 76.0
	for i in _cards.size():
		var card: PanelContainer = _cards[i]["panel"]
		card.position = Vector2(x0 + float(i) * (CARD_W + 12.0), y)
		card.size = Vector2(CARD_W, CARD_H)
		card.custom_minimum_size = Vector2(CARD_W, CARD_H)
		card.pivot_offset = Vector2(CARD_W, CARD_H) * 0.5
	_hint.position = Vector2(0, sz.y - 16)
	_hint.size = Vector2(sz.x, 9)


func _apply_selection() -> void:
	for i in _cards.size():
		var card: PanelContainer = _cards[i]["panel"]
		card.add_theme_stylebox_override("panel", _card_box(i == _selected))


func _select(index: int) -> void:
	var next := clampi(index, 0, _cards.size() - 1)
	if next == _selected:
		return
	_selected = next
	Sfx.play("click", 1.5, -22.0)
	_apply_selection()
	var card: PanelContainer = _cards[_selected]["panel"]
	card.scale = Vector2(1.03, 1.03)
	var tw := create_tween()
	tw.tween_property(card, "scale", Vector2.ONE, 0.16)


func _choose(index: int) -> void:
	var mode := String(_cards[clampi(index, 0, _cards.size() - 1)]["mode"])
	Platform.set_mode(mode)
	Sfx.play("click", 1.0, -10.0)
	chosen.emit(mode)


func _on_card_input(event: InputEvent, index: int) -> void:
	var pressed := false
	if event is InputEventMouseButton:
		pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		pressed = event.pressed
	if not pressed:
		return
	_select(index)
	_choose(index)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		_select(_selected - 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_select(_selected + 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_choose(_selected)
		get_viewport().set_input_as_handled()
