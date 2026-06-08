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


func _make_damage_source(damage: int, group: String) -> Area2D:
	var script := GDScript.new()
	script.source_code = "extends Node2D\nvar DAMAGE = " + str(damage)
	script.reload()
	var source := Node2D.new()
	source.set_script(script)
	add_child(auto_free(source))
	var area := Area2D.new()
	area.add_to_group(group)
	source.add_child(area)
	return area


func test_enemy_hitbox_damages_player() -> void:
	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)
	await_idle_frame()

	var fake_area = _make_damage_source(1, "enemy_hitbox")
	player.health._on_hurtbox_area_entered(fake_area)

	assert_int(player.health.current_health).is_equal(player.health.MAX_HEALTH - 1)


func test_player_shield_blocks_enemy_damage() -> void:
	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)
	await_idle_frame()

	player.is_shielding = true
	var fake_area = _make_damage_source(1, "enemy_hitbox")
	player.health._on_hurtbox_area_entered(fake_area)

	assert_int(player.health.current_health).is_equal(player.health.MAX_HEALTH)


func test_boss_hitbox_damages_player() -> void:
	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)
	await_idle_frame()

	var fake_area = _make_damage_source(2, "boss_hitbox")
	player.health._on_hurtbox_area_entered(fake_area)

	assert_int(player.health.current_health).is_equal(player.health.MAX_HEALTH - 2)


func test_spikes_damage_player() -> void:
	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)
	await_idle_frame()

	var fake_body = auto_free(Node2D.new())
	fake_body.add_to_group("spikes")
	add_child(fake_body)

	player.health._on_hurtbox_body_entered(fake_body)

	assert_int(player.health.current_health).is_equal(player.health.MAX_HEALTH - 1)


func test_inquisidor_takes_damage_from_player_hitbox() -> void:
	var enemy = auto_free(load("res://enemies/common/inquisidor_tenebroso/InquisidorTenebroso.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()
	enemy.current_state = enemy.State.IDLE

	var fake_area := Area2D.new()
	fake_area.add_to_group("player_hitbox")
	add_child(fake_area)

	enemy._on_enemy_hurtbox_area_entered(fake_area)

	assert_int(enemy.current_health).is_equal(2)
	assert_int(enemy.current_state).is_equal(enemy.State.STUNNED)


func test_kamikaze_dies_from_player_hitbox() -> void:
	var enemy = auto_free(load("res://enemies/common/kamikaze_electrico/KamikazeElectrico.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()
	enemy.current_state = enemy.State.SLEEP

	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)

	var fake_area := Area2D.new()
	fake_area.add_to_group("player_hitbox")
	add_child(fake_area)

	enemy._on_enemy_hurtbox_area_entered(fake_area)

	assert_int(enemy.current_health).is_equal(0)
	assert_int(enemy.current_state).is_equal(enemy.State.DEAD)


func test_corredor_magma_takes_damage_from_player_hitbox() -> void:
	var enemy = auto_free(load("res://enemies/common/corredor_magma/CorredorMagma.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()
	enemy.current_state = enemy.State.IDLE

	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)

	var fake_area := Area2D.new()
	fake_area.add_to_group("player_hitbox")
	add_child(fake_area)

	enemy._on_enemy_hurtbox_area_entered(fake_area)

	assert_int(enemy.current_health).is_equal(2)


func test_nucleo_inestable_needs_red_power_to_take_damage() -> void:
	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)

	var enemy = auto_free(load("res://enemies/common/nucleo_inestable/NucleoInestable.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()
	enemy.current_state = enemy.State.SLEEP

	var fake_area := Area2D.new()
	fake_area.add_to_group("player_hitbox")
	add_child(fake_area)

	enemy._on_enemy_hurtbox_area_entered(fake_area)

	assert_int(enemy.current_health).is_equal(enemy.MAX_HEALTH)
	assert_int(enemy.current_state).is_equal(enemy.State.STUNNED)


func test_nucleo_inestable_takes_damage_with_red_power() -> void:
	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)
	player.color_manager.unlock_power("red")
	player.color_manager.change_state(player.color_manager.red_state)

	var enemy = auto_free(load("res://enemies/common/nucleo_inestable/NucleoInestable.tscn").instantiate())
	add_child(enemy)
	await_idle_frame()
	enemy.current_state = enemy.State.SLEEP

	enemy.take_damage(1)

	assert_int(enemy.current_health).is_equal(0)
	assert_int(enemy.current_state).is_equal(enemy.State.DEAD)
