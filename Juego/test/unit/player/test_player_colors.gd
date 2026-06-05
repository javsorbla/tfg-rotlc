extends GdUnitTestSuite

var player: Node2D
var color_manager: Node


func before_test() -> void:
	player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)
	color_manager = player.get_node("ColorManager")


func test_initial_state_is_neutral() -> void:
	assert_object(color_manager.current_state).is_equal(color_manager.neutral_state)


func test_change_state_to_cyan() -> void:
	color_manager.change_state(color_manager.cyan_state)
	assert_object(color_manager.current_state).is_equal(color_manager.cyan_state)
	assert_str(color_manager.active_power).is_equal("cyan")
	assert_bool(color_manager.power_active).is_true()


func test_change_state_to_red() -> void:
	color_manager.change_state(color_manager.red_state)
	assert_object(color_manager.current_state).is_equal(color_manager.red_state)
	assert_str(color_manager.active_power).is_equal("red")
	assert_bool(color_manager.power_active).is_true()


func test_change_state_to_yellow() -> void:
	color_manager.change_state(color_manager.yellow_state)
	assert_object(color_manager.current_state).is_equal(color_manager.yellow_state)
	assert_str(color_manager.active_power).is_equal("yellow")
	assert_bool(color_manager.power_active).is_true()


func test_go_back_to_neutral_sets_empty_power() -> void:
	color_manager.change_state(color_manager.cyan_state)
	color_manager.change_state(color_manager.neutral_state)
	assert_object(color_manager.current_state).is_equal(color_manager.neutral_state)
	assert_str(color_manager.active_power).is_equal("")
	assert_bool(color_manager.power_active).is_false()


func test_power_timer_counts_down() -> void:
	color_manager.change_state(color_manager.cyan_state)
	var initial_timer = color_manager.power_timer
	await get_tree().process_frame
	assert_float(color_manager.power_timer).is_less(initial_timer)


func test_cooldown_starts_after_power_ends() -> void:
	color_manager.change_state(color_manager.cyan_state)
	color_manager.power_timer = 0.001
	await get_tree().process_frame
	assert_float(color_manager.cooldown_timers["cyan"]).is_greater(0.0)


func test_reset_for_respawn_clears_power() -> void:
	color_manager.change_state(color_manager.cyan_state)
	color_manager.reset_for_respawn()
	assert_str(color_manager.active_power).is_equal("")
	assert_bool(color_manager.power_active).is_false()
	assert_float(color_manager.cooldown_timers["cyan"]).is_equal(0.0)


func test_apply_unlocked_powers() -> void:
	color_manager.apply_unlocked_powers({"cyan": true, "red": false, "yellow": true})
	assert_bool(color_manager.unlocked["cyan"]).is_true()
	assert_bool(color_manager.unlocked["red"]).is_false()
	assert_bool(color_manager.unlocked["yellow"]).is_true()


