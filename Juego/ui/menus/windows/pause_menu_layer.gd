extends CanvasLayer

const PAUSED_VOLUME_DB := -15.0

@onready var pause_menu = %PauseMenu

var _saved_music_volume_db := 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if not event.is_action_pressed("pause"):
		return
	if visible:
		if pause_menu.has_method("is_popup_open") and pause_menu.is_popup_open():
			return
		pause_menu.close()
		hide()
	else:
		show()
	get_viewport().set_input_as_handled()

func _on_pause_menu_hidden():
	hide()

func _on_visibility_changed():
	if visible:
		pause_menu.show()
		_save_and_lower_music_volume()
	else:
		_restore_music_volume()

func _save_and_lower_music_volume() -> void:
	var idx := AudioServer.get_bus_index("Música")
	if idx < 0:
		return
	_saved_music_volume_db = AudioServer.get_bus_volume_db(idx)
	AudioServer.set_bus_volume_db(idx, PAUSED_VOLUME_DB)

func _restore_music_volume() -> void:
	var idx := AudioServer.get_bus_index("Música")
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, _saved_music_volume_db)

func _ready():
	visibility_changed.connect(_on_visibility_changed)
