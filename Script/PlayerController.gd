extends CharacterBody2D
## Player: movement, aim, melee combat, garbage handling, equipment effects.

signal hp_changed(hp: float, max_hp: float)
signal stamina_changed(v: float, max: float)

const BASE_SPEED := 94.0
const DIRS := ["down", "right", "left", "up"]
const SKILL_COOLDOWN := 5.0
const SKILL_COST := 18.0
const SKILL_RADIUS := 104.0

var max_hp := 100.0
var hp := 100.0
var max_stamina := 100.0
var stamina := 100.0
var attack_cd := 0.3
var invuln := 0.0
var stamina_delay := 0.0
var toxic_acc := 0.0
var alive := true
var locked := false

var _dir := "down"
var _aim := Vector2.RIGHT
var _prompt := ""
var _target_kind := ""
var _target: Node = null
var _focus_item: Node2D = null
var skill_cd := 0.0

## Touch sweep: full circle around the player, no facing required.
const MOBILE_REACH_BONUS := 1.2
var _slash: Sprite2D

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var swing: Sprite2D = $Swing
@onready var weapon_vis: Node2D = $Weapon
@onready var equip_vis: Node2D = $Equipment
@onready var shadow: Sprite2D = $Shadow


func _ready() -> void:
	sprite.sprite_frames = Art.quad_frames(Art.player_sheet(), 307, 320, 4, DIRS)
	sprite.play("idle_down")
	shadow.texture = Art.tex("shadow")
	swing.visible = false
	_slash = Sprite2D.new()
	_slash.texture = Art.tex("slash_ring")
	_slash.visible = false
	_slash.z_index = 3
	_slash.position = Vector2(0, -10)
	add_child(_slash)
	is_in_group("player")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 1
	max_hp = 100.0
	hp = max_hp
	_recalc_stats(false)
	if weapon_vis != null and weapon_vis.has_method("set_weapon"):
		weapon_vis.set_weapon(Inventory.weapon)
	if equip_vis != null and equip_vis.has_method("refresh"):
		equip_vis.refresh()
	Inventory.changed.connect(_on_inventory_changed)
	Economy.leveled_up.connect(_on_level_up)
	hp_changed.emit(hp, max_hp)


func _on_level_up(_lvl: int) -> void:
	_recalc_stats(true)


func _on_inventory_changed() -> void:
	if weapon_vis != null and weapon_vis.has_method("set_weapon"):
		weapon_vis.set_weapon(Inventory.weapon)
	if equip_vis != null and equip_vis.has_method("refresh"):
		equip_vis.refresh()
	_recalc_stats(true)


func _recalc_stats(add_new: bool) -> void:
	var prev := max_hp
	max_hp = 100.0 + (40.0 if Inventory.has_equipment("armor") else 0.0) + float(Economy.level - 1) * 5.0
	if add_new and max_hp > prev:
		hp += max_hp - prev
	hp = clampf(hp, 0.0, max_hp)
	hp_changed.emit(hp, max_hp)


func _physics_process(delta: float) -> void:
	if not alive:
		velocity = Vector2.ZERO
		return
	_tick_timers(delta)
	_update_aim()
	var input := Vector2.ZERO
	var blocked := locked or _ui_open()
	if not blocked:
		input = InputHub.move_vector()
	var sprinting := not blocked and input.length() > 0.1 and Input.is_action_pressed("sprint") and stamina > 6.0
	var spd := BASE_SPEED * (1.32 if sprinting else 1.0)
	velocity = input.normalized() * spd
	if sprinting:
		stamina = maxf(0.0, stamina - 13.0 * delta)
		stamina_delay = 0.45
		stamina_changed.emit(stamina, max_stamina)
	move_and_slide()
	_animate(input)
	_update_weapon_vis()


func _process(delta: float) -> void:
	if not alive:
		return
	_update_swing()
	_scan_interactions()
	if locked or _ui_open():
		return
	if InputHub.was_pressed("attack"):
		_attack()
	if InputHub.was_pressed("interact"):
		_interact()
	if InputHub.was_pressed("use_equipment"):
		_use_equipment()
	if InputHub.was_pressed("skill"):
		_skill()
	if InputHub.was_pressed("interact_alt"):
		_interact()
	if InputHub.was_pressed("inspect"):
		_inspect()
	_toxic_damage(delta)


func _tick_timers(delta: float) -> void:
	attack_cd = maxf(0.0, attack_cd - delta)
	skill_cd = maxf(0.0, skill_cd - delta)
	invuln = maxf(0.0, invuln - delta)
	stamina_delay = maxf(0.0, stamina_delay - delta)
	if stamina_delay <= 0.0:
		stamina = minf(max_stamina, stamina + 19.0 * delta)
		stamina_changed.emit(stamina, max_stamina)


