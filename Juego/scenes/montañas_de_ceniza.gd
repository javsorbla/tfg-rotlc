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
	# Congelamos a los enemigos
	for enemigo in enemigos_emboscada:
		enemigo.visible = false
		enemigo.process_mode = Node.PROCESS_MODE_DISABLED
		
	# --- ¡NUEVO! ---
	# Borramos los bloques de la entrada que dibujaste en el editor 
	# para que el camino esté abierto al empezar a jugar.
	for posicion in bloques_a_crear:
		tilemap.erase_cell(posicion)
	# ---------------


func _process(delta: float) -> void:
	pass


# --- CÓDIGO PARA REINICIAR LA ESCENA ---
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
		
		$TriggerSupervivencia.queue_free()


# --- CÓDIGO PARA DESTRUIR MÚLTIPLES BLOQUES ---
func _on_timer_timeout():
	for posicion in bloques_a_destruir:
		tilemap.erase_cell(posicion)
		
	print("🧱 ¡Camino abierto!")