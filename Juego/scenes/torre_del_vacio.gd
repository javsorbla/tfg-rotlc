extends Node2D

func _enter_tree() -> void:
	GameState.current_level = 4
	GameState.current_level_path = "res://scenes/TorreDelVacio.tscn"


func _ready() -> void:
	if GameState.has_method("auto_unlock_power_for_level"):
		GameState.auto_unlock_power_for_level()
