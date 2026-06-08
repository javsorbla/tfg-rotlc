extends GdUnitTestSuite


func test_pause_menu_loads() -> void:
	var escena = auto_free(load("res://ui/menus/windows/pause_menu.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()


func test_pause_menu_layer_loads() -> void:
	var escena = auto_free(load("res://ui/menus/windows/pause_menu_layer.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()


func test_pause_menu_options_window_loads() -> void:
	var escena = auto_free(load("res://ui/menus/windows/pause_menu_options_window.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()
