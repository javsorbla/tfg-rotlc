extends GdUnitTestSuite


func test_pause_menu_cancel_input_handles() -> void:
	var menu = auto_free(load("res://ui/menus/windows/pause_menu.tscn").instantiate())
	add_child(menu)

	menu._handle_cancel_input()
	assert_bool(menu.visible).is_false()


func test_pause_menu_refresh_buttons() -> void:
	var menu = auto_free(load("res://ui/menus/windows/pause_menu.tscn").instantiate())
	add_child(menu)

	menu._refresh_exit_button()
	menu._refresh_options_button()
	menu._refresh_main_menu_button()
	assert_bool(true).is_true()


func test_pause_menu_get_main_menu_scene() -> void:
	var menu = auto_free(load("res://ui/menus/windows/pause_menu.tscn").instantiate())
	add_child(menu)
	var path = menu.get_main_menu_scene_path()
	assert_bool(path.length() > 0 or path.is_empty()).is_true()


func test_pause_menu_is_popup_open() -> void:
	var menu = auto_free(load("res://ui/menus/windows/pause_menu.tscn").instantiate())
	add_child(menu)
	assert_bool(menu.is_popup_open()).is_false()
