extends Area2D

@export var velocidad_caida: float = 400.0
@export var dano: int = 1

func _physics_process(delta):
	# Hace que el pincho caiga constantemente
	position.y += velocidad_caida * delta

# NUEVA FUNCIÓN: Ahora detectamos otras ÁREAS (como tu Hurtbox)
func _on_area_entered(area):
	# Comprobamos si el área que el pincho ha tocado tiene el grupo "player_hurtbox"
	if area.is_in_group("player_hurtbox"):
		
		# El Hurtbox suele ser un "hijo" del jugador. 'owner' busca al nodo principal (el Player)
		var jugador = area.owner 
		
		# Accedemos al nodo Health del jugador
		var health = jugador.get_node_or_null("Health")
		if health and health.has_method("take_damage"): 
			health.take_damage(dano)
			
		# El pincho se destruye tras pinchar al jugador
		queue_free()

# Para que se borre si cae al vacío
func _on_visible_on_screen_notifier_2d_screen_exited():
	queue_free()