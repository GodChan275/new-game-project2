extends CanvasLayer
## Game HUD. Layout follows the reference: player status (top-left), objective
## (top-right), missions/enemies (right), item info (bottom-left), action bar
## (bottom-centre), minimap + shortcuts (bottom-right). Panels are separate scenes;
## this script positions them, draws the minimap and owns the overlays.

const SHOP_SCENE := preload("res://Shop.tscn")
const INV_SCENE := preload("res://Inventory.tscn")
const STATUS_SCENE := preload("res://PlayerStatusPanel.tscn")
const OBJECTIVE_SCENE := preload("res://ObjectivePanel.tscn")
const QUEST_SCENE := preload("res://QuestPanel.tscn")
const BOOK_SCENE := preload("res://QuestMenu.tscn")
const ACTIONBAR_SCENE := preload("res://ActionBar.tscn")
const MOBILE_SCENE := preload("res://MobileControls.tscn")
const RADIAL_SCENE := preload("res://RadialMenu.tscn")
const LOADOUT_SCENE := preload("res://LoadoutPanel.tscn")
const SETTINGS_SCENE := preload("res://SettingsPanel.tscn")
const RADIAL_ICON := preload("res://Assets/image/icon/Radial.png")

var player: Node = null
var map: Node = null

var _root: Control
var _status: Control
var _objective: Control
var _quests: Control
var _book: Control
var _actionbar: Control
var _minimap_panel: PanelContainer
var _minimap: Control
var _ui_scale := 1.0
var _scale_btn: Button
var _mode_btn: Button
var _mobile := false
var _mobile_controls: Control
var _map_expanded := false
var _map_hidden := false
var _map_tw: Tween
var _map_before := true
var _idle := 0.0
var _buttons: HBoxContainer
var _prompt_panel: PanelContainer
var _prompt_label: Label
var _toast_box: VBoxContainer
var _banner: Label
var _banner_tw: Tween
var _scan: ColorRect

var _quest_pop: PanelContainer
var _qp_title: Label
var _qp_sub: Label
var _qp_name: Label
var _qp_tween: Tween

var _sort_panel: PanelContainer
var _sort_bin_label: Label
var _sort_bin: Node = null
var _sort_hint: Label
var _sort_item_icon: TextureRect
var _sort_item_name: Label
var _sort_item_en: Label
var _sort_item_count: Label
var _sort_bins: Array = []
var _sort_index := 0
var _sort_feedback: PanelContainer
var _sort_fb_title: Label
var _sort_fb_body: Label
var _sort_fb_retry: Button

var _info_panel: PanelContainer
var _info_icon: TextureRect
var _info_name: Label
var _info_en: Label
var _info_cat: Label
var _info_desc: Label
var _info_dispose: Label
var _info_meta: Label
var _info_id := ""
var _info_timer := 0.0

var _report_panel: PanelContainer
var _report_title: Label
var _report_body: Label

var _shop: CanvasLayer
var _inv: CanvasLayer
var _radial: CanvasLayer
var _loadout: CanvasLayer
var _settings: CanvasLayer
var _dim: ColorRect
var _pause_panel: PanelContainer
var _end_panel: PanelContainer
var _end_title: Label
var _end_stats: Label
var _end_respawn: Button

var _ui_mode := ""
var _prompt := ""
var _last_prompt := " "
var _map_t := 0.0
var _won := false


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_root.size = get_viewport().get_visible_rect().size
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UI.theme()
	add_child(_root)

	_mobile = Platform.mobile()
	_ui_scale = Platform.ui_scale
	_mobile_controls = MOBILE_SCENE.instantiate()
	_mobile_controls.visible = _mobile
	_root.add_child(_mobile_controls)
	Platform.mode_changed.connect(_on_mode_changed)
	Platform.settings_changed.connect(_on_settings_changed)

	_status = STATUS_SCENE.instantiate()
	_objective = OBJECTIVE_SCENE.instantiate()
	_quests = QUEST_SCENE.instantiate()
	_actionbar = ACTIONBAR_SCENE.instantiate()
	for c in [_status, _objective, _quests, _actionbar]:
		_root.add_child(c)

	_build_minimap()
	_build_buttons()
	_build_prompt()
	_build_toasts()
	_build_banner()
	_build_scanlines()
	_build_sorting()
	_book = BOOK_SCENE.instantiate()
	_root.add_child(_book)
	_book.closed.connect(_on_panel_closed)
	_build_pause()
	_build_end()
	_build_quest_pop()
	_build_info_panel()
	_build_report()
	Quests.quest_done.connect(_on_quest_done)

	_shop = SHOP_SCENE.instantiate()
	add_child(_shop)
	_shop.closed.connect(_on_panel_closed)
	_inv = INV_SCENE.instantiate()
	add_child(_inv)
	_inv.closed.connect(_on_panel_closed)
	_radial = RADIAL_SCENE.instantiate()
	add_child(_radial)
	_radial.connect("action", _on_radial_action)
	_radial.connect("closed", _on_radial_closed)
	_loadout = LOADOUT_SCENE.instantiate()
	add_child(_loadout)
	_loadout.connect("closed", _on_panel_closed)
	_loadout.connect("equipped", _on_equipped)
	_settings = SETTINGS_SCENE.instantiate()
	add_child(_settings)
	_settings.connect("closed", _on_panel_closed)

	Pollution.critical_outbreak.connect(_on_critical)
	_objective.connect("expanded_changed", _on_objective_expanded)
	get_viewport().size_changed.connect(_layout)
	_layout()


