extends Node
## Morning / invasion lighting, warning glow and the flashlight.

var world_modulate: CanvasModulate
var player: Node2D
var flashlight: PointLight2D
var invasion := false
var _pulse := 0.0
var _target := Color(1, 1, 1)

const MORNING_COLOR := Color(1.0, 0.99, 0.94)
const INVASION_COLOR := Color(0.46, 0.5, 0.68)
const CRITICAL_COLOR := Color(0.58, 0.42, 0.48)


func setup(mod: CanvasModulate, p: Node2D) -> void:
	world_modulate = mod
	player = p
	if mod != null:
		mod.color = MORNING_COLOR
	_build_flashlight()


func _build_flashlight() -> void:
	if player == null or not player.is_inside_tree():
		return
	if flashlight != null and is_instance_valid(flashlight):
		return
	flashlight = PointLight2D.new()
	flashlight.texture = Art.tex("light")
	flashlight.texture_scale = 2.2
	flashlight.energy = 1.6
	flashlight.color = Color(0.855, 0.675, 0.012, 0.427)
	flashlight.enabled = false
	player.add_child(flashlight)
	flashlight.position = Vector2(0, -10)


func apply_phase(phase: int) -> void:
	invasion = phase == 1
	_target = INVASION_COLOR if invasion else MORNING_COLOR
	if _is_critical():
		_target = CRITICAL_COLOR
	if flashlight != null and is_instance_valid(flashlight):
		flashlight.enabled = invasion and Inventory.has_equipment("flashlight")


func _is_critical() -> bool:
	return invasion and Pollution.pct >= 80.0


func _process(delta: float) -> void:
	if world_modulate == null:
		return
	var target := _target
	if _is_critical():
		_pulse += delta * 4.0
		target = INVASION_COLOR.lerp(CRITICAL_COLOR, 0.5 + 0.5 * sin(_pulse))
	world_modulate.color = world_modulate.color.lerp(target, clampf(delta * 3.0, 0.0, 1.0))
	if flashlight != null and is_instance_valid(flashlight):
		var want := invasion and Inventory.has_equipment("flashlight")
		flashlight.enabled = want
		if want and player != null and is_instance_valid(player):
			flashlight.position = Vector2(0, -10) + player.aim_dir() * 6.0
