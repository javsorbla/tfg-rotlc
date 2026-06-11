extends GdUnitTestSuite


func test_proyectil_hielo_loads() -> void:
	var escena = auto_free(load("res://enemies/bosses/ice_guardian/ProyectilHielo.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()


func test_bola_oscura_loads() -> void:
	var escena = auto_free(load("res://enemies/bosses/vacio/bola_oscura.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()


func test_pincho_vacio_loads() -> void:
	var escena = auto_free(load("res://enemies/bosses/vacio/pincho_vacio.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()


func test_chorro_lava_loads() -> void:
	var escena = auto_free(load("res://enemies/bosses/coloso_ceniza/ChorroLava.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()


func test_huracan_loads() -> void:
	var escena = auto_free(load("res://enemies/bosses/tempestad_dorada/Huracan.tscn").instantiate())
	assert_that(escena).is_not_null()


func test_rayo_loads() -> void:
	var escena = auto_free(load("res://enemies/bosses/tempestad_dorada/Rayo.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()


func test_tormenta_loads() -> void:
	var escena = auto_free(load("res://enemies/bosses/tempestad_dorada/Tormenta.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()


func test_pinchos_magma_loads() -> void:
	var escena = auto_free(load("res://enemies/bosses/coloso_ceniza/PinchosMagma.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()


func test_onda_hielo_loads() -> void:
	var escena = auto_free(load("res://enemies/bosses/ice_guardian/OndaHielo.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()


func test_ataque_inquisidor_loads() -> void:
	var escena = auto_free(load("res://enemies/common/inquisidor_tenebroso/AtaqueInquisidor.tscn").instantiate())
	add_child(escena)
	assert_that(escena).is_not_null()
