extends Node2D

const TUTORIAL_SCENE := "res://scenes/Tutorial.tscn"


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GameState.current_level = 1
	call_deferred("_mover_player")

func _mover_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		if GameState.coming_from_transition:
			GameState.coming_from_transition = false
			GameState.checkpoint_activated = false
			player.global_position = Vector2(6728, -770)
		elif GameState.checkpoint_activated:
			player.global_position = GameState.spawn_position
		else:
			player.global_position = Vector2(6728, -770)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_key_pressed(KEY_F6):
		GameState.coming_from_transition = false
		GameState.checkpoint_activated = false
		get_tree().call_deferred("change_scene_to_file", TUTORIAL_SCENE)