# ---------------------------------------------------------------- layout
func _layout() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if vp.x <= 1.0:
		vp = Vector2(480, 270)
	_root.scale = Vector2(_ui_scale, _ui_scale)
	_root.size = vp / _ui_scale
	var sz: Vector2 = _root.size

	var L: Dictionary = AdaptiveHUD.layout(_mobile, sz)
	_status.position = (L["status"] as Rect2).position
	_status.size = (L["status"] as Rect2).size
	_quests.position = (L["quests"] as Rect2).position
	_quests.size = (L["quests"] as Rect2).size
	_objective.position = (L["objective"] as Rect2).position
	_objective.size = (L["objective"] as Rect2).size

	_minimap_panel.position = _map_rect().position
	_minimap_panel.size = _map_rect().size

	var bw: float = _actionbar.custom_minimum_size.x
	_actionbar.position = Vector2((sz.x - bw) * 0.5, (L["hotbar"] as Rect2).position.y)
	_actionbar.size = Vector2(bw, 20)

	_prompt_panel.position = Vector2((sz.x - 168) * 0.5, AdaptiveHUD.prompt_y(_mobile, sz))
	_prompt_panel.size = Vector2(168, 16)
	_toast_box.position = (L["toasts"] as Rect2).position
	_toast_box.size = (L["toasts"] as Rect2).size
	_quest_pop.position = (L["quest_pop"] as Rect2).position
	_quest_pop.size = (L["quest_pop"] as Rect2).size
	_banner.position = (L["banner"] as Rect2).position
	_banner.size = (L["banner"] as Rect2).size

	_buttons.position = (L["buttons"] as Rect2).position
	_buttons.size = (L["buttons"] as Rect2).size
	_buttons.visible = not _mobile

	if _mobile_controls != null:
		_mobile_controls.position = Vector2.ZERO
		_mobile_controls.size = sz
		_mobile_controls.visible = _mobile
		_mobile_controls.call("layout", sz)

	_sort_panel.size = Vector2(minf(292.0, sz.x - 12.0), 212)
	_sort_panel.position = ((sz - _sort_panel.size) * 0.5).max(Vector2(4, 4))
	if _info_panel != null:
		var iw: float = minf(248.0, sz.x - 16.0)
		_info_panel.size = Vector2(iw, 120)
		_info_panel.position = Vector2((sz.x - iw) * 0.5, 84)
	if _report_panel != null:
		var rw: float = minf(286.0, sz.x - 16.0)
		_report_panel.size = Vector2(rw, 198)
		_report_panel.position = ((sz - _report_panel.size) * 0.5).max(Vector2(4, 4))
	_pause_panel.size = Vector2(232, 176)
	_pause_panel.position = (sz - _pause_panel.size) * 0.5
	_end_panel.size = Vector2(246, 168)
	_end_panel.position = (sz - _end_panel.size) * 0.5
	if _minimap != null:
		_minimap.queue_redraw()


func _on_objective_expanded(open: bool) -> void:
	if _map_hidden:
		return
	if open:
		_map_before = _minimap_panel.visible
		_minimap_panel.visible = false
	else:
		_minimap_panel.visible = _map_before


func _map_rect() -> Rect2:
	var sz: Vector2 = _root.size
	if _map_expanded:
		var m := minf(96.0, minf(sz.x - 8.0, sz.y - 40.0))
		return Rect2(Vector2(sz.x - m - 4.0, 94.0), Vector2(m, m))
	var ms := 30.0 if _mobile else 34.0
	return Rect2(Vector2(sz.x - ms - 4.0, 94.0), Vector2(ms, ms))


# ---------------------------------------------------------------- builders
func _build_minimap() -> void:
	_minimap_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.05, 0.62)
	sb.border_color = Color(0.95, 0.90, 0.78, 0.22)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	_minimap_panel.add_theme_stylebox_override("panel", sb)
	_minimap_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_minimap_panel.tooltip_text = "คลิกเพื่อขยายแผนที่"
	_root.add_child(_minimap_panel)
	_minimap_panel.gui_input.connect(_on_map_input)

	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_left", 2)
	m.add_theme_constant_override("margin_right", 2)
	m.add_theme_constant_override("margin_top", 2)
	m.add_theme_constant_override("margin_bottom", 2)
	_minimap_panel.add_child(m)

	_minimap = Control.new()
	_minimap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_minimap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap.draw.connect(_draw_minimap)
	m.add_child(_minimap)


func _build_buttons() -> void:
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 1)
	_root.add_child(_buttons)
	_buttons.add_child(_icon_button("icon_map", "แผนที่ · ซ่อน/แสดง (M)", toggle_minimap))
	_buttons.add_child(_icon_button("icon_bag", "กระเป๋า (I)", open_inventory))
	_buttons.add_child(_icon_button("radial", "เมนูวงล้อ (R)", toggle_radial, RADIAL_ICON))
	_buttons.add_child(_icon_button("icon_shop", "ร้านค้า (E ที่ร้าน)", _on_shop_button))
	_buttons.add_child(_icon_button("icon_pause", "หยุด · ตั้งค่า (ESC)", _toggle_pause))


func _icon_button(icon_name: String, hint: String, cb: Callable, direct: Texture2D = null) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(12, 13)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.tooltip_text = hint
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.05, 0.62)
	sb.border_color = Color(0.95, 0.90, 0.78, 0.20)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	p.add_theme_stylebox_override("panel", sb)
	var tex: Texture2D = direct if direct != null else Art.tex(icon_name)
	if tex != null:
		var ic := TextureRect.new()
		ic.texture = tex
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.position = Vector2(1, 1)
		ic.size = Vector2(10, 11)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(ic)
	p.mouse_entered.connect(func() -> void: sb.border_color = UI.GOLD)
	p.mouse_exited.connect(func() -> void: sb.border_color = Color(0.95, 0.90, 0.78, 0.20))
	p.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			cb.call())
	return p


func _build_prompt() -> void:
	_prompt_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.05, 0.80)
	sb.border_color = Color(0.95, 0.90, 0.78, 0.28)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	_prompt_panel.add_theme_stylebox_override("panel", sb)
	_prompt_panel.theme = UI.hud_theme()
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_panel.visible = false
	_prompt_panel.modulate.a = 0.0
	_root.add_child(_prompt_panel)
	_prompt_label = UI.label(_prompt_panel, "", 6, UI.CREAM)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_label.clip_text = true


func _build_toasts() -> void:
	_toast_box = VBoxContainer.new()
	_toast_box.alignment = BoxContainer.ALIGNMENT_END
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_box.add_theme_constant_override("separation", 1)
	_root.add_child(_toast_box)


func _build_banner() -> void:
	_banner = UI.title_label(_root, "", 18, UI.RED)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_banner.add_theme_constant_override("outline_size", 4)
	_banner.visible = false


func _build_scanlines() -> void:
	_scan = ColorRect.new()
	_scan.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scan.color = Color(0.55, 0.9, 0.1, 0.0)
	_scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_scan)


