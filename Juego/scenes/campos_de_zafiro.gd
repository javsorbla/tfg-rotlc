extends Node2D

const PAUSE_MENU_LAYER_SCENE := preload("res://ui/menus/windows/pause_menu_layer.tscn")


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_ensure_pause_menu_layer()
	Hud.show_hud()
	GameState.current_level = 1
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
		if GameState.coming_from_transition:
			GameState.coming_from_transition = false
			GameState.checkpoint_activated = false
			player.global_position = Vector2(38, -7)
		elif GameState.checkpoint_activated:
			player.global_position = GameState.spawn_position
		else:
			player.global_position = Vector2(38, -7)
