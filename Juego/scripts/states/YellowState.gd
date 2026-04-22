class_name YellowState
extends ColorState

var is_shielding = false

func enter():
	player.speed_multiplier = 0.0
	player.is_shielding = true
	player.can_jump = false
	player.can_dash = false
	player.can_attack = false

func exit():
	player.speed_multiplier = 1.0
	player.is_shielding = false
	player.can_jump = true
	player.can_dash = true
	player.can_attack = true

func process(delta):
	pass
