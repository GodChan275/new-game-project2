extends Node
## Shared visual language for TOXIC WASTELAND: fonts, palette, panel and widget
## factories. The provided "Pixel Game" font files are picked up automatically when
## they are placed in Assets/Fonts; Thai glyphs fall back to Noto Sans Thai.

const CREAM := Color("efe6cf")
const MUTED := Color("9aa78d")
const GOLD := Color("e8c832")
const GREEN := Color("8ad02a")
const RED := Color("e04a4a")
const ORANGE := Color("e67828")
const BLUE := Color("5aa0e8")
const LINE := Color("5d7048")
const INK := Color("0d1410")
## --- reference palette: cream paper panels with warm wooden outlines ---
const PAPER := Color("f3e4c2")
const PAPER_D := Color("e5d0a6")
const PAPER_EDGE := Color("bb8c5e")
const PAPER_EDGE_D := Color("8a6242")
const INK_BROWN := Color("4a3524")
const INK_SOFT := Color("7d6549")
const GREEN_DEEP := Color("3f7a36")
const GREEN_MID := Color("57a747")
const GOLD_DEEP := Color("bf801c")
const RED_DEEP := Color("b8443a")
const BLUE_DEEP := Color("3d6fa8")

const PARCH := Color("e6d9b8")
const PARCH_LINE := Color("4a3b28")
const PARCH_INK := Color("2b2318")
const PARCH_MUTED := Color("6b5b40")

var body_font: Font
var title_font: Font
var thai_font: Font

var _theme: Theme
var _hud_theme: Theme


func _ready() -> void:
	_build_fonts()


func _try_font(path: String) -> Font:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Font


func _crisp(f: Font) -> Font:
	if f is FontFile:
		var ff := f as FontFile
		ff.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		ff.hinting = TextServer.HINTING_NONE
	return f


func _system_thai() -> Font:
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Leelawadee UI", "Tahoma", "Noto Sans Thai", "Sarabun"])
	return sf


func _build_fonts() -> void:
	thai_font = _try_font("res://Assets/Fonts/Anuphan-Regular.ttf")	
	if thai_font is FontFile:
		(thai_font as FontFile).antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	if thai_font == null:
		thai_font = _system_thai()

	body_font = _try_font("res://Assets/Fonts/Pixel Game.otf")
	if body_font == null:
		body_font = _try_font("res://Assets/Fonts/Prompt.ttf")
	if body_font == null:
		body_font = ThemeDB.fallback_font
	body_font = _crisp(body_font)

	title_font = _try_font("res://Assets/Fonts/Pixel Game Extrude.otf")
	if title_font == null:
		title_font = _try_font("res://Assets/Fonts/Prompt.ttf")
	if title_font == null:
		title_font = body_font
	title_font = _crisp(title_font)

	var fb: Array[Font] = []
	fb.append(thai_font)
	if body_font is FontFile:
		(body_font as FontFile).fallbacks = fb
	if title_font is FontFile:
		(title_font as FontFile).fallbacks = fb


func theme() -> Theme:
	if _theme != null:
		return _theme
	_theme = Theme.new()
	_theme.default_font = body_font
	_theme.default_font_size = 10

	_theme.set_stylebox("panel", "Panel", dark_box())
	_theme.set_stylebox("panel", "PanelContainer", dark_box())
	_theme.set_stylebox("normal", "Button", btn_box(Color(0.11, 0.16, 0.12, 0.94), LINE))
	_theme.set_stylebox("hover", "Button", btn_box(Color(0.16, 0.24, 0.15, 0.98), GREEN))
	_theme.set_stylebox("pressed", "Button", btn_box(Color(0.09, 0.13, 0.09, 1.0), GOLD))
	_theme.set_stylebox("disabled", "Button", btn_box(Color(0.08, 0.09, 0.08, 0.6), Color(0.28, 0.31, 0.26)))
	_theme.set_stylebox("focus", "Button", btn_box(Color(0, 0, 0, 0), GOLD))
	_theme.set_color("font_color", "Button", CREAM)
	_theme.set_color("font_hover_color", "Button", Color("f7f1da"))
	_theme.set_color("font_pressed_color", "Button", GOLD)
	_theme.set_color("font_disabled_color", "Button", Color(0.45, 0.48, 0.42))
	_theme.set_font_size("font_size", "Button", 10)
	_theme.set_color("font_color", "Label", CREAM)
	_theme.set_font_size("font_size", "Label", 10)
	_theme.set_stylebox("panel", "TooltipPanel", dark_box(0.98))
	_theme.set_color("font_color", "TooltipLabel", CREAM)
	_theme.set_font_size("font_size", "TooltipLabel", 10)
	_theme.set_color("font_color", "RichTextLabel", CREAM)
	_theme.set_font_size("normal_font_size", "RichTextLabel", 10)
	return _theme


# ---------------------------------------------------------------- boxes
func dark_box(alpha := 0.93) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.086, 0.129, 0.098, alpha)
	sb.border_color = LINE
	sb.set_border_width_all(1)
	sb.set_content_margin_all(3)
	return sb


