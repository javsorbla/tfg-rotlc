extends GdUnitTestSuite


func test_speed_constant() -> void:
	var p = auto_free(load("res://enemies/proyectil_base.gd").new())
	assert_float(p.get_speed()).is_equal(200.0)


func test_damage_constant() -> void:
	var p = auto_free(load("res://enemies/proyectil_base.gd").new())
	assert_int(p.get_damage()).is_equal(2)
