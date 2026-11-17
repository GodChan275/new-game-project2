extends CharacterBody2D
## Invader AI: chase, attack, scatter garbage, die.

const STATS := {
	"runner": {"hp": 26.0, "speed": 100.0, "dmg": 6.0, "reward": 7, "radius": 8.0,
		"sheet": "enemy_runner", "fw": 20, "fh": 22, "cat": 0, "every": 9.0},
	"brute": {"hp": 95.0, "speed": 47.0, "dmg": 16.0, "reward": 18, "radius": 12.0,
		"sheet": "enemy_brute", "fw": 32, "fh": 32, "cat": 1, "every": 12.0},
	"toxic": {"hp": 50.0, "speed": 62.0, "dmg": 9.0, "reward": 13, "radius": 11.0,
		"sheet": "enemy_toxic", "fw": 28, "fh": 28, "cat": 1, "every": 10.0},
	"swarm": {"hp": 14.0, "speed": 118.0, "dmg": 3.0, "reward": 4, "radius": 6.0,
		"sheet": "enemy_swarm", "fw": 16, "fh": 16, "cat": 2, "every": 11.0},
}

var type := "runner"
var hp := 20.0
var max_hp := 20.0
var speed := 50.0
var dmg := 5.0
var reward := 5
var radius := 8.0
var scatter_cat := 2
var scatter_every := 5.0

var dead := false

var _sheet := "enemy_runner"
var _fw := 20
var _fh := 22
var _atk_cd := 1.0
var _scatter_t := 3.0
var _anim_lock := 0.0
var _knock := Vector2.ZERO
var _target: Node2D = null
var _hit_flash := 0.0
var _hp_bg: ColorRect
var _hp_fill: ColorRect

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var shadow: Sprite2D = $Shadow


func setup(t: String, day: int) -> void:
	type = t
	var s: Dictionary = STATS.get(t, STATS["runner"])
	max_hp = float(s["hp"]) * (1.0 + 0.13 * float(day - 1))
	hp = max_hp
	speed = float(s["speed"]) + float(day - 1) * 2.0
	dmg = float(s["dmg"]) * (1.0 + 0.08 * float(day - 1))
	reward = int(s["reward"]) + day
	radius = float(s["radius"])
	scatter_cat = int(s["cat"])
	scatter_every = float(s["every"])
	_sheet = String(s["sheet"])
	_fw = int(s["fw"])
	_fh = int(s["fh"])


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	sprite.sprite_frames = Art.strip_frames(Art.tex(_sheet), _fw, _fh, 4)
	sprite.offset = Vector2(0, -_fh / 2.0)
	sprite.play("walk")
	shadow.texture = Art.tex("shadow")
	shadow.position = Vector2(0, -1)
	shadow.scale = Vector2(radius / 9.0, radius / 12.0)
	_target = GameManager.player
	_scatter_t = randf_range(1.5, scatter_every)
	_hp_bg = ColorRect.new()
	_hp_bg.color = Color(0.05, 0.05, 0.06, 0.85)
	_hp_bg.size = Vector2(16, 3)
	_hp_bg.position = Vector2(-8, -_fh - 7)
	_hp_bg.visible = false
	_hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hp_bg)
	_hp_fill = ColorRect.new()
	_hp_fill.color = Color("e04a4a")
	_hp_fill.position = Vector2.ONE
	_hp_fill.size = Vector2(14, 1)
	_hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_bg.add_child(_hp_fill)
	Combat.register_enemy(self)
	add_to_group("enemies")


func _exit_tree() -> void:
	Combat.unregister_enemy(self)


func _physics_process(delta: float) -> void:
	if dead:
		return
	_atk_cd = maxf(0.0, _atk_cd - delta)
	_anim_lock = maxf(0.0, _anim_lock - delta)
	_hit_flash = maxf(0.0, _hit_flash - delta)
	if _hit_flash <= 0.0:
		sprite.modulate = Color.WHITE
	if _target == null or not is_instance_valid(_target):
		_target = GameManager.player

	var to := Vector2.ZERO
	var dist := 99999.0
	if _target != null and is_instance_valid(_target):
		to = _target.global_position - global_position
		dist = to.length()

	var move := Vector2.ZERO
	if dist < 440.0:
		if dist > radius + 12.0:
			move = to.normalized() * speed
		if dist <= radius + 16.0 and _atk_cd <= 0.0:
			_attack()
		sprite.flip_h = to.x < 0.0
		if _anim_lock <= 0.0:
			var want := "walk" if move.length() > 1.0 else "idle"
			if sprite.animation != want:
				sprite.play(want)
	velocity = move + _knock
	_knock = _knock.lerp(Vector2.ZERO, clampf(delta * 9.0, 0.0, 1.0))
	move_and_slide()
	if _hp_bg != null:
		_hp_bg.visible = hp < max_hp - 0.01
		var ratio := clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
		_hp_fill.size = Vector2(maxf(1.0, 14.0 * ratio), 1.0)
		_hp_fill.color = Color("e04a4a") if ratio > 0.35 else Color("e8c832")

	_scatter_t -= delta
	if _scatter_t <= 0.0:
		_scatter_t = scatter_every * randf_range(0.8, 1.3)
		if GameManager.is_invasion() and Garbage.items.size() < 52:
			Garbage.spawn(GameManager.free_spot(global_position, 20.0), scatter_cat)
		if type == "toxic" and GameManager.is_invasion() and Pollution.zones.size() < 16:
			Pollution.spawn_zone(global_position + Vector2(randf_range(-8, 8), randf_range(-8, 8)))


func _attack() -> void:
	_atk_cd = randf_range(0.9, 1.3)
	_anim_lock = 0.45
	sprite.play("attack")
	if _target != null and is_instance_valid(_target) and _target.has_method("take_damage"):
		_target.take_damage(dmg, global_position)
	Sfx.play("hit", 0.8, -14.0)


func take_damage(amount: float, dir: Vector2) -> void:
	if dead:
		return
	hp -= amount
	Combat.floating(str(int(round(amount))), global_position + Vector2(0, -14), Color("ffe08a"))
	_knock = dir.normalized() * 130.0
	_hit_flash = 0.14
	sprite.modulate = Color(1, 0.55, 0.55)
	Sfx.play("hit", randf_range(1.05, 1.25), -12.0)
	if hp <= 0.0:
		_die()


func _die() -> void:
	if dead:
		return
	dead = true
	Combat.unregister_enemy(self)
	collision_layer = 0
	collision_mask = 0
	sprite.play("die")
	if _hp_bg != null:
		_hp_bg.visible = false
	Sfx.play("enemy_die", randf_range(0.9, 1.1))
	Economy.add_money(reward)
	Economy.add_xp(6)
	Quests.report("kill", 1)
	Combat.floating("+$%d" % reward, global_position + Vector2(0, -22), Color("e8c832"))
	if randf() < 0.5:
		Garbage.spawn(GameManager.free_spot(global_position, 14.0), -1)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.45).set_delay(0.3)
	tw.tween_callback(queue_free)


func flee() -> void:
	if dead:
		return
	dead = true
	Combat.unregister_enemy(self)
	collision_layer = 0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.55)
	tw.tween_callback(queue_free)
