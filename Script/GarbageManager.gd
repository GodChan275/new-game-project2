extends Node
## Spawns, tracks and removes garbage nodes in the world.

const SCENE := preload("res://Garbage.tscn")
const MAX_ITEMS := 80

var world: Node2D
var items: Array = []


func reset() -> void:
	for g in items.duplicate():
		if is_instance_valid(g):
			g.queue_free()
	items.clear()


func spawn(pos: Vector2, cat: int = -1, id: String = "") -> Node2D:
	if world == null or items.size() >= MAX_ITEMS:
		return null
	var gid := id
	if gid == "":
		gid = ItemDB.random_waste(cat)
	var node: Node2D = SCENE.instantiate()
	world.add_child(node)
	node.global_position = pos
	if node.has_method("setup"):
		node.setup(gid)
	items.append(node)
	Pollution.recalc()
	return node


func remove(node: Node2D) -> void:
	items.erase(node)
	if is_instance_valid(node):
		node.queue_free()
	Pollution.recalc()


func nearest(pos: Vector2, radius: float) -> Node2D:
	var best: Node2D = null
	var best_d := radius
	for g in items:
		if not is_instance_valid(g):
			continue
		var d: float = g.global_position.distance_to(pos)
		if d <= best_d:
			best_d = d
			best = g
	return best


func scatter(center: Vector2, radius: float, count: int, cat: int = -1) -> void:
	for i in count:
		var pos := GameManager.free_spot(center, radius)
		spawn(pos, cat)


## Fills the map with starting litter. Later days start dirtier.
func populate(day: int) -> void:
	var spots: Array = GameManager.map_regions()
	if spots.is_empty():
		return
	var total := 10 + day * 2
	for i in total:
		var c: Vector2 = spots[randi() % spots.size()]
		spawn(GameManager.free_spot(c, 130.0), randi() % 4)
