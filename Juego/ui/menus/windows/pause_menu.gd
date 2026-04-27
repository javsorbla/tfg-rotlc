extends OverlaidWindow

@export var options_menu_scene : PackedScene
## Path to a main menu scene.
## Will attempt to read from AppConfig if left empty.
@export_file("*.tscn") var main_menu_scene_path : String
@export_node_path(&"ConfirmationOverlaidWindow") var restart_confirmation_node_path : NodePath
@export_node_path(&"ConfirmationOverlaidWindow") var main_menu_confirmation_node_path : NodePath
@export_node_path(&"ConfirmationOverlaidWindow") var exit_confirmation_node_path : NodePath
@export var menu_container_node_path : NodePath = ^".."

@onready var restart_confirmation : ConfirmationOverlaidWindow = get_node(restart_confirmation_node_path)
@onready var main_menu_confirmation : ConfirmationOverlaidWindow = get_node(main_menu_confirmation_node_path)
@onready var exit_confirmation : ConfirmationOverlaidWindow = get_node(exit_confirmation_node_path)
@onready var menu_container : Node = get_node(menu_container_node_path)
@onready var options_button = %OptionsButton
@onready var main_menu_button = %MainMenuButton
@onready var exit_button = %ExitButton

var open_window : Node
var _ignore_first_cancel : bool = false

func get_main_menu_scene_path() -> String:
	if main_menu_scene_path.is_empty():
		return AppConfig.main_menu_scene_path
	return main_menu_scene_path

func close_window() -> void:
	if open_window != null:
		if open_window.has_method("close"):
			open_window.close()
		else:
			open_window.hide()
		open_window = null

func _disable_focus() -> void:
	for child in %MenuButtons.get_children():
		if child is Control:
			child.focus_mode = FOCUS_NONE

func _enable_focus() -> void:
	for child in %MenuButtons.get_children():
		if child is Control:
			child.focus_mode = FOCUS_ALL

func _show_window(window : Control) -> void:
	_disable_focus.call_deferred()
	window.show()
	open_window = window
	await window.hidden
	open_window = null
	_enable_focus.call_deferred()

func close() -> void:
	if open_window != null:
		close_window()
	super.close()

func _load_and_show_menu(scene : PackedScene) -> void:
	var window_instance : Control = scene.instantiate()
	window_instance.visible = false
	menu_container.add_child(window_instance)
	# Esperar a que el nodo esté en el árbol antes de aplicar progresión
	await get_tree().process_frame
	MenuProgressionHelper.apply_progress_to_node(window_instance)
	await _show_window(window_instance)
	window_instance.queue_free()

func _handle_cancel_input() -> void:
	if _ignore_first_cancel:
		_ignore_first_cancel = false
		return
	if open_window != null:
		close_window()
	else:
		super._handle_cancel_input()

func show() -> void:
	super.show()
	if Input.is_action_pressed("ui_cancel"):
		_ignore_first_cancel = true
	# Esperar a que el árbol esté listo antes de aplicar progresión
	await get_tree().process_frame
	MenuProgressionHelper.apply_progress_to_node(self)
	if restart_confirmation != null:
		MenuProgressionHelper.apply_progress_to_node(restart_confirmation)
	if main_menu_confirmation != null:
		MenuProgressionHelper.apply_progress_to_node(main_menu_confirmation)
	if exit_confirmation != null:
		MenuProgressionHelper.apply_progress_to_node(exit_confirmation)

func _refresh_exit_button() -> void:
	exit_button.visible = !OS.has_feature("web")

func _refresh_options_button() -> void:
	options_button.visible = options_menu_scene != null

func _refresh_main_menu_button() -> void:
	main_menu_button.visible = !get_main_menu_scene_path().is_empty()

func _ready() -> void:
	_refresh_exit_button()
	_refresh_options_button()
	_refresh_main_menu_button()
	restart_confirmation.confirmed.connect(_on_restart_confirmation_confirmed)
	main_menu_confirmation.confirmed.connect(_on_main_menu_confirmation_confirmed)
	exit_confirmation.confirmed.connect(_on_exit_confirmation_confirmed)

func _on_restart_button_pressed() -> void:
	_show_window(restart_confirmation)

func _on_options_button_pressed() -> void:
	_load_and_show_menu(options_menu_scene)

func _on_main_menu_button_pressed() -> void:
	_show_window(main_menu_confirmation)

func _on_exit_button_pressed() -> void:
	_show_window(exit_confirmation)

func _on_restart_confirmation_confirmed() -> void:
	# Cerrar ventana de confirmación PRIMERO
	if open_window != null:
		close_window()
	# Esperar a que el árbol esté limpio
	await get_tree().process_frame
	# LUEGO despausa y carga
	get_tree().paused = false
	SceneLoader.load_scene(GameState.current_level_path)
	close()

func _on_main_menu_confirmation_confirmed() -> void:
	# Cerrar ventana de confirmación PRIMERO
	if open_window != null:
		close_window()
	# Esperar a que el árbol esté limpio
	await get_tree().process_frame
	# LUEGO despausa y carga
	get_tree().paused = false
	SceneLoader.load_scene(get_main_menu_scene_path())
	close()

func _on_exit_confirmation_confirmed():
	get_tree().quit()

func _input(event: InputEvent) -> void:
	# Debug input removed - levels are set by scene
	pass

func _on_close_button_pressed() -> void:
	close()

func _on_save_game_button_pressed() -> void:
	pass

func _on_load_game_button_pressed() -> void:
	pass
