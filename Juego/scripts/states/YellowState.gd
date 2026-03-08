class_name YellowState
extends ColorState

var is_shielding = false

func enter():
	player.speed_multiplier = 1.0
	player.damage_multiplier = 1.0

func process(delta):
	# El escudo se activa manteniendo el botón
	if Input.is_action_pressed("power_yellow"):
		is_shielding = true
		player.speed_multiplier = 0.0  # no puede moverse con escudo activo
		player.hurtbox.monitorable = false  # invulnerable
	else:
		is_shielding = false
		player.speed_multiplier = 1.0
		if not player.health.is_invincible:
			player.hurtbox.monitorable = true

func exit():
	is_shielding = false
	player.speed_multiplier = 1.0
	if not player.health.is_invincible:
		player.hurtbox.monitorable = true
