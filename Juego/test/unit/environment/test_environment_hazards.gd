extends GdUnitTestSuite


# --- Fuego (Fire Hazard) ---

func test_fuego_constants() -> void:
	var fuego = auto_free(load("res://scenes/enviroment/Fuego.tscn").instantiate())
	add_child(fuego)

	assert_int(fuego.damage_amount).is_equal(1)


func test_fuego_signal_connected() -> void:
	var fuego = auto_free(load("res://scenes/enviroment/Fuego.tscn").instantiate())
	add_child(fuego)
	fuego.area_entered.is_connected(fuego._on_area_entered)

	assert_bool(fuego.area_entered.is_connected(fuego._on_area_entered)).is_true()


# --- ZonaMuerte (Death Zone) ---

func test_zona_muerte_signal_connected() -> void:
	var zona = auto_free(load("res://scenes/enviroment/ZonaMuerte.tscn").instantiate())
	add_child(zona)

	assert_bool(zona.body_entered.is_connected(zona._on_body_entered)).is_true()


# --- PinchoQueCae (Falling Spike) ---

func test_pincho_constants() -> void:
	var pincho = auto_free(load("res://scenes/enviroment/pincho_que_cae.tscn").instantiate())
	add_child(pincho)

	assert_float(pincho.velocidad_caida).is_equal(200.0)
	assert_int(pincho.dano).is_equal(7)
	assert_float(pincho.distancia_maxima).is_equal(370.0)


func test_pincho_falls_down() -> void:
	var pincho = auto_free(load("res://scenes/enviroment/pincho_que_cae.tscn").instantiate())
	add_child(pincho)
	var start_y = pincho.global_position.y

	pincho._physics_process(0.016)

	assert_bool(pincho.global_position.y > start_y).is_true()


# --- Checkpoint ---

func test_checkpoint_signal_connected() -> void:
	var cp = auto_free(load("res://scenes/enviroment/Checkpoint.tscn").instantiate())
	add_child(cp)

	assert_bool(cp.body_entered.is_connected(cp._on_body_entered)).is_true()


# --- OrbeDeLuz (Light Orb) ---

func test_orbe_constants() -> void:
	var orbe = auto_free(load("res://objects/OrbeDeLuz.tscn").instantiate())
	add_child(orbe)

	assert_bool(orbe.is_spawned).is_false()


func test_orbe_signal_connected() -> void:
	var orbe = auto_free(load("res://objects/OrbeDeLuz.tscn").instantiate())
	add_child(orbe)

	assert_bool(orbe.body_entered.is_connected(orbe._on_body_entered)).is_true()


# --- PlataformaRompible3 (Breakable Platform) ---

func test_plataforma_constants() -> void:
	var plat = auto_free(load("res://scenes/enviroment/PlataformaRompible3.tscn").instantiate())
	add_child(plat)

	assert_float(plat.SHAKE_DURATION).is_equal(1.0)
	assert_float(plat.BREAK_DELAY).is_equal(0.3)
	assert_float(plat.RESPAWN_TIME).is_equal(3.0)


func test_plataforma_detector_signal_connected() -> void:
	var plat = auto_free(load("res://scenes/enviroment/PlataformaRompible3.tscn").instantiate())
	add_child(plat)
	var detector = plat.get_node_or_null("Detector")

	assert_object(detector).is_not_null()
	if detector:
		assert_bool(detector.body_entered.is_connected(plat._on_detector_body_entered)).is_true()


# --- ZonaViento (Wind Zone) ---

func test_zona_viento_constants() -> void:
	var zona = auto_free(load("res://scenes/enviroment/ZonaViento.tscn").instantiate())
	add_child(zona)

	assert_float(zona.wind_force).is_equal(150.0)
	assert_bool(zona.wind_direction == Vector2.LEFT).is_true()


func test_zona_viento_signal_connected() -> void:
	var zona = auto_free(load("res://scenes/enviroment/ZonaViento.tscn").instantiate())
	add_child(zona)

	assert_bool(zona.body_entered.is_connected(zona._on_body_entered)).is_true()
	assert_bool(zona.body_exited.is_connected(zona._on_body_exited)).is_true()
