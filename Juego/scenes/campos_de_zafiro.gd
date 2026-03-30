extends Node2D

const UMBRA_SCENE := preload("res://enemies/bosses/umbra/Umbra.tscn")
const TUTORIAL_SCENE := "res://scenes/Tutorial.tscn"

@export var spawn_umbra_in_level := true
@export var umbra_spawn_position := Vector2(210, -35)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GameState.current_level = 2
	if spawn_umbra_in_level:
		_spawn_umbra_if_missing()
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
	if Input.is_key_pressed(KEY_F6):
		GameState.coming_from_transition = false
		GameState.checkpoint_activated = false
		get_tree().call_deferred("change_scene_to_file", TUTORIAL_SCENE)


func _spawn_umbra_if_missing() -> void:
	if get_tree().get_first_node_in_group("umbra_boss"):
		return

	var umbra = UMBRA_SCENE.instantiate()
	add_child(umbra)
	umbra.global_position = umbra_spawn_position
	if umbra.has_method("activate"):
		umbra.activate()
