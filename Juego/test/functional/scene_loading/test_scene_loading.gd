extends GdUnitTestSuite


func test_tutorial_scene_loads() -> void:
	var scene = load("res://scenes/Tutorial.tscn")
	assert_object(scene).is_not_null()

	var instance = auto_free(scene.instantiate())
	assert_object(instance).is_not_null()


func test_campos_zafiro_scene_loads() -> void:
	var scene = load("res://scenes/CamposDeZafiro.tscn")
	assert_object(scene).is_not_null()

	var instance = auto_free(scene.instantiate())
	assert_object(instance).is_not_null()


func test_montanas_ceniza_scene_loads() -> void:
	var scene = load("res://scenes/MontañasDeCeniza.tscn")
	assert_object(scene).is_not_null()

	var instance = auto_free(scene.instantiate())
	assert_object(instance).is_not_null()


func test_costa_ambar_scene_loads() -> void:
	var scene = load("res://scenes/CostaAmbar.tscn")
	assert_object(scene).is_not_null()

	var instance = auto_free(scene.instantiate())
	assert_object(instance).is_not_null()


func test_torre_vacio_scene_loads() -> void:
	var scene = load("res://scenes/TorreDelVacio.tscn")
	assert_object(scene).is_not_null()

	var instance = auto_free(scene.instantiate())
	assert_object(instance).is_not_null()


func test_all_level_scenes_are_loadable() -> void:
	var level_order = [
		"res://scenes/Tutorial.tscn",
		"res://scenes/CamposDeZafiro.tscn",
		"res://scenes/MontañasDeCeniza.tscn",
		"res://scenes/CostaAmbar.tscn",
	]

	for level_path in level_order:
		var scene = load(level_path)
		assert_object(scene).is_not_null()


func test_scene_transition_from_tutorial_to_campos() -> void:
	var gs = auto_free(load("res://scripts/GameState.gd").new())
	get_tree().root.add_child(gs)

	gs.current_level = 0
	var next = gs.get_next_level_scene()
	assert_str(next).is_equal("res://scenes/CamposDeZafiro.tscn")


func test_get_next_level_scene_returns_empty_at_max() -> void:
	var gs = auto_free(load("res://scripts/GameState.gd").new())
	get_tree().root.add_child(gs)

	gs.current_level = 3
	var next = gs.get_next_level_scene()
	assert_str(next).is_empty()
