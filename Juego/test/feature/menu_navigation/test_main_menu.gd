extends GdUnitTestSuite


var _gs: Node


func before_test() -> void:
	_gs = get_node("/root/GameState")
	_gs.reset_for_new_game()
	_gs.current_level = 0


func test_continue_button_disabled_when_no_save() -> void:
	var menu = auto_free(load("res://ui/menus/main_menu/main_menu.tscn").instantiate())
	add_child(menu)
	await_idle_frame()

	var continue_btn = menu.find_child("ContinueButton", true, false)
	assert_object(continue_btn).is_not_null()
	assert_bool(continue_btn.disabled).is_true()


func test_new_game_shows_confirmation() -> void:
	var menu = auto_free(load("res://ui/menus/main_menu/main_menu.tscn").instantiate())
	add_child(menu)

	menu._on_new_game_button_pressed()

	var confirm = menu.get_node_or_null("NewGameConfirmation")
	assert_object(confirm).is_not_null()


func test_main_menu_has_all_essential_buttons() -> void:
	var menu = auto_free(load("res://ui/menus/main_menu/main_menu.tscn").instantiate())
	add_child(menu)

	var continue_btn = menu.find_child("ContinueButton", true, false)
	var new_game_btn = menu.find_child("NewGameButton", true, false)
	var leaderboard_btn = menu.find_child("LeaderboardButton", true, false)

	assert_object(continue_btn).is_not_null()
	assert_object(new_game_btn).is_not_null()
	assert_object(leaderboard_btn).is_not_null()


func test_continue_enabled_when_save_exists() -> void:
	_gs.current_level = 2
	_gs.current_level_path = "res://scenes/MontañasDeCeniza.tscn"
	_gs.save_game("test")

	var menu = auto_free(load("res://ui/menus/main_menu/main_menu.tscn").instantiate())
	add_child(menu)
	await_idle_frame()

	var continue_btn = menu.find_child("ContinueButton", true, false)
	assert_bool(continue_btn.disabled).is_false()


func test_menu_progress_reflects_current_level() -> void:
	var menu = auto_free(load("res://ui/menus/main_menu/main_menu.tscn").instantiate())
	add_child(menu)

	menu.max_level = 5
	_gs.current_level = 2

	var progress = menu._resolve_progress()
	assert_float(progress).is_equal_approx(0.4, 0.01)
