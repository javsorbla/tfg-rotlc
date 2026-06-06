extends GdUnitTestSuite


func test_constants() -> void:
	var enemy = auto_free(load("res://enemies/common/nucleo_inestable/NucleoInestable.tscn").instantiate())
	add_child(enemy)

	assert_int(enemy.MAX_HEALTH).is_equal(1)
	assert_int(enemy.DAMAGE).is_equal(2)


func test_initial_state_is_sleep() -> void:
	var enemy = auto_free(load("res://enemies/common/nucleo_inestable/NucleoInestable.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	assert_int(enemy.current_state).is_equal(enemy.State.SLEEP)
	assert_int(enemy.current_health).is_equal(enemy.MAX_HEALTH)


func test_take_damage_without_red_power_only_stuns() -> void:
	var enemy = auto_free(load("res://enemies/common/nucleo_inestable/NucleoInestable.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)
	enemy.player = player

	enemy.current_state = enemy.State.SLEEP
	enemy.take_damage(1)

	assert_int(enemy.current_state).is_equal(enemy.State.STUNNED)
	assert_int(enemy.current_health).is_equal(1)


func test_take_damage_with_red_power_kills() -> void:
	var enemy = auto_free(load("res://enemies/common/nucleo_inestable/NucleoInestable.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)
	enemy.player = player
	var cm = player.get_node("ColorManager")
	cm.active_power = "red"
	cm.power_active = true

	enemy.current_state = enemy.State.SLEEP
	enemy.take_damage(1)

	assert_int(enemy.current_state).is_equal(enemy.State.DEAD)
	assert_int(enemy.current_health).is_equal(0)


func test_damage_noop_when_dead() -> void:
	var enemy = auto_free(load("res://enemies/common/nucleo_inestable/NucleoInestable.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	enemy.current_state = enemy.State.DEAD
	enemy.current_health = 0
	enemy.take_damage(1)

	assert_int(enemy.current_health).is_equal(0)


func test_hurtbox_and_hitbox_connected() -> void:
	var enemy = auto_free(load("res://enemies/common/nucleo_inestable/NucleoInestable.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	assert_object(enemy.get_node_or_null("EnemyHurtbox")).is_not_null()
	assert_object(enemy.get_node_or_null("EnemyHitbox")).is_not_null()
