extends OverlaidWindow

func _ready() -> void:
	%MenuButtons.focus_first()
	await get_tree().process_frame
	MenuProgressionHelper.apply_progress_to_node(self)

func show() -> void:
	# Asegurar que el juego esté pausado antes de mostrar
	print("[DeathScreen] show() called, current paused state: ", get_tree().paused)
	if not get_tree().paused:
		get_tree().paused = true
		print("[DeathScreen] Game was not paused, pausing now")
	# Llamar al show del padre
	super.show()
	print("[DeathScreen] DeathScreen is now visible: ", visible)

func _on_retry_button_pressed() -> void:
	print("[DeathScreen] Retry button pressed")
	close()
	await get_tree().process_frame
	get_tree().paused = false
	var level_path := GameState.current_level_path
	if level_path != "":
		SceneLoader.load_scene(level_path)
	else:
		SceneLoader.load_scene(AppConfig.main_menu_scene_path)

func _on_main_menu_button_pressed() -> void:
	get_tree().paused = false
	SceneLoader.load_scene(AppConfig.main_menu_scene_path)
