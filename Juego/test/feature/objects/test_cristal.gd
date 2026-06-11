extends GdUnitTestSuite


func test_cristal_ready_sets_group_and_animation() -> void:
	var c = auto_free(load("res://objects/Cristal.tscn").instantiate())
	add_child(c)
	await get_tree().process_frame
	assert_bool(c.is_in_group("boss_crystal")).is_true()


func test_cristal_follows_player_when_in_range() -> void:
	var c = auto_free(load("res://objects/Cristal.tscn").instantiate())
	add_child(c)
	var player = auto_free(load("res://player/player.tscn").instantiate())
	player.add_to_group("player")
	add_child(player)
	player.global_position = c.global_position + Vector2(100, 0)
	c.follow_player = true
	c._player_ref = player
	var start_x = c.global_position.x

	c._physics_process(1.0)

	assert_bool(abs(c.global_position.x - start_x) > 0).is_true()


func test_cristal_does_not_follow_when_disabled() -> void:
	var c = auto_free(load("res://objects/Cristal.tscn").instantiate())
	add_child(c)
	c.follow_player = false
	var start_x = c.global_position.x

	c._physics_process(1.0)

	assert_float(c.global_position.x).is_equal(start_x)
