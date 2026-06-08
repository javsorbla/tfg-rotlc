extends GdUnitTestSuite


func test_antorcha_loads() -> void:
	var escena = auto_free(load("res://scenes/enviroment/Antorcha.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()


func test_antorcha_suelo_loads() -> void:
	var escena = auto_free(load("res://scenes/enviroment/AntorchaSuelo.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()


func test_fuego_loads() -> void:
	var escena = auto_free(load("res://scenes/enviroment/Fuego.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()


func test_fuego_morado_loads() -> void:
	var escena = auto_free(load("res://scenes/enviroment/FuegoMorado.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()


func test_particulas_bloques_loads() -> void:
	var escena = auto_free(load("res://scenes/enviroment/ParticulasBloques.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()


func test_hit_particles_loads() -> void:
	var escena = auto_free(load("res://scenes/effects/HitParticles.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()