## Sorting panel: the carried waste is shown one piece at a time, the four bins
## are chosen explicitly, and the result is explained before the next piece.
func _build_sorting() -> void:
	_sort_panel = PanelContainer.new()
	_sort_panel.add_theme_stylebox_override("panel", UI.paper_box(0.99))
	_sort_panel.theme = UI.hud_theme()
	_sort_panel.visible = false
	_sort_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_sort_panel)

	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 6)
	_sort_panel.add_child(m)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	m.add_child(vb)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 3)
	vb.add_child(head)
	UI.label(head, "คัดแยกขยะ", 12, UI.GREEN_DEEP)
	UI.label(head, "SORTING", 6, UI.INK_SOFT)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	_sort_bin_label = UI.label(head, "", 7, UI.INK_BROWN)

	_sort_hint = UI.label(vb, "เลือกขยะ แล้วเลือกถังให้ถูกประเภท", 6, UI.INK_SOFT)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.well_box())
	vb.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	card.add_child(row)

	row.add_child(_arrow_button("◀", _cycle_sort_item.bind(-1)))
	_sort_item_icon = UI.icon(row, null, 26.0)
	_sort_item_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	_sort_item_name = UI.label(col, "", 10, UI.INK_BROWN)
	_sort_item_name.clip_text = true
	_sort_item_en = UI.label(col, "", 6, UI.INK_SOFT)
	_sort_item_en.clip_text = true
	_sort_item_count = UI.label(row, "", 7, UI.GOLD_DEEP)
	_sort_item_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_arrow_button("▶", _cycle_sort_item.bind(1)))

	var bins := GridContainer.new()
	bins.columns = 4
	bins.add_theme_constant_override("h_separation", 3)
	bins.add_theme_constant_override("v_separation", 2)
	vb.add_child(bins)
	_sort_bins.clear()
	for c in [ItemDB.Cat.GENERAL, ItemDB.Cat.ORGANIC, ItemDB.Cat.RECYCLABLE, ItemDB.Cat.HAZARDOUS]:
		var b := Button.new()
		b.custom_minimum_size = Vector2(64, 40)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.text = String(ItemDB.cat_short(c))
		b.icon = ItemDB.cat_icon(c)
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_constant_override("icon_max_width", 15)
		b.add_theme_font_size_override("font_size", 7)
		b.add_theme_color_override("font_color", UI.INK_BROWN)
		b.add_theme_color_override("font_hover_color", UI.GREEN_DEEP)
		b.add_theme_stylebox_override("normal", UI.btn_box(UI.PAPER_D, ItemDB.cat_color(c).darkened(0.2)))
		b.add_theme_stylebox_override("hover", UI.btn_box(Color("f7ecd2"), ItemDB.cat_color(c)))
		b.add_theme_stylebox_override("pressed", UI.btn_box(UI.PAPER_D, UI.GOLD_DEEP))
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = "ทิ้งลง%s" % String(ItemDB.cat_bin_thai(c))
		b.pressed.connect(_on_bin_choice.bind(c))
		bins.add_child(b)
		_sort_bins.append(b)

	_sort_feedback = PanelContainer.new()
	_sort_feedback.add_theme_stylebox_override("panel", UI.well_box())
	_sort_feedback.custom_minimum_size = Vector2(0, 66)
	vb.add_child(_sort_feedback)
	var fv := VBoxContainer.new()
	fv.add_theme_constant_override("separation", 1)
	_sort_feedback.add_child(fv)
	_sort_fb_title = UI.label(fv, "พร้อมคัดแยก", 8, UI.INK_BROWN)
	_sort_fb_body = UI.label(fv, "", 6, UI.INK_SOFT)
	_sort_fb_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sort_fb_body.max_lines_visible = 5
	_sort_fb_body.custom_minimum_size = Vector2(0, 38)
	var frow := HBoxContainer.new()
	frow.add_theme_constant_override("separation", 3)
	fv.add_child(frow)
	_sort_fb_retry = Button.new()
	_sort_fb_retry.text = "ลองอีกครั้ง"
	_sort_fb_retry.add_theme_font_size_override("font_size", 7)
	_sort_fb_retry.custom_minimum_size = Vector2(0, 15)
	_sort_fb_retry.focus_mode = Control.FOCUS_NONE
	_sort_fb_retry.visible = false
	_sort_fb_retry.pressed.connect(_on_retry)
	frow.add_child(_sort_fb_retry)
	var inspect := Button.new()
	inspect.text = "ข้อมูลขยะ"
	inspect.add_theme_font_size_override("font_size", 7)
	inspect.custom_minimum_size = Vector2(0, 15)
	inspect.focus_mode = Control.FOCUS_NONE
	inspect.pressed.connect(_on_sort_inspect)
	frow.add_child(inspect)

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 3)
	vb.add_child(foot)
	var bulk := Button.new()
	bulk.text = "F  คัดแยกทั้งหมดลงถังนี้"
	bulk.add_theme_font_size_override("font_size", 7)
	bulk.custom_minimum_size = Vector2(0, 16)
	bulk.focus_mode = Control.FOCUS_NONE
	bulk.pressed.connect(_on_bulk)
	foot.add_child(bulk)
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(sp2)
	var close := Button.new()
	close.text = "ปิด (ESC)"
	close.add_theme_font_size_override("font_size", 7)
	close.custom_minimum_size = Vector2(0, 16)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(_on_sort_close)
	foot.add_child(close)


