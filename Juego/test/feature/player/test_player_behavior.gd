extends GdUnitTestSuite

var player: Node2D


func before_test() -> void:
	player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)
	await get_tree().process_frame


func test_take_damage_reduces_health() -> void:
	var before = player.health.current_health
	player.health.take_damage(1)
	assert_int(player.health.current_health).is_equal(before - 1)


func test_take_damage_sets_invincible() -> void:
	player.health.take_damage(1)
	assert_bool(player.health.is_invincible).is_true()


func test_shield_blocks_damage() -> void:
	player.is_shielding = true
	var before = player.health.current_health
	player.health.take_damage(1)
	assert_int(player.health.current_health).is_equal(before)


func test_shield_bypass() -> void:
	player.is_shielding = true
	var before = player.health.current_health
	player.health.take_damage(1, true)
	assert_int(player.health.current_health).is_equal(before - 1)


func test_invincibility_blocks_damage() -> void:
	player.health.take_damage(1)
	var before = player.health.current_health
	player.health.take_damage(1)
	assert_int(player.health.current_health).is_equal(before)


func test_heal_increases_health() -> void:
	player.health.take_damage(2)
	var before = player.health.current_health
	player.health.heal(1)
	assert_int(player.health.current_health).is_equal(before + 1)


func test_heal_caps_at_max() -> void:
	player.health.heal_to_full()
	player.health.heal(1)
	assert_int(player.health.current_health).is_equal(player.health.MAX_HEALTH)


func test_cyan_power_increases_speed_multiplier() -> void:
	player.color_manager.unlock_power("cyan")
	player.color_manager.change_state(player.color_manager.cyan_state)
	assert_float(player.speed_multiplier).is_equal(1.5)


func test_red_power_increases_damage_multiplier() -> void:
	player.color_manager.unlock_power("red")
	player.color_manager.change_state(player.color_manager.red_state)
	assert_float(player.damage_multiplier).is_equal(2.0)


func test_yellow_power_activates_shield() -> void:
	player.color_manager.unlock_power("yellow")
	player.color_manager.change_state(player.color_manager.yellow_state)
	assert_bool(player.is_shielding).is_true()
	assert_bool(player.can_jump).is_false()
	assert_bool(player.can_dash).is_false()


func test_reset_for_respawn_clears_powers() -> void:
	player.color_manager.unlock_power("cyan")
	player.color_manager.change_state(player.color_manager.cyan_state)
	player.color_manager.reset_for_respawn()
	assert_float(player.speed_multiplier).is_equal(1.0)
	assert_bool(player.is_shielding).is_false()
