extends Node2D
## Floating combat text.

@onready var label: Label = $Label


func _ready() -> void:
	label.position = Vector2(-46, -8)
	label.size = Vector2(92, 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	label.add_theme_constant_override("outline_size", 3)


func show_text(t: String, c: Color, big := false) -> void:
	label.text = t
	label.add_theme_color_override("font_color", c)
	label.add_theme_font_size_override("font_size", 11 if big else 8)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:y", position.y - 18.0, 0.75)
	tw.tween_property(label, "modulate:a", 0.0, 0.55).set_delay(0.3)
	tw.chain().tween_callback(queue_free)
