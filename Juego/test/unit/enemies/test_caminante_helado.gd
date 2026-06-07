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
