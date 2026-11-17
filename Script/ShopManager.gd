extends Node
## Shop catalogue and purchases.

signal purchase_finished(id: String, ok: bool, msg: String)


func catalog() -> Array:
	var out: Array = []
	for id in ItemDB.weapons.keys():
		var d: Dictionary = ItemDB.weapons[id]
		if String(id) == "baton":
			continue
		out.append({
			"id": id, "kind": "weapon", "name": d["name"], "icon": d["icon"],
			"price": int(d["price"]), "desc": d["desc"],
			"stats": "DMG %d  |  %.2fs swing  |  %.0f reach" % [int(d["damage"]), float(d["cooldown"]), float(d["reach"])],
			"owned": Inventory.owned.has(id),
		})
	for id in ItemDB.equipment.keys():
		var d: Dictionary = ItemDB.equipment[id]
		out.append({
			"id": id, "kind": "equipment", "name": d["name"], "icon": d["icon"],
			"price": int(d["price"]), "desc": d["desc"], "stats": d["stats"],
			"owned": Inventory.owned.has(id),
		})
	for id in ItemDB.consumables.keys():
		var d: Dictionary = ItemDB.consumables[id]
		if int(d["price"]) <= 0:
			continue
		out.append({
			"id": id, "kind": "consumable", "name": d["name"], "icon": d["icon"],
			"price": int(d["price"]), "desc": d["desc"], "stats": "Heals %.0f HP" % float(d["heal"]),
			"owned": false,
		})
	return out


func buy(id: String) -> Dictionary:
	var found := ItemDB.find_item(id)
	if found.is_empty():
		return {"ok": false, "msg": "Unknown item"}
	var kind := String(found["kind"])
	var def: Dictionary = found["def"]
	var price := int(def.get("price", 0))
	if kind != "consumable" and Inventory.owned.has(id):
		return {"ok": false, "msg": "Already owned"}
	if not Economy.can_afford(price):
		Sfx.play("sort_bad")
		return {"ok": false, "msg": "Not enough money"}
	if not Economy.spend(price):
		return {"ok": false, "msg": "Not enough money"}
	match kind:
		"weapon":
			Inventory.add_owned(id)
			Inventory.equip_weapon(id)
			Quests.report("buy_tool", 1)
		"equipment":
			Inventory.add_owned(id)
			Quests.report("buy_tool", 1)
		"consumable":
			Inventory.add_item(id, 1)
	Economy.add_xp(10)
	Sfx.play("buy")
	var msg := "ซื้อ %s แล้ว" % String(def["name"])
	purchase_finished.emit(id, true, msg)
	return {"ok": true, "msg": msg}
