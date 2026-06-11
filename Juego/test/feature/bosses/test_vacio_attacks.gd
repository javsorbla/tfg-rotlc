extends GdUnitTestSuite

var boss: Node2D

func before_test() -> void:
	boss = auto_free(load("res://enemies/bosses/vacio/Vacio.tscn").instantiate())
	add_child(boss)
	boss.is_active = true


func test_initial_state() -> void:
	assert_int(boss.current_state).is_equal(boss.State.IDLE)
	assert_int(boss.current_health).is_equal(60)


func test_chase_transitions_to_attack() -> void:
	var player = auto_free(load("res://player/player.tscn").instantiate())
	player.add_to_group("player")
	add_child(player)
	boss.player = player
	boss._enter_state(boss.State.CHASE)
	boss.action_timer = 0.0
	boss.bolsa_ataques = [boss.State.EXPAND, boss.State.AOE, boss.State.SPIKE_RAIN, boss.State.SHOOT, boss.State.VANISH]

	boss._physics_process(0.016)

	assert_bool(boss.current_state != boss.State.CHASE).is_true()


func test_attack_queue_does_not_repeat_until_all_used() -> void:
	var attacks_used: Array = []
	boss.bolsa_ataques = [boss.State.EXPAND, boss.State.AOE, boss.State.SPIKE_RAIN, boss.State.SHOOT, boss.State.VANISH]
	for i in range(5):
		var next_attack = boss._sacar_ataque_de_bolsa()
		assert_bool(attacks_used.has(next_attack)).is_false()
		attacks_used.append(next_attack)
	assert_bool(boss.bolsa_ataques.is_empty()).is_true()

	var refilled = boss._sacar_ataque_de_bolsa()
	assert_bool(attacks_used.has(refilled)).is_true()


func test_spike_rain_spawns_spikes() -> void:
	boss.escena_pincho = load("res://enemies/bosses/vacio/pincho_vacio.tscn")
	boss._enter_state(boss.State.SPIKE_RAIN)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_bool(boss.get_parent().get_child_count() > 0).is_true()


func test_take_damage_reduces_health() -> void:
	boss.take_damage(5)
	assert_int(boss.current_health).is_equal(55)


func test_take_damage_blocked_when_dead() -> void:
	boss.current_state = boss.State.DEAD
	boss.take_damage(5)
	assert_int(boss.current_health).is_equal(60)


func test_take_damage_blocked_when_dying() -> void:
	boss.current_state = boss.State.DYING
	boss.take_damage(5)
	assert_int(boss.current_health).is_equal(60)


func test_take_damage_blocked_when_invulnerable() -> void:
	boss.is_invulnerable = true
	boss.take_damage(5)
	assert_int(boss.current_health).is_equal(60)


func test_take_damage_blocked_during_expand() -> void:
	boss._enter_state(boss.State.EXPAND)
	boss.take_damage(5)
	assert_int(boss.current_health).is_equal(60)


func test_phase_transition_at_20_hp() -> void:
	boss.current_health = 21
	boss.take_damage(1)
	assert_int(boss.current_state).is_equal(boss.State.PHASE_TRANSITION)
	assert_bool(boss.in_phase_2).is_false()

	boss._physics_process(2.1)
	assert_bool(boss.in_phase_2).is_true()
	assert_int(boss.current_state).is_equal(boss.State.CHASE)


func test_activate_sets_chase_state() -> void:
	boss.activate()
	assert_int(boss.current_state).is_equal(boss.State.CHASE)
	assert_bool(boss.is_active).is_true()


func test_dying_sequence() -> void:
	boss._enter_state(boss.State.DYING)
	assert_bool(boss.is_invulnerable).is_true()
	assert_int(boss.current_state).is_equal(boss.State.DYING)
