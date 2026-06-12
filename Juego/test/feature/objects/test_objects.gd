extends GdUnitTestSuite


func test_cristal_loads() -> void:
	var escena = auto_free(load("res://objects/Cristal.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()


func test_nucleo_prisma_loads() -> void:
	var escena = auto_free(load("res://objects/NucleoDePrisma.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()


func test_orbe_luz_loads() -> void:
	var escena = auto_free(load("res://objects/OrbeDeLuz.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()
