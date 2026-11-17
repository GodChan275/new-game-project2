extends Control
## Fantasy pixel-art clock HUD (top-right). Shows the Time.jpg day/night globe in
## a warm orange frame, the Day plaque, phase + air icons, a 12-hour clock derived
## from the existing morning/invasion timers, and the live pollution strip.
## Clicking still expands the small mission card (and hides the minimap).

signal expanded_changed(open: bool)

const W := 118.0
const H := 86.0
const CARD_H := 44.0

const SKY_PATH := "res://Assets/image/Time/Time.jpg"
const SKY_C := Vector2(25.0, 25.0)
const SKY_R := 23.0
const SKY_RECT := Rect2(2.0, 2.0, 46.0, 46.0)

const BODY := Rect2(48.0, 2.0, 68.0, 62.0)
const DAY_RECT := Rect2(52.0, 5.0, 60.0, 16.0)
const CELL_A := Rect2(52.0, 24.0, 18.0, 18.0)
const CELL_B := Rect2(74.0, 24.0, 18.0, 18.0)
const CELL_C := Rect2(96.0, 24.0, 18.0, 18.0)
const TIME_RECT := Rect2(52.0, 45.0, 60.0, 16.0)
const POLL_RECT := Rect2(4.0, 69.0, 112.0, 15.0)

# ---------------------------------------------------------------- palette
const WOOD := Color("46280f")
const ORANGE := Color("d2801f")
const ORANGE_L := Color("f0a94a")
const ORANGE_D := Color("9c5413")
const GOLD := Color("f6cf5c")
const GOLD_D := Color("c9971f")
const CREAM := Color("f6e3ba")
const CREAM_D := Color("dfc38b")
const INK := Color("3a2410")
const SKY_BACK := Color("8ecfe8")
const HAZE_BACK := Color("e9d7a8")
const MASK_BACK := Color("7fd7ae")
const GREEN_PLATE := Color("5ec24a")
const GREEN_PLATE_D := Color("2f7a2c")
const MOON := Color("e2e8ff")
## Compact status words so the strip never clips inside the 112 px frame.
const POLL_SHORT := ["สะอาด", "มลพิษปานกลาง", "มลพิษสูง", "พิษระบาด"]

var _sky: Texture2D
var _day: Label
var _time: Label
var _poll: Label
var _card: Panel
var _phase: Label
var _main: Label
var _counters: Label
var _open := false
var _open_t := 0.0
var _last_day := -1
var _last_min := -1
var _last_poll := -1.0
var _last_phase := -1


func _ready() -> void:
	custom_minimum_size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tooltip_text = "เวลา มลพิษ และสภาพแวดล้อม · คลิกดูรายละเอียด"
	theme = UI.hud_theme()

	_sky = _make_sky()

	_day = UI.title_label(self, "Day 1", 9, INK)
	_day.position = DAY_RECT.position
	_day.size = DAY_RECT.size
	_day.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_day.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_day.clip_text = true

	_time = UI.title_label(self, "6:00 AM", 9, INK)
	_time.position = TIME_RECT.position
	_time.size = TIME_RECT.size
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_time.clip_text = true

	_poll = UI.label(self, "", 6, Color.WHITE)
	_poll.position = POLL_RECT.position + Vector2(15.0, 1.0)
	_poll.size = POLL_RECT.size - Vector2(19.0, 2.0)
	_poll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_poll.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_poll.clip_text = true
	_poll.add_theme_constant_override("outline_size", 2)
	_poll.add_theme_color_override("font_outline_color", GREEN_PLATE_D)

	_build_card()
	gui_input.connect(_on_press)


