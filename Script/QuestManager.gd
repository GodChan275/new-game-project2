extends Node
## Quest system: main / daily / side / special, with progress bars, rewards and
## claiming. Daily + side rewards are granted on completion; main and special
## rewards are claimed from the quest book (J).

signal missions_changed()
signal quest_done(quest: Dictionary)
signal quest_claimed(quest: Dictionary)

const MAIN_REWARD := 140
const SPECIAL_REWARD := 220

var day := 1
var missions: Array = []
var _life := {"kill": 0, "collect": 0, "days": 0}
var _uid := 0

const CATS := [
	{"id": "main", "th": "ภารกิจหลัก", "color": "bf801c"},
	{"id": "daily", "th": "ภารกิจประจำวัน", "color": "3f7a36"},
	{"id": "sorting", "th": "ภารกิจคัดแยก", "color": "6a8f2a"},
	{"id": "side", "th": "ภารกิจเสริม", "color": "3d6fa8"},
	{"id": "special", "th": "ภารกิจพิเศษ", "color": "b8443a"},
]

const DAILY_POOL := [
	{"kind": "collect", "th": "เก็บขยะ %d ชิ้น", "base": 10, "step": 2, "reward": 60},
	{"kind": "sort_recyclable", "th": "แยกขยะรีไซเคิล %d ชิ้น", "base": 5, "step": 1, "reward": 70},
	{"kind": "sort_hazardous", "th": "แยกขยะอันตราย %d ชิ้น", "base": 3, "step": 1, "reward": 85},
	{"kind": "kill", "th": "กำจัดศัตรู %d ตัว", "base": 5, "step": 1, "reward": 80},
	{"kind": "pollution", "th": "ลดมลพิษให้ต่ำกว่า %d%%", "base": 30, "step": -2, "reward": 90},
]

## Educational sorting missions: correctness, category practice and a total goal.
const SORTING_POOL := [
	{"kind": "sort", "th": "คัดแยกขยะถูกต้อง %d ชิ้น", "base": 5, "step": 1, "reward": 55},
	{"kind": "collect_recyclable", "th": "เก็บขยะรีไซเคิล %d ชิ้น", "base": 3, "step": 1, "reward": 60},
	{"kind": "sort_hazardous", "th": "กำจัดขยะอันตรายให้ถูกถัง %d ชิ้น", "base": 2, "step": 0, "reward": 75},
	{"kind": "sort_all", "th": "คัดแยกถูกต้องรวม %d ชิ้น", "base": 10, "step": 2, "reward": 95},
]


func reset() -> void:
	day = 1
	missions.clear()
	_life = {"kill": 0, "collect": 0, "days": 0}
	missions_changed.emit()


func start_day(d: int) -> void:
	day = d
	_life["days"] = maxi(int(_life["days"]), d - 1)
	missions.clear()

	# --- main objective of the day (claimed from the quest book)
	missions.append(_mk("main", "collect", "ฟื้นฟูหมู่บ้าน: เก็บขยะ %d ชิ้น" % (12 + (d - 1) * 3),
		12 + (d - 1) * 3, MAIN_REWARD, false))

	# --- five daily missions, exactly the reference set
	for tpl in DAILY_POOL:
		var target := int(tpl["base"]) + int(tpl["step"]) * (d - 1)
		if String(tpl["kind"]) == "pollution":
			target = maxi(12, target)
		missions.append(_mk("daily", String(tpl["kind"]), String(tpl["th"]) % target, target,
			int(tpl["reward"]), true))

	# --- educational sorting missions, tied to Sorting.sort_one / collection
	for tpl in SORTING_POOL:
		var starget := int(tpl["base"]) + int(tpl["step"]) * (d - 1)
		missions.append(_mk("sorting", String(tpl["kind"]), String(tpl["th"]) % starget, starget,
			int(tpl["reward"]), true))

	# --- side missions
	missions.append(_mk("side", "buy_tool", "ซื้ออุปกรณ์เก็บขยะ 1 ชิ้น", 1, 50, true))
	missions.append(_mk("side", "clean", "ทำความสะอาดคราบพิษ %d จุด" % (2 + d), 2 + d, 65, true))
	missions.append(_mk("side", "survive", "รอดจากการบุกโจมตี 1 ครั้ง", 1, 75, true))

	# --- long-run special missions (persist across days)
	_add_life("special", "kill_life", "กำจัดผู้บุกรุกสะสม %d ตัว" % 25, 25)
	_add_life("special", "collect_life", "เก็บขยะสะสม %d ชิ้น" % 150, 150)
	_add_life("special", "days_life", "อยู่รอดให้ครบ %d วัน" % 3, 3)

	missions_changed.emit()


