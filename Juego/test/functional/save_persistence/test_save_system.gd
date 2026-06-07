extends GdUnitTestSuite


var _gs: Node


func before_test() -> void:
	_gs = get_node("/root/GameState")
	_gs.reset_for_new_game()


func test_save_game_creates_file() -> void:
	_gs.current_level = 1
	_gs.current_level_path = "res://scenes/Tutorial.tscn"
	_gs.spawn_position = Vector2(50, 100)

	var success = _gs.save_game("test_save")
	assert_bool(success).is_true()

	var save_exists = FileAccess.file_exists("user://savegame.json")
	assert_bool(save_exists).is_true()

	var file = FileAccess.open("user://savegame.json", FileAccess.READ)
	assert_object(file).is_not_null()

	if file:
		var content = file.get_as_text()
		file.close()
		assert_str(content).is_not_empty()


func test_save_and_load_restores_state() -> void:
	_gs.current_level = 2
	_gs.current_level_path = "res://scenes/CamposDeZafiro.tscn"
	_gs.spawn_position = Vector2(100, 200)
	_gs.checkpoint_activated = true
	_gs.save_game("test_restore")

	var loaded = _gs.load_game()
	assert_bool(loaded).is_true()

	assert_int(_gs.current_level).is_equal(2)
	assert_str(_gs.current_level_path).is_equal("res://scenes/CamposDeZafiro.tscn")
	assert_bool(_gs.checkpoint_activated).is_true()


func test_save_checksum_validates_integrity() -> void:
	_gs.current_level = 1
	_gs.save_game("test_checksum")

	var file = FileAccess.open("user://savegame.json", FileAccess.READ)
	var content = file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(content)
	assert_bool(parsed.has("checksum")).is_true()
	assert_bool(parsed.has("payload")).is_true()

	var payload = parsed["payload"]
	assert_float(float(payload["current_level"])).is_equal_approx(1.0, 0.001)


func test_backup_created_on_second_save() -> void:
	_gs.save_game("save1")
	_gs.save_game("save2")

	var bak_exists = FileAccess.file_exists("user://savegame.json.bak")
	assert_bool(bak_exists).is_true()


func test_reset_for_new_game_clears_all_data() -> void:
	_gs.current_level = 3
	_gs.spawn_position = Vector2(150, 250)
	_gs.checkpoint_activated = true
	_gs.umbra_progress["encounters"] = 10
	_gs.umbra_progress["wins"] = 5
	_gs.player_progress["max_health_bonus"] = 2

	_gs.reset_for_new_game()

	assert_int(_gs.current_level).is_equal(0)
	assert_bool(_gs.checkpoint_activated).is_false()
	assert_int(_gs.umbra_progress["encounters"]).is_equal(0)
	assert_int(_gs.umbra_progress["wins"]).is_equal(0)
	assert_int(_gs.player_progress["max_health_bonus"]).is_equal(0)


func test_unlock_power_persists_across_reset() -> void:
	_gs.player_progress["nickname"] = "TestPlayer"
	var result = _gs.unlock_power("cyan")
	assert_bool(result).is_true()

	_gs.reset_for_new_game()

	var unlocked = _gs.get_unlocked_powers()
	assert_bool(unlocked["cyan"]).is_false()
	assert_str(_gs.player_progress["nickname"]).is_equal("TestPlayer")


func test_has_save_returns_false_after_reset() -> void:
	_gs.save_game("test")
	assert_bool(_gs.has_save()).is_true()

	_gs.reset_for_new_game()
	assert_bool(_gs.has_save()).is_false()
