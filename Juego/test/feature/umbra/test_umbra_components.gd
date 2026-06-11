extends GdUnitTestSuite

var boss: Node2D

func before_test() -> void:
	boss = auto_free(load("res://enemies/bosses/umbra/Umbra.tscn").instantiate())
	add_child(boss)
	boss.is_active = true


func test_health_setup_connects_signals() -> void:
	var health = boss.health
	health.setup()
	assert_bool(boss.hurtbox.area_entered.is_connected(health._on_hurtbox_area_entered)).is_true()


func test_health_take_damage_reduces_health() -> void:
	boss.current_health = 3
	boss.health.take_damage(1)
	assert_int(boss.current_health).is_equal(2)


func test_health_invincibility_after_damage() -> void:
	boss.health.take_damage(1)
	assert_bool(boss.is_invincible).is_true()
	assert_bool(boss.invincibility_timer > 0).is_true()


func test_health_damage_blocked_when_invincible() -> void:
	boss.is_invincible = true
	boss.current_health = 3
	boss.health.take_damage(1)
	assert_int(boss.current_health).is_equal(3)


func test_health_triggers_die_at_zero() -> void:
	boss.current_health = 1
	boss.health.take_damage(1)
	assert_bool(boss._is_dying).is_true()


func test_combat_setup_disables_hitbox() -> void:
	var combat = boss.combat
	combat.setup()
	assert_bool(boss.attack_hitbox.monitoring).is_false()


func test_combat_cancel_attack_state() -> void:
	boss.is_attacking = true
	boss.combat.cancel_attack_state()
	assert_bool(boss.is_attacking).is_false()


func test_colors_get_speed_cyan_power() -> void:
	boss.current_power = "cyan"
	boss._power_active = true
	var speed = boss.color_manager.get_speed()
	assert_float(speed).is_equal(boss.SPEED * boss.POWER_SPEED_MULTIPLIER)


func test_colors_get_speed_normal() -> void:
	boss.current_power = "cyan"
	boss._power_active = false
	var speed = boss.color_manager.get_speed()
	assert_float(speed).is_equal(boss.SPEED)


func test_colors_get_attack_damage_red_power() -> void:
	boss.current_power = "red"
	boss._power_active = true
	var dmg = boss.color_manager.get_attack_damage()
	assert_int(dmg).is_equal(boss.DAMAGE * boss.POWER_DAMAGE_MULTIPLIER)


func test_colors_get_attack_damage_normal() -> void:
	boss.current_power = "red"
	boss._power_active = false
	var dmg = boss.color_manager.get_attack_damage()
	assert_int(dmg).is_equal(boss.DAMAGE)


func test_colors_yellow_power_makes_invincible() -> void:
	boss.current_power = "yellow"
	boss._power_active = true
	boss.color_manager.handle_power()
	assert_bool(boss.is_invincible).is_true()


func test_colors_handle_power_activates_on_request() -> void:
	boss.current_power = "cyan"
	boss._power_cooldown_timer = 0.0
	boss._power_active = false
	boss.ai_should_use_power = true

	boss.color_manager.handle_power()

	assert_bool(boss._power_active).is_true()
	assert_bool(boss._power_timer > 0.0).is_true()
