extends GdUnitTestSuite

var player: Node2D


func before_test() -> void:
	player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)


func test_set_input_enabled_disables_input() -> void:
	player.set_input_enabled(false)
	assert_bool(player.input_enabled).is_false()


func test_set_input_enabled_enables_input() -> void:
	player.set_input_enabled(false)
	player.set_input_enabled(true)
	assert_bool(player.input_enabled).is_true()


func test_movement_constants() -> void:
	assert_float(player.SPEED).is_equal(150.0)
	assert_float(player.JUMP_VELOCITY).is_equal(-300.0)
	assert_float(player.DASH_SPEED).is_equal(300.0)
	assert_float(player.DASH_DURATION).is_equal(0.25)
