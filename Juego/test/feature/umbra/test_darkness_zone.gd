extends GdUnitTestSuite


func test_darkness_zone_loads() -> void:
	var zone = auto_free(load("res://enemies/bosses/umbra/Umbra.tscn").instantiate())
	add_child(zone)
	assert_that(zone).is_not_null()


func test_darkness_zone_configure_sets_params() -> void:
	var zone = auto_free(load("res://enemies/bosses/umbra/darkness_zone.gd").new())
	add_child(zone)
	zone.configure(2, 0.5, 3.0, 0.6)
	assert_int(zone.tick_damage).is_equal(2)
	assert_float(zone.tick_interval).is_equal(0.5)
	assert_float(zone.remaining_lifetime).is_equal(3.0)
	assert_float(zone.arming_delay).is_equal(0.6)


func test_darkness_zone_ready_sets_visual() -> void:
	var zone = auto_free(load("res://enemies/bosses/umbra/darkness_zone.gd").new())
	add_child(zone)
	zone.configure(1, 0.6, 2.8, 0.55)
	await get_tree().process_frame
	zone._ready()
	assert_that(zone.get_node("Visual")).is_not_null()


func test_darkness_zone_arms_after_delay() -> void:
	var zone = auto_free(load("res://enemies/bosses/umbra/darkness_zone.gd").new())
	add_child(zone)
	zone.configure(1, 0.6, 2.8, 0.55)
	zone._ready()
	assert_bool(zone._armed).is_false()

	zone._physics_process(0.56)
	assert_bool(zone._armed).is_true()


func test_umbra_combat_spawns_darkness_zone() -> void:
	var boss = auto_free(load("res://enemies/bosses/umbra/Umbra.tscn").instantiate())
	add_child(boss)
	boss.is_active = true
	boss._darkness_cooldown_timer = 0.0
	boss._darkness_try_timer = 0.0
	boss._allow_darkness_cast = true
	boss.darkness_requires_power = false
	boss.darkness_try_chance = 1.0

	var player = auto_free(load("res://player/player.tscn").instantiate())
	player.add_to_group("player")
	add_child(player)

	var combat = boss.combat
	combat.setup()
	combat.handle_darkness_attack()
	assert_bool(boss._darkness_cooldown_timer > 0.0).is_true()