## Cuts the supplied sky art to a pixel circle (the JPG has white corners) and
## caches a small nearest-filtered copy so it stays sharp at HUD size.
func _make_sky() -> Texture2D:
	if not ResourceLoader.exists(SKY_PATH):
		return null
	var src: Texture2D = load(SKY_PATH)
	if src == null:
		return null
	var img := src.get_image()
	if img == null:
		return src
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(92, 92, Image.INTERPOLATE_BILINEAR)

	# The JPG has a white margin around the pixel disc: find the disc, crop to it
	# and mask the crop so the frame only ever shows sky art.
	var min_x := img.get_width()
	var min_y := img.get_height()
	var max_x := -1
	var max_y := -1
	var iw := img.get_width()
	var ih := img.get_height()
	for y in range(ih):
		for x in range(iw):
			var px := img.get_pixel(x, y)
			if px.r > 0.95 and px.g > 0.95 and px.b > 0.95:
				continue
			min_x = mini(min_x, x)
			max_x = maxi(max_x, x)
			min_y = mini(min_y, y)
			max_y = maxi(max_y, y)
	if max_x < 0 or max_y < 0:
		min_x = 0
		min_y = 0
		max_x = img.get_width() - 1
		max_y = img.get_height() - 1
	var box := Rect2i(min_x, min_y, maxi(1, max_x - min_x + 1), maxi(1, max_y - min_y + 1))
	var disk := img.get_region(box)
	disk.convert(Image.FORMAT_RGBA8)
	var w := disk.get_width()
	var h := disk.get_height()
	var c := Vector2((float(w) - 1.0) * 0.5, (float(h) - 1.0) * 0.5)
	var r := minf(float(w), float(h)) * 0.5 - 0.5
	for y in range(h):
		for x in range(w):
			if Vector2(float(x), float(y)).distance_to(c) > r:
				disk.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(disk)


func _build_card() -> void:
	_card = Panel.new()
	_card.position = Vector2(0.0, H + 2.0)
	_card.size = Vector2(W, CARD_H)
	_card.visible = false
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.theme = UI.hud_theme()
	_card.add_theme_stylebox_override("panel", UI.paper_box())
	add_child(_card)
	_card.gui_input.connect(_on_press)

	_phase = UI.label(_card, "", 6, UI.INK_BROWN)
	_phase.position = Vector2(5, 4)
	_phase.size = Vector2(W - 10.0, 9)
	_phase.clip_text = true

	_main = UI.label(_card, "", 5, UI.INK_SOFT)
	_main.position = Vector2(5, 14)
	_main.size = Vector2(W - 10.0, 14)
	_main.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_main.max_lines_visible = 2

	_counters = UI.label(_card, "", 5, UI.INK_SOFT)
	_counters.position = Vector2(5, 30)
	_counters.size = Vector2(W - 10.0, 9)


# ---------------------------------------------------------------- input
func _on_press(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_open = not _open
		_card.visible = _open
		_open_t = 0.0
		expanded_changed.emit(_open)
		Sfx.play("click", 1.4, -22.0)


# ---------------------------------------------------------------- data
## The project has no wall clock: morning runs 06:00-18:00 and the invasion
## night 18:00-06:00, driven by the existing GameManager timers.
func _clock_minutes() -> int:
	var progress := 1.0 - GameManager.time_ratio()
	var start := 18 * 60 if GameManager.is_invasion() else 6 * 60
	var span := 12 * 60
	return (start + int(round(progress * float(span)))) % (24 * 60)


func _format_minutes(m: int) -> String:
	var h := m / 60
	var mm := m % 60
	var suffix := "AM" if h < 12 else "PM"
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, mm, suffix]


func _process(delta: float) -> void:
	if GameManager.day != _last_day:
		_last_day = GameManager.day
		_day.text = "Day %d" % _last_day

	var m := _clock_minutes()
	if m != _last_min:
		_last_min = m
		_time.text = _format_minutes(m)

	var pct := int(round(Pollution.pct))
	if absf(Pollution.pct - _last_poll) > 0.4 or GameManager.phase != _last_phase:
		_last_poll = Pollution.pct
		if GameManager.phase != _last_phase:
			_last_phase = GameManager.phase
		_poll.text = "%d%% · %s" % [pct, POLL_SHORT[Pollution.level_index()]]
		queue_redraw()

	if not _open:
		return
	_open_t += delta
	if _open_t > 6.0:
		_open = false
		_card.visible = false
		expanded_changed.emit(false)
		return
	_phase.text = "บุกโจมตี" if GameManager.is_invasion() else "เช้า · ปลอดภัย"
	_phase.add_theme_color_override("font_color", UI.RED_DEEP if GameManager.is_invasion() else UI.GREEN_DEEP)
	var collect := Quests.progress_of("collect")
	_main.text = Quests.main_text()
	_counters.text = "เก็บ %d/%d · ศัตรู %d" % [collect.x, maxi(collect.y, collect.x), Combat.live_enemies()]


