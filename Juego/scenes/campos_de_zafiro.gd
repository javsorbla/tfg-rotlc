extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	call_deferred("_mover_player")

func _mover_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		if GameState.coming_from_transition:
			GameState.coming_from_transition = false
			GameState.checkpoint_activated = false
			player.global_position = Vector2(38, -7)
		elif GameState.checkpoint_activated:
			player.global_position = GameState.spawn_position
		else:
			player.global_position = Vector2(38, -7)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
