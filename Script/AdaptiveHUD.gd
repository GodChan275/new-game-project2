class_name AdaptiveHUD
extends RefCounted
## Layout maths for the two HUD modes. Mobile keeps the same compact chips but
## reserves the lower corners for the joystick and the action buttons and drops
## the desktop shortcut column, so the world stays visible.

const STATUS_SIZE := Vector2(196, 62)
const QUEST_SIZE := Vector2(116, 38)
const BAR_WIDTH := 125.0


static func layout(mobile: bool, sz: Vector2) -> Dictionary:
	var map_size := 30.0 if mobile else 34.0
	var objective_w := 118.0
	var hotbar_y := sz.y - (26.0 if mobile else 24.0)
	return {
		"mobile": mobile,
		"status": Rect2(Vector2(4, 4), STATUS_SIZE),
		"quests": Rect2(Vector2(4, 70), QUEST_SIZE),
		"objective": Rect2(Vector2(sz.x - objective_w - 4.0, 4), Vector2(objective_w, 86)),
		"map": Rect2(Vector2(sz.x - map_size - 4.0, 94), Vector2(map_size, map_size)),
		"hotbar": Rect2(Vector2((sz.x - BAR_WIDTH) * 0.5, hotbar_y), Vector2(BAR_WIDTH, 20)),
		"buttons": Rect2(Vector2(sz.x - 72, sz.y - 18), Vector2(68, 13)),
		"toasts": Rect2(Vector2((sz.x - 180) * 0.5, 62), Vector2(180, 54)),
		"quest_pop": Rect2(Vector2((sz.x - 150) * 0.5, 32), Vector2(150, 28)),
		"banner": Rect2(Vector2(0, sz.y * 0.36), Vector2(sz.x, 26)),
	}


static func prompt_y(mobile: bool, sz: Vector2) -> float:
	return sz.y - (46.0 if mobile else 42.0)
