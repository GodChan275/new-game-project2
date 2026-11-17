extends Control
## Fantasy-RPG player HUD (top-left): circular portrait, gold level badge,
## crimson HP bar, teal stamina bar and gold counter, all inside one ornate
## metal frame. Values come from PlayerController signals and the Economy
## autoload, so the HUD never stores or recomputes stats.

const W := 196.0
const H := 62.0
const CARD_W := 180.0
const CARD_H := 112.0

const PORTRAIT_C := Vector2(24.0, 25.0)
const PORTRAIT_R := 16.0
const HP_RECT := Rect2(56.0, 9.0, 132.0, 16.0)
const ST_RECT := Rect2(56.0, 30.0, 114.0, 12.0)
const BADGE_RECT := Rect2(13.0, 47.0, 30.0, 10.0)

const STEEL := Color("aab4b9")
const STEEL_D := Color("505c63")
const STEEL_L := Color("d3dadd")
const IRON := Color("0a1012")
const PLATE := Color(0.106, 0.145, 0.149, 0.95)
const GOLD := Color("e3b64a")
const GOLD_D := Color("8d6820")
const GOLD_L := Color("f7dd94")
const INK := Color("241a08")
const CREAM := Color("efe6cf")

const HP_BANDS: Array[Color] = [Color("e2604f"), Color("c93a32"), Color("a32424"), Color("7d1a1a")]
const ST_BANDS: Array[Color] = [Color("8ef0dd"), Color("55d6cf"), Color("2fa9ac"), Color("227f86")]

## Face crop of the player sheet (row 1, first frame) used for the portrait.
const PORTRAIT_REGION := Rect2i(85, 24, 160, 160)

var player: Node = null

var _portrait_tex: Texture2D
var _coin_tex: Texture2D
var _lvl: Label
var _hp_text: Label
var _st_text: Label
var _gold_text: Label
var _card: Panel
var _card_text: Label
var _card_open := false
var _card_left := 0.0

var _hp_ratio := 1.0
var _st_ratio := 1.0
var _hp_shown := 1.0
var _st_shown := 1.0
var _hp_flash := 0.0
var _st_glow := 0.0
var _t := 0.0
var _hp_str := ""
var _st_str := ""


func _ready() -> void:
	custom_minimum_size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "สถานะตัวละคร · คลิกดูรายละเอียด"
	theme = UI.hud_theme()

	_build_portrait()
	_build_labels()
	_build_card()
	gui_input.connect(_on_press)

	Economy.money_changed.connect(_on_money)
	Economy.leveled_up.connect(_on_level_up)
	_on_money(Economy.money, 0)
	_on_level_up(Economy.level)
	queue_redraw()


# ---------------------------------------------------------------- build
func _build_portrait() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait_tex = _make_portrait()


## Cuts the face out of the player sheet and masks it to a hard pixel circle,
## so the circular frame needs no shader and keeps nearest-neighbour edges.
func _make_portrait() -> Texture2D:
	var sheet := Art.player_sheet()
	if sheet == null:
		return null
	var img := sheet.get_image()
	if img == null:
		return sheet
	if img.is_compressed():
		img.decompress()
	if PORTRAIT_REGION.end.x > img.get_width() or PORTRAIT_REGION.end.y > img.get_height():
		return sheet
	var sub := img.get_region(PORTRAIT_REGION)
	sub.convert(Image.FORMAT_RGBA8)
	var w := sub.get_width()
	var h := sub.get_height()
	var cx := (float(w) - 1.0) * 0.5
	var cy := (float(h) - 1.0) * 0.5
	var r := float(mini(w, h)) * 0.5
	for y in h:
		for x in w:
			var d := Vector2(float(x) - cx, float(y) - cy).length()
			var a := clampf(r - d, 0.0, 1.0)
			if a < 1.0:
				var c := sub.get_pixel(x, y)
				sub.set_pixel(x, y, Color(c.r, c.g, c.b, c.a * a))
	return ImageTexture.create_from_image(sub)


