class_name RedState
extends ColorState

func enter():
	player.speed_multiplier = 1.0
	player.damage_multiplier = 2.0

func exit():
	player.damage_multiplier = 1.0
