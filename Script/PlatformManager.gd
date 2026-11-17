extends Node
## Platform selection and persisted control / HUD preferences.
##
## The game ships one build for PC and touch. `control_mode` is the player's
## choice ("auto" / "pc" / "mobile"); `mobile()` is the effective mode after
## detection, which the HUD, player and touch overlay all read.

signal mode_changed(mobile: bool)
signal settings_changed

const CFG_PATH := "user://toxic_wasteland.cfg"
const SECTION := "platform"
const MODES := ["auto", "pc", "mobile"]
const MODE_LABELS := {
	"auto": "อัตโนมัติ",
	"pc": "PC / คีย์บอร์ด",
	"mobile": "มือถือ / สัมผัส",
}
## UI size presets. Mobile starts at Large; PC at Normal.
const UI_SIZES := ["small", "normal", "large", "xlarge"]
const UI_SIZE_LABELS := {
	"small": "เล็ก",
	"normal": "ปกติ",
	"large": "ใหญ่",
	"xlarge": "ใหญ่พิเศษ",
}
const UI_SIZE_SCALES := {"small": 0.85, "normal": 1.0, "large": 1.2, "xlarge": 1.35}
const UI_SCALE_STEPS := [1.0, 1.15, 1.3, 0.85]
const JOYSTICK_STEPS := [1.0, 1.2, 1.4, 0.8]
const OPACITY_STEPS := [1.0, 0.8, 0.6, 0.9]
const SENSITIVITY_STEPS := [1.0, 1.3, 1.6, 0.7]
## --- display / graphics ---
const WINDOW_MODES := ["windowed", "borderless", "fullscreen"]
const WINDOW_LABELS := {
	"windowed": "หน้าต่าง",
	"borderless": "ไร้ขอบ",
	"fullscreen": "จอเต็ม",
}
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]
const QUALITIES := ["low", "medium", "high", "ultra"]
const QUALITY_LABELS := {"low": "ต่ำ", "medium": "กลาง", "high": "สูง", "ultra": "สูงสุด"}
const QUALITY_MSAA := {
	"low": Viewport.MSAA_DISABLED,
	"medium": Viewport.MSAA_2X,
	"high": Viewport.MSAA_4X,
	"ultra": Viewport.MSAA_4X,
}
const RENDER_SCALE_STEPS := [1.0, 0.75, 0.5]
const DISPLAY_SECTION := "display"
const MIN_WINDOW := Vector2i(640, 360)

var window_mode := "windowed"
var resolution_index := 1
var quality := "high"
var render_scale := 1.0

var control_mode := "auto"
var touch_available := false
var recommended := "pc"

var ui_size := ""
var ui_scale := 1.0
## Font bump for the inventory / shop / quest book on touch screens.
var joystick_scale := 1.0
var button_opacity := 1.0
var sensitivity := 1.0

var _saved := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	touch_available = _detect_touch()
	recommended = "mobile" if touch_available else "pc"
	_load()
	_apply_ui_size()
	_apply_display()
	_apply_quality()


## True when the player (or a previous session) already picked a platform.
func has_saved_mode() -> bool:
	return _saved


func mobile() -> bool:
	if control_mode == "mobile":
		return true
	if control_mode == "pc":
		return false
	return touch_available


func mode_label() -> String:
	return String(MODE_LABELS.get(control_mode, control_mode))


func cycle_mode() -> String:
	var i := MODES.find(control_mode)
	set_mode(MODES[(i + 1) % MODES.size()] if i >= 0 else "auto")
	return control_mode


func set_mode(mode: String) -> void:
	if not MODES.has(mode):
		mode = "auto"
	var changed := mobile() != (mode == "mobile" or (mode == "auto" and touch_available))
	control_mode = mode
	_saved = true
	_apply_ui_size()
	_save()
	if changed:
		mode_changed.emit(mobile())


func ui_size_key() -> String:
	if UI_SIZES.has(ui_size):
		return ui_size
	return "large" if mobile() else "normal"


func ui_size_label() -> String:
	return String(UI_SIZE_LABELS.get(ui_size_key(), ui_size_key()))


func _apply_ui_size() -> void:
	ui_scale = float(UI_SIZE_SCALES.get(ui_size_key(), 1.0))