func _update_aim() -> void:
	# Touch has no cursor: aim follows the joystick, keeping the last direction.
	if Platform.mobile():
		var mv := InputHub.move_vector()
		if mv.length() > 0.25:
			_aim = mv.normalized()
		return
	var m := get_global_mouse_position() - global_position
	if m.length() > 1.0:
		_aim = m.normalized()


func _animate(input: Vector2) -> void:
	var anim := ""
	if input.length() > 0.1:
		_dir = _dir_from(input)
		anim = "walk_" + _dir
	else:
		anim = "idle_" + _dir
	if sprite.animation != anim:
		sprite.play(anim)


func _dir_from(v: Vector2) -> String:
	if absf(v.x) > absf(v.y):
		return "right" if v.x < 0.0 else "left"
	return "down" if v.y > 0.0 else "up"


func _update_weapon_vis() -> void:
	if weapon_vis != null and weapon_vis.has_method("aim_at"):
		weapon_vis.aim_at(_aim, _dir)


func _update_swing() -> void:
	if not swing.visible:
		return
	var total := maxf(float(Inventory.weapon_def()["cooldown"]), 0.12)
	var prog := 1.0 - clampf(attack_cd / total, 0.0, 1.0)
	swing.frame = clampi(int(prog * 3.0), 0, 2)
	swing.modulate.a = 1.0 - prog * 0.75
	if attack_cd <= 0.0:
		swing.visible = false


# ---------------------------------------------------------------- combat
func _attack() -> void:
	var w := Inventory.weapon_def()
	if attack_cd > 0.0:
		return
	var cost := float(w["stamina"])
	if stamina < cost * 0.6:
		_toast("เหนื่อยเกินกว่าจะตี", Color("e8c832"))
		return
	stamina = maxf(0.0, stamina - cost)
	stamina_delay = 0.8
	attack_cd = float(w["cooldown"])
	var weak := stamina <= 0.5
	var dmg := float(w["damage"]) * (0.6 if weak else 1.0)
	var reach := float(w["reach"])
	if Platform.mobile():
		# 360° sweep: every enemy inside the radius is hit, no facing needed.
		Combat.melee(global_position, _aim, reach * MOBILE_REACH_BONUS, 360.0, dmg, 170.0, true)
		_show_slash(reach * MOBILE_REACH_BONUS)
	else:
		Combat.melee(global_position + _aim * 6.0, _aim, reach, float(w["arc"]), dmg, 170.0)
		Sfx.play("swing", randf_range(0.94, 1.08), -14.0)
		swing.visible = true
		swing.rotation = _aim.angle()
		swing.position = _aim * 12.0 + Vector2(0, -10)
		swing.modulate = Color(1, 1, 1, 0.9)
	stamina_changed.emit(stamina, max_stamina)


func take_damage(amount: float, from: Vector2) -> void:
	if not alive or invuln > 0.0:
		return
	var dmg := amount
	if Inventory.has_equipment("shield"):
		dmg *= 0.7
	hp = maxf(0.0, hp - dmg)
	invuln = 0.55
	Combat.floating("-%d" % int(round(dmg)), global_position + Vector2(0, -16), Color("ff6a5a"), true)
	Sfx.play("hurt")
	Combat.shake(3.0)
	modulate = Color(1, 0.6, 0.6)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.28)
	_knock((global_position - from).normalized())
	hp_changed.emit(hp, max_hp)
	if hp <= 0.0:
		_die()


func _knock(dir: Vector2) -> void:
	var spare := get_parent()
	if spare == null:
		return
	global_position += dir * 4.0


func _die() -> void:
	if not alive:
		return
	alive = false
	hp = 0.0
	hp_changed.emit(0.0, max_hp)
	velocity = Vector2.ZERO
	sprite.play("idle_down")
	GameManager.player_died()


func revive() -> void:
	alive = true
	hp = max_hp
	invuln = 2.5
	if GameManager.map != null and is_instance_valid(GameManager.map):
		global_position = GameManager.map.safe_pos
	modulate = Color.WHITE
	hp_changed.emit(hp, max_hp)


func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)
	hp_changed.emit(hp, max_hp)


func _toxic_damage(delta: float) -> void:
	var dps := 0.0
	for z in Pollution.zones:
		if not is_instance_valid(z):
			continue
		var r: float = z.radius
		if z.global_position.distance_to(global_position) < r:
			dps += 9.0
	if dps <= 0.0:
		return
	var applied := dps * Pollution.toxic_multiplier() * delta
	hp = maxf(0.0, hp - applied)
	toxic_acc += applied
	if toxic_acc >= 7.0:
		toxic_acc = 0.0
		Combat.floating("TOXIC", global_position + Vector2(0, -20), Color("8ad02a"))
		Sfx.play("hurt", 1.35, -10.0)
	hp_changed.emit(hp, max_hp)
	if hp <= 0.0:
		_die()


