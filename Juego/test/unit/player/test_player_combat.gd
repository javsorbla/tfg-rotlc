extends GdUnitTestSuite

var combat: Node
var player: Node2D


func before_test() -> void:
	player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)
	combat = player.combat


func test_attack_constants() -> void:
	assert_float(combat.ATTACK_DURATION).is_equal(0.3)
	assert_int(combat.HITBOX_OFFSET_X).is_equal(14)
	assert_int(combat.HITBOX_OFFSET_Y).is_equal(22)
	assert_float(combat.HITSTOP_DURATION).is_equal(0.05)


func test_initial_state_not_attacking() -> void:
	assert_bool(combat.is_attacking).is_false()
	assert_float(combat.hitstop_timer).is_equal(0.0)


func test_attack_timer_expiry_disables_hitbox() -> void:
	combat.is_attacking = true
	combat.attack_timer = 0.001
	combat.process(0.002)
	assert_bool(combat.is_attacking).is_false()
