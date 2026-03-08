class_name CyanState
extends ColorState

func enter():
	player.speed_multiplier = 1.5
	player.damage_multiplier = 1.0

func exit():
	player.speed_multiplier = 1.0
