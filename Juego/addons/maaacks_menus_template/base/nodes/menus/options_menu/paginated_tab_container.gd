extends TabContainer
## Applies UI page up and page down inputs to tab switching.

func _find_first_button(parent: Node) -> Button:
	for child in parent.get_children():
		if child is Button and child.visible and not child.disabled:
			return child
		var found := _find_first_button(child)
		if found != null:
			return found
	return null


func _ready() -> void:
	tab_changed.connect(_on_tab_changed)


func _on_tab_changed(_tab: int) -> void:
	var tab := get_child(current_tab)
	if tab == null:
		return
	var btn := _find_first_button(tab)
	if btn != null:
		btn.call_deferred("grab_focus")


func _unhandled_input(event : InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_page_down"):
		current_tab = (current_tab+1) % get_tab_count()
	elif event.is_action_pressed("ui_page_up"):
		if current_tab == 0:
			current_tab = get_tab_count()-1
		else:
			current_tab = current_tab-1
