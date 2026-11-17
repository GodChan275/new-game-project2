extends Node
## Combat resolution, floating damage text, screen shake.

const FLOAT_SCENE := preload("res://FloatingText.tscn")

var world: Node2D
var camera: Camera2D
var enemies: Array = []

var _shake_amount := 0.0
var _shake_time := 0.0


func reset() -> void:
	enemies.clear()
	_shake_amount = 0.0
	_shake_time = 0.0


func register_enemy(e: Node2D) -> void:
	if not enemies.has(e):
		enemies.append(e)


func unregister_enemy(e: Node2D) -> void:
	enemies.erase(e)


func live_enemies() -> int:
	var n := 0
	for e in enemies:
		if is_instance_valid(e):
			n += 1
	return n


## Arc melee sweep. `radial` knocks enemies away from the origin instead of
## along `dir`, which is what the 360 degree touch sweep needs.
func melee(origin: Vector2, dir: Vector2, reach: float, arc_deg: float, dmg: float, knock: float, radial := false) -> int:
	var hits := 0
	var half := deg_to_rad(arc_deg) * 0.5
	for e in enemies.duplicate():
		if not is_instance_valid(e):
			continue
		var to: Vector2 = (e.global_position - origin)
		var dist := to.length()
		var radius := 10.0
		var rv = e.get("radius")
		if rv != null:
			radius = float(rv)
		if dist > reach + radius:
			continue
		if not radial:
			var ang := absf(dir.angle_to(to.normalized())) if dist > 0.5 else 0.0
			if ang > half:
				continue
		var push := dir
		if radial and dist > 0.5:
			push = to.normalized()
		e.take_damage(dmg, push)
		hits += 1
	if hits > 0:
		shake(2.2)
		Sfx.play("hit", randf_range(0.9, 1.1))
	return hits


func shake(amount: float) -> void:
	_shake_amount = maxf(_shake_amount, amount)
	_shake_time = 0.18


func floating(text: String, pos: Vector2, color: Color = Color.WHITE, big: bool = false) -> void:
	if world == null:
		return
	var f: Node2D = FLOAT_SCENE.instantiate()
	world.add_child(f)
	f.global_position = pos + Vector2(randf_range(-3, 3), -8)
	if f.has_method("show_text"):
		f.show_text(text, color, big)


func _process(delta: float) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	if _shake_time > 0.0:
		_shake_time -= delta
		var amt := _shake_amount * maxf(0.0, _shake_time / 0.18)
		camera.offset = Vector2(randf_range(-amt, amt), randf_range(-amt, amt))
	else:
		_shake_amount = 0.0
		if camera.offset != Vector2.ZERO:
			camera.offset = camera.offset.lerp(Vector2.ZERO, clampf(delta * 12.0, 0.0, 1.0))
