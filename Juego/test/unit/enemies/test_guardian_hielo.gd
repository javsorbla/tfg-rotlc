extends GdUnitTestSuite

var boss: Node2D


func before_test() -> void:
	boss = auto_free(load("res://enemies/bosses/ice_guardian/GuardianHielo.tscn").instantiate())
	add_child(boss)


func test_constants() -> void:
	assert_int(boss.MAX_HEALTH).is_equal(35)
	assert_int(boss.DAMAGE).is_equal(1)


func test_initial_state() -> void:
	assert_int(boss.current_health).is_equal(35)
	assert_int(boss.current_state).is_equal(boss.State.IDLE)


func test_take_damage_reduces_health() -> void:
	boss.take_damage(5)
	assert_int(boss.current_health).is_equal(30)


func test_damage_reduces_health_when_dead() -> void:
	boss.current_state = boss.State.DEAD
	boss.take_damage(5)
	assert_int(boss.current_health).is_equal(30)


func test_idle_transitions_to_charge_when_cooldown_ready() -> void:
	boss.is_active = true
	boss.current_state = boss.State.IDLE
	boss.charge_timer = 0.0
	boss.projectile_timer = 5.0
	boss.action_timer = 0.0
	boss.post_jump_recover_timer = 0.0
	boss._physics_process(0.016)

	assert_int(boss.current_state).is_equal(boss.State.CHARGE)


func test_idle_transitions_to_projectile_when_cd_ready() -> void:
	boss.is_active = true
	boss.current_state = boss.State.IDLE
	boss.charge_timer = 5.0
	boss.projectile_timer = 0.0
	boss.action_timer = 0.0
	boss.post_jump_recover_timer = 0.0
	boss._physics_process(0.016)

	assert_int(boss.current_state).is_equal(boss.State.PROJECTILE)
