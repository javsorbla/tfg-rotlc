extends GdUnitTestSuite


func test_scrolling_credits_loads() -> void:
	var credits = auto_free(load("res://ui/menus/credits/scrolling_credits.tscn").instantiate())
	add_child(credits)
	assert_that(credits).is_not_null()


func test_scrolling_credits_has_exit_hint() -> void:
	var credits = auto_free(load("res://ui/menus/credits/scrolling_credits.tscn").instantiate())
	add_child(credits)
	assert_that(credits.exit_hint_label).is_not_null()


func test_scrolling_credits_auto_scroll_pauses() -> void:
	var credits = auto_free(load("res://ui/menus/credits/scrolling_credits.tscn").instantiate())
	add_child(credits)
	credits.scroll_paused = true
	assert_bool(credits.scroll_paused).is_true()


func test_scrolling_credits_is_end_reached_starts_false() -> void:
	var credits = auto_free(load("res://ui/menus/credits/scrolling_credits.tscn").instantiate())
	add_child(credits)
	assert_bool(credits.is_end_reached()).is_false()
