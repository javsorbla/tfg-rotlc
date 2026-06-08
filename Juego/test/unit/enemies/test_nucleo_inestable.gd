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


func test_sleep_velocity_is_zero() -> void:
	var enemy = auto_free(load("res://enemies/common/nucleo_inestable/NucleoInestable.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	enemy.current_state = enemy.State.SLEEP
	enemy._physics_process(0.016)

	assert_float(enemy.velocity.x).is_equal(0.0)


func test_sleep_transitions_to_jump_when_player_near() -> void:
	var enemy = auto_free(load("res://enemies/common/nucleo_inestable/NucleoInestable.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)
	enemy.player = player
	player.global_position = enemy.global_position + Vector2(100, 0)

	enemy.current_state = enemy.State.SLEEP
	enemy._physics_process(0.016)

	assert_int(enemy.current_state).is_equal(enemy.State.JUMP)


func test_jump_transitions_to_rolling_on_floor() -> void:
	var enemy = auto_free(load("res://enemies/common/nucleo_inestable/NucleoInestable.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	var floor = StaticBody2D.new()
	var collision = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(1000, 20)
	collision.shape = rect
	floor.add_child(collision)
	add_child(floor)
	floor.global_position = Vector2(enemy.global_position.x, enemy.global_position.y + 100)

	enemy._enter_state(enemy.State.JUMP)
	for _i in range(20):
		enemy._physics_process(0.1)
		if enemy.current_state == enemy.State.ROLLING:
			break

	assert_int(enemy.current_state).is_equal(enemy.State.ROLLING)


func test_rolling_sets_velocity() -> void:
	var enemy = auto_free(load("res://enemies/common/nucleo_inestable/NucleoInestable.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)
	enemy.player = player
	player.global_position = enemy.global_position + Vector2(100, 0)

	enemy._enter_state(enemy.State.ROLLING)
	enemy._physics_process(0.016)

	assert_float(abs(enemy.velocity.x)).is_equal(enemy.ROLL_SPEED)


func test_stunned_transitions_to_sleep() -> void:
	var enemy = auto_free(load("res://enemies/common/nucleo_inestable/NucleoInestable.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	enemy._enter_state(enemy.State.STUNNED)
	enemy.stun_timer = 0.0
	enemy._physics_process(0.016)

	assert_int(enemy.current_state).is_equal(enemy.State.SLEEP)
