extends Node2D
## Worn equipment visuals (shield on the back).

@onready var shield: Sprite2D = $Shield


func _ready() -> void:
	refresh()


func refresh() -> void:
	if shield == null:
		return
	shield.visible = Inventory.has_equipment("shield")
	shield.texture = Art.tex("icon_shield")
	shield.scale = Vector2(0.5, 0.5)
	shield.position = Vector2(-8, -14)
	shield.modulate = Color(1, 1, 1, 0.95)
