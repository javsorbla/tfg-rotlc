extends GdUnitTestSuite


func test_player_dummy_loads() -> void:
	var dummy = auto_free(load("res://enemies/bosses/umbra/PlayerDummy.tscn").instantiate())
	add_child(dummy)
	assert_that(dummy).is_not_null()


func test_player_dummy_smart_bot_moves_toward_umbra() -> void:
	var dummy = auto_free(load("res://enemies/bosses/umbra/PlayerDummy.tscn").instantiate())
	add_child(dummy)
	dummy.control_mode = dummy.ControlMode.SMART_BOT

	var umbra = auto_free(load("res://enemies/bosses/umbra/Umbra.tscn").instantiate())
	umbra.add_to_group("enemies")
	add_child(umbra)
	umbra.global_position = dummy.global_position + Vector2(200, 0)

	dummy._smart_bot_control(1.0)
	assert_bool(dummy._desired_dir > 0).is_true()


func test_player_dummy_smart_bot_retreats_when_too_close() -> void:
	var dummy = auto_free(load("res://enemies/bosses/umbra/PlayerDummy.tscn").instantiate())
	add_child(dummy)
	dummy.control_mode = dummy.ControlMode.SMART_BOT

	var umbra = auto_free(load("res://enemies/bosses/umbra/Umbra.tscn").instantiate())
	umbra.add_to_group("enemies")
	add_child(umbra)
	umbra.global_position = dummy.global_position + Vector2(20, 0)

	dummy._smart_bot_control(1.0)
	assert_bool(dummy._desired_dir < 0).is_true()


func test_player_dummy_reset_for_training() -> void:
	var dummy = auto_free(load("res://enemies/bosses/umbra/PlayerDummy.tscn").instantiate())
	add_child(dummy)
	dummy.reset_for_training(Vector2(100, 100))
	assert_float(dummy.global_position.x).is_equal(100)
	assert_float(dummy.velocity.x).is_equal(0)


func test_player_dummy_attack_triggers() -> void:
	var dummy = auto_free(load("res://enemies/bosses/umbra/PlayerDummy.tscn").instantiate())
	add_child(dummy)

	dummy._trigger_attack()

	assert_bool(dummy.is_attacking).is_true()
	assert_bool(dummy.attack_hitbox.monitoring).is_true()


func test_player_dummy_dash_starts() -> void:
	var dummy = auto_free(load("res://enemies/bosses/umbra/PlayerDummy.tscn").instantiate())
	add_child(dummy)

	dummy._start_dash(1.0)

	assert_bool(dummy.is_dashing).is_true()
	assert_float(dummy.dash_timer).is_equal(dummy.DASH_DURATION)
