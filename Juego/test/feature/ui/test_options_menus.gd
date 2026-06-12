extends GdUnitTestSuite


func test_audio_options_menu_loads() -> void:
	var escena = auto_free(load("res://ui/menus/options_menu/audio/audio_options_menu.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()


func test_audio_input_option_loads() -> void:
	var escena = auto_free(load("res://ui/menus/options_menu/audio/audio_input_option_control.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()


func test_video_options_menu_loads() -> void:
	var escena = auto_free(load("res://ui/menus/options_menu/video/video_options_menu.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()


func test_video_options_menu_with_extras_loads() -> void:
	var escena = auto_free(load("res://ui/menus/options_menu/video/video_options_menu_with_extras.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()


func test_input_options_menu_loads() -> void:
	var escena = auto_free(load("res://ui/menus/options_menu/input/input_options_menu.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()


func test_input_options_menu_with_sensitivity_loads() -> void:
	var escena = auto_free(load("res://ui/menus/options_menu/input/input_options_menu_with_mouse_sensitivity.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()


func test_input_controls_split_loads() -> void:
	var escena = auto_free(load("res://ui/menus/options_menu/input/input_controls_split.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()


func test_input_extras_menu_loads() -> void:
	var escena = auto_free(load("res://ui/menus/options_menu/input/input_extras_menu.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()


func test_input_icon_mapper_loads() -> void:
	var escena = auto_free(load("res://ui/menus/options_menu/input/input_icon_mapper.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()


func test_master_options_menu_loads() -> void:
	var escena = auto_free(load("res://ui/menus/options_menu/master_options_menu_with_tabs.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()


func test_mini_options_menu_loads() -> void:
	var escena = auto_free(load("res://ui/menus/options_menu/mini_options_menu.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()