func _arrow_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(16, 24)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 8)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func _build_pause() -> void:
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0, 0, 0, 0.7)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.visible = false
	_root.add_child(_dim)

	_pause_panel = PanelContainer.new()
	_pause_panel.add_theme_stylebox_override("panel", UI.dark_box(0.98))
	_pause_panel.visible = false
	_pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_pause_panel)

	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 8)
	_pause_panel.add_child(m)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	m.add_child(vb)

	var title := UI.title_label(vb, "หยุดชั่วคราว", 15, UI.GREEN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.label(vb, "WASD เดิน · คลิกซ้าย โจมตี · Q กวาดขยะ\nE เก็บ/ทิ้ง · F ใช้ไอเทม · I กระเป๋า", 6, UI.MUTED)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	vb.add_child(row)
	var resume := Button.new()
	resume.text = "เล่นต่อ"
	resume.add_theme_font_size_override("font_size", 8)
	resume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resume.focus_mode = Control.FOCUS_NONE
	resume.pressed.connect(_close_ui)
	row.add_child(resume)
	var restart := Button.new()
	restart.text = "เริ่มใหม่"
	restart.add_theme_font_size_override("font_size", 8)
	restart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restart.focus_mode = Control.FOCUS_NONE
	restart.pressed.connect(_on_restart)
	row.add_child(restart)

	_scale_btn = Button.new()
	_scale_btn.text = "ขนาด UI  " + Platform.ui_size_label()
	_scale_btn.add_theme_font_size_override("font_size", 8)
	_scale_btn.focus_mode = Control.FOCUS_NONE
	_scale_btn.pressed.connect(_cycle_ui_scale)
	vb.add_child(_scale_btn)

	_mode_btn = Button.new()
	_mode_btn.text = "โหมดควบคุม  " + Platform.mode_label()
	_mode_btn.add_theme_font_size_override("font_size", 8)
	_mode_btn.focus_mode = Control.FOCUS_NONE
	_mode_btn.pressed.connect(_cycle_control_mode)
	vb.add_child(_mode_btn)

	var menu := Button.new()
	menu.text = "กลับเมนูหลัก"
	menu.add_theme_font_size_override("font_size", 8)
	menu.focus_mode = Control.FOCUS_NONE
	menu.pressed.connect(_on_main_menu)
	vb.add_child(menu)


func _build_end() -> void:
	_end_panel = PanelContainer.new()
	_end_panel.add_theme_stylebox_override("panel", UI.dark_box(0.98))
	_end_panel.visible = false
	_end_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_end_panel)

	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 10)
	_end_panel.add_child(m)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	m.add_child(vb)

	_end_title = UI.title_label(vb, "", 15, UI.RED)
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_stats = UI.label(vb, "", 6, UI.CREAM)
	UI.rule(vb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	vb.add_child(row)
	_end_respawn = Button.new()
	_end_respawn.text = "เกิดใหม่"
	_end_respawn.add_theme_font_size_override("font_size", 7)
	_end_respawn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_end_respawn.focus_mode = Control.FOCUS_NONE
	_end_respawn.pressed.connect(_on_respawn)
	row.add_child(_end_respawn)
	var restart := Button.new()
	restart.text = "เริ่มใหม่"
	restart.add_theme_font_size_override("font_size", 7)
	restart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restart.focus_mode = Control.FOCUS_NONE
	restart.pressed.connect(_on_restart)
	row.add_child(restart)

	var menu := Button.new()
	menu.text = "กลับเมนูหลัก"
	menu.add_theme_font_size_override("font_size", 7)
	menu.focus_mode = Control.FOCUS_NONE
	menu.pressed.connect(_on_main_menu)
	vb.add_child(menu)


# ---------------------------------------------------------------- runtime
func bind(p: Node, m: Node) -> void:
	player = p
	map = m
	if _status != null and _status.has_method("bind"):
		_status.bind(p)
	if _actionbar != null and _actionbar.has_method("bind"):
		_actionbar.bind(p)
	_layout()


func ui_open() -> bool:
	return (_sort_panel.visible or _shop.visible or _inv.visible or _book.visible
		or _pause_panel.visible or _end_panel.visible or _ui_mode != ""
		or (_radial != null and bool(_radial.call("is_open")))
		or (_loadout != null and _loadout.visible) or (_settings != null and _settings.visible)
		or (_report_panel != null and _report_panel.visible))


func set_prompt(text: String) -> void:
	_prompt = text


func _process(delta: float) -> void:
	if _mobile and ui_open():
		InputHub.clear_move()
	if _info_timer > 0.0:
		_info_timer = maxf(0.0, _info_timer - delta)
		if _info_timer <= 0.0:
			hide_waste_info()
	var want_prompt := _prompt != "" and not ui_open()
	if _prompt != _last_prompt:
		_last_prompt = _prompt
		_prompt_label.text = _prompt
		var pw := clampf(_prompt_label.get_minimum_size().x + 12.0, 46.0, 216.0)
		_prompt_panel.size = Vector2(pw, 16)
		_prompt_panel.position = Vector2((_root.size.x - pw) * 0.5, AdaptiveHUD.prompt_y(_mobile, _root.size))
	var target_a := 1.0 if want_prompt else 0.0
	_prompt_panel.modulate.a = move_toward(_prompt_panel.modulate.a, target_a, delta * 9.0)
	_prompt_panel.visible = _prompt_panel.modulate.a > 0.02

	if Pollution.is_critical() and GameManager.is_invasion() and Platform.haze_enabled():
		_scan.color.a = 0.05 + 0.05 * sin(Time.get_ticks_msec() * 0.006)
	else:
		_scan.color.a = 0.0

	_map_t += delta
	if _map_t > 0.12 and _minimap != null:
		_map_t = 0.0
		_minimap.queue_redraw()

	# Secondary HUD recedes while the player explores; HP stays readable.
	var moving := false
	var low := false
	if player != null and is_instance_valid(player):
		var v = player.get("velocity")
		if v is Vector2:
			moving = v.length() > 3.0
		low = float(player.hp) <= float(player.max_hp) * 0.3
	_idle = 0.0 if (moving or _prompt != "" or GameManager.is_invasion()) else _idle + delta
	var dim := 0.5 if _idle > 5.0 else 1.0
	if low:
		dim = 1.0
	_quests.modulate.a = move_toward(_quests.modulate.a, dim, delta * 1.6)
	_objective.modulate.a = move_toward(_objective.modulate.a, dim, delta * 1.6)


func toast(text: String, color := Color.WHITE) -> void:
	if _toast_box == null or text == "":
		return
	var l := UI.label(_toast_box, text, 8, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	l.add_theme_constant_override("outline_size", 3)
	while _toast_box.get_child_count() > 5:
		var old := _toast_box.get_child(0)
		_toast_box.remove_child(old)
		old.queue_free()
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func() -> void:
		if is_instance_valid(l):
			l.queue_free())


func banner(text: String, color := Color.WHITE) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.modulate = Color(1, 1, 1, 1)
	_banner.visible = true
	if _banner_tw != null and _banner_tw.is_valid():
		_banner_tw.kill()
	_banner_tw = create_tween()
	_banner_tw.tween_interval(1.1)
	_banner_tw.tween_property(_banner, "modulate:a", 0.0, 0.8)
	_banner_tw.tween_callback(func() -> void: _banner.visible = false)


func on_phase_changed(_phase: int, _day: int) -> void:
	pass


func _build_quest_pop() -> void:
	_quest_pop = PanelContainer.new()
	_quest_pop.add_theme_stylebox_override("panel", UI.paper_box(0.98))
	_quest_pop.theme = UI.hud_theme()
	_quest_pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quest_pop.visible = false
	_quest_pop.modulate.a = 0.0
	_root.add_child(_quest_pop)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 5)
	m.add_theme_constant_override("margin_right", 5)
	m.add_theme_constant_override("margin_top", 2)
	m.add_theme_constant_override("margin_bottom", 2)
	_quest_pop.add_child(m)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	m.add_child(vb)
	_qp_title = UI.label(vb, "ภารกิจสำเร็จ!", 8, UI.GREEN_DEEP)
	_qp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_qp_sub = UI.label(vb, "", 6, UI.GOLD_DEEP)
	_qp_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_qp_name = UI.label(vb, "", 6, UI.INK_SOFT)
	_qp_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_qp_name.clip_text = true
	_qp_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


