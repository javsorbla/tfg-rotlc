@tool
extends Control

const ALREADY_ASSIGNED_TEXT: String = "{key} ya esta asignado a {action}."
const ONE_INPUT_MINIMUM_TEXT: String = "%s debe tener al menos una tecla o boton asignado."
const WRONG_INPUT_TYPE_TEXT: String = "La entrada {key} no pertenece a {expected_device}."
const KEY_DELETION_TEXT: String = "Se va a quitar {key} de {action}."

const GAMEPLAY_ACTION_NAMES: Array[StringName] = [
	&"move_left",
	&"move_right",
	&"jump",
	&"dash",
	&"attack",
	&"power_cyan",
	&"power_red",
	&"power_yellow",
	&"pause",
]

const GAMEPLAY_ACTION_LABELS: Array[String] = [
	"Mover a la izquierda",
	"Mover a la derecha",
	"Saltar",
	"Esquivar",
	"Atacar",
	"Poder Cian",
	"Poder Rojo",
	"Poder Amarillo",
	"Pausa",
]

@onready var device_tabs: TabContainer = %DeviceTabs
@onready var keyboard_actions_list: FilteredInputActionsList = %KeyboardActionsList
@onready var gamepad_actions_list: FilteredInputActionsList = %GamepadActionsList
@onready var key_assignment_window: ConfirmationOverlaidWindow = %KeyAssignmentWindow
@onready var key_deletion_confirmation: ConfirmationOverlaidWindow = %KeyDeletionConfirmation
@onready var reset_confirmation: ConfirmationOverlaidWindow = %ResetConfirmation
@onready var one_input_minimum_message: OverlaidWindow = %OneInputMinimumMessage
@onready var already_assigned_message: OverlaidWindow = %AlreadyAssignedMessage

var _target_list_for_assignment: FilteredInputActionsList
var _target_item_for_deletion: TreeItem
var _last_input_readable_name: String


func _ready() -> void:
	_configure_action_labels(keyboard_actions_list)
	_configure_action_labels(gamepad_actions_list)
	_connect_list_signals(keyboard_actions_list)
	_connect_list_signals(gamepad_actions_list)
	_select_default_tab_by_device()


func _on_visibility_changed() -> void:
	if visible:
		_select_default_tab_by_device()


func _connect_list_signals(list_node: FilteredInputActionsList) -> void:
	list_node.button_clicked.connect(_on_actions_list_button_clicked.bind(list_node))
	list_node.already_assigned.connect(_on_actions_list_already_assigned)
	list_node.minimum_reached.connect(_on_actions_list_minimum_reached)
	list_node.input_type_rejected.connect(_on_actions_list_input_type_rejected)


func _configure_action_labels(list_node: FilteredInputActionsList) -> void:
	list_node.input_action_names = GAMEPLAY_ACTION_NAMES
	list_node.readable_action_names = GAMEPLAY_ACTION_LABELS
	list_node.show_all_actions = false
	list_node.show_built_in_actions = false
	list_node.button_minimum_size = Vector2(260, 42)
	list_node.action_label_minimum_width = 280


func _select_default_tab_by_device() -> void:
	if Input.get_connected_joypads().is_empty():
		device_tabs.current_tab = 0
	else:
		device_tabs.current_tab = 1


func _active_list() -> FilteredInputActionsList:
	if device_tabs.current_tab == 1:
		return gamepad_actions_list
	return keyboard_actions_list


func _open_key_assignment_window(action_name: String, readable_input_name: String = "") -> void:
	_target_list_for_assignment = _active_list()
	key_assignment_window.title = tr("Asignar entrada para {action}").format({action = action_name})
	if readable_input_name.strip_edges().is_empty():
		key_assignment_window.text = ""
	else:
		key_assignment_window.text = readable_input_name
	key_assignment_window.confirm_button.disabled = true
	key_assignment_window.show()


func _on_actions_list_button_clicked(action_name: String, readable_input_name: String, source_list: FilteredInputActionsList) -> void:
	_target_list_for_assignment = source_list
	_open_key_assignment_window(action_name, readable_input_name)


func _on_actions_list_already_assigned(action_name: String, input_name: String) -> void:
	already_assigned_message.text = tr(ALREADY_ASSIGNED_TEXT).format({key = input_name, action = action_name})
	already_assigned_message.show()


func _on_actions_list_minimum_reached(action_name: String) -> void:
	one_input_minimum_message.text = ONE_INPUT_MINIMUM_TEXT % action_name
	one_input_minimum_message.show()


func _on_actions_list_input_type_rejected(expected_device: String, input_name: String) -> void:
	one_input_minimum_message.text = WRONG_INPUT_TYPE_TEXT.format({key = input_name, expected_device = expected_device})
	one_input_minimum_message.show()


func _on_key_assignment_window_confirmed() -> void:
	if _target_list_for_assignment == null:
		return
	var input_event = key_assignment_window.last_input_event
	_last_input_readable_name = key_assignment_window.last_input_text
	_target_list_for_assignment.add_action_event(_last_input_readable_name, input_event)


func _on_reset_button_pressed() -> void:
	reset_confirmation.show()


func _on_reset_confirmation_confirmed() -> void:
	keyboard_actions_list.reset()
	gamepad_actions_list.reset()


func _on_key_deletion_confirmation_confirmed() -> void:
	if _target_item_for_deletion == null:
		return
	# Placeholder for future tree-mode support.
	_target_item_for_deletion = null


func _on_device_tabs_tab_changed(_tab: int) -> void:
	_target_list_for_assignment = _active_list()