func _build_labels() -> void:
	_lvl = _label("LV 1", Rect2(BADGE_RECT.position.x, 40, BADGE_RECT.size.x, BADGE_RECT.size.y - 1.0), 6, INK)
	_lvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lvl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_hp_text = _label("100 / 100", Rect2(HP_RECT.position.x + 7.0, 6, HP_RECT.size.x - 20.0, 12.0), 7, Color.WHITE)
	_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_text.add_theme_constant_override("outline_size", 1)

	_st_text = _label("100 / 100", Rect2(ST_RECT.position.x + 4.0, 23 + 1.0, ST_RECT.size.x - 20.0, 10.0), 6, Color.WHITE)
	_st_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_st_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_st_text.add_theme_constant_override("outline_size", 1)

	_coin_tex = Art.tex("icon_coin")
	_gold_text = _label("0", Rect2(73.0, 38.0, 110.0, 11.0), 7, GOLD_L)
	_gold_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _label(text: String, rect: Rect2, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = rect.position
	l.size = rect.size
	l.add_theme_font_override("font", UI.title_font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.03, 0.95))
	l.add_theme_constant_override("outline_size", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _build_card() -> void:
	_card = Panel.new()
	_card.position = Vector2(W + 4.0, 0)
	_card.size = Vector2(CARD_W, CARD_H)
	_card.visible = false
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.theme = UI.hud_theme()

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.06, 0.90)
	sb.border_color = Color(0.95, 0.90, 0.78, 0.28)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	_card.add_theme_stylebox_override("panel", sb)
	add_child(_card)

	_card_text = UI.label(_card, "", 4, UI.CREAM)
	_card_text.position = Vector2(5, 4)
	_card_text.size = Vector2(CARD_W - 3, CARD_H - 3)
	_card_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.gui_input.connect(_on_press)


# ---------------------------------------------------------------- data
func bind(p: Node) -> void:
	_unbind()
	player = p
	if p == null or not is_instance_valid(p):
		return
	if p.has_signal("hp_changed"):
		p.hp_changed.connect(_on_hp)
	if p.has_signal("stamina_changed"):
		p.stamina_changed.connect(_on_st)
	_on_hp(float(p.get("hp")), float(p.get("max_hp")))
	_on_st(float(p.get("stamina")), float(p.get("max_stamina")))
	_hp_shown = _hp_ratio
	_st_shown = _st_ratio


func _unbind() -> void:
	if player == null or not is_instance_valid(player):
		player = null
		return
	if player.hp_changed.is_connected(_on_hp):
		player.hp_changed.disconnect(_on_hp)
	if player.stamina_changed.is_connected(_on_st):
		player.stamina_changed.disconnect(_on_st)
	player = null


func _on_hp(hp: float, max_hp: float) -> void:
	var r := clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
	if r < _hp_ratio - 0.002:
		_hp_flash = 1.0
	_hp_ratio = r
	_refresh_texts()
	queue_redraw()


func _on_st(value: float, max_value: float) -> void:
	var r := clampf(value / maxf(max_value, 1.0), 0.0, 1.0)
	if r > _st_ratio + 0.05:
		_st_glow = 1.0
	_st_ratio = r
	_refresh_texts()
	queue_redraw()


func _on_money(money: int, _delta: int) -> void:
	if _gold_text != null:
		_gold_text.text = "%d" % money


func _on_level_up(level: int) -> void:
	if _lvl != null:
		_lvl.text = "LV %d" % level


func _refresh_texts() -> void:
	if player == null or not is_instance_valid(player) or _hp_text == null:
		return
	var hp_str := "%d / %d" % [int(ceil(float(player.hp))), int(ceil(float(player.max_hp)))]
	if hp_str != _hp_str:
		_hp_str = hp_str
		_hp_text.text = hp_str
	var st_str := "%d / %d" % [int(ceil(float(player.stamina))), int(ceil(float(player.max_stamina)))]
	if st_str != _st_str:
		_st_str = st_str
		_st_text.text = st_str