func _on_quest_done(q: Dictionary) -> void:
	var claimed := bool(q.get("claimed", false))
	var sub := "ได้รับเงินรางวัล %s" % UI.money(int(q["reward"])) if claimed else ("รางวัล %s · กด J เพื่อรับ" % UI.money(int(q["reward"])))
	_show_quest_pop("ภารกิจสำเร็จ!", sub, String(q["th"]))


func _show_quest_pop(title: String, sub: String, name: String) -> void:
	if _quest_pop == null:
		return
	_qp_title.text = title
	_qp_sub.text = sub
	_qp_name.text = name
	_qp_sub.add_theme_color_override("font_color", UI.GOLD_DEEP)
	_quest_pop.visible = true
	_quest_pop.modulate.a = 0.0
	var y: float = _quest_pop.position.y
	_quest_pop.position.y = y - 6.0
	if _qp_tween != null and _qp_tween.is_valid():
		_qp_tween.kill()
	_qp_tween = create_tween()
	_qp_tween.set_parallel(true)
	_qp_tween.tween_property(_quest_pop, "modulate:a", 1.0, 0.22)
	_qp_tween.tween_property(_quest_pop, "position:y", y, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_qp_tween.set_parallel(false)
	_qp_tween.tween_interval(2.4)
	_qp_tween.tween_property(_quest_pop, "modulate:a", 0.0, 0.5)
	_qp_tween.tween_callback(func() -> void:
		if is_instance_valid(_quest_pop):
			_quest_pop.visible = false)


func _on_critical() -> void:
	banner("พิษระบาด!", Color("8ad02a"))
	Sfx.play("alarm")
	toast("มลพิษถึงขั้นวิกฤต - คราบพิษกำลังแพร่กระจาย", Color("8ad02a"))


# ---------------------------------------------------------------- minimap
func _draw_minimap() -> void:
	if map == null or not is_instance_valid(map):
		return
	var sz: Vector2 = _minimap.size
	if sz.x < 4.0:
		return
	_minimap.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.14, 0.22, 0.16))
	var ws: Vector2 = map.world_size
	var sc := Vector2(sz.x / ws.x, sz.y / ws.y)
	for r in map.region_info():
		var center: Vector2 = r["center"]
		var size: Vector2 = r["size"]
		var terrain := String(r["terrain"])
		var col := Color(0.28, 0.45, 0.26)
		match terrain:
			"concrete":
				col = Color(0.60, 0.56, 0.46)
			"dirt":
				col = Color(0.47, 0.37, 0.25)
			"water":
				col = Color(0.34, 0.64, 0.61)
			"mud":
				col = Color(0.40, 0.36, 0.24)
		if terrain == "water":
			_minimap.draw_circle(center * sc, maxf(size.x, size.y) * 0.42 * sc.x, col)
		else:
			_minimap.draw_rect(Rect2((center - size * 0.5) * sc, size * sc), col)
	for b in map.bins:
		if is_instance_valid(b):
			_minimap.draw_rect(Rect2(b.global_position * sc - Vector2(1, 1), Vector2(2, 2)), ItemDB.cat_color(b.bin_cat))
	_minimap.draw_rect(Rect2(map.shop_pos * sc - Vector2(2, 2), Vector2(4, 4)), Color("e8b93a"))
	_minimap.draw_rect(Rect2(map.station_pos * sc - Vector2(2, 2), Vector2(4, 4)), Color("6ec95a"))
	_minimap.draw_rect(Rect2(map.storage_pos * sc - Vector2(1, 1), Vector2(3, 3)), Color("b98a5e"))
	var shown := 0
	for g in Garbage.items:
		if shown >= 60:
			break
		if is_instance_valid(g):
			_minimap.draw_rect(Rect2(g.global_position * sc - Vector2(0.5, 0.5), Vector2(1, 1)), Color(0.62, 0.62, 0.56, 0.8))
			shown += 1
	for e in Combat.enemies:
		if is_instance_valid(e):
			_minimap.draw_rect(Rect2(e.global_position * sc - Vector2(1, 1), Vector2(2, 2)), Color("e04a4a"))
	for z in Pollution.zones:
		if is_instance_valid(z):
			_minimap.draw_circle(z.global_position * sc, 1.5, Color(0.55, 0.8, 0.15, 0.85))
	if player != null and is_instance_valid(player):
		var pp: Vector2 = player.global_position * sc
		_minimap.draw_rect(Rect2(pp - Vector2(2, 2), Vector2(4, 4)), Color.WHITE)
		_minimap.draw_rect(Rect2(pp - Vector2(2, 2), Vector2(4, 4)), Color("2c3a30"), false, 1.0)
	_minimap.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.88, 0.80, 0.62, 0.85), false, 1.0)


# ---------------------------------------------------------------- panels
func open_shop() -> void:
	if _ui_mode != "" or _shop == null:
		return
	_shop.open()
	GameManager.set_paused(true)


func open_inventory() -> void:
	if _ui_mode != "" or _inv == null:
		return
	_inv.open()
	GameManager.set_paused(true)


## `from_touch` is the finger that triggered the toggle (-1 for keyboard/mouse),
## so the wheel can ignore that same finger's release.
func toggle_radial(from_touch := -1) -> void:
	if _radial != null and bool(_radial.call("is_open")):
		_radial.call("close")
	else:
		open_radial(from_touch)


## Radial hub: the wheel itself lives in RadialMenu.tscn.
func open_radial(from_touch := -1) -> void:
	if _radial == null or bool(_radial.call("is_open")) or _ui_mode != "":
		return
	if _shop.visible or _inv.visible or (_book != null and _book.visible):
		return
	if _sort_panel.visible or _end_panel.visible or _pause_panel.visible:
		return
	if _loadout.visible or _settings.visible:
		return
	_radial.call("open", from_touch)
	GameManager.set_paused(true)


func _on_radial_action(id: String) -> void:
	match id:
		"inventory":
			_inv.open()
			GameManager.set_paused(true)
		"equipment":
			_open_loadout("equipment")
		"weapons":
			_open_loadout("weapons")
		"settings":
			_settings.call("open")
			GameManager.set_paused(true)


func _open_loadout(mode: String) -> void:
	if _loadout == null:
		return
	_loadout.call("open", mode)
	GameManager.set_paused(true)


func _on_equipped(label: String) -> void:
	toast("ติดตั้ง %s แล้ว" % label, Color("8ad02a"))


func _on_radial_closed() -> void:
	_on_panel_closed()


func _on_shop_button() -> void:
	if player == null or map == null or not is_instance_valid(player):
		return
	if map.shop_pos.distance_to(player.global_position) < 70.0:
		open_shop()
	else:
		toast("ต้องอยู่ใกล้ร้านค้า", Color("e8c832"))


