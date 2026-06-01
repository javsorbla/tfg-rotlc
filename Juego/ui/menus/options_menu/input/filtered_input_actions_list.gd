@tool
class_name FilteredInputActionsList
extends InputActionsList

enum DeviceFilter {
	KEYBOARD,
	GAMEPAD,
}

signal input_type_rejected(expected_device: String, input_name: String)

@export var device_filter: DeviceFilter = DeviceFilter.KEYBOARD
@export var action_label_minimum_width: float = 280.0

var _button_raw_input_map: Dictionary = {}

const SPANISH_INPUT_REPLACEMENTS := {
	"Space": "Espacio",
	"Enter": "Intro",
	"Escape": "Esc",
	"Backspace": "Retroceso",
	"Delete": "Supr",
	"Insert": "Insert",
	"PageUp": "RePag",
	"PageDown": "AvPag",
	"Up": "Arriba",
	"Down": "Abajo",
	"Left": "Izquierda",
	"Right": "Derecha",
	"Shift": "Mayus",
	"Ctrl": "Control",
	"Alt": "Alt",
	"Tab": "Tabulador",
	"Mouse": "Raton",
	"Button": "Boton",
	"Wheel": "Rueda",
	"Joypad": "Mando",
	"Start": "START",
}


func _to_spanish_input_name(raw_text: String) -> String:
	var value := raw_text
	if value.is_empty() or value == EMPTY_INPUT_ACTION_STRING:
		return value
	for key in SPANISH_INPUT_REPLACEMENTS.keys():
		value = value.replace(key, SPANISH_INPUT_REPLACEMENTS[key])
	return value


func _update_assigned_inputs_and_button(action_name: String, action_group: int, input_event: InputEvent) -> void:
	var raw_input_name = InputEventHelper.get_text(input_event)
	var new_readable_input_name = _to_spanish_input_name(raw_input_name)
	var button = _get_button_by_action(action_name, action_group)
	if not button:
		return
	var icon: Texture
	if input_icon_mapper:
		icon = input_icon_mapper.get_icon(input_event)
	if icon:
		button.icon = icon
	else:
		button.icon = null
	if button.icon == null:
		button.text = new_readable_input_name
	else:
		button.text = ""
	if button in _button_raw_input_map:
		assigned_input_events.erase(_button_raw_input_map[button])
	button_readable_input_map[button] = new_readable_input_name
	_button_raw_input_map[button] = raw_input_name
	assigned_input_events[raw_input_name] = action_name


func _clear_button(action_name: String, action_group: int) -> void:
	var button = _get_button_by_action(action_name, action_group)
	if not button:
		return
	button.icon = null
	button.text = EMPTY_INPUT_ACTION_STRING
	if button in _button_raw_input_map:
		assigned_input_events.erase(_button_raw_input_map[button])
		_button_raw_input_map.erase(button)
	button_readable_input_map[button] = EMPTY_INPUT_ACTION_STRING


func _matches_filter(input_event: InputEvent) -> bool:
	if input_event == null:
		return false
	match device_filter:
		DeviceFilter.KEYBOARD:
			return input_event is InputEventKey or input_event is InputEventMouseButton
		DeviceFilter.GAMEPAD:
			return input_event is InputEventJoypadButton or input_event is InputEventJoypadMotion
	return false


func _filter_events_for_device(input_events: Array[InputEvent]) -> Array[InputEvent]:
	var filtered: Array[InputEvent] = []
	for input_event in input_events:
		if _matches_filter(input_event):
			filtered.append(input_event)
	return filtered


func _rebuild_action_events_with_filter(action_name: String, replacement_event: InputEvent, action_group: int) -> Array[InputEvent]:
	var action_events := InputMap.action_get_events(action_name)
	var filtered_events: Array[InputEvent] = []
	var retained_events: Array[InputEvent] = []
	for input_event in action_events:
		if _matches_filter(input_event):
			filtered_events.append(input_event)
		else:
			retained_events.append(input_event)

	if action_group < filtered_events.size():
		filtered_events[action_group] = replacement_event
	else:
		filtered_events.append(replacement_event)

	var final_filtered: Array[InputEvent] = []
	for input_event in filtered_events:
		if input_event != null:
			final_filtered.append(input_event)

	if device_filter == DeviceFilter.KEYBOARD:
		return final_filtered + retained_events
	return retained_events + final_filtered


func _add_action_options(action_name: String, readable_action_name: String, input_events: Array[InputEvent]) -> void:
	var new_action_box = %ActionBoxContainer.duplicate()

	var action_name_str := String(action_name)
	var is_aim_action := action_name_str.begins_with("aim_")
	if is_aim_action:
		var move_action := action_name_str.replace("aim_", "move_")
		var move_events := InputMap.action_get_events(move_action)
		if move_events.size() > 0:
			InputMap.action_erase_events(action_name)
			for ev in move_events:
				InputMap.action_add_event(action_name, ev)
			input_events = move_events

	var visible_events := _filter_events_for_device(input_events)
	new_action_box.visible = true
	new_action_box.vertical = !vertical
	new_action_box.add_theme_constant_override("separation", 24)
	var action_label := new_action_box.get_child(0) as Label
	action_label.text = readable_action_name
	action_label.custom_minimum_size.x = action_label_minimum_width
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	for group_iter in range(action_groups):
		var input_event: InputEvent
		if group_iter < visible_events.size():
			input_event = visible_events[group_iter]
		var text = _to_spanish_input_name(InputEventHelper.get_text(input_event))
		var is_disabled = group_iter > visible_events.size()
		if is_aim_action:
			is_disabled = true
		if text.is_empty():
			text = EMPTY_INPUT_ACTION_STRING
		var icon: Texture
		if input_icon_mapper:
			icon = input_icon_mapper.get_icon(input_event)
		var content = icon if icon else text
		var button: Button = _add_new_button(content, new_action_box, is_disabled)
		_connect_button_and_add_to_maps(button, text, action_name, group_iter)
	%ParentBoxContainer.add_child(new_action_box)


