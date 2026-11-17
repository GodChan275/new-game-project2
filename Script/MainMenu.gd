extends Control
## Manga-poster title screen built from the MAIN art set: MAIN1 backdrop,
## TOXEN vertical logo and the word-art menu buttons (normal + hover art).

signal start_selected(mode: String)

const BG_TEX := preload("res://Assets/image/Main/MAIN1.png")
const LOGO_TEX := preload("res://Assets/image/Main/TOXEN.png")

const ITEMS := [
	{"id": "new", "en": "NEW GAME", "th": "เริ่มเกมใหม่", "art": "NEW GAME", "hover": "NEW GAMEH"},
	{"id": "continue", "en": "RETURN", "th": "เล่นต่อจากเซฟเดิม", "art": "RETURN", "hover": "RETURN copy"},
	{"id": "how", "en": "TUTORIALS", "th": "วิธีเล่น", "art": "TUTORIALS", "hover": "TUTORIALS"},
	{"id": "settings", "en": "SETTING", "th": "ตั้งค่า", "art": "SETTING", "hover": "SETTING copy"},
	{"id": "credits", "en": "CREDIT", "th": "เครดิต", "art": "CREDIT", "hover": "CREDIT copy"},
	{"id": "quit", "en": "QUIT", "th": "ออกจากเกม", "art": "QUIT", "hover": "QUIT copy"},
]

const CFG_PATH := "user://toxic_wasteland.cfg"
const ART_DIR := "res://Assets/image/Main/%s.png"
const DISPLAY_FONT := preload("res://Assets/Fonts/Silkscreen-Bold.ttf")

var _rng := RandomNumberGenerator.new()
var _t := 0.0

var _scene: Control
var _bg: TextureRect
var _halftone: TextureRect
var _logo: TextureRect
var _logo_base := Vector2.ZERO
var _logo_scale := Vector2.ONE
var _menu: VBoxContainer
var _buttons: Array[Button] = []
var _labels: Array[Label] = []
var _selected := 0
var _hint: Label
var _particles: Array = []
var _mouse := Vector2.ZERO

var _modal: PanelContainer
var _modal_box: VBoxContainer
var _volume := 80.0

var _art_cache: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.seed = 20261113
	_load_settings()

	_scene = Control.new()
	_scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scene)

	_build_backdrop()
	_build_logo()
	_build_halftone()
	_build_particles()
	_build_menu()
	_build_hint()
	_build_modal()

	resized.connect(_layout)
	_layout()
	_apply_selection()
	_play_intro()


func _art(name: String) -> Texture2D:
	if _art_cache.has(name):
		return _art_cache[name]
	var path := ART_DIR % name
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path) as Texture2D
	_art_cache[name] = t
	return t


# ---------------------------------------------------------------- backdrop
func _build_backdrop() -> void:
	_bg = TextureRect.new()
	_bg.texture = BG_TEX
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.modulate.a = 0.0
	_scene.add_child(_bg)


func _build_logo() -> void:
	_logo = TextureRect.new()
	_logo.texture = LOGO_TEX
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.modulate.a = 0.0
	_scene.add_child(_logo)


## Slow drifting halftone film over the whole poster.
func _build_halftone() -> void:
	_halftone = TextureRect.new()
	_halftone.texture = _halftone_tile()
	_halftone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_halftone.stretch_mode = TextureRect.STRETCH_TILE
	_halftone.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_halftone.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_halftone.modulate = Color(0.85, 1.0, 0.98, 0.07)
	_halftone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene.add_child(_halftone)


func _halftone_tile() -> ImageTexture:
	var s := 96
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var step := 7.0
	var y := 0.0
	while y < s:
		var x := 0.0
		while x < s:
			var r := 1.6 + 0.9 * sin(x * 0.21 + y * 0.17)
			var px := -r
			while px <= r:
				var py := -r
				while py <= r:
					var d := sqrt(px * px + py * py)
					var a := clampf((r - d) / 0.9, 0.0, 1.0)
					var ix := int(round(x + px))
					var iy := int(round(y + py))
					if a > 0.0 and ix >= 0 and iy >= 0 and ix < s and iy < s:
						img.set_pixel(ix, iy, Color(1, 1, 1, a))
					py += 1.0
				px += 1.0
			x += step
		y += step
	var tex := ImageTexture.create_from_image(img)
	return tex


