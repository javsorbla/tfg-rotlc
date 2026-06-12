extends Area2D

# Aquí arrastraremos la PRIMERA plataforma de la escalera
@export var primera_plataforma: StaticBody2D

func _on_body_entered(body):
	if body.is_in_group("player"):
		# Si el jugador cae aquí, le decimos a la primera plataforma que inicie el reseteo
		if primera_plataforma != null:
			primera_plataforma.reiniciar()