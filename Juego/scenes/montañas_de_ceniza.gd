extends Node2D

const COSTA_SCENE := "res://scenes/CostaAmbar.tscn"
const PAUSE_MENU_LAYER_SCENE := preload("res://ui/menus/windows/pause_menu_layer.tscn")
const DEATH_SCREEN_SCENE := preload("res://ui/menus/windows/death_screen.tscn")

@onready var tilemap = $Nivel 
@onready var enemigos_emboscada = [
	$Enemigos/NucleoInestable2,
	$Enemigos/NucleoInestable3
]

var bloques_a_destruir = [
	Vector2i(300, 35), 
	Vector2i(300, 36),
	Vector2i(300, 37)
] 

var bloques_a_crear = [
	Vector2i(273, 35), 
	Vector2i(273, 36),
	Vector2i(273, 37)
]
var id_tileset = 1 
var coordenadas_imagen = Vector2i(2, 1) 


func _ready() -> void:
	GameState.current_level = 2
	GameState.current_level_path = "res://scenes/MontañasDeCeniza.tscn"
	
	if GameState.has_method("auto_unlock_power_for_level"):
		GameState.auto_unlock_power_for_level()
	_ensure_pause_menu_layer()
	_ensure_death_screen()
	call_deferred("_wire_player_death")
	call_deferred("_mover_player")
	GameState.level_reset.connect(reiniciar_trampa)
	reiniciar_trampa()

func _ensure_pause_menu_layer() -> void:
	if get_node_or_null("PauseMenuLayer") != null:
		return
	add_child(PAUSE_MENU_LAYER_SCENE.instantiate())

func _ensure_death_screen() -> void:
	if get_node_or_null("DeathScreenLayer/DeathScreen") != null:
		return
	var death_layer := get_node_or_null("DeathScreenLayer")
	if death_layer == null:
		death_layer = CanvasLayer.new()
		death_layer.name = "DeathScreenLayer"
		death_layer.layer = 50
		add_child(death_layer)
	var death_screen = DEATH_SCREEN_SCENE.instantiate()
	death_screen.name = "DeathScreen"
	death_screen.hide()
	death_layer.add_child(death_screen)

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

func reiniciar_trampa():
	$Timer.stop()

	for enemigo in enemigos_emboscada:
		enemigo.visible = false
		enemigo.process_mode = Node.PROCESS_MODE_DISABLED

	for posicion in bloques_a_crear:
		tilemap.erase_cell(posicion)

		
	for posicion in bloques_a_destruir:
		tilemap.set_cell(posicion, id_tileset, coordenadas_imagen)

	$TriggerSupervivencia.set_deferred("monitoring", true)


func _process(delta: float) -> void:
	pass


func _unhandled_input(event):
	if event.is_action_pressed("reiniciar_escena"):
		get_tree().reload_current_scene()


func _on_trigger_supervivencia_body_entered(body):
	if body.name == "Player":
		$Timer.start() 
		
		for posicion in bloques_a_crear:
			tilemap.set_cell(posicion, id_tileset, coordenadas_imagen)
		
		for enemigo in enemigos_emboscada:
			enemigo.visible = true
			enemigo.process_mode = Node.PROCESS_MODE_INHERIT
			

		$TriggerSupervivencia.set_deferred("monitoring", false)


func _on_timer_timeout():
	for posicion in bloques_a_destruir:
		tilemap.erase_cell(posicion)
		
	
func _mover_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var player_health = player.get_node("Health")
		Hud.show_hud()
		Hud.update_hearts(player_health.current_health, player_health.MAX_HEALTH)
		if GameState.coming_from_transition:
			GameState.coming_from_transition = false
			GameState.checkpoint_activated = false
			player.global_position = Vector2(-78, 18)
		elif GameState.checkpoint_activated:
			player.global_position = GameState.spawn_position
		else:
			player.global_position = Vector2(-78, 18)
	
func _on_final_body_entered(body) -> void:
	if body is CharacterBody2D:
		GameState.coming_from_transition = true
		ProjectMusicController.stop()
		get_tree().call_deferred("change_scene_to_file", COSTA_SCENE)

func _on_player_died(_owner: Node) -> void:
	var death_screen = get_node_or_null("DeathScreenLayer/DeathScreen")
	if death_screen != null and death_screen.has_method("show"):
		death_screen.call_deferred("show")
