extends GdUnitTestSuite


func test_death_screen_loads() -> void:
	var escena = auto_free(load("res://ui/menus/windows/death_screen.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()
