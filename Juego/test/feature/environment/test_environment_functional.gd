extends GdUnitTestSuite


func test_zona_jefe_loads() -> void:
	var escena = auto_free(load("res://scenes/enviroment/ZonaJefe.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()


func test_checkpoint_loads() -> void:
	var escena = auto_free(load("res://scenes/enviroment/Checkpoint.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()


func test_portal_loads() -> void:
	var escena = auto_free(load("res://scenes/enviroment/Portal.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()


func test_zona_muerte_loads() -> void:
	var escena = auto_free(load("res://scenes/enviroment/ZonaMuerte.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()


func test_plataforma_magica_loads() -> void:
	var escena = auto_free(load("res://scenes/enviroment/PlataformaMagica.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()


func test_plataforma_rompible3_loads() -> void:
	var escena = auto_free(load("res://scenes/enviroment/PlataformaRompible3.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()


func test_plataforma_rompible_por_nivel_loads() -> void:
	var escena = auto_free(load("res://scenes/enviroment/PlataformaRompiblePorNivel.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()


func test_pincho_que_cae_loads() -> void:
	var escena = auto_free(load("res://scenes/enviroment/pincho_que_cae.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()


func test_generador_pinchos_loads() -> void:
	var escena = auto_free(load("res://scenes/enviroment/GeneradorPinchos.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()


func test_zona_viento_loads() -> void:
	var escena = auto_free(load("res://scenes/enviroment/ZonaViento.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()


func test_tutorial_message_manager_loads() -> void:
	var escena = auto_free(load("res://scenes/tutorial_message_manager.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()
