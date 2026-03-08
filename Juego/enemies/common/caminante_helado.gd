extends CharacterBody2D

var target: Node2D = null
var detection_range = 180.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	# Buscamos al jugador al iniciar
	target = _find_player_target()

func _physics_process(_delta):
	# Si no tenemos al jugador, intentamos buscarlo
	if not target:
		target = _find_player_target()
		_update_animation_state()
		return

	# Actualizamos la animación en cada frame basado en la posición del jugador
	_update_animation_state()

func _update_animation_state():
	if not target:
		animated_sprite.play("idle")
		return

	var distance_to_target = global_position.distance_to(target.global_position)
	var dx = target.global_position.x - global_position.x

	# Lógica de animaciones:
	# 1. Si está fuera de rango, se queda quieto
	if distance_to_target > detection_range:
		animated_sprite.play("idle")
	# 2. Si el jugador está a la izquierda (dx negativo)
	elif dx < 0:
		animated_sprite.play("walk_left")
	# 3. Si el jugador está a la derecha (dx positivo)
	elif dx > 0:
		animated_sprite.play("walk_right")
	# 4. Si están exactamente en la misma posición (poco probable)
	else:
		animated_sprite.play("idle")

# Función de apoyo para encontrar al jugador en la escena
func _find_player_target() -> Node2D:
	for node in get_tree().get_nodes_in_group("player"):
		if node != self and node is Node2D and node.name == "Player":
			return node as Node2D
	for node in get_tree().get_nodes_in_group("player"):
		if node != self and node is Node2D:
			return node as Node2D
	return null