func _build_particles() -> void:
	for i in 16:
		var p := TextureRect.new()
		p.texture = Art.tex("dot")
		p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		p.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var s := _rng.randf_range(1.2, 2.8)
		p.size = Vector2(s, s)
		p.modulate = Color(0.85, 0.98, 0.96, _rng.randf_range(0.15, 0.5))
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_scene.add_child(p)
		_particles.append({
			"node": p,
			"speed": _rng.randf_range(2.5, 9.0),
			"sway": _rng.randf_range(1.0, 3.5),
			"phase": _rng.randf_range(0.0, 6.28),
			"x": _rng.randf_range(0.0, 1.0),
			"y": _rng.randf_range(0.0, 1.0),
		})


# ---------------------------------------------------------------- menu
func _build_menu() -> void:
	_menu = VBoxContainer.new()
	_menu.alignment = BoxContainer.ALIGNMENT_END
	_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.rotation = -0.05
	_scene.add_child(_menu)

	for i in ITEMS.size():
		var b := Button.new()
		b.name = "Menu_" + String(ITEMS[i]["id"])
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.text = ""
		b.tooltip_text = String(ITEMS[i]["en"])
		b.icon = null
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		b.size_flags_horizontal = Control.SIZE_SHRINK_END
		b.add_theme_color_override("icon_normal_color", Color(1, 1, 1, 1))
		b.add_theme_color_override("icon_hover_color", Color(1, 1, 1, 1))
		b.add_theme_color_override("icon_pressed_color", Color(1, 1, 1, 1))
		b.add_theme_color_override("icon_focus_color", Color(1, 1, 1, 1))
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		b.mouse_entered.connect(_select.bind(i))
		b.button_down.connect(_on_press.bind(i))
		b.button_up.connect(_on_release.bind(i))
		b.pressed.connect(_activate.bind(i))
		_menu.add_child(b)
		_buttons.append(b)

		# Real, editable English label drawn as the resting menu text. The MAIN
		# word art takes over while the row is hovered/selected.
		var lbl := Label.new()
		lbl.name = "Label_" + String(ITEMS[i]["id"])
		lbl.text = String(ITEMS[i]["en"])
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_override("font", DISPLAY_FONT)
		lbl.add_theme_color_override("font_color", Color(0.99, 0.99, 0.97))
		lbl.add_theme_color_override("font_outline_color", Color("e9825b"))
		lbl.add_theme_constant_override("outline_size", 4)
		lbl.add_theme_color_override("font_shadow_color", Color(0.04, 0.12, 0.13, 0.9))
		lbl.add_theme_constant_override("shadow_offset_x", 1)
		lbl.add_theme_constant_override("shadow_offset_y", 1)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(lbl)
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		_labels.append(lbl)


func _build_hint() -> void:
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_hint.add_theme_font_override("font", UI.thai_font)
	_hint.add_theme_font_size_override("font_size", 9)
	_hint.add_theme_color_override("font_color", Color(0.80, 0.92, 0.90, 0.95))
	_hint.add_theme_color_override("font_outline_color", Color(0.02, 0.06, 0.06, 0.9))
	_hint.add_theme_constant_override("outline_size", 3)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene.add_child(_hint)


# ---------------------------------------------------------------- layout
## Rect the 16:9 backdrop actually covers after STRETCH_KEEP_ASPECT_COVERED.
func _drawn_bg_rect() -> Rect2:
	var area := size
	if area.x <= 1.0 or area.y <= 1.0:
		area = Vector2(480, 270)
	var src: Vector2 = BG_TEX.get_size()
	var s := maxf(area.x / src.x, area.y / src.y)
	var drawn: Vector2 = src * s
	return Rect2((area - drawn) * 0.5, drawn)


