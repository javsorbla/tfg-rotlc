extends Node2D

const UMBRA_SCENE := preload("res://enemies/bosses/umbra/Umbra.tscn")
const CAMPOS_SCENE := "res://scenes/CamposDeZafiro.tscn"

@export var spawn_umbra_in_level := true
@export var umbra_spawn_position := Vector2(1320, -30)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GameState.current_level = 1
	if spawn_umbra_in_level:
		_spawn_umbra_if_missing()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_key_pressed(KEY_F7):
		GameState.coming_from_transition = true
		get_tree().call_deferred("change_scene_to_file", CAMPOS_SCENE)


func _spawn_umbra_if_missing() -> void:
	if get_tree().get_first_node_in_group("umbra_boss"):
		return

	var umbra = UMBRA_SCENE.instantiate()
	add_child(umbra)
	umbra.global_position = umbra_spawn_position
	if umbra.has_method("activate"):
		umbra.activate()


func _on_final_body_entered(body) -> void:
	if body is CharacterBody2D:
		GameState.coming_from_transition = true
		get_tree().call_deferred("change_scene_to_file", CAMPOS_SCENE)