# ---------------------------------------------------------------- painting
func _draw() -> void:
	_draw_body()
	_draw_sky()
	_draw_plaque(DAY_RECT)
	_draw_plaque(TIME_RECT)
	_draw_cell(CELL_A, SKY_BACK)
	_draw_cell(CELL_B, HAZE_BACK)
	_draw_cell(CELL_C, MASK_BACK)
	_draw_phase_icon(CELL_A)
	_draw_haze_icon(CELL_B)
	_draw_mask_icon(CELL_C)
	_draw_pollution()


func _plate(rect: Rect2, body: Color, light: Color, dark: Color) -> void:
	draw_rect(rect, WOOD)
	var inner := rect.grow(-1.0)
	draw_rect(inner, body)
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, 1.0)), light)
	draw_rect(Rect2(inner.position + Vector2(0.0, inner.size.y - 1.0), Vector2(inner.size.x, 1.0)), dark)
	draw_rect(Rect2(inner.position, Vector2(1.0, inner.size.y)), light)
	draw_rect(Rect2(inner.position + Vector2(inner.size.x - 1.0, 0.0), Vector2(1.0, inner.size.y)), dark)


func _draw_body() -> void:
	draw_rect(Rect2(BODY.position + Vector2(0.0, 1.0), BODY.size), Color(0.09, 0.05, 0.02, 0.45))
	_plate(BODY, ORANGE, ORANGE_L, ORANGE_D)
	# corner studs, matching the player plate language
	for corner in [BODY.position + Vector2(2.0, 2.0), BODY.position + Vector2(BODY.size.x - 4.0, 2.0),
			BODY.position + Vector2(2.0, BODY.size.y - 4.0), BODY.position + Vector2(BODY.size.x - 4.0, BODY.size.y - 4.0)]:
		draw_rect(Rect2(corner, Vector2(2.0, 2.0)), GOLD_D)
	# wooden stalks down to the pollution strip
	for x in [40.0, 86.0]:
		draw_rect(Rect2(x, BODY.position.y + BODY.size.y - 1.0, 5.0, 7.0), WOOD)
		draw_rect(Rect2(x + 1.0, BODY.position.y + BODY.size.y, 3.0, 5.0), ORANGE)


func _draw_plaque(rect: Rect2) -> void:
	_plate(rect, ORANGE_D, ORANGE, WOOD)
	var inner := rect.grow(-2.0)
	draw_rect(inner, WOOD)
	var face := inner.grow(-1.0)
	draw_rect(face, CREAM)
	draw_rect(Rect2(face.position, Vector2(face.size.x, 1.0)), CREAM_D)
	draw_rect(Rect2(face.position + Vector2(0.0, face.size.y - 1.0), Vector2(face.size.x, 1.0)), Color("fff3d6"))


func _draw_sky() -> void:
	draw_circle(SKY_C + Vector2(0.0, 1.0), SKY_R + 1.0, Color(0.12, 0.07, 0.02, 0.5))
	if _sky != null:
		draw_texture_rect(_sky, SKY_RECT, false)
	# warm metallic rim so the art reads as part of the orange frame
	draw_arc(SKY_C, SKY_R - 0.5, 0.0, TAU, 64, ORANGE_D, 4.0, false)
	draw_arc(SKY_C, SKY_R - 1.5, 0.0, TAU, 64, GOLD, 2.0, false)
	draw_arc(SKY_C, SKY_R - 2.8, 0.0, TAU, 64, Color(0.28, 0.15, 0.05, 0.35), 1.0, false)
	for i in 4:
		var a := TAU * float(i) / 4.0 + PI * 0.25
		var p := SKY_C + Vector2(cos(a), sin(a)) * (SKY_R - 1.0)
		draw_rect(Rect2((p - Vector2(1.0, 1.0)).floor(), Vector2(2.0, 2.0)), GOLD)


func _draw_cell(rect: Rect2, bg: Color) -> void:
	draw_rect(rect, WOOD)
	draw_rect(rect.grow(-1.0), ORANGE)
	var inner := rect.grow(-2.0)
	draw_rect(inner, bg)
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, 1.0)), Color(1, 1, 1, 0.22))
	draw_rect(Rect2(inner.position + Vector2(0.0, inner.size.y - 1.0), Vector2(inner.size.x, 1.0)), Color(0, 0, 0, 0.18))


func _cell_center(rect: Rect2) -> Vector2:
	return rect.position + Vector2(9.0, 9.0)


