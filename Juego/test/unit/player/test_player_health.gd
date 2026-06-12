extends GdUnitTestSuite

var health: Node
var player: Node2D


func before_test() -> void:
	player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)
	health = player.health


func test_health_constants() -> void:
	assert_int(health.BASE_MAX_HEALTH).is_equal(3)
	assert_float(health.INVINCIBILITY_DURATION).is_equal(1.0)
	assert_float(health.FLASH_DURATION).is_equal(0.1)


func test_max_health_default() -> void:
	assert_int(health.MAX_HEALTH).is_equal(3)


func test_current_health_default() -> void:
	assert_int(health.current_health).is_equal(health.MAX_HEALTH)


func test_invincibility_default() -> void:
	assert_bool(health.is_invincible).is_false()
