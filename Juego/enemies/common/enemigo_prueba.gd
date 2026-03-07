extends CharacterBody2D

const SPEED = 60.0
const MAX_HEALTH = 1

var current_health = MAX_HEALTH
var player = null

func _ready():
	# Buscar al jugador en la escena
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta):
	if not is_on_floor():
		velocity += get_gravity() * delta

	if player:
		# Moverse hacia el jugador en línea recta
		var direction = sign(player.global_position.x - global_position.x)
		velocity.x = direction * SPEED
		# Voltear sprite según dirección
		$AnimatedSprite2D.flip_h = direction < 0

	move_and_slide()

func take_damage(amount: int):
	current_health -= amount
	if current_health <= 0:
		die()

func die():
	queue_free()  # elimina el enemigo de la escena