func _layout() -> void:
	var area := size
	if area.x <= 1.0 or area.y <= 1.0:
		area = Vector2(480, 270)
	_bg.position = Vector2.ZERO
	_bg.size = area
	_bg.pivot_offset = area * 0.5

	var logo_h := area.y * 1.10
	var logo_w := logo_h * (float(LOGO_TEX.get_width()) / float(LOGO_TEX.get_height()))
	_logo_base = Vector2(-logo_w * 0.02, -logo_h * 0.02)
	_logo.size = Vector2(logo_w, logo_h)
	_logo.position = _logo_base
	_logo.pivot_offset = _logo.size * 0.5

	_halftone.size = area + Vector2(120, 120)
	_halftone.position = Vector2(-60, -60)

	# Menu words sit on the torn paper of the backdrop, right aligned. Screen-space
	# placement keeps them visible on every aspect ratio; the paper occupies the
	# right side of the art, so they still land on it.
	var word_h := area.y * 0.098
	var gap := maxi(3, int(round(word_h * 0.24)))
	_menu.add_theme_constant_override("separation", gap)
	var widest := 0.0
	var widths: Array[float] = []
	var min_fit := 99.0
	for i in _buttons.size():
		var t: Texture2D = _art(String(ITEMS[i]["art"]))
		var aspect := 4.0
		if t != null and t.get_height() > 0:
			aspect = float(t.get_width()) / float(t.get_height())
		var w := word_h * aspect
		widths.append(w)
		widest = maxf(widest, w)
		_buttons[i].custom_minimum_size = Vector2(w, word_h)
		var chars := maxi(1, String(ITEMS[i]["en"]).length())
		min_fit = minf(min_fit, (w * 0.84) / (float(chars) * 0.70))
	# One type size for every row keeps the column even.
	var label_px := int(round(clampf(minf(word_h * 0.68, min_fit), 5.0, 26.0)))
	for i in _labels.size():
		_labels[i].add_theme_font_size_override("font_size", label_px)
	var total := word_h * _buttons.size() + gap * (_buttons.size() - 1)
	_menu.size = Vector2(widest, total)
	var right := area.x - maxf(area.x * 0.042, 12.0)
	var top := area.y * 0.045
	_menu.position = Vector2(right - widest, top)
	_menu.pivot_offset = Vector2(widest, total * 0.5)

	for b in _buttons:
		b.pivot_offset = b.size * 0.5

	# Thai caption lives on the dark band under the character, where it reads.
	_hint.position = Vector2(area.x * 0.30, area.y - 20.0)
	_hint.size = Vector2(area.x * 0.40, 14.0)

	_modal.size = Vector2(minf(340.0, area.x - 24.0), minf(250.0, area.y - 24.0))
	_modal.position = ((area - _modal.size) * 0.5).floor()


