extends Node2D

@onready var tilemap = $Nivel 

# 1. Los enemigos de la emboscada
@onready var enemigos_emboscada = [
	$Enemigos/NucleoInestable2,
	$Enemigos/NucleoInestable3
]

# 2. La puerta que se abrirá al ganar (destruir)
var bloques_a_destruir = [
	Vector2i(300, 35), 
	Vector2i(300, 36),
	Vector2i(300, 37)
] 

# 3. La puerta que se cerrará a tu espalda (crear)
var bloques_a_crear = [
	Vector2i(273, 35), 
	Vector2i(273, 36),
	Vector2i(273, 37)
]
var id_tileset = 1 
var coordenadas_imagen = Vector2i(2, 1) 


func _ready() -> void:
	# ¡NUEVO! El nivel escucha la señal de tu jugador.
	# Cuando el jugador muera, ejecutará la función 'reiniciar_trampa'
	GameState.level_reset.connect(reiniciar_trampa)
	
	# Llamamos a la función también al empezar el nivel para prepararlo todo
	reiniciar_trampa()


# --- ¡NUEVO! FUNCIÓN QUE RESETEA SOLO LA TRAMPA ---
func reiniciar_trampa():
	$Timer.stop() # Paramos el reloj por si te moriste mientras contaba

	# 1. Volvemos a congelar a los enemigos
	for enemigo in enemigos_emboscada:
		enemigo.visible = false
		enemigo.process_mode = Node.PROCESS_MODE_DISABLED

	# 2. Borramos la puerta de entrada para dejarte pasar
	for posicion in bloques_a_crear:
		tilemap.erase_cell(posicion)
		
	# 3. Volvemos a CREAR la puerta de salida (por si moriste después de que se abriera)
	for posicion in bloques_a_destruir:
		tilemap.set_cell(posicion, id_tileset, coordenadas_imagen)

	# 4. Volvemos a encender el Trigger (usamos set_deferred por seguridad en Godot)
	$TriggerSupervivencia.set_deferred("monitoring", true)
# --------------------------------------------------


func _process(delta: float) -> void:
	pass


func _unhandled_input(event):
	if event.is_action_pressed("reiniciar_escena"):
		get_tree().reload_current_scene()


# --- CÓDIGO PARA EL TRIGGER ---
func _on_trigger_supervivencia_body_entered(body):
	if body.name == "Player":
		$Timer.start() 
		
		# CREAMOS EL MURO A LA ESPALDA
		for posicion in bloques_a_crear:
			tilemap.set_cell(posicion, id_tileset, coordenadas_imagen)
		print("🚪 ¡Muro de entrada creado! No hay escapatoria.")
		
		# DESPERTAMOS ENEMIGOS
		for enemigo in enemigos_emboscada:
			enemigo.visible = true
			enemigo.process_mode = Node.PROCESS_MODE_INHERIT
			
		print("😈 ¡Emboscada! Enemigos específicos activados.")
		
		# ¡CAMBIO IMPORTANTE! Ya no borramos el trigger con queue_free().
		# Lo apagamos temporalmente para poder volver a encenderlo si mueres.
		$TriggerSupervivencia.set_deferred("monitoring", false)


# --- CÓDIGO PARA DESTRUIR MÚLTIPLES BLOQUES ---
func _on_timer_timeout():
	for posicion in bloques_a_destruir:
		tilemap.erase_cell(posicion)
		
	print("🧱 ¡Camino abierto!")