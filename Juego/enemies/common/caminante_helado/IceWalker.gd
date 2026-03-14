extends CharacterBody2D

@onready var target = get_parent().get_node("Player") 

var speed = 50.0
var knockback_speed = 300.0  # Fuerza con la que sale despedido
var knockback_timer = 0.0

func _ready():
	# Conectamos la señal por código para asegurarnos de que no falle
	$Hurtbox.body_entered.connect(_on_hurtbox_body_entered)

func _physics_process(delta):
	if not target:
		return

	if knockback_timer > 0:
		# Está en estado de retroceso
		knockback_timer -= delta
	else:
		# Persecución normal. Usamos direction_to, que es matemáticamente más seguro
		var direction = global_position.direction_to(target.global_position)
		velocity = direction * speed
		
	move_and_slide()

# Esta función se dispara automáticamente cuando el jugador entra en el Hurtbox del enemigo
func _on_hurtbox_body_entered(body):
	if body.name == "Player":
		# 1. Calculamos la dirección de rebote (desde el jugador hacia el enemigo)
		var knock_direction = body.global_position.direction_to(global_position)
		
		# 2. Le aplicamos la velocidad de retroceso
		velocity = knock_direction * knockback_speed
		
		# 3. Activamos el timer (0.3 segundos de retroceso suele verse bien)
		knockback_timer = 0.3
