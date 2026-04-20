extends Node2D

@onready var tilemap = $Nivel 

# 1. Guardamos una lista con la ruta exacta de los enemigos que queramos.
# Fíjate que usamos $Enemigos/NombreDelEnemigo para llegar a ellos.
@onready var enemigos_emboscada = [
	$Enemigos/NucleoInestable2,
	$Enemigos/NucleoInestable3
]

var bloques_a_destruir = [
	Vector2i(300, 35), 
	Vector2i(300, 36),
	Vector2i(300, 37)
] 


func _ready() -> void:
	# 2. Usamos un bucle para congelar SOLO a los de la lista
	for enemigo in enemigos_emboscada:
		enemigo.visible = false
		enemigo.process_mode = Node.PROCESS_MODE_DISABLED


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
		
		# 3. Despertamos SOLO a los de la lista
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