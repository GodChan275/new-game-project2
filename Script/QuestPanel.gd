extends Control
## Floating quest tracker: no background panel, at most three objectives,
## finished objectives fade out on their own, the header collapses the list.

const ROWS := 3
const W := 150.0
const HEAD_H := 20.0
const ROW_H := 15.0

var collapsed := false

var _head: Label
var _hit: Control
var _labels: Array[Label] = []
var _counts: Array[Label] = []
var _dots: Array[ColorRect] = []
var _t := 0.0
var _done_at := {}


func _ready() -> void:
	custom_minimum_size = Vector2(W, HEAD_H + ROWS * ROW_H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UI.hud_theme()

	_head = UI.label(self, "▾ ภารกิจ", 12, UI.CREAM)
	_head.position = Vector2(0, 27)
	_head.size = Vector2(W, HEAD_H)
	_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_head.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_head.add_theme_constant_override("outline_size", 3)

	for i in ROWS:
		var dot := ColorRect.new()
		dot.position = Vector2(2, HEAD_H + i * ROW_H + 4)
		dot.size = Vector2(2, 2)
		dot.color = UI.GOLD
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dot)
		_dots.append(dot)

		var l := UI.label(self, "", 8, UI.CREAM)
		l.position = Vector2(6, HEAD_H + i * ROW_H + 25)
		l.size = Vector2(W - 10, ROW_H)
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		l.add_theme_constant_override("outline_size", 3)
		_labels.append(l)

		var c := UI.label(self, "", 8, UI.CREAM)
		c.position = Vector2(W - 26, HEAD_H + i * ROW_H + 25)
		c.size = Vector2(24, ROW_H)
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		c.add_theme_constant_override("outline_size", 3)
		_counts.append(c)

	_hit = Control.new() 
	_hit.position = Vector2(0, 25)
	_hit.size = Vector2(W, HEAD_H)
	_hit.mouse_filter = Control.MOUSE_FILTER_STOP
	_hit.tooltip_text = "ย่อ / ขยาย · J เปิดสมุดภารกิจ"
	_hit.gui_input.connect(_on_hit)
	add_child(_hit)

	Quests.missions_changed.connect(_refresh)
	_refresh()


func _on_hit(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		toggle_collapse()


func toggle_collapse() -> void:
	collapsed = not collapsed
	Sfx.play("click", 1.25, -20.0)
	_refresh()


func _refresh() -> void:
	var list: Array = []
	for m in Quests.lines():
		if not bool(m["done"]):
			list.append(m)
	for m in Quests.lines():
		if bool(m["done"]):
			list.append(m)

	var now := Time.get_ticks_msec() / 1000.0
	var rows: Array = []
	for q in list:
		var key := String(q["th"])
		if bool(q["done"]):
			if not _done_at.has(key):
				_done_at[key] = now
			if now - float(_done_at[key]) > 1.6:
				continue
		else:
			_done_at.erase(key)
		rows.append(q)
		if rows.size() >= ROWS:
			break

	for i in ROWS:
		var lbl := _labels[i]
		var cnt := _counts[i]
		lbl.visible = not collapsed
		cnt.visible = not collapsed
		if i >= rows.size() or collapsed:
			lbl.text = ""
			cnt.text = ""
			_dots[i].visible = false
			continue
		_dots[i].visible = true
		var q: Dictionary = rows[i]
		var done := bool(q["done"])
		var cat := String(q["cat"])
		_dots[i].color = UI.GREEN if done else Quests.cat_color(cat)
		lbl.text = ("✓ " if done else "") + String(q["th"])
		lbl.add_theme_color_override("font_color", UI.GREEN if done else (UI.GOLD if cat == "main" else UI.CREAM))
		cnt.text = "%d/%d" % [int(q["progress"]), int(q["target"])]
		cnt.add_theme_color_override("font_color", UI.GREEN if done else UI.GOLD)

	var arrow := "▸" if collapsed else "▾"
	_head.text = "%s ภารกิจ  %d/%d" % [arrow, Quests.completed_today(), Quests.missions.size()]


func _process(delta: float) -> void:
	_t += delta
	if _t >= 0.35:
		_t = 0.0
		_refresh()
