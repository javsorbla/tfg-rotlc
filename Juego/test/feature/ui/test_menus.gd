extends GdUnitTestSuite


func test_main_menu_credits_window_loads() -> void:
	var escena = auto_free(load("res://ui/menus/windows/main_menu_credits_window.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()


func test_loading_screen_loads() -> void:
	var escena = auto_free(load("res://ui/menus/loading_screen/loading_screen.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()


func test_loading_screen_shader_caching_loads() -> void:
	var escena = auto_free(load("res://ui/menus/loading_screen/loading_screen_with_shader_caching.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()


func test_confirmation_window_loads() -> void:
	var escena = auto_free(load("res://ui/menus/windows/confirmation_overlaid_window_rotlc.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()


func test_nickname_dialog_loads() -> void:
	var escena = auto_free(load("res://ui/menus/windows/nickname_dialog.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()