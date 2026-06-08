extends GdUnitTestSuite


func test_opening_loads() -> void:
	var escena = auto_free(load("res://ui/menus/opening/opening.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()


func test_credits_label_loads() -> void:
	var escena = auto_free(load("res://ui/menus/credits/credits_label.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()


func test_scrolling_credits_loads() -> void:
	var escena = auto_free(load("res://ui/menus/credits/scrolling_credits.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()
