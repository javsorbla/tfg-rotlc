extends GdUnitTestSuite

var boss: CharacterBody2D


func before_test() -> void:
	if "umbra_progress" in GameState:
		GameState.umbra_progress["difficulty_scale"] = 1.0
	boss = auto_free(load("res://enemies/bosses/umbra/Umbra.tscn").instantiate())
	add_child(boss)


func test_constants() -> void:
	assert_int(boss.DAMAGE).is_equal(1)


func test_initial_health() -> void:
	assert_int(boss.current_health).is_equal(boss.max_health)


func test_take_damage_reduces_health() -> void:
	var initial = boss.current_health
	boss.take_damage(1)
	assert_int(boss.current_health).is_equal(initial - 1)


func test_initial_state_values() -> void:
	assert_bool(boss.is_active).is_false()
	assert_bool(boss.is_dashing).is_false()
	assert_bool(boss.is_attacking).is_false()
	assert_int(boss.ai_move_direction).is_equal(0)


func test_cooldown_timers_decrease() -> void:
	boss.dash_cooldown_timer = 1.0
	boss.attack_cooldown_timer = 1.0
	boss._handle_timers(0.5)

	assert_bool(boss.dash_cooldown_timer < 1.0).is_true()
	assert_bool(boss.attack_cooldown_timer < 1.0).is_true()