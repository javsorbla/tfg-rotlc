extends GdUnitTestSuite


func test_entrenamiento_umbra_loads() -> void:
	var scene := load("res://enemies/bosses/umbra/EntrenamientoUmbra.tscn")
	var entrenamiento = auto_free(scene.instantiate())
	assert_that(entrenamiento.get_node("Umbra")).is_not_null()
	assert_that(entrenamiento.get_node("Player")).is_not_null()


func test_apply_preset_config_quick() -> void:
	var scene := load("res://enemies/bosses/umbra/EntrenamientoUmbra.tscn")
	var entrenamiento = auto_free(scene.instantiate())

	entrenamiento.preset_enabled = true
	entrenamiento.training_preset = entrenamiento.TrainingPreset.QUICK
	entrenamiento._apply_preset_config()

	assert_float(entrenamiento._preset_human_ratio).is_equal(0.25)
	assert_int(entrenamiento._preset_block_size).is_equal(8)


func test_apply_preset_config_serious() -> void:
	var scene := load("res://enemies/bosses/umbra/EntrenamientoUmbra.tscn")
	var entrenamiento = auto_free(scene.instantiate())

	entrenamiento.preset_enabled = true
	entrenamiento.training_preset = entrenamiento.TrainingPreset.SERIOUS
	entrenamiento._apply_preset_config()

	assert_float(entrenamiento._preset_human_ratio).is_equal(0.50)
	assert_int(entrenamiento._preset_block_size).is_equal(10)


func test_training_power_cycle() -> void:
	var scene := load("res://enemies/bosses/umbra/EntrenamientoUmbra.tscn")
	var entrenamiento = auto_free(scene.instantiate())
	var umbra = entrenamiento.get_node("Umbra")

	umbra.forced_power = "cyan"
	assert_str(umbra.forced_power).is_equal("cyan")

	umbra.forced_power = "red"
	assert_str(umbra.forced_power).is_equal("red")

	umbra.forced_power = "yellow"
	assert_str(umbra.forced_power).is_equal("yellow")
