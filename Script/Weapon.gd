extends Node2D
## Shows the equipped weapon in the player's hand.

@onready var sprite: Sprite2D = $Sprite

var weapon_id := ""


func _ready() -> void:
	if sprite != null:
		sprite.position = Vector2(7, 0)


func set_weapon(id: String) -> void:
	weapon_id = id
	if sprite != null:
		sprite.texture = ItemDB.item_icon(id)
		sprite.scale = Vector2(0.55, 0.55)


func aim_at(aim: Vector2, dir: String) -> void:
	position = aim * 8.0 + Vector2(0, -12)
	rotation = aim.angle()
	if sprite != null:
		sprite.flip_v = dir == "left"
	z_index = 1
