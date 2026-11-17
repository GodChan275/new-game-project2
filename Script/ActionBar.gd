extends Control
## Compact bottom-centre hotbar: icon-only slots with tiny key numbers,
## selected highlight and cooldown fills.

const SLOT := 20.0
const GAP := 1.0

const SLOTS := [
	{"id": "move", "th": "เดิน", "bind": "WASD", "icon": "icon_boots"},
	{"id": "attack", "th": "โจมตี", "bind": "คลิกซ้าย", "icon": "icon_baton"},
	{"id": "skill", "th": "สกิล", "bind": "Q", "icon": "icon_broom"},
	{"id": "item", "th": "ไอเทม", "bind": "F", "icon": "icon_medkit"},
	{"id": "collect", "th": "เก็บ", "bind": "E", "icon": "icon_grabber"},
	{"id": "interact", "th": "โต้ตอบ", "bind": "SPC", "icon": "icon_sortbox"},
]

var player: Node = null
var _slots: Array = []
var _selected := 0
var _hover := -1
var _mobile := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(SLOTS.size() * (SLOT + GAP) - GAP, SLOT)
	theme = UI.hud_theme()

	for i in SLOTS.size():
		_slots.append(_build_slot(i))
	set_mobile(Platform.mobile())
	_apply_selection()


func _build_slot(i: int) -> Dictionary:
	var def: Dictionary = SLOTS[i]
	var slot := Control.new()
	slot.position = Vector2(i * (SLOT + GAP), 0)
	slot.size = Vector2(SLOT, SLOT)
	slot.custom_minimum_size = Vector2(SLOT, SLOT)
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.tooltip_text = "%s · %s · ปุ่ม %d" % [String(def["th"]), String(def["bind"]), i + 1]
	slot.gui_input.connect(_on_slot_input.bind(i))
	slot.mouse_entered.connect(_on_hover.bind(i, true))
	slot.mouse_exited.connect(_on_hover.bind(i, false))
	add_child(slot)

	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_theme_stylebox_override("panel", _slot_sb(0))
	slot.add_child(bg)

	var icon := TextureRect.new()
	icon.texture = Art.tex(String(def["icon"]))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.position = Vector2(3.5, 3.0)
	icon.size = Vector2(13, 13)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon)

	var key := UI.label(slot, str(i + 1), 4, UI.CREAM)
	key.position = Vector2(SLOT - 7, SLOT - 7)
	key.size = Vector2(6, 6)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	key.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	key.add_theme_constant_override("outline_size", 2)
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var badge := UI.label(slot, "", 4, UI.GOLD)
	badge.position = Vector2(1, SLOT - 7)
	badge.size = Vector2(10, 6)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var cd := ColorRect.new()
	cd.color = Color(0.02, 0.04, 0.02, 0.62)
	cd.position = Vector2(1, 1)
	cd.size = Vector2(SLOT - 2, 0)
	cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(cd)

	return {"panel": slot, "bg": bg, "icon": icon, "cd": cd, "badge": badge, "key": key}


func bind(p: Node) -> void:
	player = p


func is_mobile() -> bool:
	return _mobile


## Mobile has no number keys, so the shortcut digits are hidden there.
func set_mobile(mobile: bool) -> void:
	_mobile = mobile
	for i in _slots.size():
		var key := _slots[i]["key"] as Label
		if key != null:
			key.visible = not mobile


func _on_slot_input(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_trigger(i)


func _on_hover(i: int, inside: bool) -> void:
	_hover = i if inside else -1
	_apply_selection()


func _trigger(i: int) -> void:
	_selected = i
	_apply_selection()
	if GameManager.hud != null and is_instance_valid(GameManager.hud) and GameManager.hud.ui_open():
		return
	var id := String(SLOTS[i]["id"])
	if player == null or not is_instance_valid(player):
		return
	if id == "move":
		Sfx.play("click", 1.4, -20.0)
		return
	player.action(id)


func _slot_sb(state: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.05, 0.55)
	sb.border_color = Color(0.95, 0.90, 0.78, 0.20)
	if state == 1:
		sb.bg_color = Color(0.10, 0.12, 0.08, 0.70)
		sb.border_color = Color(0.95, 0.90, 0.78, 0.55)
	elif state == 2:
		sb.bg_color = Color(0.14, 0.16, 0.09, 0.78)
		sb.border_color = UI.GOLD
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	return sb


func _apply_selection() -> void:
	for i in _slots.size():
		var s: Dictionary = _slots[i]
		var state := 0
		if i == _selected:
			state = 2
		elif i == _hover:
			state = 1
		(s["bg"] as Panel).add_theme_stylebox_override("panel", _slot_sb(state))


func _process(_delta: float) -> void:
	if _slots.is_empty():
		return
	var attack_remain := 0.0
	var skill_remain := 0.0
	if player != null and is_instance_valid(player):
		var w := Inventory.weapon_def()
		var total: float = maxf(float(w["cooldown"]), 0.01)
		attack_remain = clampf(float(player.attack_cd) / total, 0.0, 1.0)
		skill_remain = 1.0 - float(player.skill_ratio())
	_set_cd(1, attack_remain)
	_set_cd(2, skill_remain)
	if player != null and is_instance_valid(player):
		var med := Inventory.item_count("medkit")
		(_slots[3]["icon"] as TextureRect).modulate = Color(1, 1, 1, 1) if med > 0 else Color(1, 1, 1, 0.35)
		(_slots[3]["badge"] as Label).text = "×%d" % med if med > 1 else ""


func _set_cd(index: int, ratio: float) -> void:
	if index >= _slots.size():
		return
	var cd: ColorRect = _slots[index]["cd"]
	var h: float = (SLOT - 2.0) * clampf(ratio, 0.0, 1.0)
	cd.size = Vector2(SLOT - 2.0, h)
	cd.visible = h > 1.0


func _unhandled_input(event: InputEvent) -> void:
	for i in SLOTS.size():
		if event.is_action_pressed("slot_%d" % (i + 1)):
			_trigger(i)
			get_viewport().set_input_as_handled()
			return
