extends GdUnitTestSuite


func test_constants() -> void:
	var enemy = auto_free(load("res://enemies/common/kamikaze_electrico/KamikazeElectrico.tscn").instantiate())
	add_child(enemy)

	assert_int(enemy.MAX_HEALTH).is_equal(1)
	assert_int(enemy.DAMAGE).is_equal(10)


func test_initial_state_is_sleep() -> void:
	var enemy = auto_free(load("res://enemies/common/kamikaze_electrico/KamikazeElectrico.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	assert_int(enemy.current_state).is_equal(enemy.State.SLEEP)
	assert_int(enemy.current_health).is_equal(enemy.MAX_HEALTH)


func test_take_damage_kills_in_one_hit() -> void:
	var enemy = auto_free(load("res://enemies/common/kamikaze_electrico/KamikazeElectrico.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	enemy.current_state = enemy.State.SLEEP
	enemy.take_damage(1)

	assert_int(enemy.current_health).is_equal(0)
	assert_int(enemy.current_state).is_equal(enemy.State.DEAD)


func test_damage_noop_when_dead_or_explode() -> void:
	var enemy = auto_free(load("res://enemies/common/kamikaze_electrico/KamikazeElectrico.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	enemy.current_state = enemy.State.DEAD
	enemy.current_health = 0
	enemy.take_damage(1)

	assert_int(enemy.current_health).is_equal(0)

	enemy.current_state = enemy.State.EXPLODE
	enemy.current_health = 0
	enemy.take_damage(1)

	assert_int(enemy.current_health).is_equal(0)


func test_hurtbox_and_hitbox_connected() -> void:
	var enemy = auto_free(load("res://enemies/common/kamikaze_electrico/KamikazeElectrico.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	assert_object(enemy.get_node_or_null("EnemyHurtbox")).is_not_null()
	assert_object(enemy.get_node_or_null("EnemyHitbox")).is_not_null()
