@tool
extends Control

signal end_reached
signal request_close

@export var auto_scroll_speed: float = 60.0
@export var input_scroll_speed : float = 400.0
@export var scroll_restart_delay : float = 1.5
@export var scroll_paused : bool = false
@export_file("*.tscn") var main_menu_scene_path: String = ""
@export var allow_any_button_exit : bool = true
@export var exit_hint_blink_speed : float = 2.2
@export var exit_actions : Array[StringName] = [
	&"ui_cancel",
	&"ui_accept",
	&"attack",
	&"jump",
	&"dash",
	&"power"
]

var timer : Timer = Timer.new()
var _current_scroll_position : float = 0.0
var _hint_blink_time : float = 0.0
var _hint_refresh_accum : float = 0.0

@onready var header_space : Control = %HeaderSpace
@onready var footer_space : Control = %FooterSpace
@onready var credits_label : Control = %CreditsLabel
@onready var scroll_container : ScrollContainer = %ScrollContainer
@onready var exit_hint_label : Label = %ExitHintLabel


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func set_header_and_footer() -> void:
	header_space.custom_minimum_size.y = size.y
	footer_space.custom_minimum_size.y = size.y
	credits_label.custom_minimum_size.x = size.x

func _on_resized() -> void:
	set_header_and_footer()
	_current_scroll_position = scroll_container.scroll_vertical

func _end_reached() -> void:
	scroll_paused = true
	end_reached.emit()

func is_end_reached() -> bool:
	var _end_of_credits_vertical = credits_label.size.y + header_space.size.y
	return scroll_container.scroll_vertical > _end_of_credits_vertical

func _check_end_reached() -> void:
	if not is_end_reached():
		return
	_end_reached()

func _scroll_container(amount : float) -> void:
	if not visible or scroll_paused:
		return
	_current_scroll_position += amount
	scroll_container.scroll_vertical = round(_current_scroll_position)
	_check_end_reached()

func _on_gui_input(event : InputEvent) -> void:
	# Captures the mouse scroll wheel input event
	if event is InputEventMouseButton:
		scroll_paused = true
		_start_scroll_restart_timer()
	_check_end_reached()

func _on_scroll_started() -> void:
	# Captures the touch input event
	scroll_paused = true
	_start_scroll_restart_timer()

func _start_scroll_restart_timer() -> void:
	timer.start(scroll_restart_delay)

func _on_scroll_restart_timer_timeout() -> void:
	_current_scroll_position = scroll_container.scroll_vertical
	scroll_paused = false

func _on_visibility_changed() -> void:
	if visible:
		scroll_container.scroll_vertical = 0
		_current_scroll_position = scroll_container.scroll_vertical
		scroll_paused = false
		_hint_blink_time = 0.0
		_hint_refresh_accum = 0.0
		_update_exit_hint_text()
		_hide_scrollbar()


func _get_main_menu_scene_path() -> String:
	if not main_menu_scene_path.is_empty():
		return main_menu_scene_path
	if has_node("/root/AppConfig"):
		return AppConfig.main_menu_scene_path
	return ""


func _trigger_close_request() -> void:
	if get_signal_connection_list("request_close").is_empty():
		var menu_path := _get_main_menu_scene_path()
		if not menu_path.is_empty():
			SceneLoader.load_scene(menu_path)
		return
	request_close.emit()


func _update_exit_hint_text() -> void:
	if exit_hint_label == null:
		return
	if Input.get_connected_joypads().is_empty():
		exit_hint_label.text = "ESC para salir"
	else:
		exit_hint_label.text = "A, B o START para salir"

func _hide_scrollbar() -> void:
	var v_bar := scroll_container.get_v_scroll_bar()
	if v_bar:
		v_bar.modulate = Color(1, 1, 1, 0)
		v_bar.mouse_filter = MOUSE_FILTER_IGNORE


func _ready() -> void:
	scroll_container.scroll_started.connect(_on_scroll_started)
	gui_input.connect(_on_gui_input)
	resized.connect(_on_resized)
	visibility_changed.connect(_on_visibility_changed)
	timer.timeout.connect(_on_scroll_restart_timer_timeout)
	set_header_and_footer()
	add_child(timer)
	scroll_paused = false
	_update_exit_hint_text()
	_hide_scrollbar()


func _process(delta : float) -> void:
	var input_axis = Input.get_axis("ui_up", "ui_down")
	if input_axis != 0:
		_scroll_container(input_axis * input_scroll_speed * delta)
	else:
		_scroll_container(auto_scroll_speed * delta)

	if exit_hint_label != null:
		_hint_blink_time += delta
		var blink := 0.5 + 0.5 * sin(_hint_blink_time * TAU * (exit_hint_blink_speed * 0.5))
		exit_hint_label.modulate.a = lerpf(0.28, 1.0, blink)

		_hint_refresh_accum += delta
		if _hint_refresh_accum >= 1.0:
			_hint_refresh_accum = 0.0
			_update_exit_hint_text()


func _unhandled_input(event : InputEvent) -> void:
	if Engine.is_editor_hint() or not visible:
		return
	if not allow_any_button_exit:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_trigger_close_request()
	elif event is InputEventJoypadButton and event.pressed:
		_trigger_close_request()

func _exit_tree() -> void:
	_current_scroll_position = scroll_container.scroll_vertical