# ---------------------------------------------------------------- intro & motion
func _play_intro() -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_bg, "modulate:a", 1.0, 0.7)
	tw.tween_property(_logo, "modulate:a", 1.0, 0.45)
	tw.tween_property(_logo, "scale", Vector2.ONE, 0.55).from(Vector2(1.14, 1.14)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for i in _buttons.size():
		var b: Button = _buttons[i]
		b.modulate.a = 0.0
		var start_scale := Vector2(0.88, 0.88)
		b.scale = start_scale
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(b, "modulate:a", 1.0, 0.32).set_delay(0.25 + i * 0.07)
		t.tween_property(b, "scale", Vector2.ONE, 0.38).set_delay(0.25 + i * 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_t += delta
	if _logo != null:
		_logo.position = _logo_base + Vector2(0, sin(_t * 1.4) * 2.2)
		var pulse := 1.0 + 0.012 * sin(_t * 1.1)
		_logo.scale = Vector2(pulse, pulse)
		# slow highlight sweep across the logo
		var glint := 1.0 + 0.05 * maxf(0.0, sin(_t * 0.7 - 0.6))
		_logo.modulate = Color(glint, glint, glint, 1.0)
	if _bg != null:
		# subtle poster breathing for depth; the menu tracks the screen edge
		var breathe := 1.012 + 0.006 * sin(_t * 0.5)
		_bg.scale = Vector2(breathe, breathe)
	if _halftone != null:
		var drift := Vector2(fmod(_t * 3.0, 96.0), fmod(-_t * 2.0, 96.0))
		_halftone.position = Vector2(-60, -60) + drift + _mouse * 4.0
	var area := size
	if area.x <= 1.0:
		area = Vector2(480, 270)
	for p in _particles:
		var node: TextureRect = p["node"]
		var pos := node.position
		pos.y -= float(p["speed"]) * delta
		pos.x += sin(_t * float(p["sway"]) + float(p["phase"])) * 6.0 * delta
		if pos.y < -6.0:
			pos.y = area.y + 4.0
			pos.x = float(p["x"]) * area.x
		node.position = pos
		node.modulate.a = 0.18 + 0.22 * (0.5 + 0.5 * sin(_t * 1.7 + float(p["phase"])))


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var area := size
		if area.x > 1.0:
			_mouse = ((event as InputEventMouseMotion).position / area - Vector2(0.5, 0.5)) * 2.0


# ---------------------------------------------------------------- menu logic
func _select(i: int) -> void:
	if i == _selected:
		return
	_selected = clampi(i, 0, ITEMS.size() - 1)
	Sfx.play("click", 1.55, -26.0)
	_apply_selection()


func _apply_selection() -> void:
	for i in _buttons.size():
		var b := _buttons[i]
		var on := i == _selected
		var art := _art(String(ITEMS[i]["hover"])) if on else null
		if art == null:
			art = _art(String(ITEMS[i]["art"]))
		b.icon = art if on else null
		_labels[i].visible = not on
		if is_instance_valid(b) and b.is_inside_tree():
			var want := Vector2(1.05, 1.05) if on else Vector2.ONE
			var t := create_tween()
			t.tween_property(b, "scale", want, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _hint != null:
		_hint.text = String(ITEMS[_selected]["th"])


func _on_press(i: int) -> void:
	# Touch taps do not fire mouse_entered, so selecting here keeps the Thai
	# caption and the hover art in sync for finger input as well.
	_select(i)
	var b: Button = _buttons[i]
	var t := create_tween()
	t.tween_property(b, "scale", Vector2(0.95, 0.95), 0.06)


func _on_release(i: int) -> void:
	var b: Button = _buttons[i]
	var t := create_tween()
	t.tween_property(b, "scale", Vector2(1.05, 1.05) if i == _selected else Vector2.ONE, 0.10)


func _activate(i: int) -> void:
	_selected = i
	_apply_selection()
	match String(ITEMS[i]["id"]):
		"new", "continue":
			Sfx.play("click", 1.0, -10.0)
			_fade_then(func() -> void: start_selected.emit(String(ITEMS[i]["id"])))
		"how":
			_open_modal("how")
		"settings":
			_open_modal("settings")
		"credits":
			_open_modal("credits")
		"quit":
			Sfx.play("click", 0.9, -10.0)
			_fade_then(func() -> void: start_selected.emit("quit"))


## Quick fade to the next screen so scene swaps are not a hard cut.
func _fade_then(action: Callable) -> void:
	var veil := ColorRect.new()
	veil.color = Color(0.02, 0.04, 0.04, 0.0)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(veil)
	var tw := create_tween()
	tw.tween_property(veil, "color:a", 1.0, 0.26)
	tw.tween_callback(action)


# ---------------------------------------------------------------- modal
func _build_modal() -> void:
	_modal = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.94, 0.97, 0.95, 0.99)
	box.border_color = Color(0.06, 0.23, 0.24)
	box.set_border_width_all(2)
	box.set_corner_radius_all(2)
	box.set_content_margin_all(3)
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = 3
	_modal.add_theme_stylebox_override("panel", box)
	_modal.visible = false
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_modal)

	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 8)
	_modal.add_child(m)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m.add_child(scroll)
	_modal_box = VBoxContainer.new()
	_modal_box.add_theme_constant_override("separation", 4)
	_modal_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_modal_box)


func _clear_modal() -> void:
	for c in _modal_box.get_children():
		_modal_box.remove_child(c)
		c.queue_free()