func set_ui_size(key: String) -> void:
	if not UI_SIZES.has(key):
		key = "normal"
	ui_size = key
	_apply_ui_size()
	_save()
	settings_changed.emit()


func cycle_ui_size() -> String:
	var i := UI_SIZES.find(ui_size_key())
	set_ui_size(UI_SIZES[(i + 1) % UI_SIZES.size()] if i >= 0 else "normal")
	return ui_size_key()


func set_ui_scale(value: float) -> void:
	ui_scale = value
	_save()
	settings_changed.emit()


func set_joystick_scale(value: float) -> void:
	joystick_scale = value
	_save()
	settings_changed.emit()


func set_button_opacity(value: float) -> void:
	button_opacity = value
	_save()
	settings_changed.emit()


func set_sensitivity(value: float) -> void:
	sensitivity = value
	_save()
	settings_changed.emit()


# ---------------------------------------------------------------- display
func resolution() -> Vector2i:
	return RESOLUTIONS[clampi(resolution_index, 0, RESOLUTIONS.size() - 1)]


## Pixels the game renders into: the chosen resolution scaled by render_scale.
func window_size() -> Vector2i:
	var base := resolution()
	var size := Vector2i(roundi(base.x * render_scale), roundi(base.y * render_scale))
	return Vector2i(maxi(size.x, MIN_WINDOW.x), maxi(size.y, MIN_WINDOW.y))


func window_mode_label() -> String:
	return String(WINDOW_LABELS.get(window_mode, window_mode))


func resolution_label() -> String:
	return "%d × %d" % [resolution().x, resolution().y]


func quality_label() -> String:
	return String(QUALITY_LABELS.get(quality, quality))


func render_scale_label() -> String:
	return "%d%%" % roundi(render_scale * 100.0)


func set_window_mode(mode: String) -> void:
	window_mode = mode if WINDOW_MODES.has(mode) else "windowed"
	_apply_display()
	_save()
	settings_changed.emit()


func cycle_window_mode() -> String:
	var i := WINDOW_MODES.find(window_mode)
	set_window_mode(WINDOW_MODES[(i + 1) % WINDOW_MODES.size()] if i >= 0 else "windowed")
	return window_mode


func set_resolution_index(index: int) -> void:
	resolution_index = clampi(index, 0, RESOLUTIONS.size() - 1)
	_apply_display()
	_save()
	settings_changed.emit()


func cycle_resolution() -> int:
	set_resolution_index((resolution_index + 1) % RESOLUTIONS.size())
	return resolution_index


func set_render_scale(value: float) -> void:
	render_scale = clampf(value, 0.5, 1.0)
	_apply_display()
	_save()
	settings_changed.emit()


func cycle_render_scale() -> float:
	var i := RENDER_SCALE_STEPS.find(render_scale)
	render_scale = float(RENDER_SCALE_STEPS[(i + 1) % RENDER_SCALE_STEPS.size()] if i >= 0 else RENDER_SCALE_STEPS[0])
	_apply_display()
	_save()
	settings_changed.emit()
	return render_scale


func set_quality(value: String) -> void:
	quality = value if QUALITIES.has(value) else "high"
	_apply_quality()
	_save()
	settings_changed.emit()


func cycle_quality() -> String:
	var i := QUALITIES.find(quality)
	set_quality(QUALITIES[(i + 1) % QUALITIES.size()] if i >= 0 else "high")
	return quality


## Low quality drops the full-screen haze pass; everything else keeps it.
func haze_enabled() -> bool:
	return quality != "low"


## Applies the saved window mode, size and render scale. Safe in headless runs.
func _apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var win := get_tree().root
	if win == null:
		return
	win.min_size = MIN_WINDOW
	var screen := DisplayServer.screen_get_size()
	var usable := DisplayServer.screen_get_usable_rect()
	match window_mode:
		"fullscreen":
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		"borderless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			DisplayServer.window_set_position(Vector2i.ZERO)
			DisplayServer.window_set_size(screen)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			var target := window_size()
			target = Vector2i(mini(target.x, usable.size.x), mini(target.y, usable.size.y))
			DisplayServer.window_set_size(target)
			DisplayServer.window_set_position(usable.position + (usable.size - target) / 2)


