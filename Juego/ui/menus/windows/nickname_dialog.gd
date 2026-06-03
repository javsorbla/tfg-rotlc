extends Control

signal done

const MIN_LENGTH := 3
const MAX_LENGTH := 20

@onready var line_edit: LineEdit = %LineEdit
@onready var confirm_button: Button = %ConfirmButton
@onready var error_label: Label = %ErrorLabel


func _ready() -> void:
	line_edit.grab_focus()
	confirm_button.disabled = true


func _on_line_edit_text_changed(new_text: String) -> void:
	error_label.hide()
	var trimmed := new_text.strip_edges()
	confirm_button.disabled = trimmed.length() < MIN_LENGTH or trimmed.length() > MAX_LENGTH


func _on_confirm_button_pressed() -> void:
	var nickname := line_edit.text.strip_edges()
	if nickname.length() < MIN_LENGTH:
		error_label.text = "Mínimo " + str(MIN_LENGTH) + " caracteres"
		error_label.show()
		return
	if nickname.length() > MAX_LENGTH:
		error_label.text = "Máximo " + str(MAX_LENGTH) + " caracteres"
		error_label.show()
		return

	GameState.player_progress["nickname"] = nickname
	GameState._save_player_progress()
	NakamaManager.set_nickname(nickname)
	done.emit()
	queue_free()


func _on_line_edit_text_submitted(_new_text: String) -> void:
	if not confirm_button.disabled:
		_on_confirm_button_pressed()