# ---------------------------------------------------------------- interaction
func context_target() -> Node:
	return _target


func context_kind() -> String:
	return _target_kind


func _scan_interactions() -> void:
	_target = null
	_target_kind = ""
	_prompt = ""
	var map_ok: bool = GameManager.map != null and is_instance_valid(GameManager.map)
	if map_ok:
		if GameManager.map.shop_pos.distance_to(global_position) < 66.0:
			_target_kind = "shop"
			_prompt = _prompt_text("E  เปิดร้านค้า", "แตะ  เปิดร้านค้า")
	if _target_kind == "" and map_ok:
		var best: Node = null
		var bd := 44.0
		for b in GameManager.map.bins:
			if is_instance_valid(b):
				var d: float = b.global_position.distance_to(global_position)
				if d < bd:
					bd = d
					best = b
		if best != null:
			_target = best
			_target_kind = "bin"
			_prompt = _prompt_text("E  ทิ้งขยะ  ·  F คัดแยก", "แตะ  ทิ้งขยะ  ·  คัดแยกทั้งหมด")
	if _target_kind == "":
		var g: Node2D = Garbage.nearest(global_position, pickup_radius())
		if g != null:
			_target = g
			_target_kind = "garbage"
			var wname := String(ItemDB.waste_def(String(g.waste_id))["name"])
			_prompt = _prompt_text("E  เก็บ %s  ·  V ตรวจสอบ" % wname, "แตะ เก็บ %s" % wname)
	if _target_kind == "":
		var z := _nearest_zone(30.0)
		if z != null:
			_target = z
			_target_kind = "zone"
			_prompt = _prompt_text("E  เก็บกวาดสารพิษ", "แตะ  เก็บกวาดสารพิษ")
	# Only the closest waste object wears a label, so the screen stays readable.
	if _target_kind == "garbage" and _target is Node2D:
		_set_focus_item(_target as Node2D)
	else:
		_set_focus_item(null)
	if map_ok:
		for b in GameManager.map.bins:
			if is_instance_valid(b):
				b.set_highlight(_target == b)
	if GameManager.hud != null and is_instance_valid(GameManager.hud):
		GameManager.hud.set_prompt(_prompt)


## Expanding ring for the 360° mobile sweep. Uses the generated slash_ring art.
func _show_slash(radius: float) -> void:
	if _slash == null or _slash.texture == null:
		return
	var base := maxf(radius / 44.0, 0.4)
	_slash.visible = true
	_slash.rotation = randf() * TAU
	_slash.modulate = Color(1, 1, 1, 0.9)
	_slash.scale = Vector2.ONE * base * 0.7
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_slash, "scale", Vector2.ONE * base * 1.1, 0.24)
	tw.tween_property(_slash, "modulate:a", 0.0, 0.24)
	tw.set_parallel(false)
	tw.tween_callback(func() -> void: _slash.visible = false)


func _prompt_text(pc: String, touch: String) -> String:
	return touch if Platform.mobile() else pc


func _nearest_zone(radius: float) -> Node2D:
	var best: Node2D = null
	var bd := radius
	for z in Pollution.zones:
		if is_instance_valid(z):
			var d: float = z.global_position.distance_to(global_position)
			if d < bd:
				bd = d
				best = z
	return best


func _interact() -> void:
	match _target_kind:
		"shop":
			Sfx.play("click")
			GameManager.hud.open_shop()
		"bin":
			Sfx.play("click")
			GameManager.hud.open_sorting(_target)
		"garbage":
			_pickup(_target)
		"zone":
			_clean(_target)


func _pickup(g: Node2D) -> void:
	var id := String(g.waste_id)
	var err := Inventory.add_garbage(id)
	if err != "":
		_toast(err, Color("e04a4a"))
		Sfx.play("sort_bad", 1.2, -12.0)
		return
	var cat := ItemDB.waste_cat(id)
	Sorting.note_collected(id)
	Combat.floating(ItemDB.cat_name(cat), g.global_position, ItemDB.cat_color(cat))
	_toast("เก็บ%sแล้ว" % String(ItemDB.waste_def(id)["name"]), ItemDB.cat_color(cat))
	Sfx.play("pick", randf_range(0.95, 1.1), -10.0)
	Garbage.remove(g)
	Quests.report("collect", 1)
	Quests.report("collect_" + ItemDB.cat_key(cat), 1)
	_target = null
	_target_kind = ""
	_set_focus_item(null)


