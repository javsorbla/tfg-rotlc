@tool
extends Control

signal request_close
signal end_reached

@onready var scroll_container : ScrollContainer = %ScrollContainer
@onready var credits_label : RichTextLabel = %CreditsLabel

@export var auto_scroll_speed : float = 80.0
@export var startup_delay_seconds : float = 0.8
@export var end_hold_seconds : float = 1.5
@export var emit_end_reached_on_finish : bool = false
@export var allow_any_button_exit : bool = true
@export var exit_actions : Array[StringName] = [
	&"ui_cancel",
	&"ui_accept",
	&"attack",
	&"jump",
	&"dash",
	&"power"
]

var _scroll_position : float = 0.0
var _max_scroll : float = 0.0
var _startup_timer : float = 0.0
var _finished : bool = false
var _end_hold_timer : float = 0.0

func _on_visibility_changed() -> void:
	if visible:
		_reset_scroll_state()


func _reset_scroll_state() -> void:
	_scroll_position = 0.0
	_startup_timer = startup_delay_seconds
	_finished = false
	_end_hold_timer = 0.0
	await get_tree().process_frame
	_max_scroll = credits_label.get_content_height() - scroll_container.size.y
	if _max_scroll < 0:
		_max_scroll = 0.0
	scroll_container.scroll_vertical = 0
	credits_label.grab_focus()


func _has_exit_input() -> bool:
	for action in exit_actions:
		if InputMap.has_action(action) and Input.is_action_just_pressed(action):
			return true
	return false


func _trigger_close_request() -> void:
	request_close.emit()

func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	if visible:
		_reset_scroll_state()

func _process(delta : float) -> void:
	if Engine.is_editor_hint() or not visible:
		return
	if scroll_container == null or credits_label == null:
		return

	if _has_exit_input():
		_trigger_close_request()
		return

	if _startup_timer > 0.0:
		_startup_timer -= delta
		return

	if not _finished:
		_scroll_position = minf(_max_scroll, _scroll_position + auto_scroll_speed * delta)
		scroll_container.scroll_vertical = int(round(_scroll_position))
		if _scroll_position >= _max_scroll:
			_finished = true
			if emit_end_reached_on_finish:
				end_reached.emit()

	if _finished and end_hold_seconds > 0.0:
		_end_hold_timer += delta


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not visible:
		return
	if not allow_any_button_exit:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_trigger_close_request()
	elif event is InputEventJoypadButton and event.pressed:
		_trigger_close_request()
