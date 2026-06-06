extends GdUnitTestSuite


func test_health_initial_values() -> void:
	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)
	var health = player.get_node("Health")

	assert_int(health.current_health).is_equal(3)
	assert_int(health.MAX_HEALTH).is_equal(3)
	assert_bool(health.is_invincible).is_false()


func test_take_damage_reduces_health() -> void:
	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)

	var health = player.get_node("Health")
	health.is_invincible = false
	health.current_health = 3
	player.is_shielding = false

	health.take_damage(1)

	assert_int(health.current_health).is_equal(2)


func test_take_damage_triggers_invincibility() -> void:
	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)

	var health = player.get_node("Health")
	health.is_invincible = false
	health.current_health = 3
	player.is_shielding = false

	health.take_damage(1)

	assert_bool(health.is_invincible).is_true()
	assert_float(health.invincibility_timer).is_equal(1.0)


func test_invincibility_blocks_damage() -> void:
	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)

	var health = player.get_node("Health")
	health.is_invincible = true
	health.current_health = 3

	health.take_damage(1)

	assert_int(health.current_health).is_equal(3)


func test_shielding_blocks_damage() -> void:
	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)

	var health = player.get_node("Health")
	health.is_invincible = false
	health.current_health = 3
	player.is_shielding = true

	health.take_damage(1)

	assert_int(health.current_health).is_equal(3)


func test_heal_restores_health() -> void:
	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)

	var health = player.get_node("Health")
	health.current_health = 1

	health.heal(1)

	assert_int(health.current_health).is_equal(2)


func test_heal_to_full() -> void:
	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)

	var health = player.get_node("Health")
	health.current_health = 1

	health.heal_to_full()

	assert_int(health.current_health).is_equal(health.MAX_HEALTH)


func test_heal_does_not_exceed_max() -> void:
	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)

	var health = player.get_node("Health")
	health.is_invincible = false
	player.is_shielding = false
	health.current_health = 3

	health.take_damage(1)
	health.heal(2)

	assert_int(health.current_health).is_equal(3)


func test_damage_bypass_shield_when_flag_set() -> void:
	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)

	var health = player.get_node("Health")
	health.is_invincible = false
	health.current_health = 3
	player.is_shielding = true

	health.take_damage(1, true)

	assert_int(health.current_health).is_equal(2)
