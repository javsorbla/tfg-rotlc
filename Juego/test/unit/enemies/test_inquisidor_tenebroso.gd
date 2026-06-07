extends GdUnitTestSuite


func test_constants() -> void:
	var enemy = auto_free(load("res://enemies/common/inquisidor_tenebroso/InquisidorTenebroso.tscn").instantiate())
	add_child(enemy)

	assert_int(enemy.MAX_HEALTH).is_equal(3)
	assert_int(enemy.DAMAGE).is_equal(1)


func test_initial_state_is_idle() -> void:
	var enemy = auto_free(load("res://enemies/common/inquisidor_tenebroso/InquisidorTenebroso.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	assert_int(enemy.current_state).is_equal(enemy.State.IDLE)
	assert_int(enemy.current_health).is_equal(enemy.MAX_HEALTH)


func test_take_damage_reduces_health() -> void:
	var enemy = auto_free(load("res://enemies/common/inquisidor_tenebroso/InquisidorTenebroso.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	enemy.current_state = enemy.State.IDLE
	enemy.take_damage(1)

	assert_int(enemy.current_health).is_equal(2)
	assert_int(enemy.current_state).is_equal(enemy.State.STUNNED)


func test_take_damage_excess_triggers_death() -> void:
	var enemy = auto_free(load("res://enemies/common/inquisidor_tenebroso/InquisidorTenebroso.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	enemy.current_state = enemy.State.IDLE
	enemy.take_damage(3)

	assert_int(enemy.current_health).is_equal(0)
	assert_int(enemy.current_state).is_equal(enemy.State.DEAD)


func test_damage_noop_when_dead() -> void:
	var enemy = auto_free(load("res://enemies/common/inquisidor_tenebroso/InquisidorTenebroso.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	enemy.current_state = enemy.State.DEAD
	enemy.current_health = 0
	enemy.take_damage(1)

	assert_int(enemy.current_health).is_equal(0)


func test_hurtbox_and_hitbox_connected() -> void:
	var enemy = auto_free(load("res://enemies/common/inquisidor_tenebroso/InquisidorTenebroso.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	assert_object(enemy.get_node_or_null("EnemyHurtbox")).is_not_null()
	assert_object(enemy.get_node_or_null("EnemyHitbox")).is_not_null()