func _on_panel_closed() -> void:
	if _shop.visible or _inv.visible or (_book != null and _book.visible):
		return
	if _loadout.visible or _settings.visible:
		return
	if _radial != null and bool(_radial.call("is_open")):
		return
	GameManager.set_paused(false)


func open_quests() -> void:
	if _book == null or not _book.has_method("open_book"):
		return
	_book.open_book()


func open_sorting(bin: Node) -> void:
	if _ui_mode != "" or bin == null:
		return
	hide_waste_info()
	_sort_bin = bin
	_sort_panel.visible = true
	_sort_index = 0
	var cat := int(bin.bin_cat)
	_sort_bin_label.text = "ถังที่ใช้: " + String(ItemDB.cat_bin_thai(cat))
	_sort_bin_label.add_theme_color_override("font_color", ItemDB.cat_color(cat).darkened(0.25))
	_clear_feedback()
	_layout()
	_refresh_sort_panel()
	GameManager.set_paused(true)


func _close_sorting() -> void:
	if not _sort_panel.visible:
		return
	_sort_panel.visible = false
	_sort_bin = null
	_on_panel_closed()


func _on_sort_close() -> void:
	Sfx.play("click")
	_close_sorting()


## Keeps the panel pointing at a valid carried item and updates the card.
func _refresh_sort_panel() -> void:
	if _sort_panel == null:
		return
	var n := Inventory.garbage.size()
	if n == 0:
		_sort_index = 0
		_sort_item_icon.texture = null
		_sort_item_name.text = "กระเป๋าว่าง"
		_sort_item_en.text = "เก็บขยะก่อนแล้วกลับมาแยก"
		_sort_item_count.text = "0/0"
		_set_bins_enabled(false)
		return
	_sort_index = clampi(_sort_index, 0, n - 1)
	var id := String(Inventory.garbage[_sort_index]["id"])
	_sort_item_icon.texture = ItemDB.waste_icon(id)
	_sort_item_name.text = String(ItemDB.waste_def(id)["name"])
	_sort_item_en.text = ItemDB.waste_en(id)
	_sort_item_count.text = "%d/%d" % [_sort_index + 1, n]
	_set_bins_enabled(true)


func _set_bins_enabled(on: bool) -> void:
	for b in _sort_bins:
		(b as Button).disabled = not on


func _cycle_sort_item(step: int) -> void:
	if Inventory.garbage.size() <= 1:
		return
	_sort_index = wrapi(_sort_index + step, 0, Inventory.garbage.size())
	_clear_feedback()
	_refresh_sort_panel()
	Sfx.play("click", 1.2, -20.0)


## The player picks the bin; the selected waste decides whether it is correct.
func _on_bin_choice(cat: int) -> void:
	if Inventory.garbage.is_empty():
		return
	var res := Sorting.sort_one(_sort_index, cat)
	if bool(res.get("ok", false)):
		_show_good_sort(res)
	else:
		_show_bad_sort(res)
	_refresh_sort_panel()


func _show_good_sort(res: Dictionary) -> void:
	var pts := int(res.get("score", 0))
	var cash := int(res.get("reward", 0))
	_sort_fb_title.text = String(res.get("title", "คัดแยกถูกต้อง!"))
	_sort_fb_title.add_theme_color_override("font_color", UI.GREEN_DEEP)
	_sort_fb_body.text = "%s → %s\n+%d คะแนน · +฿%d\n%s" % [
		String(res["item"]), String(res["bin_thai"]), pts, cash, String(res.get("disposal", "")),
	]
	_sort_fb_retry.visible = false
	banner("คัดแยกถูกต้อง! · Correct Sorting!", UI.GREEN)
	if _sort_bin != null and is_instance_valid(_sort_bin):
		Combat.floating("+%d คะแนน" % pts, _sort_bin.global_position + Vector2(0, -34), UI.GREEN, true)
		Combat.floating("+฿%d" % cash, _sort_bin.global_position + Vector2(0, -26), UI.GOLD)


func _show_bad_sort(res: Dictionary) -> void:
	_sort_fb_title.text = String(res.get("title", "คัดแยกผิด!"))
	_sort_fb_title.add_theme_color_override("font_color", UI.RED_DEEP)
	_sort_fb_body.text = "%s\n%s\nลองเลือกถังที่ถูกต้องอีกครั้ง" % [
		String(res.get("explanation", "")), String(res.get("why", "")),
	]
	_sort_fb_retry.visible = true
	banner("คัดแยกผิด! · Incorrect Sorting!", UI.RED)
	if _sort_bin != null and is_instance_valid(_sort_bin):
		Combat.floating("ผิดช่อง!", _sort_bin.global_position + Vector2(0, -30), UI.RED)


func _clear_feedback() -> void:
	if _sort_fb_title == null:
		return
	_sort_fb_title.text = "พร้อมคัดแยก"
	_sort_fb_title.add_theme_color_override("font_color", UI.INK_BROWN)
	_sort_fb_body.text = "ขยะแต่ละประเภทต้องลงถังให้ถูกสี เลือกถังด้านบนเพื่อทิ้ง"
	_sort_fb_retry.visible = false


func _on_retry() -> void:
	Sfx.play("click")
	_clear_feedback()
	_refresh_sort_panel()


func _on_sort_inspect() -> void:
	if Inventory.garbage.is_empty():
		return
	var id := String(Inventory.garbage[clampi(_sort_index, 0, Inventory.garbage.size() - 1)]["id"])
	show_waste_info(id)


func _on_bulk() -> void:
	if _sort_bin == null:
		return
	var res := Sorting.bulk(_sort_bin.bin_cat)
	var ok := bool(res.get("ok", false))
	toast(String(res["msg"]), UI.GREEN if ok else UI.GOLD)
	if ok:
		Combat.floating("+฿%d" % int(res.get("reward", 0)), _sort_bin.global_position + Vector2(0, -28), UI.GOLD, true)
		_sort_fb_title.text = "คัดแยกทั้งหมดแล้ว"
		_sort_fb_title.add_theme_color_override("font_color", UI.GREEN_DEEP)
		_sort_fb_body.text = String(res["msg"])
		_sort_fb_retry.visible = false
	_refresh_sort_panel()