func _mk(cat: String, kind: String, th: String, target: int, reward: int, auto: bool) -> Dictionary:
	_uid += 1
	return {
		"id": "%s_%d" % [kind, _uid],
		"cat": cat,
		"kind": kind,
		"th": th,
		"text": th,
		"target": maxi(1, target),
		"progress": 0,
		"reward": reward,
		"done": false,
		"claimed": false,
		"auto": auto,
	}


func _add_life(cat: String, kind: String, th: String, target: int) -> void:
	var q := _mk(cat, kind, th, target, SPECIAL_REWARD, false)
	q["progress"] = _life_value(kind)
	missions.append(q)
	if int(q["progress"]) >= int(q["target"]):
		_finish(q)


func _life_value(kind: String) -> int:
	match kind:
		"kill_life":
			return int(_life["kill"])
		"collect_life":
			return int(_life["collect"])
		"days_life":
			return int(_life["days"])
	return 0


# ---------------------------------------------------------------- progress
func report(kind: String, amount: int = 1) -> void:
	if kind in _life:
		_life[kind] = int(_life[kind]) + amount
	var dirty := false
	for m in missions:
		if bool(m["done"]) or String(m["kind"]) != kind:
			continue
		m["progress"] = int(m["progress"]) + amount
		if int(m["progress"]) >= int(m["target"]):
			_finish(m)
		dirty = true
	if _sync_life():
		dirty = true
	if dirty:
		missions_changed.emit()


func _sync_life() -> bool:
	var dirty := false
	for m in missions:
		var k := String(m["kind"])
		if bool(m["done"]) or not k.ends_with("_life"):
			continue
		m["progress"] = _life_value(k)
		if int(m["progress"]) >= int(m["target"]):
			_finish(m)
		dirty = true
	return dirty


func check_pollution(pct: float) -> void:
	var dirty := false
	for m in missions:
		if bool(m["done"]) or String(m["kind"]) != "pollution":
			continue
		if pct <= float(m["target"]):
			_finish(m)
			dirty = true
	if dirty:
		missions_changed.emit()


func _finish(m: Dictionary) -> void:
	m["done"] = true
	m["progress"] = m["target"]
	if bool(m.get("auto", false)):
		m["claimed"] = true
		Economy.add_money(int(m["reward"]))
	Economy.add_xp(20 if bool(m.get("auto", false)) else 35)
	Sfx.play("levelup", 1.15, -6.0)
	quest_done.emit(m)


# ---------------------------------------------------------------- rewards
func claim(qid: String) -> Dictionary:
	for m in missions:
		if String(m["id"]) != qid or not bool(m["done"]) or bool(m["claimed"]):
			continue
		m["claimed"] = true
		Economy.add_money(int(m["reward"]))
		quest_claimed.emit(m)
		missions_changed.emit()
		return {"ok": true, "reward": int(m["reward"])}
	return {"ok": false}


func claim_all() -> int:
	var total := 0
	for m in missions:
		if bool(m["done"]) and not bool(m["claimed"]):
			m["claimed"] = true
			Economy.add_money(int(m["reward"]))
			total += int(m["reward"])
			quest_claimed.emit(m)
	if total > 0:
		missions_changed.emit()
	return total


func pending_rewards() -> int:
	var n := 0
	for m in missions:
		if bool(m["done"]) and not bool(m["claimed"]):
			n += 1
	return n


# ---------------------------------------------------------------- queries
func lines(cat := "") -> Array:
	var out: Array = []
	for m in missions:
		if cat != "" and String(m["cat"]) != cat:
			continue
		out.append(m)
	return out


func main_text() -> String:
	for m in missions:
		if String(m["cat"]) == "main":
			return "%s  (%d/%d)" % [String(m["th"]), int(m["progress"]), int(m["target"])]
	return "ไม่มีภารกิจหลัก"


func active_text() -> String:
	return main_text()


func by_kind(kind: String) -> Dictionary:
	for m in missions:
		if String(m["kind"]) == kind:
			return m
	return {}


func progress_of(kind: String) -> Vector2i:
	var m := by_kind(kind)
	if m.is_empty():
		return Vector2i(0, 0)
	return Vector2i(int(m["progress"]), int(m["target"]))


func completed_today() -> int:
	var n := 0
	for m in missions:
		if bool(m["done"]):
			n += 1
	return n


func cat_color(cat: String) -> Color:
	for c in CATS:
		if String(c["id"]) == cat:
			return Color(String(c["color"]))
	return Color("4a3524")


func cat_th(cat: String) -> String:
	for c in CATS:
		if String(c["id"]) == cat:
			return String(c["th"])
	return cat
