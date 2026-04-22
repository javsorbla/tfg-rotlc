extends Node2D

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
	Hud.show_hud()
	GameState.current_level = 2
	call_deferred("_mover_player")
	
	for enemigo in enemigos_emboscada:
		enemigo.visible = false
		enemigo.process_mode = Node.PROCESS_MODE_DISABLED

	for posicion in bloques_a_crear:
		tilemap.erase_cell(posicion)


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
			
		
		$TriggerSupervivencia.queue_free()


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
	
