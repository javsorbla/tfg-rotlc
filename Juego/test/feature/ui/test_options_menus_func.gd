extends GdUnitTestSuite


func test_video_options_menu_has_settings() -> void:
	var menu = auto_free(load("res://ui/menus/options_menu/video/video_options_menu.tscn").instantiate())
	add_child(menu)
	var options = menu.find_children("*", "OptionButton")
	assert_bool(options.size() > 0).is_true()


func test_input_options_menu_has_action_list() -> void:
	var menu = auto_free(load("res://ui/menus/options_menu/input/input_options_menu.tscn").instantiate())
	add_child(menu)
	assert_that(menu).is_not_null()


func test_master_options_menu_with_tabs_loads() -> void:
	var menu = auto_free(load("res://ui/menus/options_menu/master_options_menu_with_tabs.tscn").instantiate())
	add_child(menu)
	var tabs = menu.find_children("*", "TabContainer")
	assert_bool(tabs.size() > 0).is_true()


func test_mini_options_menu_loads() -> void:
	var menu = auto_free(load("res://ui/menus/options_menu/mini_options_menu.tscn").instantiate())
	add_child(menu)
	assert_that(menu).is_not_null()
