extends GdUnitTestSuite


func test_constants() -> void:
	var enemy = auto_free(load("res://enemies/common/centinela_marfil/CentinelaMarfil.tscn").instantiate())
	add_child(enemy)

	assert_int(enemy.MAX_HEALTH).is_equal(4)
	assert_int(enemy.DAMAGE).is_equal(1)


func test_initial_state_is_patrol() -> void:
	var enemy = auto_free(load("res://enemies/common/centinela_marfil/CentinelaMarfil.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	assert_int(enemy.current_state).is_equal(enemy.State.PATROL)
	assert_int(enemy.current_health).is_equal(enemy.MAX_HEALTH)
	assert_bool(enemy.shield_active).is_true()


func test_take_damage_with_shield_frontal_no_red_bypasses() -> void:
	var enemy = auto_free(load("res://enemies/common/centinela_marfil/CentinelaMarfil.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)
	enemy.player = player
	enemy.is_facing_right = true
	player.global_position.x = enemy.global_position.x + 50

	enemy.current_state = enemy.State.PATROL
	enemy.shield_active = true
	enemy.take_damage(1)

	assert_int(enemy.current_health).is_equal(4)
	assert_bool(enemy.shield_active).is_true()


func test_take_damage_from_behind_bypasses_shield() -> void:
	var enemy = auto_free(load("res://enemies/common/centinela_marfil/CentinelaMarfil.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)
	enemy.player = player
	enemy.is_facing_right = true
	player.global_position.x = enemy.global_position.x - 50

	enemy.current_state = enemy.State.PATROL
	enemy.shield_active = true
	enemy.take_damage(1)

	assert_int(enemy.current_health).is_equal(3)
	assert_int(enemy.current_state).is_equal(enemy.State.STUNNED)


func test_take_damage_normally_when_shield_down() -> void:
	var enemy = auto_free(load("res://enemies/common/centinela_marfil/CentinelaMarfil.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)
	enemy.player = player

	enemy.shield_active = false
	enemy.current_state = enemy.State.PATROL
	enemy.take_damage(1)

	assert_int(enemy.current_health).is_equal(3)
	assert_int(enemy.current_state).is_equal(enemy.State.STUNNED)


func test_take_damage_excess_triggers_fainted() -> void:
	var enemy = auto_free(load("res://enemies/common/centinela_marfil/CentinelaMarfil.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)
	enemy.player = player
	enemy.is_facing_right = true
	player.global_position.x = enemy.global_position.x - 50

	enemy.current_state = enemy.State.PATROL
	enemy.shield_active = false
	enemy.take_damage(4)

	assert_int(enemy.current_health).is_equal(0)
	assert_int(enemy.current_state).is_equal(enemy.State.FAINTED)


func test_hurtbox_and_hitbox_connected() -> void:
	var enemy = auto_free(load("res://enemies/common/centinela_marfil/CentinelaMarfil.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	assert_object(enemy.get_node_or_null("AnimatedSprite2D")).is_not_null()
	assert_object(enemy.get_node_or_null("EnemyHurtbox")).is_not_null()
	assert_object(enemy.get_node_or_null("EnemyHitbox")).is_not_null()
