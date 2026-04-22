extends Node2D

const CAMPOS_SCENE := "res://scenes/CamposDeZafiro.tscn"
const PAUSE_MENU_LAYER_SCENE := preload("res://ui/menus/windows/pause_menu_layer.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_ensure_pause_menu_layer()
	Hud.show_hud()
	call_deferred("_mover_player")

func _ensure_pause_menu_layer() -> void:
	if get_node_or_null("PauseMenuLayer") != null:
		return
	add_child(PAUSE_MENU_LAYER_SCENE.instantiate())

func _mover_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var player_health = player.get_node("Health")
		Hud.show_hud()
		Hud.update_hearts(player_health.current_health, player_health.MAX_HEALTH)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

	GameState.current_level = 1

func _on_final_body_entered(body) -> void:
	if body is CharacterBody2D:
		GameState.coming_from_transition = true
		get_tree().call_deferred("change_scene_to_file", CAMPOS_SCENE)
