extends Node2D
## Root scene controller: wires the managers to the world and spawns invaders.

const ENEMY_SCENE := preload("res://Enemy.tscn")
const TYPES := ["runner", "runner", "runner", "swarm", "swarm", "toxic", "brute"]

@onready var map: Node2D = $Map
@onready var world: Node2D = $World
@onready var player: CharacterBody2D = $World/Player
@onready var camera = $Camera
@onready var hud: CanvasLayer = $HUD
@onready var world_mod: CanvasModulate = $CanvasModulate


func _ready() -> void:
	randomize()
	GameManager.main = self
	GameManager.map = map
	GameManager.player = player
	GameManager.hud = hud
	Garbage.world = world
	Pollution.world = world
	Combat.world = world
	Combat.camera = camera

	map.build(world)
	player.global_position = map.safe_pos
	_setup_camera()
	DayNight.setup(world_mod, player)
	hud.bind(player, map)
	if GameManager.resume_requested:
		GameManager.resume_requested = false
		GameManager.session_active = true
		GameManager.running = true
		GameManager.begin_morning()
		hud.toast("เล่นต่อ - วันที่ %d" % GameManager.day, Color("8ad02a"))
	else:
		GameManager.start_game()
		hud.toast("วันที่ 1 - เก็บขยะให้หมดก่อนการบุกโจมตี", Color("8ad02a"))



func _process(_delta: float) -> void:
	pass


func _setup_camera() -> void:
	camera.call("setup", player, map.world_size)
	Combat.camera = camera


func find_free_spot(center: Vector2, radius: float) -> Vector2:
	return map.find_free_spot(center, radius)


## Litter is placed when a new morning starts.
func on_morning_start(day: int) -> void:
	if day <= 1 or Garbage.items.is_empty():
		Garbage.populate(day)
	else:
		var spots: Array = map.regions_centers()
		var extra := 4 + day
		for i in extra:
			if spots.is_empty():
				break
			var c: Vector2 = spots[randi() % spots.size()]
			Garbage.spawn(find_free_spot(c, 120.0), -1)
	Pollution.recalc()


func on_invasion_start(_day: int) -> void:
	for i in 2:
		var pos: Vector2 = map.nearest_spawn(player.global_position, 260.0)
		for k in 2:
			Garbage.spawn(pos + Vector2(randf_range(-24, 24), randf_range(-18, 18)), -1)


func spawn_invader(day: int) -> void:
	var t: String = TYPES[randi() % TYPES.size()]
	if day >= 3 and randf() < 0.22:
		t = "brute"
	elif day >= 2 and randf() < 0.18:
		t = "toxic"
	var pos: Vector2 = map.nearest_spawn(player.global_position, 300.0)
	var e: Node2D = ENEMY_SCENE.instantiate()
	e.setup(t, day)
	world.add_child(e)
	e.global_position = pos
	e.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(e, "modulate:a", 1.0, 0.35)
	Combat.floating("!" + t.capitalize(), pos + Vector2(0, -18), Color("e04a4a"))


func clear_enemies(flee: bool) -> void:
	for e in Combat.enemies.duplicate():
		if is_instance_valid(e) and e.has_method("flee") and flee:
			e.flee()
		elif is_instance_valid(e):
			e.queue_free()
	Combat.enemies.clear()
