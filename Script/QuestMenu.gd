extends Control
## Quest book: categories on the left, quest list in the middle, details and the
## reward button on the right. Opens over the game and pauses it.

signal closed()

const PANEL_SIZE := Vector2(444, 236)

var _cat := "daily"
var _selected := ""
var _panel: PanelContainer
var _list: VBoxContainer
var _scroll: ScrollContainer
var _cat_buttons: Dictionary = {}
var _title: Label
var _cat_label: Label
var _desc: Label
var _bar: Dictionary
var _prog: Label
var _reward: Label
var _status: Label
var _claim: Button
var _claim_all: Button
var _empty: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UI.hud_theme()
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.08, 0.06, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UI.paper_box(1.0, 2))
	_panel.custom_minimum_size = PANEL_SIZE
	_panel.size = PANEL_SIZE
	add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	_panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	margin.add_child(vb)

	# header
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	vb.add_child(head)
	UI.label(head, "สมุดภารกิจ", 12, UI.GREEN_DEEP)
	UI.label(head, "QUEST BOOK", 6, UI.INK_SOFT)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	_claim_all = Button.new()
	_claim_all.text = "รับรางวัลทั้งหมด"
	_claim_all.add_theme_font_size_override("font_size", 10)
	_claim_all.focus_mode = Control.FOCUS_NONE
	_claim_all.pressed.connect(_on_claim_all)
	head.add_child(_claim_all)
	var close := Button.new()
	close.text = "✕"
	close.add_theme_font_size_override("font_size", 10)
	close.custom_minimum_size = Vector2(16, 14)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(close_book)
	head.add_child(close)

	var rule := ColorRect.new()
	rule.color = Color(UI.PAPER_EDGE.r, UI.PAPER_EDGE.g, UI.PAPER_EDGE.b, 0.9)
	rule.custom_minimum_size = Vector2(0, 1)
	vb.add_child(rule)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 5)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(body)

	# categories
	var cats := VBoxContainer.new()
	cats.add_theme_constant_override("separation", 2)
	cats.custom_minimum_size = Vector2(96, 0)
	body.add_child(cats)
	for c in Quests.CATS:
		var b := Button.new()
		b.text = String(c["th"])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 10)
		b.custom_minimum_size = Vector2(96, 19)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.pressed.connect(_on_cat.bind(String(c["id"])))
		cats.add_child(b)
		_cat_buttons[String(c["id"])] = b
	var spc := Control.new()
	spc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cats.add_child(spc)
	UI.label(cats, "J หรือ ESC เพื่อปิด", 6, UI.INK_SOFT)

	# list
	var list_wrap := VBoxContainer.new()
	list_wrap.custom_minimum_size = Vector2(150, 0)
	body.add_child(list_wrap)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UI.well_box())
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_wrap.add_child(frame)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 1)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	_empty = UI.label(list_wrap, "", 6, UI.INK_SOFT)

	# details
	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 2)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(detail)

	_cat_label = UI.label(detail, "", 6, UI.GOLD_DEEP)
	_title = UI.label(detail, "", 9, UI.INK_BROWN)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.custom_minimum_size = Vector2(0, 16)
	_desc = UI.label(detail, "", 6, UI.INK_SOFT)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(0, 18)
	_desc.max_lines_visible = 3
	UI.label(detail, "ความคืบหน้า", 6, UI.INK_SOFT)
	_bar = UI.bar(detail, 6, UI.GREEN_MID)
	_bar["bg"].color = Color(UI.PAPER_EDGE_D.r, UI.PAPER_EDGE_D.g, UI.PAPER_EDGE_D.b, 0.35)
	_prog = UI.label(detail, "0/0", 7, UI.INK_BROWN)
	_reward = UI.label(detail, "", 7, UI.GOLD_DEEP)
	_status = UI.label(detail, "", 6, UI.INK_SOFT)
	var rule2 := ColorRect.new()
	rule2.color = Color(UI.PAPER_EDGE.r, UI.PAPER_EDGE.g, UI.PAPER_EDGE.b, 0.7)
	rule2.custom_minimum_size = Vector2(0, 1)
	detail.add_child(rule2)
	_claim = Button.new()
	_claim.text = "รับรางวัล"
	_claim.custom_minimum_size = Vector2(0, 20)
	_claim.add_theme_font_size_override("font_size", 10)
	_claim.focus_mode = Control.FOCUS_NONE
	_claim.pressed.connect(_on_claim)
	detail.add_child(_claim)

	resized.connect(_layout)
	Quests.missions_changed.connect(_refresh_all)


func _layout() -> void:
	if _panel == null:
		return
	_panel.size = PANEL_SIZE
	_panel.position = ((size - PANEL_SIZE) * 0.5).floor().max(Vector2.ZERO)


func open_book() -> void:
	visible = true
	_layout()
	_refresh_all()
	if _selected == "":
		var first: Array = Quests.lines(_cat)
		if not first.is_empty():
			_selected = String(first[0]["id"])
	_refresh_details()
	GameManager.set_paused(true)


func close_book() -> void:
	if not visible:
		return
	visible = false
	GameManager.set_paused(false)
	closed.emit()


func _on_cat(id: String) -> void:
	Sfx.play("click")
	_cat = id
	_selected = ""
	var first: Array = Quests.lines(_cat)
	if not first.is_empty():
		_selected = String(first[0]["id"])
	_refresh_all()


