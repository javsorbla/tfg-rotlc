extends GdUnitTestSuite


func test_entrenamiento_umbra_loads() -> void:
	var entrenamiento = auto_free(load("res://enemies/bosses/umbra/EntrenamientoUmbra.tscn").instantiate())
	add_child(entrenamiento)
	assert_that(entrenamiento).is_not_null()


func test_apply_preset_config_quick() -> void:
	var entrenamiento = auto_free(load("res://enemies/bosses/umbra/EntrenamientoUmbra.tscn").instantiate())
	add_child(entrenamiento)
	entrenamiento.preset_enabled = true
	entrenamiento.training_preset = entrenamiento.TrainingPreset.QUICK

	entrenamiento._apply_preset_config()

	assert_float(entrenamiento._preset_human_ratio).is_equal(0.25)
	assert_int(entrenamiento._preset_block_size).is_equal(8)


func test_apply_preset_config_serious() -> void:
	var entrenamiento = auto_free(load("res://enemies/bosses/umbra/EntrenamientoUmbra.tscn").instantiate())
	add_child(entrenamiento)
	entrenamiento.preset_enabled = true
	entrenamiento.training_preset = entrenamiento.TrainingPreset.SERIOUS

	entrenamiento._apply_preset_config()

	assert_float(entrenamiento._preset_human_ratio).is_equal(0.50)
	assert_int(entrenamiento._preset_block_size).is_equal(10)


func test_training_power_cycle() -> void:
	var entrenamiento = auto_free(load("res://enemies/bosses/umbra/EntrenamientoUmbra.tscn").instantiate())
	add_child(entrenamiento)
	entrenamiento.training_power_mode = "cycle"
	entrenamiento._episode_index = 0

	entrenamiento._apply_training_power()
	assert_str(entrenamiento.umbra.forced_power).is_equal("cyan")

	entrenamiento._episode_index = 1
	entrenamiento._apply_training_power()
	assert_str(entrenamiento.umbra.forced_power).is_equal("red")

	entrenamiento._episode_index = 2
	entrenamiento._apply_training_power()
	assert_str(entrenamiento.umbra.forced_power).is_equal("yellow")
