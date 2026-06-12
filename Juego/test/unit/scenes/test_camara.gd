extends GdUnitTestSuite

var camara: Camera2D


func before_test() -> void:
	camara = auto_free(load("res://scenes/camara.gd").new())
	add_child(camara)


func test_default_zoom_is_2_25() -> void:
	assert_vector(camara.zoom).is_equal(Vector2(2.25, 2.25))


func test_shake_sets_timer_and_intensity() -> void:
	camara.shake()
	assert_float(camara.shake_timer).is_equal(camara.SHAKE_DURATION)
	assert_float(camara.shake_intensity).is_equal(camara.SHAKE_INTENSITY)


func test_shake_decays_over_time() -> void:
	camara.shake()
	camara._process(0.05)
	assert_float(camara.shake_timer).is_less(0.2)


func test_dead_zone_y_constants() -> void:
	assert_float(camara.DEADZONE_Y).is_equal(30.0)
	assert_float(camara.FOLLOW_SPEED_X).is_equal(0.15)
	assert_float(camara.FOLLOW_SPEED_Y).is_equal(0.1)
