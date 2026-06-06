extends GdUnitTestSuite

var boss: Node2D


func before_test() -> void:
	boss = auto_free(load("res://enemies/bosses/tempestad_dorada/TempestadDorada.tscn").instantiate())
	add_child(boss)


func test_constants() -> void:
	assert_int(boss.MAX_HEALTH).is_equal(50)
	assert_int(boss.DAMAGE).is_equal(1)


func test_initial_state() -> void:
	assert_int(boss.current_health).is_equal(50)
	assert_int(boss.current_state).is_equal(boss.State.PATROL)


func test_take_damage_reduces_health() -> void:
	boss.take_damage(10)
	assert_int(boss.current_health).is_equal(40)