## Applies the 2D anti-aliasing level of the current quality preset.
func _apply_quality() -> void:
	var vp := get_viewport()
	if vp != null:
		vp.msaa_2d = QUALITY_MSAA.get(quality, Viewport.MSAA_4X)


## Cycle helpers used by the settings / pause menus.
## Kept for older callers: cycles the size preset and returns its scale.
func cycle_ui_scale() -> float:
	cycle_ui_size()
	return ui_scale


func cycle_joystick_scale() -> float:
	joystick_scale = _next(JOYSTICK_STEPS, joystick_scale)
	_save()
	settings_changed.emit()
	return joystick_scale


func cycle_button_opacity() -> float:
	button_opacity = _next(OPACITY_STEPS, button_opacity)
	_save()
	settings_changed.emit()
	return button_opacity


func cycle_sensitivity() -> float:
	sensitivity = _next(SENSITIVITY_STEPS, sensitivity)
	_save()
	settings_changed.emit()
	return sensitivity


func _next(steps: Array, value: float) -> float:
	var i := steps.find(value)
	if i < 0:
		return float(steps[0])
	return float(steps[(i + 1) % steps.size()])


## Merge-safe write used by the menu so its volume/fullscreen keys and the
## platform keys can share one ConfigFile.
func write_setting(section: String, key: String, value) -> void:
	var cfg := ConfigFile.new()
	cfg.load(CFG_PATH)
	cfg.set_value(section, key, value)
	cfg.save(CFG_PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) != OK:
		return
	if cfg.has_section_key(SECTION, "control_mode"):
		var mode := String(cfg.get_value(SECTION, "control_mode", "auto"))
		control_mode = mode if MODES.has(mode) else "auto"
		_saved = true
	if cfg.has_section_key(SECTION, "ui_size"):
		var size_key := String(cfg.get_value(SECTION, "ui_size", ""))
		if UI_SIZES.has(size_key):
			ui_size = size_key
	joystick_scale = float(cfg.get_value(SECTION, "joystick_scale", 1.0))
	button_opacity = float(cfg.get_value(SECTION, "button_opacity", 1.0))
	sensitivity = float(cfg.get_value(SECTION, "sensitivity", 1.0))

	if cfg.has_section(DISPLAY_SECTION):
		var mode := String(cfg.get_value(DISPLAY_SECTION, "window_mode", "windowed"))
		window_mode = mode if WINDOW_MODES.has(mode) else "windowed"
		resolution_index = clampi(int(cfg.get_value(DISPLAY_SECTION, "resolution_index", 1)), 0, RESOLUTIONS.size() - 1)
		var q := String(cfg.get_value(DISPLAY_SECTION, "quality", "high"))
		quality = q if QUALITIES.has(q) else "high"
		render_scale = clampf(float(cfg.get_value(DISPLAY_SECTION, "render_scale", 1.0)), 0.5, 1.0)
	elif bool(cfg.get_value("ui", "fullscreen", false)):
		# migrate the old boolean fullscreen toggle
		window_mode = "fullscreen"


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(CFG_PATH)
	cfg.set_value(SECTION, "control_mode", control_mode)
	cfg.set_value(SECTION, "ui_size", ui_size_key())
	cfg.set_value(SECTION, "ui_scale", ui_scale)
	cfg.set_value(SECTION, "joystick_scale", joystick_scale)
	cfg.set_value(SECTION, "button_opacity", button_opacity)
	cfg.set_value(SECTION, "sensitivity", sensitivity)
	cfg.set_value(DISPLAY_SECTION, "window_mode", window_mode)
	cfg.set_value(DISPLAY_SECTION, "resolution_index", resolution_index)
	cfg.set_value(DISPLAY_SECTION, "quality", quality)
	cfg.set_value(DISPLAY_SECTION, "render_scale", render_scale)
	cfg.save(CFG_PATH)


## Browser detection is only used for the recommendation, never to force a mode.
func _detect_touch() -> bool:
	if DisplayServer.is_touchscreen_available():
		return true
	if OS.has_feature("web"):
		var js := Engine.get_singleton("JavaScriptBridge")
		if js != null:
			var found = js.eval(
				"(navigator.maxTouchPoints||0)>0 || "
				+ "/Android|iPhone|iPad|iPod|Mobile/i.test(navigator.userAgent)"
			)
			return bool(found)
	return false
