extends GdUnitTestSuite

var level: Node

func before_test() -> void:
	level = auto_free(load("res://scenes/MontañasDeCeniza.tscn").instantiate())
	add_child(level)
	await get_tree().process_frame


func test_ready_sets_game_state() -> void:
	assert_int(GameState.current_level).is_equal(2)
	assert_str(GameState.current_level_path).is_equal("res://scenes/MontañasDeCeniza.tscn")


func test_ensure_pause_menu_layer() -> void:
	level._ensure_pause_menu_layer()
	var pause = level.get_node_or_null("PauseMenuLayer")
	assert_that(pause).is_not_null()


func test_ensure_death_screen() -> void:
	level._ensure_death_screen()
	var death = level.get_node_or_null("DeathScreenLayer/DeathScreen")
	assert_that(death).is_not_null()
