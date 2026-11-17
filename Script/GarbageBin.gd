extends Node2D
## A sorting bin. bin_cat must be set before it enters the tree.

var bin_cat := 0

@onready var sprite: Sprite2D = $Sprite
@onready var tag: Label = $Tag


func _ready() -> void:
	if sprite != null:
		sprite.texture = Art.tex(ItemDB.bin_texture(bin_cat))
		if sprite.texture != null:
			sprite.scale = Vector2(1.3, 1.3)
			sprite.offset = Vector2(0, -sprite.texture.get_height() / 2.0)
	if tag != null:
		tag.text = String(ItemDB.cat_thai(bin_cat))
		tag.add_theme_color_override("font_color", ItemDB.cat_color(bin_cat))
		tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		tag.add_theme_constant_override("outline_size", 2)
		tag.add_theme_font_size_override("font_size", 8)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.size = Vector2(56, 9)
		# alternate label rows so neighbouring bins never overlap
		if bin_cat % 2 == 1:
			tag.position = Vector2(-28, -50)
		else:
			tag.position = Vector2(-28, 10)
	add_to_group("bins")


func set_highlight(on: bool) -> void:
	modulate = Color(1.3, 1.28, 1.15) if on else Color.WHITE
