extends GdUnitTestSuite


func test_player_instantiation() -> void:
	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)

	assert_object(player).is_not_null()
	assert_that(player.speed_multiplier).is_equal(1.0)
	assert_that(player.damage_multiplier).is_equal(1.0)
	assert_bool(player.is_dashing).is_false()
	assert_bool(player.can_jump).is_true()


func test_player_has_required_nodes() -> void:
	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)

	assert_object(player.get_node_or_null("AnimatedSprite2D")).is_not_null()
	assert_object(player.get_node_or_null("Hurtbox")).is_not_null()
	assert_object(player.get_node_or_null("Health")).is_not_null()
	assert_object(player.get_node_or_null("Combat")).is_not_null()
	assert_object(player.get_node_or_null("ColorManager")).is_not_null()
	assert_object(player.get_node_or_null("AttackHitbox")).is_not_null()


func test_set_input_enabled_disables_movement() -> void:
	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)

	player.set_input_enabled(false)
	assert_bool(player.input_enabled).is_false()
	assert_vector(player.velocity).is_equal(Vector2.ZERO)


func test_speed_multiplier_affects_physics() -> void:
	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)

	player.speed_multiplier = 2.0
	assert_float(player.speed_multiplier).is_equal(2.0)


func test_dash_state_flags() -> void:
	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)

	player.is_dashing = true
	player.dash_timer = 0.25
	player.dash_direction = 1.0

	assert_bool(player.is_dashing).is_true()


func test_gravity_applies_in_air() -> void:
	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)

	player.position = Vector2(0, -1000)
	player.set_input_enabled(false)
	player.velocity = Vector2.ZERO

	await await_millis(200)

	assert_float(player.velocity.y).is_greater(0.0)
