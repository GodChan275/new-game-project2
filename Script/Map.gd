extends Node2D
## Compact abandoned-forest-village map: 56x56 tiles at 16px (896x896).
## Zones: safe clearing + shop + bins, forest, pond, ruins, waste yard, toxic ground.

const W := 56
const H := 56
const TILE := 16
const BIN_SCENE := preload("res://GarbageBin.tscn")

# Ground atlas (6 columns of 16x16 tiles).
const T_GRASS_A := 0
const T_GRASS_B := 1
const T_GRASS_C := 2
const T_GRASS_DARK := 3
const T_GRASS_FLOWER := 4
const T_MOSS := 5
const T_PATH_A := 6
const T_PATH_B := 7
const T_PATH_C := 8
const T_SAND := 9
const T_DIRT := 10
const T_DARKGRASS := 11
const T_WATER_A := 12
const T_WATER_B := 13
const T_CONCRETE_A := 14
const T_CONCRETE_B := 15
const T_RUBBLE := 16
const T_GRASS_EDGE := 17

const SAFE_PAD := Rect2(90, 330, 262, 132)
const RUINS_GROUND := Rect2(78, 534, 226, 182)
const YARD_GROUND := Rect2(424, 534, 250, 190)
const TOXIC_GROUND := Rect2(650, 650, 226, 196)
const POND_C := Vector2(600, 236)
const POND_R := Vector2(96, 64)

var world: Node2D
var layer: TileMapLayer
var bins: Array = []
var spawn_points: Array[Vector2] = []
var shop_pos := Vector2.ZERO
var safe_pos := Vector2.ZERO
var storage_pos := Vector2.ZERO
var station_pos := Vector2.ZERO
var world_size := Vector2(W * TILE, H * TILE)

var _obstacles: Array[Rect2] = []
var _rng := RandomNumberGenerator.new()
var _regions: Array = []
var _paths: Array = []
var _landmarks: Array = []


func build(w: Node2D) -> void:
	world = w
	_rng.seed = 20261107
	_setup_regions()
	_setup_paths()
	_build_ground()
	_build_pond()
	_build_safe_zone()
	_build_bins()
	_build_ruins()
	_build_yard()
	_build_forest()
	_build_details()
	_build_bounds()
	spawn_points = [
		Vector2(70, 300), Vector2(70, 700), Vector2(300, 60), Vector2(620, 60),
		Vector2(830, 210), Vector2(830, 560), Vector2(760, 840), Vector2(430, 840),
		Vector2(120, 845), Vector2(690, 120),
	]


func _setup_regions() -> void:
	_regions = [
		{"name": "พื้นที่ปลอดภัย", "center": Vector2(200, 396), "size": Vector2(250, 128), "terrain": "concrete", "litter": 1},
		{"name": "ลานรีไซเคิล", "center": Vector2(520, 610), "size": Vector2(230, 170), "terrain": "dirt", "litter": 4},
		{"name": "ป่า", "center": Vector2(130, 140), "size": Vector2(260, 220), "terrain": "grass", "litter": 2},
		{"name": "หมู่บ้านร้าง", "center": Vector2(170, 610), "size": Vector2(200, 160), "terrain": "dirt", "litter": 3},
		{"name": "สระน้ำ", "center": POND_C, "size": Vector2(210, 150), "terrain": "water", "litter": 2},
		{"name": "พื้นที่พิษ", "center": Vector2(755, 740), "size": Vector2(200, 170), "terrain": "mud", "litter": 4},
	]


func _setup_paths() -> void:
	_paths = [
		[Vector2(200, 460), Vector2(210, 500), Vector2(320, 522), Vector2(430, 556), Vector2(512, 596)],
		[Vector2(200, 430), Vector2(330, 424), Vector2(430, 394), Vector2(500, 336), Vector2(512, 306)],
		[Vector2(176, 462), Vector2(168, 528), Vector2(158, 596), Vector2(152, 640)],
		[Vector2(566, 664), Vector2(640, 692), Vector2(716, 730)],
		[Vector2(566, 300), Vector2(614, 372), Vector2(600, 470), Vector2(560, 560)],
		[Vector2(340, 424), Vector2(338, 500), Vector2(360, 540)],
	]


func regions_centers() -> Array:
	var out: Array = []
	for r in _regions:
		for i in int(r["litter"]):
			out.append(r["center"])
	return out


func region_info() -> Array:
	var out: Array = []
	for r in _regions:
		out.append({"name": r["name"], "center": r["center"], "size": r["size"], "terrain": r["terrain"]})
	return out


func landmarks() -> Array:
	return _landmarks


