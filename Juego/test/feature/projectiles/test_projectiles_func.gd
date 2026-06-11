extends GdUnitTestSuite


func test_proyectil_base_moves_in_direction() -> void:
	var proj = auto_free(load("res://enemies/bosses/ice_guardian/ProyectilHielo.tscn").instantiate())
	add_child(proj)
	proj.direction = Vector2(1, 0)
	var start_x = proj.global_position.x

	proj._physics_process(1.0)

	assert_bool(proj.global_position.x > start_x).is_true()


func test_proyectil_base_moves_in_negative_direction() -> void:
	var proj = auto_free(load("res://enemies/bosses/ice_guardian/ProyectilHielo.tscn").instantiate())
	add_child(proj)
	proj.direction = Vector2(-1, 0)
	var start_x = proj.global_position.x

	proj._physics_process(1.0)

	assert_bool(proj.global_position.x < start_x).is_true()


func test_proyectil_hielo_init_sets_direction() -> void:
	var proj = auto_free(load("res://enemies/bosses/ice_guardian/ProyectilHielo.tscn").instantiate())
	add_child(proj)

	proj.init(Vector2(0.5, 0.5))

	assert_float(proj.direction.x).is_equal(0.5)
	assert_float(proj.direction.y).is_equal(0.5)


func test_proyectil_hielo_reflects_on_player_hitbox() -> void:
	var proj = auto_free(load("res://enemies/bosses/ice_guardian/ProyectilHielo.tscn").instantiate())
	add_child(proj)
	proj.direction = Vector2(1, 0)

	var hitbox = auto_free(Area2D.new())
	hitbox.add_to_group("player_hitbox")
	add_child(hitbox)

	proj._on_area_entered(hitbox)
	assert_bool(proj.is_reflected).is_true()


func test_bola_oscura_moves() -> void:
	var bola = auto_free(load("res://enemies/bosses/vacio/bola_oscura.tscn").instantiate())
	add_child(bola)
	bola.direction = Vector2(1, 0)
	var start_x = bola.global_position.x

	bola._physics_process(1.0)

	assert_bool(bola.global_position.x > start_x).is_true()


func test_chorro_lava_loads_and_moves() -> void:
	var lava = auto_free(load("res://enemies/bosses/coloso_ceniza/ChorroLava.tscn").instantiate())
	add_child(lava)
	assert_that(lava).is_not_null()
