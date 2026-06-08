extends GdUnitTestSuite

var boss: Node2D


func before_test() -> void:
	boss = auto_free(load("res://enemies/bosses/tempestad_dorada/TempestadDorada.tscn").instantiate())
	add_child(boss)


func test_constants() -> void:
	assert_int(boss.MAX_HEALTH).is_equal(60)
	assert_int(boss.DAMAGE).is_equal(1)


func test_initial_state() -> void:
	assert_int(boss.current_health).is_equal(60)
	assert_int(boss.current_state).is_equal(boss.State.PATROL)


func test_take_damage_reduces_health() -> void:
	boss.take_damage(10)
	assert_int(boss.current_health).is_equal(50)


func test_damage_reduces_health_when_dying() -> void:
	boss.is_dying = true
	boss.take_damage(10)
	assert_int(boss.current_health).is_equal(50)


func test_patrol_moves_horizontally() -> void:
	boss.is_active = true
	boss.current_state = boss.State.PATROL
	boss.patrol_direction = 1.0
	boss.room_left_limit = 0
	boss.room_right_limit = 1000
	boss.room_top_limit = 0
	boss.room_bottom_limit = 600
	var start_x = boss.global_position.x

	boss._physics_process(1.0)

	assert_bool(boss.global_position.x > start_x).is_true()
