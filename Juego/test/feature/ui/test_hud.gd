extends GdUnitTestSuite


func test_hud_loads() -> void:
	var escena = auto_free(load("res://ui/HUD.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()
