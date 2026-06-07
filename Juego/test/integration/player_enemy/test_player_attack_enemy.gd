extends GdUnitTestSuite


func test_player_hurtbox_detects_enemy() -> void:
	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)

	var hurtbox = player.get_node("Hurtbox")
	assert_object(hurtbox).is_not_null()
	assert_bool(hurtbox.monitorable).is_true()


func test_caminante_take_damage_from_attack() -> void:
	var enemy = auto_free(load("res://enemies/common/caminante_helado/CaminanteHelado.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	enemy.current_state = enemy.State.IDLE
	enemy.take_damage(1)

	assert_int(enemy.current_health).is_equal(2)
	assert_int(enemy.current_state).is_equal(enemy.State.STUNNED)


func test_damage_multiplier_affects_caminante() -> void:
	var enemy = auto_free(load("res://enemies/common/caminante_helado/CaminanteHelado.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()

	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)
	player.damage_multiplier = 2.0

	var fake_hitbox := Area2D.new()
	fake_hitbox.add_to_group("player_hitbox")
	add_child(fake_hitbox)

	enemy._on_enemy_hurtbox_area_entered(fake_hitbox)

	assert_int(enemy.current_health).is_equal(1)


func test_caminante_has_required_nodes() -> void:
	var scene = load("res://enemies/common/caminante_helado/CaminanteHelado.tscn")
	assert_object(scene).is_not_null()

	var enemy = auto_free(scene.instantiate())
	add_child(enemy)

	assert_object(enemy.get_node_or_null("AnimatedSprite2D")).is_not_null()
	assert_object(enemy.get_node_or_null("Vision")).is_not_null()
	assert_object(enemy.get_node_or_null("EnemyHitbox")).is_not_null()
	assert_object(enemy.get_node_or_null("EnemyHurtbox")).is_not_null()


func test_player_color_manager_initial_state() -> void:
	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)

	var cm = player.get_node("ColorManager")
	assert_object(cm.current_state).is_not_null()
	assert_object(cm.neutral_state).is_not_null()
	assert_object(cm.cyan_state).is_not_null()
	assert_object(cm.red_state).is_not_null()
	assert_object(cm.yellow_state).is_not_null()
	assert_bool(cm.power_active).is_false()
	assert_str(cm.active_power).is_empty()
