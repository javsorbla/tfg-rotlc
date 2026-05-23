extends Area2D

# Arrastraremos aquí la cámara fija que creamos en el Paso 1
@export var camara_fija: Camera2D

# Cuando el jugador ENTRA en la zona de los pinchos
func _on_body_entered(body):
	if body.is_in_group("player"):
		if camara_fija != null:
			var camara_jugador = get_tree().get_first_node_in_group("camera")
			if camara_jugador:
				# En lugar de cambiar de cámara, activamos el modo fijo de la cámara del jugador
				camara_jugador.is_fixed = true
				camara_jugador.fixed_target_pos = camara_fija.global_position
				camara_jugador.target_zoom = camara_fija.zoom

# Cuando el jugador SALE de la zona de los pinchos
func _on_body_exited(body):
	if body.is_in_group("player"):
		var camara_jugador = get_tree().get_first_node_in_group("camera")
		if camara_jugador != null:
			# Desactivamos el modo fijo y volvemos al zoom original
			camara_jugador.is_fixed = false
			camara_jugador.target_zoom = camara_jugador.DEFAULT_ZOOM