func _open_modal(kind: String) -> void:
	Sfx.play("click", 1.0, -12.0)
	_clear_modal()
	var head := UI.title_label(_modal_box, "", 12, UI.PARCH_INK)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	match kind:
		"how":
			head.text = "วิธีการเล่น"
			var body := UI.label(_modal_box, "", 6, UI.PARCH_INK)
			body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			body.text = "• WASD เดิน · คลิกซ้าย โจมตี · Q กวาดขยะ\n" \
				+ "• E เก็บขยะ / ทิ้งขยะ / เปิดร้านค้า\n" \
				+ "• F คัดแยกทั้งหมด หรือใช้ชุดปฐมพยาบาล\n" \
				+ "• I กระเป๋า · SHIFT วิ่ง · ESC หยุด\n\n" \
				+ "แยกขยะ 4 ประเภท: ขยะเปียก (เขียว) ขยะอันตราย (แดง) ขยะทั่วไป (น้ำเงิน) ขยะรีไซเคิล (เหลือง)\n" \
				+ "แยกถูกได้เงิน แยกผิดโดนปรับและมลพิษเพิ่ม\n" \
				+ "เก็บขยะให้หมดและรอดจากการบุกโจมตี 7 วัน"
			body.custom_minimum_size = Vector2(270, 96)
		"settings":
			head.text = "ตั้งค่า"
			var vol_row := HBoxContainer.new()
			_modal_box.add_child(vol_row)
			UI.label(vol_row, "เสียง", 7, UI.PARCH_INK)
			var vol := HSlider.new()
			vol.min_value = 0
			vol.max_value = 100
			vol.step = 5
			vol.value = _volume
			vol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			vol.custom_minimum_size = Vector2(0, 14)
			vol.value_changed.connect(_on_volume)
			vol_row.add_child(vol)

			var wm := Button.new()
			wm.text = "โหมดหน้าต่าง:  " + Platform.window_mode_label()
			wm.add_theme_font_size_override("font_size", 7)
			wm.focus_mode = Control.FOCUS_NONE
			wm.pressed.connect(_cycle_window_mode.bind(wm))
			_modal_box.add_child(wm)

			var res := Button.new()
			res.text = "ความละเอียด:  " + Platform.resolution_label()
			res.add_theme_font_size_override("font_size", 7)
			res.focus_mode = Control.FOCUS_NONE
			res.pressed.connect(_cycle_resolution.bind(res))
			_modal_box.add_child(res)

			var rs := Button.new()
			rs.text = "สเกลเรนเดอร์:  " + Platform.render_scale_label()
			rs.add_theme_font_size_override("font_size", 7)
			rs.focus_mode = Control.FOCUS_NONE
			rs.pressed.connect(_cycle_render_scale.bind(rs))
			_modal_box.add_child(rs)

			var gq := Button.new()
			gq.text = "คุณภาพกราฟิก:  " + Platform.quality_label()
			gq.add_theme_font_size_override("font_size", 7)
			gq.focus_mode = Control.FOCUS_NONE
			gq.pressed.connect(_cycle_quality.bind(gq))
			_modal_box.add_child(gq)

			var mode := Button.new()
			mode.text = "โหมดควบคุม:  " + Platform.mode_label()
			mode.add_theme_font_size_override("font_size", 7)
			mode.focus_mode = Control.FOCUS_NONE
			mode.pressed.connect(_cycle_control_mode.bind(mode))
			_modal_box.add_child(mode)

			var ui_size := Button.new()
			ui_size.text = "ขนาด UI:  %s" % Platform.ui_size_label()
			ui_size.add_theme_font_size_override("font_size", 7)
			ui_size.focus_mode = Control.FOCUS_NONE
			ui_size.pressed.connect(_cycle_ui_size.bind(ui_size))
			_modal_box.add_child(ui_size)

			var joy := Button.new()
			joy.text = "ขนาดจอย/ปุ่ม  %d%%" % int(round(Platform.joystick_scale * 100.0))
			joy.add_theme_font_size_override("font_size", 7)
			joy.focus_mode = Control.FOCUS_NONE
			joy.pressed.connect(_cycle_joystick.bind(joy))
			_modal_box.add_child(joy)

			var alpha := Button.new()
			alpha.text = "ความทึบปุ่ม  %d%%" % int(round(Platform.button_opacity * 100.0))
			alpha.add_theme_font_size_override("font_size", 7)
			alpha.focus_mode = Control.FOCUS_NONE
			alpha.pressed.connect(_cycle_opacity.bind(alpha))
			_modal_box.add_child(alpha)

			var sens := Button.new()
			sens.text = "ความไวการเดิน  %d%%" % int(round(Platform.sensitivity * 100.0))
			sens.add_theme_font_size_override("font_size", 7)
			sens.focus_mode = Control.FOCUS_NONE
			sens.pressed.connect(_cycle_sensitivity.bind(sens))
			_modal_box.add_child(sens)

			var hint := UI.label(_modal_box, "การตั้งค่าจะถูกบันทึกอัตโนมัติ", 5, UI.PARCH_MUTED)
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		"credits":
			head.text = "เครดิต"
			var body2 := UI.label(_modal_box, "", 6, UI.PARCH_INK)
			body2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			body2.text = "TOXIC WASTELAND: SURVIVE & RECYCLE\n\n" \
				+ "ออกแบบและพัฒนาเกม: ทีม Toxic Wasteland\n" \
				+ "เอนจิน: Godot 4.7\n" \
				+ "ฟอนต์: Pixel Game / Silkscreen + Noto Sans Thai\n" \
				+ "ภาพและเสียง: สร้างด้วยสคริปต์ในโปรเจกต์"
			body2.custom_minimum_size = Vector2(270, 90)

	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 2)
	_modal_box.add_child(sp)

	var back := Button.new()
	back.text = "ย้อนกลับ"
	back.add_theme_font_size_override("font_size", 8)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(_close_modal)
	_modal_box.add_child(back)

	_modal.visible = true
	_modal.modulate.a = 0.0
	_modal.scale = Vector2(0.96, 0.96)
	_modal.pivot_offset = _modal.size * 0.5
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_modal, "modulate:a", 1.0, 0.16)
	tw.tween_property(_modal, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _close_modal() -> void:
	Sfx.play("click", 1.2, -16.0)
	_modal.visible = false
	_clear_modal()


# ---------------------------------------------------------------- settings
func _on_volume(v: float) -> void:
	_volume = v
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 1.0) / 100.0))
	_save_settings()


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) == OK:
		_volume = float(cfg.get_value("ui", "volume", 80.0))
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(_volume, 1.0) / 100.0))


