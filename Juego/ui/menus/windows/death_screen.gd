extends OverlaidWindow

func _ready() -> void:
	%MenuButtons.focus_first()

func _on_retry_button_pressed() -> void:
	var level_path = GameState.current_level_path
	if level_path != "":
		SceneLoader.load_scene(level_path)
	else:
		SceneLoader.load_scene(AppConfig.main_menu_scene_path)

func _on_main_menu_button_pressed() -> void:
	SceneLoader.load_scene(AppConfig.main_menu_scene_path)