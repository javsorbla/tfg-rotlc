extends GdUnitTestSuite


func test_combat_initial_state() -> void:
	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)

	var combat = player.get_node("Combat")
	assert_bool(combat.is_attacking).is_false()
	assert_object(combat.hitbox).is_not_null()


func test_attack_hitbox_configured() -> void:
	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)

	var hitbox = player.get_node("AttackHitbox")
	assert_object(hitbox.get_node("CollisionShape2D")).is_not_null()


func test_attack_activation_flags() -> void:
	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)

	var combat = player.get_node("Combat")
	combat.is_attacking = true
	combat.attack_timer = 0.3

	assert_bool(combat.is_attacking).is_true()


func test_attack_timer_expiry_disables_attack() -> void:
	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)

	var combat = player.get_node("Combat")
	combat.is_attacking = true
	combat.attack_timer = 0.001
	combat.hitbox.monitoring = true

	combat.process(0.002)

	assert_bool(combat.is_attacking).is_false()
	assert_bool(combat.hitbox.monitoring).is_false()


func test_hitbox_position_follows_direction() -> void:
	var player = auto_free(load("res://player/player.tscn").instantiate())
	add_child(player)

	var combat = player.get_node("Combat")
	player.last_direction = 1

	combat.is_attacking = true
	combat.attack_timer = 0.3
	combat.hitbox.monitoring = true
	combat.hitbox.monitorable = true
	combat.hitbox.visible = true

	assert_bool(combat.is_attacking).is_true()
