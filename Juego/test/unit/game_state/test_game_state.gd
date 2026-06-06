extends GdUnitTestSuite


var _game_state: Node


func before_test() -> void:
	_game_state = auto_free(load("res://scripts/GameState.gd").new())
	get_tree().root.add_child(_game_state)
	_game_state.reset_for_new_game()


func test_default_player_progress() -> void:
	var progress = _game_state._make_default_player_progress()
	assert_int(progress["max_health_bonus"]).is_equal(0)
	assert_bool(progress["prism_core_collected"]).is_false()
	assert_bool(progress["unlocked_powers"].has("cyan")).is_true()
	assert_bool(progress["unlocked_powers"].has("red")).is_true()
	assert_bool(progress["unlocked_powers"].has("yellow")).is_true()


func test_default_umbra_progress() -> void:
	var progress = _game_state._make_default_umbra_progress()
	assert_int(progress["encounters"]).is_equal(0)
	assert_int(progress["wins"]).is_equal(0)
	assert_int(progress["losses"]).is_equal(0)
	assert_float(progress["difficulty_scale"]).is_equal(1.0)
	assert_str(progress["latest_model_path"]).is_empty()
	assert_bool(progress["player_metrics"].has("avg_distance")).is_true()


func test_prism_core_collection() -> void:
	_game_state.current_level = 1

	var collected = _game_state.collect_prism_core()
	assert_bool(collected).is_true()
	assert_bool(_game_state.has_prism_core_upgrade(1)).is_true()

	var duplicate = _game_state.collect_prism_core(1)
	assert_bool(duplicate).is_false()


func test_prism_core_increases_health_bonus() -> void:
	_game_state.collect_prism_core(1)
	assert_int(_game_state.player_progress["max_health_bonus"]).is_equal(1)

	_game_state.collect_prism_core(2)
	assert_int(_game_state.player_progress["max_health_bonus"]).is_equal(2)


func test_get_player_max_health_with_bonus() -> void:
	var base = _game_state.BASE_PLAYER_MAX_HEALTH

	assert_int(_game_state.get_player_max_health()).is_equal(base)

	_game_state.collect_prism_core(1)
	assert_int(_game_state.get_player_max_health()).is_equal(base + 1)

	_game_state.collect_prism_core(2)
	assert_int(_game_state.get_player_max_health()).is_equal(base + 2)


func test_unlock_power_marks_as_unlocked() -> void:
	var result = _game_state.unlock_power("cyan")
	assert_bool(result).is_true()

	var unlocked = _game_state.get_unlocked_powers()
	assert_bool(unlocked["cyan"]).is_true()


func test_unlock_power_returns_false_if_already_unlocked() -> void:
	_game_state.unlock_power("cyan")
	var result = _game_state.unlock_power("cyan")
	assert_bool(result).is_false()


func test_unlock_power_returns_false_for_invalid_color() -> void:
	var result = _game_state.unlock_power("invalid_color")
	assert_bool(result).is_false()


func test_get_unlocked_powers_defaults() -> void:
	var unlocked = _game_state.get_unlocked_powers()
	assert_bool(unlocked["cyan"]).is_false()
	assert_bool(unlocked["red"]).is_false()
	assert_bool(unlocked["yellow"]).is_false()


func test_boss_room_tracking() -> void:
	var key = _game_state.make_boss_room_key("res://scenes/CamposDeZafiro.tscn", "Room1")
	assert_bool(_game_state.is_boss_room_cleared(key)).is_false()

	_game_state.mark_boss_room_cleared(key)
	assert_bool(_game_state.is_boss_room_cleared(key)).is_true()

	assert_bool(_game_state.is_boss_room_cleared("")).is_false()


func test_umbra_register_encounter_player_wins() -> void:
	_game_state.register_umbra_encounter({
		"umbra_won": false,
		"player_metrics": {}
	})

	assert_int(_game_state.umbra_progress["encounters"]).is_equal(1)
	assert_int(_game_state.umbra_progress["wins"]).is_equal(0)
	assert_int(_game_state.umbra_progress["losses"]).is_equal(1)


func test_umbra_register_encounter_umbra_wins() -> void:
	_game_state.register_umbra_encounter({
		"umbra_won": true,
		"player_metrics": {}
	})

	assert_int(_game_state.umbra_progress["encounters"]).is_equal(1)
	assert_int(_game_state.umbra_progress["wins"]).is_equal(1)
	assert_int(_game_state.umbra_progress["losses"]).is_equal(0)


func test_get_umbra_learning_summary() -> void:
	_game_state.umbra_progress["encounters"] = 10
	_game_state.umbra_progress["wins"] = 6
	_game_state.umbra_progress["losses"] = 4

	var summary = _game_state.get_umbra_learning_summary()
	assert_int(summary["encounters"]).is_equal(10)
	assert_int(summary["wins"]).is_equal(6)
	assert_float(summary["win_rate"]).is_equal_approx(0.6, 0.01)
	assert_float(summary["difficulty_scale"]).is_equal(1.0)


func test_umbra_difficulty_scales_with_win_rate() -> void:
	for i in range(5):
		_game_state.register_umbra_encounter({
			"umbra_won": true,
			"player_metrics": {}
		})

	assert_float(_game_state.get_umbra_difficulty_scale()).is_greater(0.8)


func test_reset_umbra_learning_clears_progress() -> void:
	_game_state.umbra_progress["encounters"] = 20
	_game_state.umbra_progress["wins"] = 15
	_game_state.umbra_progress["losses"] = 5

	_game_state.reset_umbra_learning()

	assert_int(_game_state.umbra_progress["encounters"]).is_equal(0)
	assert_int(_game_state.umbra_progress["wins"]).is_equal(0)


func test_bind_onnx_model_returns_false_for_null_agent() -> void:
	var result = _game_state.bind_onnx_model_for_agent(null, "umbra.onnx")
	assert_bool(result).is_false()


func test_level_default_powers_mapping() -> void:
	assert_str(_game_state.LEVEL_DEFAULT_POWER[2]).is_equal("cyan")
	assert_str(_game_state.LEVEL_DEFAULT_POWER[3]).is_equal("red")
	assert_str(_game_state.LEVEL_DEFAULT_POWER[4]).is_equal("yellow")


func test_get_umbra_player_metrics_returns_copy() -> void:
	var metrics = _game_state.get_umbra_player_metrics()
	assert_bool(metrics.has("avg_distance")).is_true()
	assert_bool(metrics.has("dash_frequency")).is_true()

	metrics["avg_distance"] = 999.0
	var metrics_again = _game_state.get_umbra_player_metrics()
	assert_float(metrics_again["avg_distance"]).is_equal(200.0)


func test_auto_unlock_power_at_level_2() -> void:
	_game_state.current_level = 2
	var result = _game_state.auto_unlock_power_for_level()
	assert_bool(result).is_true()

	var unlocked = _game_state.get_unlocked_powers()
	assert_bool(unlocked["cyan"]).is_true()


func test_auto_unlock_power_noop_at_level_1() -> void:
	_game_state.current_level = 1
	var result = _game_state.auto_unlock_power_for_level()
	assert_bool(result).is_false()


func test_boss_crystal_collection() -> void:
	var collected = _game_state.collect_boss_crystal(1, 0)
	assert_bool(collected).is_true()
	assert_bool(_game_state.has_boss_crystal(1, 0)).is_true()

	var duplicate = _game_state.collect_boss_crystal(1, 0)
	assert_bool(duplicate).is_false()


func test_is_valid_onnx_output_rejects_empty() -> void:
	assert_bool(_game_state._is_valid_onnx_output("")).is_false()
