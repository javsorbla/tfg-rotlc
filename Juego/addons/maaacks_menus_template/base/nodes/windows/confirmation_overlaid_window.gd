@tool
class_name ConfirmationOverlaidWindow
extends OverlaidWindow

signal confirmed

@onready var confirm_button : Button = %ConfirmButton

@export var confirm_button_text : String = "Confirm" :
	set(value):
		confirm_button_text = value
		if update_content and is_inside_tree():
			confirm_button.text = confirm_button_text

func confirm():
	confirmed.emit()
	close()

func _on_confirm_button_pressed():
	confirm()


func _ready() -> void:
	# Ensure keyboard navigation works: focus confirm button when visible
	if not visibility_changed.is_connected(_on_confirmation_visibility_changed):
		visibility_changed.connect(_on_confirmation_visibility_changed)


func _on_confirmation_visibility_changed() -> void:
	if is_visible_in_tree():
		# Ensure all buttons in the dialog are focusable
		var menu_btns := get_node_or_null("ContentContainer/BoxContainer/MenuButtonsMargin/MenuButtons")
		if menu_btns != null:
			# Make children focusable
			for child in menu_btns.get_children():
				if child is Control:
					child.focus_mode = Control.FOCUS_ALL
			# If the container provides a helper, prefer that
			if menu_btns.has_method("focus_first"):
				menu_btns.focus_first()
			else:
				# Focus the first button available
				for child in menu_btns.get_children():
					if child is Button:
						child.grab_focus()
						break
		else:
			# Fallback: ensure explicit buttons are focusable and focus the confirm button
			if confirm_button and confirm_button is Control:
				confirm_button.focus_mode = Control.FOCUS_ALL
				confirm_button.grab_focus()
			var close_btn := get_node_or_null("CloseButton")
			if close_btn and close_btn is Control:
				close_btn.focus_mode = Control.FOCUS_ALL