# ---------------------------------------------------------------- ground
func _build_ground() -> void:
	layer = TileMapLayer.new()
	layer.z_index = -30
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world.add_child(layer)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	var src := TileSetAtlasSource.new()
	src.texture = Art.tex("ground")
	src.texture_region_size = Vector2i(TILE, TILE)
	for i in 18:
		src.create_tile(Vector2i(i % 6, i / 6))
	var sid := ts.add_source(src)
	layer.tile_set = ts
	for cy in H:
		for cx in W:
			var t := _terrain(cx, cy)
			layer.set_cell(Vector2i(cx, cy), sid, Vector2i(t % 6, t / 6))


func _hash(x: int, y: int) -> int:
	var n := x * 374761393 + y * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	return absi(n ^ (n >> 16))


func _terrain(cx: int, cy: int) -> int:
	var p := Vector2(cx * TILE + TILE * 0.5, cy * TILE + TILE * 0.5)
	var hsh := _hash(cx, cy)
	if _in_pond(p):
		return T_WATER_A if hsh % 4 else T_WATER_B
	if _pond_dist(p) < 1.22:
		return T_SAND if hsh % 5 else T_GRASS_EDGE
	if SAFE_PAD.has_point(p):
		var edge := p.x < SAFE_PAD.position.x + 8.0 or p.x > SAFE_PAD.end.x - 8.0 or p.y < SAFE_PAD.position.y + 8.0 or p.y > SAFE_PAD.end.y - 8.0
		return T_PATH_B if edge else (T_CONCRETE_A if hsh % 5 else T_CONCRETE_B)
	if RUINS_GROUND.has_point(p) or YARD_GROUND.has_point(p):
		return T_DIRT if hsh % 4 else T_RUBBLE
	if TOXIC_GROUND.has_point(p):
		return T_DIRT if hsh % 3 else T_DARKGRASS
	if _near_path(p):
		return T_PATH_A + (hsh % 3)
	if hsh % 23 == 0:
		return T_GRASS_FLOWER
	if hsh % 11 == 0:
		return T_MOSS
	if hsh % 6 == 0:
		return T_GRASS_C
	if hsh % 5 == 0:
		return T_GRASS_B
	return T_GRASS_A


func _in_pond(p: Vector2) -> bool:
	var d := Vector2((p.x - POND_C.x) / POND_R.x, (p.y - POND_C.y) / POND_R.y)
	return d.length() < 1.0


func _pond_dist(p: Vector2) -> float:
	return Vector2((p.x - POND_C.x) / POND_R.x, (p.y - POND_C.y) / POND_R.y).length()


func _near_path(p: Vector2) -> bool:
	for path in _paths:
		for i in path.size() - 1:
			if _point_seg_dist(p, path[i], path[i + 1]) < 13.0:
				return true
	return false


func _point_seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


# ---------------------------------------------------------------- props
func _prop(tex_name: String, pos: Vector2, coll := Vector2.ZERO, coll_off := Vector2.ZERO) -> Sprite2D:
	var t := Art.tex(tex_name)
	if t == null:
		return null
	var s := Sprite2D.new()
	s.texture = t
	s.offset = Vector2(0, -t.get_height() / 2.0)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world.add_child(s)
	s.global_position = pos
	if coll != Vector2.ZERO:
		_obstacle(pos + coll_off, coll)
	_obstacles.append(Rect2(pos + coll_off - coll * 0.5 - Vector2(6, 2), coll + Vector2(12, 8)))
	return s


