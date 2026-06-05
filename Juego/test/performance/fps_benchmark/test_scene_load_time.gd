extends GdUnitTestSuite


func test_scene_instantiation_time_fast() -> void:
	var scenes = [
		"res://scenes/Tutorial.tscn",
		"res://scenes/CamposDeZafiro.tscn",
	]

	for scene_path in scenes:
		var start = Time.get_ticks_usec()
		var scene = load(scene_path)
		var instance = auto_free(scene.instantiate())
		add_child(instance)
		var elapsed = Time.get_ticks_usec() - start

		assert_float(elapsed / 1000.0).is_less(2000.0)


func test_multiple_player_instantiations() -> void:
	var scene = load("res://player/player.tscn")

	var start = Time.get_ticks_usec()
	for i in range(10):
		var player = auto_free(scene.instantiate())
		add_child(player)
	var elapsed = Time.get_ticks_usec() - start

	assert_float(elapsed / 1000000.0).is_less(5.0)


func test_hud_instantiation() -> void:
	var start = Time.get_ticks_usec()
	var hud = auto_free(load("res://ui/hud.tscn").instantiate())
	add_child(hud)
	var elapsed = Time.get_ticks_usec() - start

	assert_float(elapsed / 1000.0).is_less(1000.0)


func test_main_menu_instantiation() -> void:
	var start = Time.get_ticks_usec()
	var menu = auto_free(load("res://ui/menus/main_menu/main_menu.tscn").instantiate())
	add_child(menu)
	var elapsed = Time.get_ticks_usec() - start

	assert_float(elapsed / 1000.0).is_less(1500.0)

