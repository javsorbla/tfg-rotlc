extends Node2D

const CAMPOS_SCENE := "res://scenes/CamposDeZafiro.tscn"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GameState.current_level = 1

func _on_final_body_entered(body) -> void:
	if body is CharacterBody2D:
		GameState.coming_from_transition = true
		get_tree().call_deferred("change_scene_to_file", CAMPOS_SCENE)