func _obstacle(center: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	world.add_child(body)
	body.global_position = center


func _blocked(pos: Vector2, clearance: float) -> bool:
	if pos.x < 26.0 or pos.y < 26.0 or pos.x > world_size.x - 26.0 or pos.y > world_size.y - 26.0:
		return true
	var cell := Vector2i(int(pos.x / TILE), int(pos.y / TILE))
	var t := _terrain(cell.x, cell.y)
	if t == T_WATER_A or t == T_WATER_B:
		return true
	for r in _obstacles:
		if r.grow(clearance).has_point(pos):
			return true
	return false


func find_free_spot(center: Vector2, radius: float) -> Vector2:
	for i in 36:
		var ang := _rng.randf() * TAU
		var r := _rng.randf() * radius
		var p := center + Vector2(cos(ang), sin(ang)) * r
		if not _blocked(p, 6.0):
			return p
	return center


func is_blocked_point(pos: Vector2) -> bool:
	return _blocked(pos, 6.0)


func nearest_spawn(from: Vector2, min_dist: float) -> Vector2:
	var pool: Array = []
	for p in spawn_points:
		if p.distance_to(from) >= min_dist:
			pool.append(p)
	if pool.is_empty():
		pool = spawn_points.duplicate()
	if pool.is_empty():
		return from + Vector2(120, 0)
	var pick: Vector2 = pool[_rng.randi() % pool.size()]
	return find_free_spot(pick, 22.0)


func _scatter(tex_name: String, center: Vector2, half: Vector2, count: int, coll := Vector2.ZERO) -> void:
	for i in count:
		var pos := Vector2(center.x + _rng.randf_range(-half.x, half.x), center.y + _rng.randf_range(-half.y, half.y))
		if _blocked(pos, 12.0):
			continue
		_prop(tex_name, pos, coll)


# ---------------------------------------------------------------- pond & landmarks
func _build_pond() -> void:
	var s := _prop("pond", POND_C + Vector2(0, -4))
	if s != null:
		s.z_index = -12
	# collision approximating the water ellipse
	_obstacle(POND_C, Vector2(POND_R.x * 1.62, POND_R.y * 1.62))
	_obstacles.append(Rect2(POND_C - POND_R - Vector2(10, 6), POND_R * 2.0 + Vector2(20, 12)))
	_prop("deck", Vector2(482, 330), Vector2(96, 20), Vector2(0, -20))
	_prop("sign", Vector2(392, 404))
	_prop("bush_flower", Vector2(700, 340))
	_prop("rock_1", Vector2(716, 300))
	_prop("tree_3", Vector2(668, 136), Vector2(12, 8), Vector2(0, -4))
	_landmarks.append({"pos": POND_C, "kind": "pond", "th": "สระน้ำ"})


func _build_safe_zone() -> void:
	safe_pos = Vector2(210, 424)
	shop_pos = Vector2(148, 392)
	storage_pos = Vector2(288, 372)
	_prop("shop_stall", shop_pos, Vector2(64, 18), Vector2(0, -8))
	_prop("shed", storage_pos, Vector2(48, 16), Vector2(0, -8))
	_prop("lamp", Vector2(112, 350), Vector2(8, 6), Vector2(0, -2))
	_prop("lamp", Vector2(332, 350), Vector2(8, 6), Vector2(0, -2))
	_prop("crate", Vector2(256, 428), Vector2(14, 10), Vector2(0, -4))
	_prop("barrel", Vector2(230, 372), Vector2(12, 9), Vector2(0, -4))
	_prop("sign", Vector2(206, 352))
	_prop("garbage_pile", Vector2(122, 448))
	_prop("crate", Vector2(332, 380), Vector2(14, 10), Vector2(0, -4))
	_prop("barrel", Vector2(98, 384), Vector2(12, 9), Vector2(0, -4))
	_prop("bush_flower", Vector2(350, 344))
	_prop("flowers_pink", Vector2(362, 452))
	for i in 7:
		var dp := Vector2(_rng.randf_range(112, 330), _rng.randf_range(346, 452))
		if _blocked(dp, 4.0):
			continue
		_prop("tuft_1" if i % 2 == 0 else "tuft_2", dp)
	_landmarks.append({"pos": shop_pos, "kind": "shop", "th": "ร้านค้า"})
	_landmarks.append({"pos": storage_pos, "kind": "storage", "th": "โกดัง"})


func _build_bins() -> void:
	var groups := [
		{"center": Vector2(298, 442), "dx": 32.0},
		{"center": Vector2(520, 668), "dx": 32.0},
	]
	for grp in groups:
		for c in 4:
			var b: Node2D = BIN_SCENE.instantiate()
			b.bin_cat = c
			world.add_child(b)
			b.global_position = grp["center"] + Vector2((float(c) - 1.5) * float(grp["dx"]), 0.0)
			bins.append(b)
			_obstacles.append(Rect2(b.global_position + Vector2(-13, -10), Vector2(26, 12)))


func _build_ruins() -> void:
	_prop("house_ruin", Vector2(146, 596), Vector2(92, 26), Vector2(0, -12))
	_prop("car", Vector2(262, 662), Vector2(44, 14), Vector2(0, -4))
	_prop("fence_broken", Vector2(196, 640), Vector2(24, 5), Vector2(0, -2))
	_prop("fence_broken", Vector2(224, 640), Vector2(24, 5), Vector2(0, -2))
	_prop("tree_dead_1", Vector2(96, 640), Vector2(8, 6), Vector2(0, -2))
	_prop("tree_dead_2", Vector2(300, 560), Vector2(8, 6), Vector2(0, -2))
	_prop("garbage_pile", Vector2(214, 690))
	_prop("garbage_pile", Vector2(118, 700))
	_scatter("bush_2", Vector2(170, 610), Vector2(100, 70), 6)


func _build_yard() -> void:
	station_pos = Vector2(486, 578)
	_prop("station", station_pos, Vector2(74, 20), Vector2(0, -10))
	_prop("dumpster", Vector2(596, 604), Vector2(34, 12), Vector2(0, -6))
	_prop("dumpster", Vector2(628, 640), Vector2(34, 12), Vector2(0, -6))
	_prop("barrel", Vector2(452, 640), Vector2(12, 9), Vector2(0, -4))
	_prop("barrel", Vector2(468, 650), Vector2(12, 9), Vector2(0, -4))
	_prop("crate", Vector2(610, 566), Vector2(14, 10), Vector2(0, -4))
	_prop("garbage_pile", Vector2(560, 596))
	_prop("garbage_pile", Vector2(636, 690))
	_prop("garbage_pile", Vector2(452, 700))
	_prop("silo", Vector2(404, 620), Vector2(26, 16), Vector2(0, -8))
	_scatter("crate", Vector2(520, 610), Vector2(80, 60), 4, Vector2(13, 10))
	_landmarks.append({"pos": station_pos, "kind": "recycle", "th": "ลานรีไซเคิล"})


func _build_forest() -> void:
	# Border ring, two rows deep, with natural gaps.
	var step := 46
	for x in range(30, int(world_size.x) - 20, step):
		_tree(Vector2(x + _rng.randf_range(-8, 8), _rng.randf_range(34, 78)))
		_tree(Vector2(x + _rng.randf_range(-8, 8), world_size.y - _rng.randf_range(30, 70)))
	for y in range(70, int(world_size.y) - 60, step):
		_tree(Vector2(_rng.randf_range(26, 62), y + _rng.randf_range(-8, 8)))
		_tree(Vector2(world_size.x - _rng.randf_range(26, 62), y + _rng.randf_range(-8, 8)))
	# Interior clusters
	_cluster(Vector2(150, 150), Vector2(110, 80), 26)
	_cluster(Vector2(690, 130), Vector2(90, 60), 16)
	_cluster(Vector2(80, 300), Vector2(50, 60), 10)
	_cluster(Vector2(760, 470), Vector2(70, 70), 14)
	_cluster(Vector2(300, 760), Vector2(90, 50), 14)
	_cluster(Vector2(120, 470), Vector2(50, 45), 8)


func _cluster(c: Vector2, half: Vector2, count: int) -> void:
	for i in count:
		_tree(Vector2(c.x + _rng.randf_range(-half.x, half.x), c.y + _rng.randf_range(-half.y, half.y)))
	_scatter("bush_1", c, half, int(count * 0.6))
	_scatter("bush_3", c, half, int(count * 0.4))
	_scatter("rock_2", c, half * 0.9, int(count * 0.3))


func _tree(pos: Vector2) -> void:
	if _blocked(pos, 16.0):
		return
	var pick := _rng.randi() % 10
	var name := "tree_2"
	if pick < 3:
		name = "tree_1"
	elif pick < 5:
		name = "tree_3"
	elif pick < 7:
		name = "tree_4"
	elif pick < 9:
		name = "tree_2"
	else:
		name = "tree_5"
	_prop(name, pos, Vector2(13, 8), Vector2(0, -4))


func _build_details() -> void:
	# Grass tufts, flowers, mushrooms, pebbles, logs — no collision, keeps the eye busy.
	for i in 150:
		var p := Vector2(_rng.randf_range(40, world_size.x - 40), _rng.randf_range(50, world_size.y - 30))
		if _blocked(p, 2.0) or _near_path(p):
			continue
		var n := "tuft_1" if i % 2 == 0 else "tuft_2"
		if i % 9 == 0:
			n = "flowers_pink"
		elif i % 13 == 0:
			n = "flowers_white"
		elif i % 17 == 0:
			n = "mushroom"
		elif i % 23 == 0:
			n = "pebbles"
		var s := _prop(n, p)
		if s != null:
			s.z_index = -6
	for i in 10:
		var lp := Vector2(_rng.randf_range(60, world_size.x - 60), _rng.randf_range(90, world_size.y - 60))
		if _blocked(lp, 10.0):
			continue
		_prop("log", lp, Vector2(24, 8), Vector2(0, -2))
	for i in 14:
		var rp := Vector2(_rng.randf_range(60, world_size.x - 60), _rng.randf_range(80, world_size.y - 50))
		if _blocked(rp, 8.0):
			continue
		_prop("rock_small", rp)
	for i in 8:
		var sp := Vector2(_rng.randf_range(60, world_size.x - 60), _rng.randf_range(80, world_size.y - 50))
		if _blocked(sp, 10.0):
			continue
		_prop("stump", sp, Vector2(14, 8), Vector2(0, -2))


func _build_bounds() -> void:
	var walls := [
		Rect2(Vector2(-40, -40), Vector2(world_size.x + 80, 44)),
		Rect2(Vector2(-40, world_size.y - 4), Vector2(world_size.x + 80, 44)),
		Rect2(Vector2(-40, -40), Vector2(44, world_size.y + 80)),
		Rect2(Vector2(world_size.x - 4, -40), Vector2(44, world_size.y + 80)),
	]
	for r in walls:
		_obstacle(r.position + r.size * 0.5, r.size)
		_obstacles.append(r)
