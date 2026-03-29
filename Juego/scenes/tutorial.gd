extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_final_body_entered(body) -> void:
	if body is CharacterBody2D:
		GameState.coming_from_transition = true
		get_tree().call_deferred("change_scene_to_file", "res://scenes/CamposDeZafiro.tscn")