# ---------------------------------------------------------------- input / card
func _on_press(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_card_open = not _card_open
		_card.visible = _card_open
		_card_left = 0.0
		Sfx.play("click", 1.35, -20.0)


func _process(delta: float) -> void:
	_t += delta
	if player != null and is_instance_valid(player):
		var r := clampf(float(player.hp) / maxf(float(player.max_hp), 1.0), 0.0, 1.0)
		if r < _hp_ratio - 0.002:
			_hp_flash = 1.0
		_hp_ratio = r
		_st_ratio = clampf(float(player.stamina) / maxf(float(player.max_stamina), 1.0), 0.0, 1.0)

	var moving := false
	if absf(_hp_shown - _hp_ratio) > 0.002:
		_hp_shown = move_toward(_hp_shown, _hp_ratio, delta * 1.8)
		moving = true
	else:
		_hp_shown = _hp_ratio
	if absf(_st_shown - _st_ratio) > 0.002:
		_st_shown = move_toward(_st_shown, _st_ratio, delta * 2.6)
		moving = true
	else:
		_st_shown = _st_ratio
	if _hp_flash > 0.0:
		_hp_flash = maxf(0.0, _hp_flash - delta * 3.6)
		moving = true
	if _st_glow > 0.0:
		_st_glow = maxf(0.0, _st_glow - delta * 2.6)
		moving = true
	if _hp_ratio <= 0.25:
		moving = true
	if moving:
		queue_redraw()

	if _card_open:
		_card_left += delta
		if _card_left > 6.0:
			_card_open = false
			_card.visible = false
		_card_text.text = "%s\nHP %d/%d\nพลัง %d/%d\nอาวุธ %s\nกระเป๋า %d/%d\nมลพิษ %d%%" % [
			"RECLAIMER",
			int(ceil(float(player.hp))), int(ceil(float(player.max_hp))),
			int(ceil(float(player.stamina))), int(ceil(float(player.max_stamina))),
			String(Inventory.weapon_def()["name"]),
			Inventory.count(), Inventory.capacity(),
			int(round(Pollution.pct)),
		]


# ---------------------------------------------------------------- drawing
func _draw() -> void:
	_draw_plate()
	_draw_portrait()
	_draw_portrait_frame()
	_draw_level_badge()
	_draw_bar(HP_RECT, _hp_shown, HP_BANDS, _hp_flash, false)
	_draw_bar(ST_RECT, _st_shown, ST_BANDS, 0.0, true)
	_draw_health_icon()
	_draw_stamina_icon()
	_draw_coin()


func _draw_plate() -> void:
	draw_rect(Rect2(0, 0, W, H), IRON)
	draw_rect(Rect2(1, 1, W - 2, H - 2), STEEL)
	draw_rect(Rect2(2, 2, W - 4, H - 4), PLATE)
	# bevel: light top-left, dark bottom-right
	draw_line(Vector2(3, 3), Vector2(W - 4, 3), Color(STEEL_L.r, STEEL_L.g, STEEL_L.b, 0.35), 1.0)
	draw_line(Vector2(3, 3), Vector2(3, H - 4), Color(STEEL_L.r, STEEL_L.g, STEEL_L.b, 0.22), 1.0)
	draw_line(Vector2(3, H - 4), Vector2(W - 4, H - 4), Color(0, 0, 0, 0.55), 1.0)
	draw_line(Vector2(W - 4, 3), Vector2(W - 4, H - 4), Color(0, 0, 0, 0.45), 1.0)
	# gold studs
	for p in [Vector2(2, 2), Vector2(W - 4, 2), Vector2(2, H - 4), Vector2(W - 4, H - 4)]:
		draw_rect(Rect2(p, Vector2(2, 2)), GOLD)
	# top ornament: three small gold diamonds
	for i in 3:
		var x := W * 0.5 + (float(i) - 1.0) * 6.0
		draw_rect(Rect2(Vector2(x - 1.0, 1.0), Vector2(2, 2)), GOLD_L if i == 1 else GOLD_D)


func _draw_portrait() -> void:
	if _portrait_tex == null:
		return
	var dest := Rect2((PORTRAIT_C - Vector2(PORTRAIT_R, PORTRAIT_R)).floor(), Vector2(PORTRAIT_R * 2.0, PORTRAIT_R * 2.0))
	draw_texture_rect(_portrait_tex, dest, false)


func _draw_portrait_frame() -> void:
	var c := PORTRAIT_C
	# stroked rings, not filled discs, so the portrait stays visible
	draw_arc(c, PORTRAIT_R + 2.5, 0.0, TAU, 48, IRON, 5.0, false)
	draw_arc(c, PORTRAIT_R + 2.0, 0.0, TAU, 48, STEEL, 2.0, false)
	draw_arc(c, PORTRAIT_R + 0.5, 0.0, TAU, 48, GOLD, 1.0, false)
	# rivets at the four compass points
	for i in 4:
		var a := TAU * float(i) / 4.0 + PI * 0.25
		var p := c + Vector2(cos(a), sin(a)) * (PORTRAIT_R + 2.0)
		draw_rect(Rect2((p - Vector2(1, 1)).floor(), Vector2(2, 2)), GOLD_L)


func _draw_level_badge() -> void:
	var b := BADGE_RECT
	draw_rect(b.grow(1.0), IRON)
	draw_rect(b, GOLD_D)
	draw_rect(Rect2(b.position + Vector2(1, 1), b.size - Vector2(2, 2)), GOLD)
	draw_rect(Rect2(b.position + Vector2(1, 1), Vector2(b.size.x - 2.0, 2.0)), GOLD_L)
	# pointed ends
	draw_colored_polygon(PackedVector2Array([
		Vector2(b.position.x - 3.0, b.position.y + b.size.y * 0.5),
		Vector2(b.position.x, b.position.y),
		Vector2(b.position.x, b.position.y + b.size.y),
	]), GOLD)
	draw_colored_polygon(PackedVector2Array([
		Vector2(b.end.x + 3.0, b.position.y + b.size.y * 0.5),
		Vector2(b.end.x, b.position.y),
		Vector2(b.end.x, b.position.y + b.size.y),
	]), GOLD)


func _draw_bar(rect: Rect2, ratio: float, bands: Array[Color], flash: float, stamina: bool) -> void:
	var r := Rect2(rect.position.floor(), rect.size.floor())
	# ornate metal frame
	draw_rect(r.grow(1.0), IRON)
	draw_rect(r, STEEL)
	draw_rect(r, STEEL_D, false, 1.0)
	draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2.0, 1.0)), STEEL_L)
	for p in [r.position, Vector2(r.end.x - 2.0, r.position.y), Vector2(r.position.x, r.end.y - 2.0), r.end - Vector2(2, 2)]:
		draw_rect(Rect2(p, Vector2(2, 2)), GOLD)

	var inner := Rect2(r.position + Vector2(2, 2), r.size - Vector2(4, 4))
	draw_rect(inner, Color("1d0a0b") if not stamina else Color("08201f"))

	var fw := floorf(inner.size.x * clampf(ratio, 0.0, 1.0))
	if fw > 0.0:
		var band_h := inner.size.y / float(bands.size())
		for i in bands.size():
			var y0 := inner.position.y + floorf(band_h * float(i))
			var y1 := inner.position.y + floorf(band_h * float(i + 1))
			draw_rect(Rect2(Vector2(inner.position.x, y0), Vector2(fw, maxf(1.0, y1 - y0))), bands[i])
		draw_rect(Rect2(inner.position, Vector2(fw, 1.0)), bands[0].lightened(0.25))
		# gold end caps
		draw_rect(Rect2(inner.position, Vector2(2.0, inner.size.y)), GOLD_D)
		draw_rect(Rect2(Vector2(inner.position.x + fw - 2.0, inner.position.y), Vector2(2.0, inner.size.y)), GOLD_D)

	if flash > 0.0:
		draw_rect(inner, Color(1.0, 0.35, 0.28, 0.45 * flash))
	if stamina and _st_glow > 0.0:
		draw_rect(inner, Color(0.85, 1.0, 1.0, 0.30 * _st_glow))
	if not stamina and _hp_ratio <= 0.25:
		var pulse := 0.5 + 0.5 * sin(_t * 6.0)
		draw_rect(inner, Color(1.0, 0.25, 0.18, 0.10 + 0.10 * pulse))


func _draw_coin() -> void:
	if _coin_tex != null:
		draw_texture_rect(_coin_tex, Rect2(58.0, 43.0, 12.0, 12.0), false)


func _draw_health_icon() -> void:
	# small pixel heart beside the HP bar
	var bx := 45.0
	var by := 13.0
	var rows := [[1, 0, 2], [4, 0, 2], [0, 1, 7], [0, 2, 7], [1, 3, 5], [2, 4, 3], [3, 5, 1]]
	for row in rows:
		var col := HP_BANDS[0] if int(row[1]) < 4 else HP_BANDS[1]
		draw_rect(Rect2(bx + float(row[0]), by + float(row[1]), float(row[2]), 1.0), col)


func _draw_stamina_icon() -> void:
	# small pixel lightning bolt beside the stamina bar
	var bx := 45.0
	var by := 31.0
	var rows := [[3, 0, 2], [2, 1, 2], [1, 2, 2], [0, 3, 5], [2, 4, 2], [1, 5, 2], [0, 6, 2]]
	for row in rows:
		draw_rect(Rect2(bx + float(row[0]), by + float(row[1]), float(row[2]), 1.0), ST_BANDS[0])