# ---------------------------------------------------------------- waste info
## Cream paper panel: name, category, description, disposal instructions.
func _build_info_panel() -> void:
	_info_panel = PanelContainer.new()
	_info_panel.add_theme_stylebox_override("panel", UI.paper_box(0.99))
	_info_panel.theme = UI.hud_theme()
	_info_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_info_panel.visible = false
	_root.add_child(_info_panel)

	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 6)
	_info_panel.add_child(m)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	m.add_child(vb)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 3)
	vb.add_child(head)
	_info_icon = UI.icon(head, null, 15.0)
	UI.label(head, "ข้อมูลขยะ", 8, UI.GREEN_DEEP)
	UI.label(head, "WASTE INFO", 5, UI.INK_SOFT)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var close := Button.new()
	close.text = "✕"
	close.add_theme_font_size_override("font_size", 8)
	close.custom_minimum_size = Vector2(14, 12)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(hide_waste_info)
	head.add_child(close)

	_info_name = UI.label(vb, "", 12, UI.INK_BROWN)
	_info_en = UI.label(vb, "", 6, UI.INK_SOFT)
	_info_cat = UI.label(vb, "", 7, UI.INK_BROWN)
	UI.rule(vb, Color(UI.PAPER_EDGE.r, UI.PAPER_EDGE.g, UI.PAPER_EDGE.b, 0.8))
	_info_desc = UI.label(vb, "", 6, UI.INK_SOFT)
	_info_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_desc.max_lines_visible = 2
	_info_dispose = UI.label(vb, "", 6, UI.INK_BROWN)
	_info_dispose.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_dispose.max_lines_visible = 2
	_info_meta = UI.label(vb, "", 6, UI.GOLD_DEEP)


func show_waste_info(id: String) -> void:
	if _info_panel == null:
		return
	if _info_panel.visible and _info_id == id:
		hide_waste_info()
		return
	_info_id = id
	var cat := ItemDB.waste_cat(id)
	_info_icon.texture = ItemDB.cat_icon(cat)
	_info_name.text = String(ItemDB.waste_def(id)["name"])
	_info_en.text = ItemDB.waste_en(id)
	_info_cat.text = "ประเภท: %s · %s" % [ItemDB.cat_thai(cat), ItemDB.cat_name_en(cat)]
	_info_cat.add_theme_color_override("font_color", ItemDB.cat_color(cat).darkened(0.3))
	_info_desc.text = ItemDB.waste_desc(id)
	_info_dispose.text = "วิธีทิ้ง: " + ItemDB.waste_disposal(id)
	_info_meta.text = "คะแนน +%d · มูลค่า ~฿%d" % [ItemDB.waste_score(id), Sorting.reward_for(id)]
	_info_panel.visible = true
	_info_timer = 9.0
	_layout()
	Sfx.play("click", 1.25, -18.0)


func hide_waste_info() -> void:
	if _info_panel == null:
		return
	_info_panel.visible = false
	_info_id = ""
	_info_timer = 0.0


# ---------------------------------------------------------------- report
func _build_report() -> void:
	_report_panel = PanelContainer.new()
	_report_panel.add_theme_stylebox_override("panel", UI.paper_box(0.99))
	_report_panel.theme = UI.hud_theme()
	_report_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_report_panel.visible = false
	_root.add_child(_report_panel)

	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 8)
	_report_panel.add_child(m)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	m.add_child(vb)

	_report_title = UI.label(vb, "สรุปการคัดแยก", 12, UI.GREEN_DEEP)
	_report_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.rule(vb, Color(UI.PAPER_EDGE.r, UI.PAPER_EDGE.g, UI.PAPER_EDGE.b, 0.8))
	_report_body = UI.label(vb, "", 6, UI.INK_BROWN)
	_report_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.rule(vb, Color(UI.PAPER_EDGE.r, UI.PAPER_EDGE.g, UI.PAPER_EDGE.b, 0.8))
	var go := Button.new()
	go.text = "เล่นต่อ"
	go.add_theme_font_size_override("font_size", 9)
	go.custom_minimum_size = Vector2(0, 20)
	go.focus_mode = Control.FOCUS_NONE
	go.pressed.connect(close_sorting_report)
	vb.add_child(go)


## End-of-sorting summary: totals, accuracy and tips from the player's mistakes.
func show_sorting_report() -> void:
	if _report_panel == null:
		return
	if _sort_panel.visible:
		_sort_panel.visible = false
		_sort_bin = null
	hide_waste_info()
	var s: Dictionary = Sorting.summary()
	_report_title.text = "สรุปการคัดแยก · วันที่ %d" % int(s.get("day", GameManager.day))
	var tips: Array = s.get("tips", [])
	var tip_text := "✓ คัดแยกครบทุกชิ้น ไม่มีข้อผิดพลาด"
	if not tips.is_empty():
		tip_text = "คำแนะนำจากข้อผิดพลาด\n· " + "\n· ".join(PackedStringArray(tips))
	_report_body.text = "เก็บขยะทั้งหมด   %d ชิ้น\nคัดแยกถูกต้อง   %d ชิ้น\nคัดแยกผิด   %d ครั้ง\nคะแนนที่ได้   %d\nเงินที่ได้   ฿%d\nความแม่นยำ   %d%%\n\n%s" % [
		int(s.get("collected", 0)), int(s.get("correct", 0)), int(s.get("wrong", 0)),
		int(s.get("score", 0)), int(s.get("money", 0)), int(s.get("accuracy", 0)), tip_text,
	]
	_report_panel.visible = true
	_dim.visible = true
	_ui_mode = "report"
	_layout()
	GameManager.set_paused(true)
	Sfx.play("levelup", 1.05, -10.0)


func close_sorting_report() -> void:
	if _report_panel == null or not _report_panel.visible:
		return
	_report_panel.visible = false
	_dim.visible = false
	if _ui_mode == "report":
		_ui_mode = ""
	Sfx.play("click")
	GameManager.set_paused(false)


# ---------------------------------------------------------------- overlays
func _toggle_pause() -> void:
	if _ui_mode == "report":
		close_sorting_report()
		return
	if _ui_mode != "":
		_close_ui()
		return
	if _sort_panel.visible:
		_close_sorting()
		return
	_ui_mode = "pause"
	_pause_panel.visible = true
	_dim.visible = true
	GameManager.set_paused(true)


func _close_ui() -> void:
	_pause_panel.visible = false
	_dim.visible = false
	_ui_mode = ""
	GameManager.set_paused(false)


func show_game_over() -> void:
	_won = false
	_ui_mode = "over"
	_end_title.text = "คุณพ่ายแพ้"
	_end_title.add_theme_color_override("font_color", UI.RED)
	_end_stats.text = "ถึงวันที่ %d\nเงิน ฿%d\nมลพิษ %d%%\nภารกิจวันนี้ %d/%d\n\nเกิดใหม่จะเสียเงิน 25%%" % [
		GameManager.day, Economy.money, int(round(Pollution.pct)),
		Quests.completed_today(), Quests.missions.size(),
	]
	_end_respawn.visible = true
	_end_respawn.text = "เกิดใหม่ (-25%)"
	_end_panel.visible = true
	_dim.visible = true