## Cream RPG panel with a wooden border, rounded pixel corners and a soft shadow.
func paper_box(alpha := 1.0, border := 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PAPER.r, PAPER.g, PAPER.b, alpha)
	sb.border_color = PAPER_EDGE
	sb.set_border_width_all(border)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(4)
	sb.shadow_color = Color(0, 0, 0, 0.28)
	sb.shadow_size = 2
	sb.shadow_offset = Vector2(0, 1)
	return sb


## Transparent button background used by icon-only controls on cream panels.
func plain_box(hover := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.0) if not hover else Color("efe1bd")
	sb.set_corner_radius_all(2)
	sb.set_content_margin_all(1)
	return sb


## Inset well used for lists, bars and slot frames on cream panels.
func well_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER_D
	sb.border_color = Color(PAPER_EDGE.r, PAPER_EDGE.g, PAPER_EDGE.b, 0.75)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.set_content_margin_all(2)
	return sb


## Theme used by the cream HUD panels (dark ink text, wooden buttons).
func hud_theme() -> Theme:
	if _hud_theme != null:
		return _hud_theme
	_hud_theme = Theme.new()
	_hud_theme.default_font = body_font
	_hud_theme.default_font_size = 10
	_hud_theme.set_color("font_color", "Label", INK_BROWN)
	_hud_theme.set_font_size("font_size", "Label", 10)
	_hud_theme.set_stylebox("panel", "Panel", paper_box())
	_hud_theme.set_stylebox("panel", "PanelContainer", paper_box())
	_hud_theme.set_stylebox("normal", "Button", btn_box(PAPER_D, PAPER_EDGE))
	_hud_theme.set_stylebox("hover", "Button", btn_box(Color("f7ecd2"), GREEN_MID))
	_hud_theme.set_stylebox("pressed", "Button", btn_box(PAPER_D, GOLD_DEEP))
	_hud_theme.set_stylebox("focus", "Button", btn_box(Color(0, 0, 0, 0), GOLD_DEEP))
	_hud_theme.set_color("font_color", "Button", INK_BROWN)
	_hud_theme.set_color("font_hover_color", "Button", GREEN_DEEP)
	_hud_theme.set_color("font_pressed_color", "Button", INK_BROWN)
	_hud_theme.set_font_size("font_size", "Button", 10)
	return _hud_theme


func parch_box(alpha := 1.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PARCH.r, PARCH.g, PARCH.b, alpha)
	sb.border_color = PARCH_LINE
	sb.set_border_width_all(1)
	sb.set_content_margin_all(3)
	return sb


func slot_box(selected := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.15, 0.11, 0.95) if not selected else Color(0.19, 0.27, 0.16, 0.98)
	sb.border_color = GOLD if selected else Color(0.30, 0.37, 0.30)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(2)
	return sb


func btn_box(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	return sb


# ---------------------------------------------------------------- factories
func label(parent: Node, text: String, size := 15, color := CREAM) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func title_label(parent: Node, text: String, size := 10, color := GOLD) -> Label:
	var l := label(parent, text, size, color)
	l.add_theme_font_override("font", title_font)
	return l


## PanelContainer with an inner margin + VBox. Returns the VBox for content.
func panel(parent: Node, pad := 4) -> VBoxContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", dark_box())
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", pad)
	m.add_theme_constant_override("margin_right", pad)
	m.add_theme_constant_override("margin_top", pad - 1)
	m.add_theme_constant_override("margin_bottom", pad - 1)
	pc.add_child(m)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 1)
	m.add_child(vb)
	parent.add_child(pc)
	return vb


## Thin horizontal divider.
func rule(parent: Node, color := Color(0.42, 0.52, 0.36, 0.55)) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


## Returns {"root": Control, "bg": ColorRect, "fill": ColorRect}.
func bar(parent: Node, height := 5.0, color := GREEN) -> Dictionary:
	var root := Control.new()
	root.custom_minimum_size = Vector2(0, height)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.08, 0.07, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	var fill := ColorRect.new()
	fill.color = color
	fill.position = Vector2(1, 1)
	fill.size = Vector2(0, height - 2)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fill)
	return {"root": root, "bg": bg, "fill": fill}


func set_ratio(bar: Dictionary, ratio: float) -> void:
	if bar.is_empty():
		return
	var root: Control = bar["root"]
	var fill: ColorRect = bar["fill"]
	var w: float = maxf(0.0, root.size.x - 2.0)
	fill.size = Vector2(w * clampf(ratio, 0.0, 1.0), maxf(1.0, root.size.y - 2.0))


func icon(parent: Node, tex: Texture2D, px := 14.0) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.custom_minimum_size = Vector2(px, px)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)
	return tr


func hsep(px := 4) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(px, 0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Small coloured category chip: a dot plus Thai label.
func cat_chip(parent: Node, cat: int, with_text := true) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	parent.add_child(row)
	var dot := ColorRect.new()
	dot.color = ItemDB.cat_color(cat)
	dot.custom_minimum_size = Vector2(5, 5)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(dot)
	if with_text:
		label(row, String(ItemDB.cat_thai(cat)), 6, ItemDB.cat_color(cat))
	return row


func money(value: int) -> String:
	return "\u0e3f%d" % value