func _save_settings() -> void:
	Platform.write_setting("ui", "volume", _volume)


func _cycle_window_mode(btn: Button) -> void:
	Platform.cycle_window_mode()
	btn.text = "โหมดหน้าต่าง:  " + Platform.window_mode_label()
	Sfx.play("click", 1.25, -18.0)


func _cycle_resolution(btn: Button) -> void:
	Platform.cycle_resolution()
	btn.text = "ความละเอียด:  " + Platform.resolution_label()
	Sfx.play("click", 1.25, -18.0)


func _cycle_render_scale(btn: Button) -> void:
	Platform.cycle_render_scale()
	btn.text = "สเกลเรนเดอร์:  " + Platform.render_scale_label()
	Sfx.play("click", 1.25, -18.0)


func _cycle_quality(btn: Button) -> void:
	Platform.cycle_quality()
	btn.text = "คุณภาพกราฟิก:  " + Platform.quality_label()
	Sfx.play("click", 1.25, -18.0)


func _cycle_control_mode(btn: Button) -> void:
	Platform.cycle_mode()
	btn.text = "โหมดควบคุม:  " + Platform.mode_label()
	Sfx.play("click", 1.25, -18.0)


func _cycle_ui_size(btn: Button) -> void:
	Platform.cycle_ui_size()
	btn.text = "ขนาด UI:  %s" % Platform.ui_size_label()
	Sfx.play("click", 1.25, -18.0)


func _cycle_joystick(btn: Button) -> void:
	btn.text = "ขนาดจอย/ปุ่ม  %d%%" % int(round(Platform.cycle_joystick_scale() * 100.0))
	Sfx.play("click", 1.25, -18.0)


func _cycle_opacity(btn: Button) -> void:
	btn.text = "ความทึบปุ่ม  %d%%" % int(round(Platform.cycle_button_opacity() * 100.0))
	Sfx.play("click", 1.25, -18.0)


func _cycle_sensitivity(btn: Button) -> void:
	btn.text = "ความไวการเดิน  %d%%" % int(round(Platform.cycle_sensitivity() * 100.0))
	Sfx.play("click", 1.25, -18.0)


# ---------------------------------------------------------------- input
func _unhandled_input(event: InputEvent) -> void:
	if _modal.visible:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
			_close_modal()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_down"):
		_select((_selected + 1) % ITEMS.size())
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_select((_selected - 1 + ITEMS.size()) % ITEMS.size())
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_activate(_selected)
		get_viewport().set_input_as_handled()
