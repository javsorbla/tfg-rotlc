extends GdUnitTestSuite


func test_statue_loads() -> void:
	var escena = auto_free(load("res://statue/Statue.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()
