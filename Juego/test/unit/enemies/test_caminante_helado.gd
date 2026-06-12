extends GdUnitTestSuite


func test_constants() -> void:
	var enemy = auto_free(load("res://enemies/common/caminante_helado/CaminanteHelado.tscn").instantiate())
	add_child(enemy)

	assert_int(enemy.MAX_HEALTH).is_equal(3)
	assert_int(enemy.DAMAGE).is_equal(1)
	assert_float(enemy.PATROL_SPEED).is_equal(30.0)
	assert_float(enemy.CHASE_SPEED).is_equal(60.0)
	assert_float(enemy.STUN_DURATION).is_equal(0.5)


func test_initial_state_is_idle() -> void:
	var enemy = auto_free(load("res://enemies/common/caminante_helado/CaminanteHelado.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	assert_int(enemy.current_state).is_equal(enemy.State.IDLE)
	assert_int(enemy.current_health).is_equal(enemy.MAX_HEALTH)


func test_take_damage_reduces_health() -> void:
	var enemy = auto_free(load("res://enemies/common/caminante_helado/CaminanteHelado.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	enemy.current_state = enemy.State.IDLE
	enemy.take_damage(1)

	assert_int(enemy.current_health).is_equal(2)
	assert_int(enemy.current_state).is_equal(enemy.State.STUNNED)
	assert_float(enemy.stun_timer).is_equal(0.5)


func test_take_damage_multiple_hits() -> void:
	var enemy = auto_free(load("res://enemies/common/caminante_helado/CaminanteHelado.tscn").instantiate())
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


func test_take_damage_excess_triggers_death() -> void:
	var enemy = auto_free(load("res://enemies/common/caminante_helado/CaminanteHelado.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	enemy.current_state = enemy.State.IDLE
	enemy.take_damage(3)

	assert_int(enemy.current_health).is_equal(0)
	assert_int(enemy.current_state).is_equal(enemy.State.DEAD)


func test_damage_noop_when_dead() -> void:
	var enemy = auto_free(load("res://enemies/common/caminante_helado/CaminanteHelado.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	enemy.current_state = enemy.State.DEAD
	enemy.current_health = 0
	enemy.take_damage(1)

	assert_int(enemy.current_health).is_equal(0)


func test_hurtbox_signal_connected() -> void:
	var enemy = auto_free(load("res://enemies/common/caminante_helado/CaminanteHelado.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	var hurtbox = enemy.get_node("EnemyHurtbox")
	assert_object(hurtbox).is_not_null()
	assert_bool(hurtbox.monitorable).is_true()


func test_hitbox_signal_connected() -> void:
	var enemy = auto_free(load("res://enemies/common/caminante_helado/CaminanteHelado.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	var hitbox = enemy.get_node("EnemyHitbox")
	assert_object(hitbox).is_not_null()


func test_stun_timer_expiry_returns_to_idle() -> void:
	var enemy = auto_free(load("res://enemies/common/caminante_helado/CaminanteHelado.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	enemy.current_state = enemy.State.STUNNED
	enemy.stun_timer = 0.001

	enemy._physics_process(0.002)

	assert_int(enemy.current_state).is_equal(enemy.State.IDLE)


func test_idle_transitions_to_patrol_after_timer() -> void:
	var enemy = auto_free(load("res://enemies/common/caminante_helado/CaminanteHelado.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	enemy.current_state = enemy.State.IDLE
	enemy.idle_timer = 0.001

	enemy._physics_process(0.002)

	assert_int(enemy.current_state).is_equal(enemy.State.PATROL)


func test_idle_transitions_to_chase_when_player_detected() -> void:
	var enemy = auto_free(load("res://enemies/common/caminante_helado/CaminanteHelado.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)
	enemy.player = player
	player.global_position = enemy.global_position + Vector2(100, 0)

	enemy.facing_dir = 1.0
	enemy.current_state = enemy.State.IDLE
	enemy.idle_timer = 5.0

	enemy._physics_process(0.016)

	assert_int(enemy.current_state).is_equal(enemy.State.CHASE)


func test_patrol_sets_velocity_in_facing_direction() -> void:
	var enemy = auto_free(load("res://enemies/common/caminante_helado/CaminanteHelado.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	enemy.current_state = enemy.State.PATROL
	enemy.facing_dir = 1.0
	enemy.patrol_timer = 5.0

	enemy._physics_process(0.016)

	assert_float(enemy.velocity.x).is_equal(enemy.PATROL_SPEED)


func test_patrol_reverses_direction_via_flip() -> void:
	var enemy = auto_free(load("res://enemies/common/caminante_helado/CaminanteHelado.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	enemy.facing_dir = 1.0
	enemy.flip_cooldown = 0.0

	enemy._flip()

	assert_float(enemy.facing_dir).is_equal(-1.0)


func test_chase_moves_towards_player() -> void:
	var enemy = auto_free(load("res://enemies/common/caminante_helado/CaminanteHelado.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)
	enemy.player = player
	player.global_position = enemy.global_position + Vector2(100, 0)

	enemy.facing_dir = 1.0
	enemy.current_state = enemy.State.CHASE

	enemy._physics_process(0.016)

	assert_float(enemy.velocity.x).is_greater(0.0)


func test_chase_returns_to_idle_when_player_too_far() -> void:
	var enemy = auto_free(load("res://enemies/common/caminante_helado/CaminanteHelado.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)
	player.global_position = enemy.global_position + Vector2(500, 0)

	enemy.current_state = enemy.State.CHASE

	enemy._physics_process(0.016)

	assert_int(enemy.current_state).is_equal(enemy.State.IDLE)


func test_attack_pause_returns_to_chase_after_timer() -> void:
	var enemy = auto_free(load("res://enemies/common/caminante_helado/CaminanteHelado.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	enemy.current_state = enemy.State.ATTACK_PAUSE
	enemy.stun_timer = 0.001

	enemy._physics_process(0.002)

	assert_int(enemy.current_state).is_equal(enemy.State.CHASE)
