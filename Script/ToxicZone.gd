extends Node2D
## Toxic spill. Damages the player while standing in it.

var radius := 22.0
var _t := 0.0

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	sprite.texture = Art.tex("toxic_spot")
	radius = 22.0 * scale.x
	_t = randf() * 6.0
	add_to_group("toxic")


func _process(delta: float) -> void:
	_t += delta
	rotation += delta * 0.12
	if sprite != null:
		sprite.modulate.a = 0.78 + 0.16 * sin(_t * 3.1)
