extends CharacterBody2D


const SPEED = 150.0
const JUMP_VELOCITY = -300.0

var can_double_jump = false
var was_on_floor = false
var jumped = false

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Al caerse de plataforma sin saltar, conceder salto
	if was_on_floor and not is_on_floor() and not jumped:
		can_double_jump = true

	# Al aterrizar, resetear todo
	if is_on_floor():
		can_double_jump = false
		jumped = false

	# Salto
	if Input.is_action_just_pressed("ui_accept"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
			can_double_jump = true
			jumped = true
		elif can_double_jump:
			velocity.y = JUMP_VELOCITY
			can_double_jump = false

	was_on_floor = is_on_floor()

	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
	_update_animation()


func _update_animation():
	if not is_on_floor():
		pass
	elif velocity.x != 0:
		$AnimatedSprite2D.play("walk")
	else:
		$AnimatedSprite2D.play("idle")
	
	# Voltear el sprite según dirección
	if velocity.x > 0:
		$AnimatedSprite2D.flip_h = false
	elif velocity.x < 0:
		$AnimatedSprite2D.flip_h = true