func _build_assigned_input_events() -> void:
	assigned_input_events.clear()
	var action_names := _get_all_action_names(show_built_in_actions and catch_built_in_duplicate_inputs)
	for action_name in action_names:
		var input_events = InputMap.action_get_events(action_name)
		for input_event in input_events:
			if _matches_filter(input_event):
				_assign_input_event(input_event, action_name)


func _assign_input_event_to_action_group(input_event: InputEvent, action_name: String, action_group: int) -> void:
	_assign_input_event(input_event, action_name)
	var final_action_events := _rebuild_action_events_with_filter(action_name, input_event, action_group)
	InputMap.action_erase_events(action_name)
	for input_action_event in final_action_events:
		if input_action_event == null:
			continue
		InputMap.action_add_event(action_name, input_action_event)
	AppSettings.set_config_input_events(action_name, final_action_events)
	var filtered_events := _filter_events_for_device(final_action_events)
	action_group = min(action_group, max(0, filtered_events.size() - 1))
	_update_assigned_inputs_and_button(action_name, action_group, input_event)
	_update_next_button_disabled_state(action_name, action_group)


func _add_header() -> void:
	if action_group_names.is_empty():
		return
	var new_action_box := _new_action_box()

	# Reconfigure child 0 (label column) to match action row label width
	if new_action_box.get_child_count() > 0:
		var label_col := new_action_box.get_child(0) as Label
		if label_col:
			label_col.custom_minimum_size.x = action_label_minimum_width
			label_col.size_flags_horizontal = SIZE_SHRINK_BEGIN
			label_col.text = ""

	for group_iter in range(action_groups):
		var group_name := ""
		if group_iter < action_group_names.size():
			group_name = action_group_names[group_iter]
		var new_label := Label.new()
		if button_minimum_size.x > 0:
			new_label.custom_minimum_size.x = button_minimum_size.x
		new_label.size_flags_horizontal = SIZE_EXPAND_FILL
		if button_minimum_size.y > 0:
			new_label.custom_minimum_size.y = button_minimum_size.y
			new_label.size_flags_vertical = SIZE_SHRINK_CENTER
		new_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		new_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		new_label.text = group_name
		new_action_box.add_child(new_label)

	%ParentBoxContainer.add_child(new_action_box)


func _set_action_box_container_size() -> void:
	%ActionBoxContainer.size_flags_horizontal = SIZE_EXPAND_FILL
	if button_minimum_size.y > 0:
		%ActionBoxContainer.size_flags_vertical = SIZE_SHRINK_CENTER
	else:
		%ActionBoxContainer.size_flags_vertical = SIZE_EXPAND_FILL


func _add_new_button(content: Variant, container: Control, disabled: bool = false) -> Button:
	var new_button := Button.new()
	if button_minimum_size.x > 0:
		new_button.custom_minimum_size.x = button_minimum_size.x
	if button_minimum_size.y > 0:
		new_button.custom_minimum_size.y = button_minimum_size.y
	new_button.size_flags_horizontal = SIZE_EXPAND_FILL
	new_button.size_flags_vertical = SIZE_SHRINK_CENTER
	new_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	new_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	new_button.expand_icon = expand_icon
	if content is Texture:
		new_button.icon = content
	elif content is String:
		new_button.text = content
	new_button.disabled = disabled
	container.add_child(new_button)
	return new_button


func add_action_event(last_input_text: String, last_input_event: InputEvent) -> void:
	last_input_readable_name = _to_spanish_input_name(last_input_text)
	if last_input_event != null:
		if not _matches_filter(last_input_event):
			input_type_rejected.emit(
				"mando" if device_filter == DeviceFilter.GAMEPAD else "teclado",
				last_input_readable_name
			)
			editing_action_name = ""
			return
		var assigned_action := _get_action_for_input_event(last_input_event)
		if not assigned_action.is_empty():
			var readable_action_name = tr(_get_action_readable_name(assigned_action))
			already_assigned.emit(readable_action_name, last_input_readable_name)
		else:
			_assign_input_event_to_action_group(last_input_event, editing_action_name, editing_action_group)
	editing_action_name = ""


func _refresh_ui_list_button_content() -> void:
	var action_names: Array[StringName] = _get_all_action_names(show_built_in_actions)
	for action_name in action_names:
		var input_events := _filter_events_for_device(InputMap.action_get_events(action_name))
		if input_events.is_empty():
			_clear_button(action_name, 0)
			_update_next_button_disabled_state(action_name, 0, true)
			continue
		var group_iter := 0
		for input_event in input_events:
			if group_iter >= action_groups:
				break
			_update_assigned_inputs_and_button(action_name, group_iter, input_event)
			var button := _get_button_by_action(action_name, group_iter)
			if button != null and button.icon == null:
				button.text = _to_spanish_input_name(button.text)
			_update_next_button_disabled_state(action_name, group_iter)
			group_iter += 1
		while group_iter < action_groups:
			_clear_button(action_name, group_iter)
			_update_next_button_disabled_state(action_name, group_iter, true)
			group_iter += 1