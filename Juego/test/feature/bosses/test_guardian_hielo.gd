extends GdUnitTestSuite

var boss: Node2D

func before_test() -> void:
	boss = auto_free(load("res://enemies/bosses/ice_guardian/GuardianHielo.tscn").instantiate())
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
	var player = auto_free(Node2D.new())
	player.add_to_group("player")
	add_child(player)
	boss.player = player
	player.global_position = boss.global_position + Vector2(500, 0)
	boss.current_state = boss.State.IDLE
	var start_x = boss.global_position.x

	boss._idle_state(1.0)

	assert_bool(boss.global_position.x > start_x).is_true()


func test_start_charge_sets_state_and_hitbox() -> void:
	var player = auto_free(load("res://player/player.tscn").instantiate())
	player.add_to_group("player")
	add_child(player)
	boss.player = player

	boss._start_charge()
	assert_int(boss.current_state).is_equal(boss.State.CHARGE)
	assert_bool(boss.attack_hitbox.monitoring).is_true()


func test_start_projectile_sets_state() -> void:
	boss._start_projectile()
	assert_int(boss.current_state).is_equal(boss.State.PROJECTILE)


func test_phase_two_at_35_percent_hp() -> void:
	boss.current_health = int(boss.MAX_HEALTH * boss.PHASE_TWO_THRESHOLD) + 1
	boss._check_phase()
	assert_int(boss.current_phase).is_equal(boss.Phase.ONE)

	boss.current_health = int(boss.MAX_HEALTH * boss.PHASE_TWO_THRESHOLD)
	boss._check_phase()
	assert_int(boss.current_phase).is_equal(boss.Phase.TWO)


func test_phase_two_triggers_fury_summon() -> void:
	boss.current_health = int(boss.MAX_HEALTH * boss.PHASE_TWO_THRESHOLD)
	boss._check_phase()
	assert_bool(boss.has_summoned_fury_walkers).is_true()


func test_jump_starts_when_cooldown_ready() -> void:
	boss.current_phase = boss.Phase.TWO
	boss.jump_timer = 0.0
	boss.action_timer = 0.0

	var player = auto_free(load("res://player/player.tscn").instantiate())
	player.add_to_group("player")
	add_child(player)
	boss.player = player
	boss.current_state = boss.State.IDLE

	boss._idle_state(0.016)
	assert_int(boss.current_state).is_equal(boss.State.JUMP)


func test_activate_resets_and_starts() -> void:
	boss.current_health = 10
	boss.activate()
	assert_int(boss.current_health).is_equal(boss.MAX_HEALTH)
	assert_int(boss.current_state).is_equal(boss.State.IDLE)
	assert_bool(boss.is_active).is_true()


func test_projectile_spawn_offset_flips_with_sprite() -> void:
	boss._update_flip(true)
	var offset = boss._get_projectile_spawn_offset(false)
	assert_bool(offset.x < 0).is_true()

	boss._update_flip(false)
	offset = boss._get_projectile_spawn_offset(false)
	assert_bool(offset.x > 0).is_true()
