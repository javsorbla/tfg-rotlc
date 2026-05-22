extends Area2D

@export var velocidad_caida: float = 400.0
@export var dano: int = 1

func _physics_process(delta):
	# Esto hace que el pincho caiga constantemente hacia abajo
	position.y += velocidad_caida * delta

# Conecta la señal 'body_entered' del Area2D a esta función
func _on_body_entered(body):
	if body.is_in_group("player"):
		# Aquí llamas a la función que le quita vida a tu jugador.
		# Asegúrate de que el nombre coincida con cómo lo tengas programado en tu Player.gd
		if body.has_method("recibir_dano"):
			body.recibir_dano(dano)
			
		# Después de hacer daño, el pincho se destruye
		queue_free()

# Conecta la señal 'screen_exited' del VisibleOnScreenNotifier2D a esta función
func _on_visible_on_screen_notifier_2d_screen_exited():
	# Si el pincho sale de la pantalla (cae al vacío), se borra para no consumir RAM
	queue_free()
