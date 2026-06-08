extends GdUnitTestSuite

var boss: Node2D

func before_test() -> void:
	boss = auto_free(load("res://enemies/bosses/tempestad_dorada/TempestadDorada.tscn").instantiate())
	add_child(boss)
	boss.is_active = true
	boss.room_left_limit = 0
	boss.room_right_limit = 1000
	boss.room_top_limit = 0
	boss.room_bottom_limit = 600


func test_initial_state() -> void:
	assert_int(boss.current_state).is_equal(boss.State.PATROL)
	assert_int(boss.current_health).is_equal(60)


func test_patrol_moves_horizontally() -> void:
	boss.current_state = boss.State.PATROL
	boss.patrol_direction = 1.0
	var start_x = boss.global_position.x

	boss._physics_process(1.0)

	assert_bool(boss.global_position.x > start_x).is_true()


func test_patrol_reverses_at_wall() -> void:
	boss.patrol_direction = 1.0
	boss.global_position.x = boss.room_right_limit - boss.BOSS_HALF_WIDTH
	boss.current_state = boss.State.PATROL

	boss._physics_process(0.016)

	assert_int(boss.current_state).is_equal(boss.State.PAUSE)


func test_take_damage_reduces_health() -> void:
	boss.take_damage(10)
	assert_int(boss.current_health).is_equal(50)


func test_phase_two_at_30_hp() -> void:
	boss.current_health = 31
	boss.hit_cooldown = 0.0
	boss.take_damage(1)
	boss._check_phase()

	assert_int(boss.current_phase).is_equal(boss.Phase.TWO)


func test_enter_weak_clears_states() -> void:
	boss._enter_weak()
	assert_int(boss.current_state).is_equal(boss.State.WEAK)
	assert_bool(boss.is_weak).is_true()
	assert_bool(boss.dive_sliding).is_false()


func test_wing_hit_reduces_health() -> void:
	boss.wing_health = boss.WING_MAX_HEALTH

	var player = auto_free(load("res://player/player.tscn").instantiate())
	player.add_to_group("player")
	add_child(player)

	var area = auto_free(Area2D.new())
	area.add_to_group("player_hitbox")
	add_child(area)

	boss._handle_wing_hit(area)
	assert_bool(boss.wing_health < boss.WING_MAX_HEALTH).is_true()


func test_wing_depleted_triggers_weak() -> void:
	boss.wing_health = 1
	var area = auto_free(Area2D.new())
	area.add_to_group("player_hitbox")
	add_child(area)

	boss._handle_wing_hit(area)
	assert_int(boss.current_state).is_equal(boss.State.WEAK)


func test_die_spawns_crystal() -> void:
	boss.die()
	assert_bool(boss.is_dying).is_true()
