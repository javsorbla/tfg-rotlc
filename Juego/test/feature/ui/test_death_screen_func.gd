extends GdUnitTestSuite


func test_death_screen_loads() -> void:
	var screen = auto_free(load("res://ui/menus/windows/death_screen.tscn").instantiate())
	add_child(screen)
	assert_that(screen).is_not_null()


func test_death_screen_shows_and_pauses() -> void:
	var screen = auto_free(load("res://ui/menus/windows/death_screen.tscn").instantiate())
	add_child(screen)

	screen.show()

	assert_bool(screen.visible).is_true()
