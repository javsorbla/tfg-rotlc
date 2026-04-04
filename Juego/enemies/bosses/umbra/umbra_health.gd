extends Node

@onready var umbra = get_parent()
@onready var hurtbox: Area2D = umbra.get_node("Hurtbox")


func setup() -> void:
	hurtbox.set_deferred("monitorable", true)
	if not hurtbox.area_entered.is_connected(_on_hurtbox_area_entered):
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)


func process_timers(delta: float) -> void:
	if umbra.invincibility_timer > 0.0:
		umbra.invincibility_timer -= delta
		if umbra.invincibility_timer <= 0.0:
			umbra.is_invincible = false
			hurtbox.set_deferred("monitorable", true)


func take_damage(amount: int) -> void:
	if umbra.is_invincible:
		return

	umbra.current_health -= amount
	umbra.is_invincible = true
	umbra.invincibility_timer = umbra.INVINCIBILITY_DURATION
	hurtbox.set_deferred("monitorable", false)
	if umbra.current_health <= 0:
		umbra.die()


func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_hitbox"):
		var attacker := area.get_parent()

		if attacker and attacker.is_in_group("player") and attacker.get_node_or_null("Combat") != null:
			return

		var damage := 1
		if attacker and attacker.has_method("get") and attacker.is_in_group("player"):
			var attacker_multiplier = float(attacker.get("damage_multiplier"))
			damage = maxi(1, int(round(attacker_multiplier)))

		take_damage(damage)
