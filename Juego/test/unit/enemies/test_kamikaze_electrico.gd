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


func test_sleep_velocity_is_zero() -> void:
	var enemy = auto_free(load("res://enemies/common/kamikaze_electrico/KamikazeElectrico.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	enemy.current_state = enemy.State.SLEEP
	enemy._physics_process(0.016)

	assert_float(enemy.velocity.x).is_equal(0.0)
	assert_float(enemy.velocity.y).is_equal(0.0)


func test_sleep_transitions_to_attack_when_player_near() -> void:
	var enemy = auto_free(load("res://enemies/common/kamikaze_electrico/KamikazeElectrico.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)
	enemy.player = player
	player.global_position = enemy.global_position + Vector2(100, 0)

	enemy.current_state = enemy.State.SLEEP
	var vision = enemy.get_node("Vision")
	vision.target_position = player.global_position - enemy.global_position
	vision.force_raycast_update()
	enemy._physics_process(0.016)

	assert_int(enemy.current_state).is_equal(enemy.State.ATTACK)


func test_attack_sets_velocity_towards_player() -> void:
	var enemy = auto_free(load("res://enemies/common/kamikaze_electrico/KamikazeElectrico.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)
	enemy.player = player
	player.global_position = enemy.global_position + Vector2(100, 0)

	enemy._enter_state(enemy.State.ATTACK)
	enemy._physics_process(0.016)

	assert_float(enemy.velocity.x).is_greater(0.0)
	assert_bool(abs(enemy.velocity.length() - enemy.ATTACK_SPEED) < 1.0).is_true()


func test_attack_explodes_after_timer() -> void:
	var enemy = auto_free(load("res://enemies/common/kamikaze_electrico/KamikazeElectrico.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)
	enemy.player = player
	player.global_position = enemy.global_position + Vector2(100, 0)

	enemy._enter_state(enemy.State.ATTACK)
	enemy.explode_timer = 1.2

	enemy._physics_process(0.016)

	assert_int(enemy.current_state).is_equal(enemy.State.EXPLODE)
