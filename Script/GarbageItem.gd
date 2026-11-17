extends Node2D
## A single piece of garbage lying in the world. The nearest one shows a floating
## label with its Thai name and category; everything else stays label-free.

var waste_id := "dirty_wrapper"
var weight := 1.0
var cat := 2

var _t := 0.0
var _focused := false

@onready var sprite: Sprite2D = $Sprite
@onready var glow: Sprite2D = $Glow
@onready var tag: Label = get_node_or_null("Tag") as Label
@onready var tag_cat: Label = get_node_or_null("TagCat") as Label


func _ready() -> void:
	_t = randf() * 10.0
	if glow != null:
		glow.texture = Art.tex("dot")
	_style_tag(tag, 6)
	_style_tag(tag_cat, 5)
	if tag != null:
		tag.visible = false
	if tag_cat != null:
		tag_cat.visible = false
	_apply()
	add_to_group("garbage")


func setup(id: String) -> void:
	waste_id = id
	if is_inside_tree():
		_apply()


func _style_tag(l: Label, size: int) -> void:
	if l == null:
		return
	l.theme = UI.theme()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", 3)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _apply() -> void:
	cat = ItemDB.waste_cat(waste_id)
	weight = ItemDB.waste_weight(waste_id)
	if sprite != null:
		sprite.texture = ItemDB.waste_icon(waste_id)
	if glow != null:
		var gc := ItemDB.cat_color(cat)
		glow.modulate = Color(gc.r, gc.g, gc.b, 0.28)
	if tag != null:
		tag.text = String(ItemDB.waste_def(waste_id)["name"])
		tag.add_theme_color_override("font_color", Color("f6e3ba"))
	if tag_cat != null:
		tag_cat.text = String(ItemDB.cat_thai(cat))
		tag_cat.add_theme_color_override("font_color", ItemDB.cat_color(cat).lightened(0.18))


## Only the closest waste item is labelled, so the screen never fills with text.
func set_focused(on: bool) -> void:
	if _focused == on:
		return
	_focused = on
	if tag != null:
		tag.visible = on
	if tag_cat != null:
		tag_cat.visible = on
	if not on:
		return
	modulate = Color(1.16, 1.16, 1.08)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.18)
	for l in [tag, tag_cat]:
		if l == null:
			continue
		l.modulate.a = 0.0
		create_tween().tween_property(l, "modulate:a", 1.0, 0.16)


func _process(delta: float) -> void:
	_t += delta
	if sprite != null:
		sprite.position.y = -6.0 + sin(_t * 2.2) * 1.1