func show_victory() -> void:
	_won = true
	_ui_mode = "victory"
	_end_title.text = "ดินแดนฟื้นคืน"
	_end_title.add_theme_color_override("font_color", UI.GREEN)
	_end_stats.text = "คุณรอดชีวิตครบ %d วัน\nเงินที่หาได้ ฿%d\nมลพิษสุดท้าย %d%%\nเลเวล %d\nภารกิจวันนี้ %d/%d" % [
		GameManager.TOTAL_DAYS, Economy.total_earned, int(round(Pollution.pct)),
		Economy.level, Quests.completed_today(), Quests.missions.size(),
	]
	_end_respawn.visible = false
	_end_panel.visible = true
	_dim.visible = true


func hide_overlays() -> void:
	_pause_panel.visible = false
	_end_panel.visible = false
	if _report_panel != null:
		_report_panel.visible = false
	_dim.visible = false
	_ui_mode = ""


func _on_respawn() -> void:
	Sfx.play("click")
	GameManager.respawn()


func _on_restart() -> void:
	Sfx.play("click")
	GameManager.restart()


func _on_main_menu() -> void:
	Sfx.play("click")
	GameManager.back_to_menu()


func _input(event: InputEvent) -> void:
	# The radial wheel, loadout and settings overlays own their own Esc handling.
	if _radial != null and bool(_radial.call("is_open")):
		return
	if (_loadout != null and _loadout.visible) or (_settings != null and _settings.visible):
		return
	if event.is_action_pressed("radial"):
		if _ui_mode == "over" or _ui_mode == "victory":
			return
		if _shop.visible:
			_shop.close()
		elif _inv.visible:
			_inv.close()
		elif _book.visible:
			_book.close_book()
		elif _sort_panel.visible:
			_close_sorting()
		elif _ui_mode == "pause":
			_close_ui()
		else:
			open_radial()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		if _ui_mode == "over" or _ui_mode == "victory":
			get_viewport().set_input_as_handled()
			return
		if _shop.visible:
			_shop.close()
		elif _inv.visible:
			_inv.close()
		elif _book.visible:
			_book.close_book()
		elif _sort_panel.visible:
			_close_sorting()
		elif _ui_mode == "report":
			close_sorting_report()
		elif _ui_mode == "pause":
			_close_ui()
		else:
			_toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quests"):
		if _ui_mode == "over" or _ui_mode == "victory":
			get_viewport().set_input_as_handled()
			return
		if _book.visible:
			_book.close_book()
		elif _shop.visible:
			_shop.close()
		elif _inv.visible:
			_inv.close()
		elif _sort_panel.visible:
			_close_sorting()
		else:
			open_quests()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory"):
		if _ui_mode == "over" or _ui_mode == "victory":
			return
		if _shop.visible:
			_shop.close()
		elif _inv.visible:
			_inv.close()
		elif _sort_panel.visible:
			_close_sorting()
		elif _ui_mode == "pause":
			_close_ui()
		else:
			open_inventory()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("map_toggle"):
		if _ui_mode != "over" and _ui_mode != "victory":
			toggle_minimap()
		get_viewport().set_input_as_handled()


func toggle_minimap() -> void:
	if _ui_mode == "over" or _ui_mode == "victory":
		return
	_map_hidden = not _map_hidden
	_minimap_panel.visible = true
	if _map_tw != null and _map_tw.is_valid():
		_map_tw.kill()
	_map_tw = create_tween()
	_map_tw.tween_property(_minimap_panel, "modulate:a", 0.0 if _map_hidden else 1.0, 0.16)
	if _map_hidden:
		_map_tw.tween_callback(func() -> void: _minimap_panel.visible = false)
	Sfx.play("click", 1.3, -22.0)


func _on_map_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_set_map_expanded(not _map_expanded)


func _set_map_expanded(expanded: bool) -> void:
	_map_expanded = expanded
	_minimap_panel.tooltip_text = "คลิกเพื่อย่อแผนที่" if expanded else "คลิกเพื่อขยายแผนที่"
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_minimap_panel, "position", _map_rect().position, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_minimap_panel, "size", _map_rect().size, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.set_parallel(false)
	tw.tween_callback(func() -> void: _minimap.queue_redraw())
	Sfx.play("click", 1.15, -20.0)


# ---------------------------------------------------------------- platform
func _on_mode_changed(mobile: bool) -> void:
	_mobile = mobile
	_buttons.visible = not mobile
	_actionbar.call("set_mobile", mobile)
	if _mobile_controls != null:
		_mobile_controls.call("release_all")
	if mobile:
		_map_expanded = false
		_map_hidden = false
	_refresh_mode_label()
	_layout()
	toast("โหมดควบคุม: %s" % Platform.mode_label(), Color("8ad02a"))


func _on_settings_changed() -> void:
	_ui_scale = Platform.ui_scale
	_refresh_scale_label()
	if _mobile_controls != null:
		_mobile_controls.call("refresh")
	_layout()


func _refresh_mode_label() -> void:
	if _mode_btn != null:
		_mode_btn.text = "โหมดควบคุม  " + Platform.mode_label()


func _refresh_scale_label() -> void:
	if _scale_btn != null:
		_scale_btn.text = "ขนาด UI  %s  %d%%" % [Platform.ui_size_label(), int(round(_ui_scale * 100.0))]


func _cycle_control_mode() -> void:
	Platform.cycle_mode()
	_refresh_mode_label()
	Sfx.play("click", 1.25, -18.0)


## Used by the touch overlay so a tap on the pause button behaves like Esc.
func toggle_pause() -> void:
	if _radial != null and bool(_radial.call("is_open")):
		_radial.call("close")
		return
	if _loadout != null and _loadout.visible:
		_loadout.call("close")
		return
	if _settings != null and _settings.visible:
		_settings.call("close")
		return
	if _shop.visible:
		_shop.close()
	elif _inv.visible:
		_inv.close()
	elif _book.visible:
		_book.close_book()
	elif _sort_panel.visible:
		_close_sorting()
	elif _ui_mode == "report":
		close_sorting_report()
	elif _ui_mode == "pause":
		_close_ui()
	else:
		_toggle_pause()


func _cycle_ui_scale() -> void:
	Platform.cycle_ui_size()
	_ui_scale = Platform.ui_scale
	_refresh_scale_label()
	_layout()
	Sfx.play("click", 1.3, -18.0)
