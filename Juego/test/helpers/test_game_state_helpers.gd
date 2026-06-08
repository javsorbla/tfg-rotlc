extends GdUnitTestSuite


var _game_state: Node


func before_test() -> void:
	_game_state = auto_free(load("res://scripts/GameState.gd").new())
	get_tree().root.add_child(_game_state)


func test_make_boss_room_key_format() -> void:
	var key = _game_state.make_boss_room_key("res://scenes/CamposDeZafiro.tscn", "BossArena")
	assert_str(key).is_equal("res://scenes/CamposDeZafiro.tscn::BossArena")


func test_level_order_contains_all_scenes() -> void:
	var order = _game_state.LEVEL_ORDER
	assert_int(order.size()).is_equal(4)
	assert_bool(order[0].contains("Tutorial")).is_true()
	assert_bool(order[1].contains("CamposDeZafiro")).is_true()
	assert_bool(order[2].contains("Montañas")).is_true()
	assert_bool(order[3].contains("CostaAmbar")).is_true()


func test_save_data_version_constant() -> void:
	assert_int(_game_state.SAVE_DATA_VERSION).is_equal(1)


func test_umbra_base_model_zip_path_format() -> void:
	assert_bool(_game_state.UMBRA_BASE_MODEL_ZIP_PATH.ends_with(".zip")).is_true()
	assert_bool(_game_state.UMBRA_BASE_MODEL_ZIP_PATH.contains("models")).is_true()


func test_umbra_progress_default_metrics() -> void:
	var result = _game_state.umbra_progress.get("player_metrics", {})
	assert_bool(result.has("avg_distance")).is_true()
	assert_bool(result.has("dash_frequency")).is_true()
	assert_bool(result.has("attack_frequency")).is_true()
	assert_bool(result.has("jump_frequency")).is_true()
	assert_bool(result.has("preferred_side")).is_true()
	assert_bool(result.has("air_time_ratio")).is_true()
	assert_bool(result.has("close_range_ratio")).is_true()
	assert_bool(result.has("low_health_ratio")).is_true()
	assert_bool(result.has("power_usage_frequency")).is_true()
	assert_int(result.keys().size()).is_equal(15)
