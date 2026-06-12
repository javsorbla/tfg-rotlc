extends GdUnitTestSuite

var boss: Node2D


func before_test() -> void:
	boss = auto_free(load("res://enemies/bosses/coloso_ceniza/ColosoCeniza.tscn").instantiate())
	add_child(boss)


func test_constants() -> void:
	assert_int(boss.MAX_HEALTH).is_equal(35)
	assert_int(boss.DAMAGE).is_equal(1)


func test_initial_state() -> void:
	assert_int(boss.current_health).is_equal(35)
	assert_int(boss.current_state).is_equal(boss.State.IDLE)


func test_take_damage_reduces_health() -> void:
	boss.take_damage(10)
	assert_int(boss.current_health).is_equal(25)


func test_damage_reduces_health_when_dead() -> void:
	boss.current_state = boss.State.DEAD
	boss.take_damage(10)
	assert_int(boss.current_health).is_equal(25)


func test_idle_moves_towards_player() -> void:
	boss.is_active = true
	boss.room_left_limit = 0
	boss.room_right_limit = 1000
	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)
	boss.player = player
	player.global_position = boss.global_position + Vector2(100, 0)
	boss.current_state = boss.State.IDLE
	var start_x = boss.global_position.x

	boss._physics_process(1.0)

	assert_bool(boss.global_position.x > start_x).is_true()


func test_idle_transitions_to_punch_when_player_close() -> void:
	boss.is_active = true
	boss.room_left_limit = 0
	boss.room_right_limit = 1000
	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)
	boss.player = player
	player.global_position = boss.global_position + Vector2(50, 0)
	boss.current_state = boss.State.IDLE
	boss.punch_timer = 0.0
	boss.recover_timer = 0.0
	boss.spike_timer = 10.0
	boss.lava_timer = 10.0
	boss.sprite.play("walk")

	boss._physics_process(0.016)

	assert_int(boss.current_state).is_equal(boss.State.PUNCH)
