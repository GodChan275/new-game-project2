extends Node
## Texture + animation helpers. All art is loaded from res://Assets/Sprites.

var _cache: Dictionary = {}


func tex(texture_name: String) -> Texture2D:
	if _cache.has(texture_name):
		return _cache[texture_name]
	var path := "res://Assets/Sprites/%s.png" % texture_name
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path) as Texture2D
	_cache[texture_name] = t
	return t


func icon(icon_name: String) -> Texture2D:
	return tex("icon_" + icon_name)


func player_sheet() -> Texture2D:
	return load("res://Assets/image/Player/Player.png") as Texture2D


## Builds walk/idle animations for a 4-direction character sheet.
## rows order: down, right, left, up
func quad_frames(sheet: Texture2D, fw: int, fh: int, cols: int, dirs: Array) -> SpriteFrames:
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	for r in dirs.size():
		var d: String = dirs[r]
		var walk := "walk_" + d
		var idle := "idle_" + d
		sf.add_animation(idle)
		sf.set_animation_speed(idle, 4.0)
		sf.set_animation_loop(idle, true)
		sf.add_animation(walk)
		sf.set_animation_speed(walk, 9.0)
		sf.set_animation_loop(walk, true)
		sf.add_frame(idle, _atlas(sheet, r * fw if false else 0, r, fw, fh), 1.0)
		for c in cols:
			sf.add_frame(walk, _atlas(sheet, c, r, fw, fh), 1.0)
	return sf


## Builds idle/walk/attack/die animations for a single-row enemy strip.
func strip_frames(sheet: Texture2D, fw: int, fh: int, count: int) -> SpriteFrames:
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	sf.add_animation("idle")
	sf.set_animation_speed("idle", 3.0)
	sf.add_frame("idle", _atlas(sheet, 0, 0, fw, fh), 1.0)
	sf.add_animation("walk")
	sf.set_animation_speed("walk", 8.0)
	for i in count:
		sf.add_frame("walk", _atlas(sheet, i, 0, fw, fh), 1.0)
	sf.add_animation("attack")
	sf.set_animation_speed("attack", 12.0)
	sf.set_animation_loop("attack", false)
	for i in [min(2, count - 1), min(3, count - 1)]:
		sf.add_frame("attack", _atlas(sheet, i, 0, fw, fh), 1.0)
	sf.add_animation("die")
	sf.set_animation_speed("die", 8.0)
	sf.set_animation_loop("die", false)
	for i in [1, 2, 3]:
		sf.add_frame("die", _atlas(sheet, min(i, count - 1), 0, fw, fh), 1.0)
	return sf


## Shared pixel-UI theme: small default font keeps control minimum sizes tight.
var _ui_theme: Theme = null


func ui_theme() -> Theme:
	if _ui_theme == null:
		_ui_theme = Theme.new()
		_ui_theme.default_font_size = 7
	return _ui_theme


func _atlas(sheet: Texture2D, col: int, row: int, fw: int, fh: int) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = sheet
	a.region = Rect2(col * fw, row * fh, fw, fh)
	a.filter_clip = true
	return a
