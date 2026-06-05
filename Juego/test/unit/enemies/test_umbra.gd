extends GdUnitTestSuite

var boss: CharacterBody2D


func before_test() -> void:
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
