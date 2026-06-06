extends GdUnitTestSuite


func test_neutral_state_applies_default_stats() -> void:
	var state = NeutralState.new()
	var player = auto_free(load("res://player/player.tscn").instantiate())
	player.speed_multiplier = 0.0
	player.damage_multiplier = 0.0

	state.init(player)
	state.enter()

	assert_float(player.speed_multiplier).is_equal(1.0)
	assert_float(player.damage_multiplier).is_equal(1.0)


func test_cyan_state_increases_speed() -> void:
	var state = CyanState.new()
	var player = auto_free(load("res://player/player.tscn").instantiate())
	player.speed_multiplier = 1.0
	player.damage_multiplier = 1.0

	state.init(player)
	state.enter()

	assert_float(player.speed_multiplier).is_equal(1.5)
	assert_float(player.damage_multiplier).is_equal(1.0)


func test_cyan_exit_resets_speed() -> void:
	var state = CyanState.new()
	var player = auto_free(load("res://player/player.tscn").instantiate())
	player.speed_multiplier = 1.5

	state.init(player)
	state.exit()

	assert_float(player.speed_multiplier).is_equal(1.0)


func test_red_state_increases_damage() -> void:
	var state = RedState.new()
	var player = auto_free(load("res://player/player.tscn").instantiate())
	player.speed_multiplier = 1.0
	player.damage_multiplier = 1.0

	state.init(player)
	state.enter()

	assert_float(player.damage_multiplier).is_equal(2.0)


func test_red_exit_resets_damage() -> void:
	var state = RedState.new()
	var player = auto_free(load("res://player/player.tscn").instantiate())
	player.damage_multiplier = 2.0

	state.init(player)
	state.exit()

	assert_float(player.damage_multiplier).is_equal(1.0)


func test_yellow_state_disables_movement_and_attack() -> void:
	var state = YellowState.new()
	var player = auto_free(load("res://player/player.tscn").instantiate())
	player.speed_multiplier = 1.0
	player.is_shielding = false
	player.can_jump = true
	player.can_dash = true
	player.can_attack = true

	state.init(player)
	state.enter()

	assert_float(player.speed_multiplier).is_equal(0.0)
	assert_bool(player.is_shielding).is_true()
	assert_bool(player.can_jump).is_false()
	assert_bool(player.can_attack).is_false()


func test_yellow_exit_restores_abilities() -> void:
	var state = YellowState.new()
	var player = auto_free(load("res://player/player.tscn").instantiate())
	player.speed_multiplier = 0.0
	player.is_shielding = true
	player.can_jump = false
	player.can_dash = false
	player.can_attack = false

	state.init(player)
	state.exit()

	assert_float(player.speed_multiplier).is_equal(1.0)
	assert_bool(player.is_shielding).is_false()
	assert_bool(player.can_jump).is_true()
	assert_bool(player.can_attack).is_true()


func test_color_state_init_sets_player_ref() -> void:
	var state = ColorState.new()
	var player = auto_free(load("res://player/player.tscn").instantiate())

	state.init(player)
	assert_object(state.player).is_not_null()


func test_color_state_default_methods_no_error() -> void:
	var state = ColorState.new()
	var player = auto_free(load("res://player/player.tscn").instantiate())
	state.init(player)

	state.enter()
	state.exit()
	state.process(0.016)
