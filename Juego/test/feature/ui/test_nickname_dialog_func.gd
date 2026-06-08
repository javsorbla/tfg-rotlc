extends GdUnitTestSuite


func test_nickname_dialog_loads() -> void:
	var dialog = auto_free(load("res://ui/menus/windows/nickname_dialog.tscn").instantiate())
	add_child(dialog)
	assert_that(dialog).is_not_null()


func test_nickname_dialog_has_line_edit() -> void:
	var dialog = auto_free(load("res://ui/menus/windows/nickname_dialog.tscn").instantiate())
	add_child(dialog)
	assert_that(dialog.line_edit).is_not_null()


func test_nickname_dialog_validates_short_input() -> void:
	var dialog = auto_free(load("res://ui/menus/windows/nickname_dialog.tscn").instantiate())
	add_child(dialog)
	dialog.line_edit.text = "ab"
	dialog._on_line_edit_text_changed("ab")
	assert_bool(dialog.confirm_button.disabled).is_true()


func test_nickname_dialog_accepts_valid_input() -> void:
	var dialog = auto_free(load("res://ui/menus/windows/nickname_dialog.tscn").instantiate())
	add_child(dialog)
	dialog.line_edit.text = "ValidName"
	dialog._on_line_edit_text_changed("ValidName")
	assert_bool(dialog.confirm_button.disabled).is_false()
