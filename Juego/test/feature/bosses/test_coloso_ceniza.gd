extends GdUnitTestSuite

var boss: Node2D

func before_test() -> void:
	boss = auto_free(load("res://enemies/bosses/coloso_ceniza/ColosoCeniza.tscn").instantiate())
	add_child(boss)
	boss.is_active = true
	boss.room_left_limit = 0
	boss.room_right_limit = 1000
	boss.room_top_limit = 0
	boss.room_bottom_limit = 600


func test_initial_state() -> void:
	assert_int(boss.current_state).is_equal(boss.State.IDLE)
	assert_int(boss.current_health).is_equal(35)


func test_take_damage_reduces_health() -> void:
	boss.take_damage(5)
	assert_int(boss.current_health).is_equal(30)


func test_damage_triggers_death_at_zero() -> void:
	boss.current_health = 5
	boss.take_damage(5)
	assert_int(boss.current_state).is_equal(boss.State.DEAD)


func test_idle_moves_toward_player() -> void:
	var player = auto_free(load("res://player/player.tscn").instantiate())
	player.add_to_group("player")
	add_child(player)
	boss.player = player
	player.global_position = boss.global_position + Vector2(200, 0)
	var start_x = boss.global_position.x

	boss._physics_process(1.0)

	assert_bool(boss.global_position.x > start_x).is_true()


func test_leg_hurtbox_reduces_leg_health() -> void:
	boss.leg_health = boss.LEG_MAX_HEALTH
	var area = auto_free(Area2D.new())
	area.add_to_group("player_hitbox")
	add_child(area)

	boss._on_leg_hurtbox_area_entered(area)
	assert_bool(boss.leg_health < boss.LEG_MAX_HEALTH).is_true()


func test_leg_depleted_enters_hurt_state() -> void:
	boss.leg_health = 1
	var area = auto_free(Area2D.new())
	area.add_to_group("player_hitbox")
	add_child(area)

	boss._on_leg_hurtbox_area_entered(area)
	assert_int(boss.current_state).is_equal(boss.State.HURT)


func test_hurt_enables_core_vulnerability() -> void:
	boss._enter_hurt()
	assert_int(boss.current_state).is_equal(boss.State.HURT)
	assert_bool(boss.is_vulnerable).is_false()

	await get_tree().create_timer(0.35).timeout
	assert_bool(boss.is_vulnerable).is_true()


func test_core_hit_during_hurt_damages_boss() -> void:
	boss._enter_hurt()
	await get_tree().create_timer(0.35).timeout

	var area = auto_free(Area2D.new())
	area.add_to_group("player_hitbox")
	add_child(area)

	boss._on_core_hurtbox_area_entered(area)
	assert_int(boss.current_health).is_equal(34)


func test_enter_punch_sets_state() -> void:
	var player = auto_free(load("res://player/player.tscn").instantiate())
	player.add_to_group("player")
	add_child(player)
	boss.player = player

	boss._enter_punch()
	assert_int(boss.current_state).is_equal(boss.State.PUNCH)


func test_phase_two_at_15_hp() -> void:
	boss.current_health = 16
	boss._check_phase()
	assert_bool(boss.phase_two).is_false()

	boss.current_health = 15
	boss._check_phase()
	assert_bool(boss.phase_two).is_true()
	assert_bool(boss.move_speed > 40.0).is_true()


func test_activate_resets_and_starts() -> void:
	boss.current_health = 10
	boss.activate()
	assert_int(boss.current_health).is_equal(boss.MAX_HEALTH)
	assert_bool(boss.is_active).is_true()
