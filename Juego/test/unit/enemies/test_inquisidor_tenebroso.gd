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


func test_idle_transitions_to_attack_when_player_near() -> void:
	var enemy = auto_free(load("res://enemies/common/inquisidor_tenebroso/InquisidorTenebroso.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)
	enemy.player = player
	player.global_position = enemy.global_position + Vector2(100, 0)

	enemy.current_state = enemy.State.IDLE
	enemy._physics_process(0.016)

	assert_int(enemy.current_state).is_equal(enemy.State.ATTACK)


func test_attack_returns_to_idle_when_player_far() -> void:
	var enemy = auto_free(load("res://enemies/common/inquisidor_tenebroso/InquisidorTenebroso.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)
	player.global_position = enemy.global_position + Vector2(300, 0)

	enemy.current_state = enemy.State.ATTACK
	enemy._physics_process(0.016)

	assert_int(enemy.current_state).is_equal(enemy.State.IDLE)


func test_stunned_returns_to_idle_after_timer() -> void:
	var enemy = auto_free(load("res://enemies/common/inquisidor_tenebroso/InquisidorTenebroso.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	enemy.current_state = enemy.State.STUNNED
	enemy.stun_timer = 0.001

	enemy._physics_process(0.002)

	assert_int(enemy.current_state).is_equal(enemy.State.IDLE)


func test_attack_shoot_cooldown() -> void:
	var enemy = auto_free(load("res://enemies/common/inquisidor_tenebroso/InquisidorTenebroso.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)
	enemy.player = player
	player.global_position = enemy.global_position + Vector2(150, 0)

	enemy.current_state = enemy.State.ATTACK
	enemy.shoot_timer = 0.0
	enemy._physics_process(0.016)

	assert_float(enemy.shoot_timer).is_equal(enemy.SHOOT_COOLDOWN)


func test_shoot_timer_counts_down() -> void:
	var enemy = auto_free(load("res://enemies/common/inquisidor_tenebroso/InquisidorTenebroso.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	enemy.shoot_timer = 1.0
	enemy._physics_process(0.5)

	assert_float(enemy.shoot_timer).is_equal(0.5)
