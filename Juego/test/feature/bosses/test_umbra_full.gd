extends GdUnitTestSuite

var boss: Node2D

func before_test() -> void:
	boss = auto_free(load("res://enemies/bosses/umbra/Umbra.tscn").instantiate())
	add_child(boss)
	boss.is_active = true


func test_initial_state() -> void:
	assert_bool(boss.is_active).is_true()


func test_take_damage_delegates_to_health() -> void:
	boss.current_health = 3
	boss.take_damage(1)
	assert_int(boss.current_health).is_equal(2)


func test_die_sets_dying_state() -> void:
	boss.die()
	assert_bool(boss._is_dying).is_true()


func test_use_heuristic_moves_toward_player() -> void:
	var player = auto_free(load("res://player/player.tscn").instantiate())
	player.add_to_group("player")
	add_child(player)
	player.global_position = boss.global_position + Vector2(100, 0)

	boss._use_heuristic()
	assert_bool(boss.ai_move_direction > 0).is_true()


func test_use_heuristic_attacks_at_close_range() -> void:
	var player = auto_free(load("res://player/player.tscn").instantiate())
	player.add_to_group("player")
	add_child(player)
	player.global_position = boss.global_position + Vector2(30, 0)

	boss._use_heuristic()
	assert_bool(boss.ai_should_attack).is_true()


func test_use_heuristic_does_not_attack_far() -> void:
	var player = auto_free(load("res://player/player.tscn").instantiate())
	player.add_to_group("player")
	add_child(player)
	player.global_position = boss.global_position + Vector2(200, 0)

	boss._use_heuristic()
	assert_bool(boss.ai_should_attack).is_false()


func test_assign_power_by_level() -> void:
	boss.forced_power = "auto"
	GameState.current_level = 1
	boss._assign_power()
	assert_str(boss.current_power).is_equal("cyan")

	GameState.current_level = 2
	boss._assign_power()
	assert_str(boss.current_power).is_equal("red")

	GameState.current_level = 3
	boss._assign_power()
	assert_str(boss.current_power).is_equal("yellow")


func test_forced_power_overrides_level() -> void:
	boss.forced_power = "cyan"
	boss.current_power = "none"
	boss._assign_power()
	assert_str(boss.current_power).is_equal("cyan")


func test_handle_jump_blocked_by_cooldown() -> void:
	boss._jump_cooldown_timer = 10.0
	# Place a floor below the boss so move_and_slide sets is_on_floor()
	var floor = StaticBody2D.new()
	var collision = CollisionShape2D.new()
	collision.shape = RectangleShape2D.new()
	collision.shape.size = Vector2(2000, 20)
	floor.add_child(collision)
	add_child(floor)
	floor.global_position = boss.global_position + Vector2(0, 30)
	boss.global_position.y += 25
	boss.move_and_slide()

	boss._handle_jump(true)
	assert_float(boss.velocity.y).is_equal(0.0)


func test_dash_starts_on_request() -> void:
	boss.dash_cooldown_timer = 0.0
	boss.ai_move_direction = 1

	boss._handle_dash(1.0, true)
	assert_bool(boss.is_dashing).is_true()


func test_dash_blocked_by_cooldown() -> void:
	boss.dash_cooldown_timer = 10.0

	boss._handle_dash(1.0, true)
	assert_bool(boss.is_dashing).is_false()


func test_apply_level_balance_scales_cooldowns() -> void:
	boss.apply_level_balance = true
	GameState.current_level = 1
	boss._apply_level_balance()
	assert_bool(boss._attack_cooldown_runtime > boss.ATTACK_COOLDOWN).is_true()


func test_activate_enables_boss() -> void:
	boss.is_active = false
	boss.activate()
	assert_bool(boss.is_active).is_true()


func test_set_ai_action_updates_movement() -> void:
	var player = auto_free(load("res://player/player.tscn").instantiate())
	player.add_to_group("player")
	add_child(player)
	boss.set_ai_action({"move": 2, "jump": 0, "attack": 0, "dash": 0, "power": 0})
	assert_bool(boss.ai_move_direction != 0).is_true()
