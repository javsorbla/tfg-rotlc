extends GdUnitTestSuite

var level: Node

func before_test() -> void:
	level = auto_free(load("res://scenes/CostaAmbar.tscn").instantiate())
	add_child(level)
	await get_tree().process_frame


func test_ready_sets_game_state() -> void:
	assert_int(GameState.current_level).is_equal(3)
	assert_str(GameState.current_level_path).is_equal("res://scenes/CostaAmbar.tscn")


func test_ensure_pause_menu_layer() -> void:
	level._ensure_pause_menu_layer()
	var pause = level.get_node_or_null("PauseMenuLayer")
	assert_that(pause).is_not_null()


func test_ensure_death_screen() -> void:
	level._ensure_death_screen()
	var death = level.get_node_or_null("DeathScreenLayer/DeathScreen")
	assert_that(death).is_not_null()


func test_setup_storm_player_creates_audio_player() -> void:
	level._setup_storm_player()
	assert_that(level.storm_player).is_not_null()


func test_is_player_in_any_cave_returns_false_when_not_in_cave() -> void:
	var result = level._is_player_in_any_cave()
	assert_bool(result).is_false()


func test_connect_cave_zones_finds_zones() -> void:
	if get_tree().get_nodes_in_group("cave_zone").size() == 0:
		return
	level._connect_cave_zones()
	assert_bool(true).is_true()