func _refresh_all() -> void:
	if not is_inside_tree() or _list == null:
		return
	for c in _cat_buttons.keys():
		var b: Button = _cat_buttons[c]
		b.add_theme_color_override("font_color", UI.GREEN_DEEP if String(c) == _cat else UI.INK_BROWN)
	for ch in _list.get_children():
		ch.queue_free()
	var list: Array = Quests.lines(_cat)
	_empty.text = "ไม่มีภารกิจในหมวดนี้" if list.is_empty() else ""
	for q in list:
		_list.add_child(_row(q))
	_claim_all.disabled = Quests.pending_rewards() == 0
	_refresh_details()


func _row(q: Dictionary) -> Button:
	var done := bool(q["done"])
	var b := Button.new()
	b.text = "%s %s" % ["✓" if done else "□", String(q["th"])]
	b.tooltip_text = "%d/%d" % [int(q["progress"]), int(q["target"])]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 15)
	b.custom_minimum_size = Vector2(146, 26)
	b.focus_mode = Control.FOCUS_NONE
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_color_override("font_color", UI.INK_SOFT if done else UI.INK_BROWN)
	if String(q["id"]) == _selected:
		b.add_theme_stylebox_override("normal", UI.btn_box(Color(0.86, 0.94, 0.80), UI.GREEN_DEEP))
	b.pressed.connect(_on_pick.bind(String(q["id"])))
	return b


func _on_pick(id: String) -> void:
	Sfx.play("click")
	_selected = id
	_refresh_all()


func _current() -> Dictionary:
	for q in Quests.missions:
		if String(q["id"]) == _selected:
			return q
	return {}


func _refresh_details() -> void:
	var q := _current()
	if q.is_empty():
		_title.text = "เลือกภารกิจ"
		_cat_label.text = ""
		_desc.text = ""
		_prog.text = ""
		_reward.text = ""
		_status.text = ""
		UI.set_ratio(_bar, 0.0)
		_claim.disabled = true
		return
	var done := bool(q["done"])
	var claimed := bool(q["claimed"])
	_cat_label.text = Quests.cat_th(String(q["cat"]))
	_cat_label.add_theme_color_override("font_color", Quests.cat_color(String(q["cat"])))
	_title.text = String(q["th"])
	_desc.text = _describe(String(q["kind"]))
	UI.set_ratio(_bar, float(q["progress"]) / maxf(float(q["target"]), 1.0))
	_bar["fill"].color = UI.GREEN_DEEP if done else UI.GREEN_MID
	_prog.text = "ความคืบหน้า %d/%d" % [int(q["progress"]), int(q["target"])]
	_reward.text = "รางวัล  %s  + %d XP" % [UI.money(int(q["reward"])), 20 if bool(q.get("auto", false)) else 35]
	_status.text = "✓ สำเร็จแล้ว" if done else "กำลังดำเนินการ"
	_status.add_theme_color_override("font_color", UI.GREEN_DEEP if done else UI.INK_SOFT)
	_claim.disabled = not done or claimed
	_claim.text = "รับรางวัลแล้ว" if claimed else ("รับรางวัล" if done else "ยังไม่สำเร็จ")


func _describe(kind: String) -> String:
	match kind:
		"collect", "collect_life":
			return "เก็บขยะที่กระจัดกระจายในพื้นที่ แล้วนำไปแยกที่ถังให้ถูกประเภท"
		"collect_recyclable":
			return "เก็บขวด กระป๋อง หรือกระดาษสะอาด เพื่อนำไปรีไซเคิล"
		"sort", "sort_recyclable", "sort_hazardous", "sort_general", "sort_organic":
			return "นำขยะไปทิ้งในถังที่ถูกต้องเพื่อรับเงินและลดมลพิษ"
		"sort_all":
			return "คัดแยกขยะให้ถูกประเภทให้ได้ตามเป้าหมายรวมของวันนี้"
		"wrong_sort":
			return "หลีกเลี่ยงการทิ้งผิดประเภท เพราะจะเพิ่มมลพิษและไม่ได้คะแนน"
		"kill", "kill_life":
			return "กำจัดผู้บุกรุกที่บุกเข้ามาในเขตปลอดภัย"
		"pollution":
			return "ลดระดับมลพิษโดยการเก็บขยะและทำความสะอาดคราบพิษ"
		"buy_tool":
			return "อัปเกรดอุปกรณ์ที่ร้านค้าเพื่อเก็บขยะได้ไวขึ้น"
		"clean":
			return "ใช้ถุงมือเก็บคราบพิษออกจากพื้นดิน"
		"survive":
			return "ป้องกันตัวเองจนกว่าศัตรูจะล่าถอย"
		"days_life":
			return "ผ่านแต่ละวันให้ครบตามเป้าหมาย"
	return "ทำภารกิจให้สำเร็จเพื่อรับรางวัล"


func _on_claim() -> void:
	var res := Quests.claim(_selected)
	if bool(res.get("ok", false)):
		Sfx.play("buy")
		_refresh_all()
		if GameManager.hud != null and is_instance_valid(GameManager.hud):
			GameManager.hud.toast("รับรางวัล %s" % UI.money(int(res["reward"])), UI.GOLD_DEEP)


func _on_claim_all() -> void:
	var total := Quests.claim_all()
	if total > 0:
		Sfx.play("buy")
		_refresh_all()
		if GameManager.hud != null and is_instance_valid(GameManager.hud):
			GameManager.hud.toast("รับรางวัลรวม %s" % UI.money(total), UI.GOLD_DEEP)
