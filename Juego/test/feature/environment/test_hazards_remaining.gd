extends GdUnitTestSuite


func test_plataforma_magica_loads() -> void:
	var p = auto_free(load("res://scenes/enviroment/PlataformaMagica.tscn").instantiate())
	add_child(p)
	assert_that(p).is_not_null()


func test_plataforma_magica_aparecer_disabled_shows_platform() -> void:
	var p = auto_free(load("res://scenes/enviroment/PlataformaMagica.tscn").instantiate())
	add_child(p)
	p.process_mode = Node.PROCESS_MODE_DISABLED
	p.hide()

	p.aparecer()

	assert_bool(p.is_visible()).is_true()
	assert_int(p.process_mode).is_equal(Node.PROCESS_MODE_INHERIT)


func test_plataforma_magica_desaparecer_hides_platform() -> void:
	var p = auto_free(load("res://scenes/enviroment/PlataformaMagica.tscn").instantiate())
	add_child(p)
	p.show()

	p.desaparecer()

	assert_bool(p.is_visible()).is_false()
	assert_int(p.process_mode).is_equal(Node.PROCESS_MODE_DISABLED)


func test_plataforma_rompible_por_nivel_loads() -> void:
	var p = auto_free(load("res://scenes/enviroment/PlataformaRompiblePorNivel.tscn").instantiate())
	add_child(p)
	assert_that(p).is_not_null()


func test_generador_pinchos_loads() -> void:
	var g = auto_free(load("res://scenes/enviroment/GeneradorPinchos.tscn").instantiate())
	add_child(g)
	assert_that(g).is_not_null()


func test_generador_pinchos_spawns_spikes() -> void:
	var g = auto_free(load("res://scenes/enviroment/GeneradorPinchos.tscn").instantiate())
	add_child(g)
	g.escena_pincho = load("res://scenes/enviroment/pincho_que_cae.tscn")
	g.ancho_generacion = 64.0
	g.separacion_pinchos = 32.0
	var child_count_before = g.get_child_count()

	g._on_timer_timeout()

	assert_bool(g.get_child_count() > child_count_before).is_true()


func test_portal_loads() -> void:
	var p = auto_free(load("res://scenes/enviroment/Portal.tscn").instantiate())
	add_child(p)
	assert_that(p).is_not_null()


func test_portal_animation_name_matches_level() -> void:
	var p = auto_free(load("res://scenes/enviroment/Portal.tscn").instantiate())
	add_child(p)
	GameState.current_level = 0
	assert_str(p._get_portal_animation_name()).is_equal("cyan")
	GameState.current_level = 1
	assert_str(p._get_portal_animation_name()).is_equal("red")
	GameState.current_level = 2
	assert_str(p._get_portal_animation_name()).is_equal("yellow")
	GameState.current_level = 3
	assert_str(p._get_portal_animation_name()).is_equal("purple")


func test_portal_light_color_matches_level() -> void:
	var p = auto_free(load("res://scenes/enviroment/Portal.tscn").instantiate())
	add_child(p)
	GameState.current_level = 0
	var color = p._get_portal_light_color()
	assert_bool(color.r > 0).is_true()


func test_zona_jefe_loads() -> void:
	var z = auto_free(load("res://scenes/enviroment/ZonaJefe.tscn").instantiate())
	add_child(z)
	assert_that(z).is_not_null()


func test_zona_jefe_builds_room_key() -> void:
	var z = auto_free(load("res://scenes/enviroment/ZonaJefe.tscn").instantiate())
	add_child(z)
	var key = z._build_room_key()
	assert_bool(key.length() > 0).is_true()