func _clean(z: Node2D) -> void:
	if not Inventory.has_equipment("gloves"):
		_toast("ต้องมีถุงมือกันสารพิษก่อน", Color("e04a4a"))
		take_damage(6.0, z.global_position)
		return
	Pollution.remove_zone(z)
	Economy.add_money(14)
	Economy.add_xp(6)
	Sfx.play("clean")
	Quests.report("clean", 1)
	Combat.floating("+฿14", z.global_position + Vector2(0, -6), Color("8ad02a"))
	_target = null
	_target_kind = ""


func _use_equipment() -> void:
	if _target_kind == "bin" and _target != null:
		var res := Sorting.bulk(_target.bin_cat)
		_toast(String(res["msg"]), Color("8ad02a") if bool(res.get("ok", false)) else Color("e8c832"))
		return
	if hp < max_hp and Inventory.item_count("medkit") > 0:
		Inventory.use_item("medkit")
		heal(40.0)
		Sfx.play("clean", 1.1)
		_toast("ใช้ชุดปฐมพยาบาล", Color("8ad02a"))
		return
	if hp < max_hp:
		_toast("ชุดปฐมพยาบาลหมดแล้ว", Color("e8c832"))
	else:
		_toast("อุปกรณ์พร้อมใช้งาน", Color("c9c3b2"))


func pickup_radius() -> float:
	return 30.0 + (34.0 if Inventory.has_equipment("grabber") else 0.0)


## Focus ring + label bookkeeping: exactly one waste object is labelled at a time.
func _set_focus_item(g: Node2D) -> void:
	if _focus_item == g:
		return
	if _focus_item != null and is_instance_valid(_focus_item) and _focus_item.has_method("set_focused"):
		_focus_item.set_focused(false)
	_focus_item = g
	if g != null and is_instance_valid(g) and g.has_method("set_focused"):
		g.set_focused(true)


## Inspection: opens the educational waste panel for the targeted item.
func _inspect() -> void:
	var hud = GameManager.hud
	if hud == null or not is_instance_valid(hud):
		return
	if _target_kind != "garbage" or _target == null or not is_instance_valid(_target):
		_toast("ไม่มีขยะให้ตรวจสอบ", Color("c9c3b2"))
		return
	hud.show_waste_info(String(_target.waste_id))


func aim_dir() -> Vector2:
	return _aim


func skill_ratio() -> float:
	return clampf(1.0 - skill_cd / SKILL_COOLDOWN, 0.0, 1.0)


## Sweep skill: hits everything around the player and pulls nearby litter in.
func _skill() -> void:
	if skill_cd > 0.0:
		_toast("สกิลยังไม่พร้อม (%d วิ)" % int(ceil(skill_cd)), Color("e8c832"))
		return
	if stamina < SKILL_COST:
		_toast("พลังไม่พอใช้สกิล", Color("e8c832"))
		return
	skill_cd = SKILL_COOLDOWN
	stamina = maxf(0.0, stamina - SKILL_COST)
	stamina_delay = 0.8
	stamina_changed.emit(stamina, max_stamina)
	Combat.melee(global_position, _aim, SKILL_RADIUS, 360.0, 6.0, 220.0)
	Combat.shake(2.6)
	Sfx.play("clean", 0.9, -8.0)
	var pulled := 0
	for g in Garbage.items.duplicate():
		if not is_instance_valid(g):
			continue
		if g.global_position.distance_to(global_position) > SKILL_RADIUS:
			continue
		var gid := String(g.waste_id)
		if Inventory.add_garbage(gid) != "":
			break
		Garbage.remove(g)
		Sorting.note_collected(gid)
		Quests.report("collect_" + ItemDB.cat_key(ItemDB.waste_cat(gid)), 1)
		pulled += 1
	if pulled > 0:
		Quests.report("collect", pulled)
		Combat.floating("+%d ขยะ" % pulled, global_position + Vector2(0, -22), Color("8ad02a"), true)
	else:
		Combat.floating("กวาด!", global_position + Vector2(0, -22), Color("8ad02a"))


## Entry point used by the HUD action bar.
func action(what: String) -> void:
	if not alive or locked or _ui_open():
		return
	match what:
		"attack":
			_attack()
		"skill":
			_skill()
		"item":
			_use_equipment()
		"collect", "interact":
			_interact()


func _ui_open() -> bool:
	return GameManager.hud != null and is_instance_valid(GameManager.hud) and GameManager.hud.ui_open()


func _toast(msg: String, col: Color) -> void:
	if GameManager.hud != null and is_instance_valid(GameManager.hud):
		GameManager.hud.toast(msg, col)
