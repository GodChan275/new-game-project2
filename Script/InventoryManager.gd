extends Node
## Player inventory: carried garbage (individual items), owned gear, consumables.

signal changed()
signal garbage_changed()

const BASE_CAPACITY := 8

## Individual carried waste pieces: [{"id": String}]
var garbage: Array[Dictionary] = []
## Consumables / resources: id -> count
var items: Dictionary = {}
## Owned weapons + equipment: id -> true
var owned: Dictionary = {"baton": true}
var weapon: String = "baton"


func reset() -> void:
	garbage.clear()
	items.clear()
	owned = {"baton": true}
	weapon = "baton"
	changed.emit()
	garbage_changed.emit()


func has_equipment(id: String) -> bool:
	return owned.has(id)


func equip_weapon(id: String) -> void:
	if ItemDB.weapons.has(id):
		weapon = id
		changed.emit()


func weapon_def() -> Dictionary:
	return ItemDB.weapons.get(weapon, ItemDB.weapons["baton"])


# ---------------------------------------------------------------- capacity
func capacity() -> int:
	var c := BASE_CAPACITY
	if has_equipment("bags"):
		c += 6
	if has_equipment("trolley"):
		c += 10
	if has_equipment("cart"):
		c += 8
	if has_equipment("industrial_kit"):
		c += 4
	return c


func capacity_for(cat: int) -> int:
	if cat == ItemDB.Cat.RECYCLABLE and not has_equipment("cart"):
		return capacity()
	return capacity()


func count() -> int:
	return garbage.size()


func is_full() -> bool:
	return garbage.size() >= capacity()


func counts_by_cat() -> Dictionary:
	var out := {0: 0, 1: 0, 2: 0, 3: 0}
	for g in garbage:
		var c := ItemDB.waste_cat(String(g["id"]))
		out[c] = int(out.get(c, 0)) + 1
	return out


func count_of_cat(cat: int) -> int:
	var n := 0
	for g in garbage:
		if ItemDB.waste_cat(String(g["id"])) == cat:
			n += 1
	return n


## Returns "" on success, otherwise a player-facing refusal message.
func add_garbage(id: String) -> String:
	var def := ItemDB.waste_def(id)
	if bool(def.get("special", false)) and not has_equipment("industrial_kit"):
		return "ต้องมีชุดเก็บขยะอุตสาหกรรม"
	if bool(def.get("hard", false)) and not has_equipment("gloves"):
		return "ต้องมีถุงมือกันสารพิษ"
	if garbage.size() >= capacity():
		return "กระเป๋าเต็มแล้ว"
	garbage.append({"id": id})
	changed.emit()
	garbage_changed.emit()
	return ""


func remove_garbage_at(index: int) -> Dictionary:
	if index < 0 or index >= garbage.size():
		return {}
	var entry: Dictionary = garbage[index]
	garbage.remove_at(index)
	changed.emit()
	garbage_changed.emit()
	return entry


func clear_garbage() -> void:
	garbage.clear()
	changed.emit()
	garbage_changed.emit()


# ---------------------------------------------------------------- generic items
func add_item(id: String, n: int = 1) -> void:
	items[id] = int(items.get(id, 0)) + n
	changed.emit()


func item_count(id: String) -> int:
	return int(items.get(id, 0))


func use_item(id: String) -> bool:
	if item_count(id) <= 0:
		return false
	items[id] = item_count(id) - 1
	if int(items[id]) <= 0:
		items.erase(id)
	changed.emit()
	return true


func add_owned(id: String) -> void:
	owned[id] = true
	changed.emit()


func owned_list() -> Array:
	return owned.keys()
