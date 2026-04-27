extends Node2D

const PAUSE_MENU_LAYER_SCENE := preload("res://ui/menus/windows/pause_menu_layer.tscn")
const DEATH_SCREEN_SCENE := preload("res://ui/menus/windows/death_screen.tscn")


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GameState.current_level = 1
	GameState.current_level_path = "res://scenes/CamposDeZafiro.tscn"
	_ensure_pause_menu_layer()
	_ensure_death_screen()
	Hud.show_hud()
	call_deferred("_wire_player_death")
	call_deferred("_mover_player")

func _ensure_pause_menu_layer() -> void:
	if get_node_or_null("PauseMenuLayer") != null:
		return
	add_child(PAUSE_MENU_LAYER_SCENE.instantiate())

func _ensure_death_screen() -> void:
	if get_node_or_null("DeathScreen") != null:
		return
	var death_screen = DEATH_SCREEN_SCENE.instantiate()
	death_screen.name = "DeathScreen"
	death_screen.hide()
	add_child(death_screen)

func _wire_player_death() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var health = player.get_node_or_null("Health")
	if health == null:
		return
	health.auto_reset = false
	if health.has_method("set_death_callback"):
		health.set_death_callback(Callable(self, "_on_player_died"))
	elif health.has_signal("died") and not health.died.is_connected(_on_player_died):
		health.died.connect(_on_player_died)

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

func _on_player_died(_owner: Node) -> void:
	var death_screen = get_node_or_null("DeathScreen")
	if death_screen != null and death_screen.has_method("show"):
		death_screen.call_deferred("show")
