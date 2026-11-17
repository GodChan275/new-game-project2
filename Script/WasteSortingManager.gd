extends Node
## Waste sorting rules: rewards, educational feedback, per-day statistics.
## Categories come from ItemDB.Cat: 0 organic · 1 hazardous · 2 general · 3 recyclable.

signal sorted(result: Dictionary)

var day := 1
var collected := 0
var correct := 0
var wrong := 0
var score := 0
var money := 0

var _collected_cat := {0: 0, 1: 0, 2: 0, 3: 0}
var _correct_cat := {0: 0, 1: 0, 2: 0, 3: 0}
var _wrong_cat := {0: 0, 1: 0, 2: 0, 3: 0}
var _tips: Array[String] = []
var _mistakes: Array = []


## Called at the start of every day so the report covers that day's sorting.
func start_day(d: int) -> void:
	day = d
	collected = 0
	correct = 0
	wrong = 0
	score = 0
	money = 0
	_collected_cat = {0: 0, 1: 0, 2: 0, 3: 0}
	_correct_cat = {0: 0, 1: 0, 2: 0, 3: 0}
	_wrong_cat = {0: 0, 1: 0, 2: 0, 3: 0}
	_tips.clear()
	_mistakes.clear()


func reward_for(id: String) -> int:
	var cat := ItemDB.waste_cat(id)
	var val := float(ItemDB.waste_def(id).get("value", 1.0))
	var r: float = ItemDB.reward_base(cat) * val
	if Inventory.has_equipment("sort_container"):
		r *= 1.3
	if cat == ItemDB.Cat.RECYCLABLE and Inventory.has_equipment("cart"):
		r *= 1.1
	return maxi(1, int(round(r)))


## Points awarded for the item itself, independent of the money reward.
func score_for(id: String) -> int:
	return maxi(1, ItemDB.waste_score(id))


## Tracks a picked-up item so the end-of-day report shows the real total.
func note_collected(id: String) -> void:
	var cat := ItemDB.waste_cat(id)
	collected += 1
	_collected_cat[cat] = int(_collected_cat.get(cat, 0)) + 1


## Attempts to dispose of Inventory.garbage[index] into a bin of bin_cat.
## Returns a result dictionary the HUD uses for feedback, education and stats.
func sort_one(index: int, bin_cat: int) -> Dictionary:
	if index < 0 or index >= Inventory.garbage.size():
		return {"ok": false, "msg": "ไม่มีขยะให้คัดแยก", "reason": "empty"}
	var id := String(Inventory.garbage[index]["id"])
	var cat := ItemDB.waste_cat(id)
	var nm := String(ItemDB.waste_def(id)["name"])
	var nm_en := ItemDB.waste_en(id)

	if cat != bin_cat:
		wrong += 1
		_wrong_cat[cat] = int(_wrong_cat.get(cat, 0)) + 1
		Pollution.add_penalty(1.0)
		Sfx.play("sort_bad")
		Quests.report("wrong_sort", 1)
		_note_mistake(id, cat, bin_cat)
		var bad := {
			"ok": false,
			"msg": "ทิ้งขยะผิดประเภท!",
			"title": "คัดแยกผิด! · Incorrect Sorting!",
			"item": nm,
			"item_en": nm_en,
			"cat": cat,
			"bin": bin_cat,
			"cat_thai": ItemDB.cat_thai(cat),
			"cat_en": ItemDB.cat_name_en(cat),
			"bin_thai": ItemDB.cat_thai(bin_cat),
			"explanation": "%s เป็น%s ไม่ใช่%s" % [nm, ItemDB.cat_thai(cat), ItemDB.cat_thai(bin_cat)],
			"why": ItemDB.cat_why(cat),
			"disposal": ItemDB.waste_disposal(id),
			"score": 0,
			"reward": 0,
			"accuracy": accuracy(),
			"retry": true,
		}
		sorted.emit(bad)
		return bad

	var reward := reward_for(id)
	var pts := score_for(id)
	Inventory.remove_garbage_at(index)
	Economy.add_money(reward)
	Economy.add_xp(3)
	correct += 1
	score += pts
	money += reward
	_correct_cat[cat] = int(_correct_cat.get(cat, 0)) + 1
	Sfx.play("sort_ok", randf_range(0.95, 1.12))
	Quests.report("sort", 1)
	Quests.report("sort_all", 1)
	Quests.report("sort_" + ItemDB.cat_key(cat), 1)
	Pollution.recalc()
	var good := {
		"ok": true,
		"msg": "ทิ้ง%sถูกต้อง!" % nm,
		"title": "คัดแยกถูกต้อง! · Correct Sorting!",
		"item": nm,
		"item_en": nm_en,
		"cat": cat,
		"bin": bin_cat,
		"cat_thai": ItemDB.cat_thai(cat),
		"cat_en": ItemDB.cat_name_en(cat),
		"bin_thai": ItemDB.cat_thai(bin_cat),
		"explanation": "ถูกต้อง! %s จัดอยู่ใน%s" % [nm, ItemDB.cat_thai(cat)],
		"why": ItemDB.cat_why(cat),
		"disposal": ItemDB.waste_disposal(id),
		"score": pts,
		"reward": reward,
		"accuracy": accuracy(),
		"retry": false,
	}
	sorted.emit(good)
	return good


