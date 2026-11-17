extends Control
## Application entry point: asks first-time players for a platform, then shows
## the main menu and hands off to the game scene.

const MENU_SCENE := preload("res://MainMenu.tscn")
const DEVICE_SCENE := preload("res://DeviceSelection.tscn")

var _menu: Control
var _select: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	if Platform.has_saved_mode():
		_show_menu()
	else:
		_show_device_select()


func _show_device_select() -> void:
	_select = DEVICE_SCENE.instantiate()
	add_child(_select)
	_select.chosen.connect(_on_device_chosen)


func _on_device_chosen(_mode: String) -> void:
	if _select != null and is_instance_valid(_select):
		_select.queue_free()
		_select = null
	_show_menu()


func _show_menu() -> void:
	_menu = MENU_SCENE.instantiate()
	add_child(_menu)
	_menu.start_selected.connect(_on_menu_action)


func _on_menu_action(mode: String) -> void:
	match mode:
		"new", "continue":
			if mode == "continue":
				GameManager.continue_game()
			else:
				GameManager.start_new_game()
		"quit":
			get_tree().quit()
