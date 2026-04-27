extends OverlaidWindow

func _ready() -> void:
	%MenuButtons.focus_first()
	await get_tree().process_frame
	MenuProgressionHelper.apply_progress_to_node(self)

func _on_retry_button_pressed() -> void:
	var level_path = GameState.current_level_path
	get_tree().paused = false
	if level_path != "":
		SceneLoader.load_scene(level_path)
	else:
		SceneLoader.load_scene(AppConfig.main_menu_scene_path)

func _on_main_menu_button_pressed() -> void:
	get_tree().paused = false
	SceneLoader.load_scene(AppConfig.main_menu_scene_path)