## Sorts every carried item that belongs in this bin. Returns a summary.
func bulk(bin_cat: int) -> Dictionary:
	var n := 0
	var total := 0
	var i := Inventory.garbage.size() - 1
	while i >= 0:
		if i < Inventory.garbage.size():
			var id := String(Inventory.garbage[i]["id"])
			if ItemDB.waste_cat(id) == bin_cat:
				var r := sort_one(i, bin_cat)
				if bool(r.get("ok", false)):
					n += 1
					total += int(r.get("reward", 0))
		i -= 1
	if n == 0:
		return {"ok": false, "sorted": 0, "reward": 0, "msg": "ไม่มี%sในกระเป๋า" % ItemDB.cat_thai(bin_cat)}
	return {"ok": true, "sorted": n, "reward": total, "msg": "คัดแยก %d ชิ้น  +฿%d" % [n, total]}


func accuracy() -> int:
	var attempts := correct + wrong
	if attempts <= 0:
		return 0
	return int(round(float(correct) / float(attempts) * 100.0))


func count_by_cat(cat: int) -> int:
	return int(_collected_cat.get(cat, 0))


## Everything the end-of-mission report needs.
func summary() -> Dictionary:
	return {
		"day": day,
		"collected": collected,
		"correct": correct,
		"wrong": wrong,
		"score": score,
		"money": money,
		"accuracy": accuracy(),
		"tips": tips(),
		"collected_by_cat": _collected_cat.duplicate(),
		"correct_by_cat": _correct_cat.duplicate(),
		"wrong_by_cat": _wrong_cat.duplicate(),
	}


## Educational tips derived from the player's own mistakes, max three lines.
func tips() -> Array:
	var out: Array = []
	for c in [ItemDB.Cat.HAZARDOUS, ItemDB.Cat.RECYCLABLE, ItemDB.Cat.ORGANIC, ItemDB.Cat.GENERAL]:
		if int(_wrong_cat.get(c, 0)) <= 0:
			continue
		out.append("%s: %s" % [ItemDB.cat_thai(c), ItemDB.cat_why(c)])
		if out.size() >= 2:
			break
	for t in _tips:
		if out.size() >= 3:
			break
		if not out.has(t):
			out.append(t)
	return out


func _note_mistake(id: String, cat: int, bin_cat: int) -> void:
	var tip := "%s ต้องทิ้งใน%s" % [String(ItemDB.waste_def(id)["name"]), ItemDB.cat_thai(cat)]
	if not _tips.has(tip):
		_tips.append(tip)
	_mistakes.append({"id": id, "cat": cat, "bin": bin_cat})
	if _mistakes.size() > 6:
		_mistakes.pop_front()
