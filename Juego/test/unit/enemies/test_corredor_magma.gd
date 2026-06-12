extends GdUnitTestSuite


func test_constants() -> void:
	var enemy = auto_free(load("res://enemies/common/corredor_magma/CorredorMagma.tscn").instantiate())
	add_child(enemy)

	assert_int(enemy.MAX_HEALTH).is_equal(3)
	assert_int(enemy.DAMAGE).is_equal(1)
	assert_float(enemy.PATROL_SPEED).is_equal(40.0)
	assert_float(enemy.CHASE_SPEED).is_equal(190.0)


func test_initial_state_is_idle() -> void:
	var enemy = auto_free(load("res://enemies/common/corredor_magma/CorredorMagma.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	assert_int(enemy.current_state).is_equal(enemy.State.IDLE)
	assert_int(enemy.current_health).is_equal(enemy.MAX_HEALTH)


func test_take_damage_reduces_health() -> void:
	var enemy = auto_free(load("res://enemies/common/corredor_magma/CorredorMagma.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	enemy.current_state = enemy.State.IDLE
	enemy.take_damage(1)

	assert_int(enemy.current_health).is_equal(2)
	assert_int(enemy.current_state).is_equal(enemy.State.STUNNED)


func test_take_damage_multiple_hits() -> void:
	var enemy = auto_free(load("res://enemies/common/corredor_magma/CorredorMagma.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	enemy.current_state = enemy.State.IDLE
	enemy.take_damage(1)
	enemy.current_state = enemy.State.IDLE
	enemy.take_damage(1)
	enemy.current_state = enemy.State.IDLE
	enemy.take_damage(1)

	assert_int(enemy.current_health).is_equal(0)
	assert_int(enemy.current_state).is_equal(enemy.State.DEAD)


func test_damage_noop_when_dead() -> void:
	var enemy = auto_free(load("res://enemies/common/corredor_magma/CorredorMagma.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	enemy.current_state = enemy.State.DEAD
	enemy.current_health = 0
	enemy.take_damage(1)

	assert_int(enemy.current_health).is_equal(0)


func test_hurtbox_and_hitbox_connected() -> void:
	var enemy = auto_free(load("res://enemies/common/corredor_magma/CorredorMagma.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	assert_object(enemy.get_node_or_null("EnemyHurtbox")).is_not_null()
	assert_object(enemy.get_node_or_null("EnemyHitbox")).is_not_null()


func test_idle_transitions_to_patrol() -> void:
	var enemy = auto_free(load("res://enemies/common/corredor_magma/CorredorMagma.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	enemy.current_state = enemy.State.IDLE
	enemy.idle_timer = 0.0
	enemy._physics_process(0.016)

	assert_int(enemy.current_state).is_equal(enemy.State.PATROL)


func test_patrol_sets_velocity() -> void:
	var enemy = auto_free(load("res://enemies/common/corredor_magma/CorredorMagma.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	enemy._enter_state(enemy.State.PATROL)
	enemy._physics_process(0.016)

	assert_float(abs(enemy.velocity.x)).is_equal(enemy.PATROL_SPEED)


func test_chase_sets_chase_speed() -> void:
	var enemy = auto_free(load("res://enemies/common/corredor_magma/CorredorMagma.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)
	enemy.player = player
	player.global_position = enemy.global_position + Vector2(100, 0)

	enemy._enter_state(enemy.State.CHASE)
	enemy._physics_process(0.016)

	assert_float(abs(enemy.velocity.x)).is_equal(enemy.CHASE_SPEED)


func test_stunned_transitions_to_idle() -> void:
	var enemy = auto_free(load("res://enemies/common/corredor_magma/CorredorMagma.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	enemy._enter_state(enemy.State.STUNNED)
	enemy.stun_timer = 0.0
	enemy._physics_process(0.016)

	assert_int(enemy.current_state).is_equal(enemy.State.IDLE)


func test_prepare_dash_transitions_to_dash() -> void:
	var enemy = auto_free(load("res://enemies/common/corredor_magma/CorredorMagma.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	enemy._enter_state(enemy.State.PREPARE_DASH)
	enemy.dash_timer = 0.0
	enemy._physics_process(0.016)

	assert_int(enemy.current_state).is_equal(enemy.State.DASH)