func _draw_phase_icon(rect: Rect2) -> void:
	var c := _cell_center(rect)
	if GameManager.is_invasion():
		draw_circle(c + Vector2(0.0, 0.5), 5.0, MOON)
		draw_circle(c + Vector2(2.4, -1.2), 4.6, SKY_BACK)
		draw_rect(Rect2(c + Vector2(-5.0, -5.0), Vector2(1.0, 1.0)), Color("eaf1ff"))
		draw_rect(Rect2(c + Vector2(4.0, 3.0), Vector2(1.0, 1.0)), Color("eaf1ff"))
		return
	var sun := Color("ffd94a")
	draw_rect(Rect2(c + Vector2(-3.0, -3.0), Vector2(6.0, 6.0)), sun)
	draw_rect(Rect2(c + Vector2(-2.0, -2.0), Vector2(4.0, 2.0)), Color("fff2b0"))
	for off in [Vector2(0.0, -6.0), Vector2(0.0, 5.0), Vector2(-6.0, 0.0), Vector2(5.0, 0.0)]:
		draw_rect(Rect2(c + off, Vector2(1.0, 1.0)), sun)
	for off in [Vector2(-5.0, -5.0), Vector2(4.0, -5.0), Vector2(-5.0, 4.0), Vector2(4.0, 4.0)]:
		draw_rect(Rect2(c + off, Vector2(1.0, 1.0)), Color("f0b93a"))


func _draw_haze_icon(rect: Rect2) -> void:
	var c := _cell_center(rect)
	var t := clampf(Pollution.pct / 100.0, 0.0, 1.0)
	var col := Color("c7d2bf").lerp(Color("86944f"), t)
	draw_rect(Rect2(c + Vector2(-6.0, -1.0), Vector2(12.0, 4.0)), col)
	draw_rect(Rect2(c + Vector2(-4.0, -3.0), Vector2(8.0, 2.0)), col)
	draw_rect(Rect2(c + Vector2(-2.0, -5.0), Vector2(5.0, 2.0)), col.lightened(0.12))
	draw_rect(Rect2(c + Vector2(-6.0, 3.0), Vector2(12.0, 1.0)), col.darkened(0.18))
	# acidic drizzle appears as the metre climbs
	if t > 0.55:
		for x in [-4.0, 0.0, 4.0]:
			draw_rect(Rect2(c + Vector2(x, 4.0), Vector2(1.0, 2.0)), Color("a8c24a"))


func _draw_mask_icon(rect: Rect2) -> void:
	var c := _cell_center(rect)
	var shell := Color("3f6b4a")
	var filter := Color("cfd9c2")
	draw_rect(Rect2(c + Vector2(-6.0, -4.0), Vector2(12.0, 5.0)), shell)
	draw_rect(Rect2(c + Vector2(-5.0, 1.0), Vector2(10.0, 3.0)), shell)
	draw_rect(Rect2(c + Vector2(-4.0, -3.0), Vector2(3.0, 3.0)), filter)
	draw_rect(Rect2(c + Vector2(1.0, -3.0), Vector2(3.0, 3.0)), filter)
	draw_rect(Rect2(c + Vector2(-1.0, 2.0), Vector2(3.0, 2.0)), GOLD_D)
	draw_rect(Rect2(c + Vector2(-8.0, -3.0), Vector2(2.0, 1.0)), shell)
	draw_rect(Rect2(c + Vector2(6.0, -3.0), Vector2(2.0, 1.0)), shell)


func _draw_pollution() -> void:
	_plate(POLL_RECT, ORANGE, ORANGE_L, ORANGE_D)
	var well := POLL_RECT.grow(-2.0)
	draw_rect(well, GREEN_PLATE_D)
	var face := well.grow(-1.0)
	draw_rect(face, GREEN_PLATE)
	draw_rect(Rect2(face.position, Vector2(face.size.x, 1.0)), GREEN_PLATE.lightened(0.18))
	# little gold hazard emblem at the left, like the reference medallion
	var c := POLL_RECT.position + Vector2(8.0, 7.5)
	draw_rect(Rect2(c + Vector2(-4.0, -4.0), Vector2(8.0, 8.0)), GREEN_PLATE_D)
	draw_rect(Rect2(c + Vector2(-3.0, -3.0), Vector2(6.0, 6.0)), GOLD)
	draw_rect(Rect2(c + Vector2(-1.0, -2.0), Vector2(2.0, 3.0)), WOOD)
	draw_rect(Rect2(c + Vector2(-1.0, 2.0), Vector2(2.0, 1.0)), WOOD)
