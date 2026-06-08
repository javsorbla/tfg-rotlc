extends GdUnitTestSuite


func test_main_menu_button_loads() -> void:
	var btn = auto_free(load("res://ui/menus/main_menu/main_menu_button.tscn").instantiate())
	add_child(btn)
	assert_that(btn).is_not_null()


func test_main_menu_button_has_arrow() -> void:
	var btn = auto_free(load("res://ui/menus/main_menu/main_menu_button.tscn").instantiate())
	add_child(btn)
	assert_that(btn.arrow).is_not_null()


func test_main_menu_button_update_highlight() -> void:
	var btn = auto_free(load("res://ui/menus/main_menu/main_menu_button.tscn").instantiate())
	add_child(btn)
	btn.button_pressed = false
	btn._update_highlight_state()
	assert_bool(true).is_true()


func test_main_menu_button_animate_arrow_shows_and_hides() -> void:
	var btn = auto_free(load("res://ui/menus/main_menu/main_menu_button.tscn").instantiate())
	add_child(btn)
	btn._animate_arrow(true)
	assert_bool(true).is_true()

	btn._animate_arrow(false)
	assert_bool(true).is_true()
