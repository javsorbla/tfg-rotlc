extends CharacterBody2D

# Constantes de movimiento
const SPEED = 150.0
const JUMP_VELOCITY = -300.0
const DASH_SPEED = 300.0
const DASH_DURATION = 0.20
const DASH_COOLDOWN = 0.5

# Constantes de ataque
const ATTACK_DURATION = 0.3
const HITBOX_OFFSET_X = 14
const HITBOX_OFFSET_Y = 22

# Variables de movimiento
var can_double_jump = false
var was_on_floor = false
var is_dashing = false
var dash_timer = 0.0
var can_dash = true
var dash_direction = 1.0
var dash_cooldown_timer = 0.0
var air_dash_used = false

# Variables de ataque
var is_attacking = false
var attack_timer = 0.0
var last_direction = 1
@onready var hitbox = $AttackHitbox

func _physics_process(delta: float) -> void:
	
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
	
	if is_on_floor():
		air_dash_used = false
	
	can_dash = dash_cooldown_timer <= 0 and (is_on_floor() or not air_dash_used)
		
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false
			velocity.y = 0
			velocity.x = dash_direction * SPEED * 0.2
		else:
			velocity.x = dash_direction * DASH_SPEED
			move_and_slide()
			return

	# Gravedad
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Salto
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
			can_double_jump = true
		elif can_double_jump:
			velocity.y = JUMP_VELOCITY
			can_double_jump = false

	# Al caerse de plataforma, conceder doble salto
	if was_on_floor and not is_on_floor() and velocity.y >= 0:
		can_double_jump = true

	# Dash
	if Input.is_action_just_pressed("dash") and can_dash:
		is_dashing = true
		dash_timer = DASH_DURATION
		dash_cooldown_timer = DASH_COOLDOWN
		if not is_on_floor():
			air_dash_used = true
		var dir = Input.get_axis("move_left", "move_right")
		dash_direction = dir if dir != 0 else (1.0 if not $AnimatedSprite2D.flip_h else -1.0)
		velocity.y = 0

	# Resetear dash al tocar suelo si ha pasado el cooldown
	if is_on_floor() and dash_cooldown_timer <= 0:
		can_dash = true

	# Guardar estado del suelo ANTES de move_and_slide
	was_on_floor = is_on_floor()

	var direction := Input.get_axis("move_left", "move_right")
	if direction:
		last_direction = direction
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * 0.2)

	move_and_slide()
	_handle_attack(delta)
	_update_animation()

func _update_animation():
	if is_dashing:
		return
	if not is_on_floor():
		pass
	elif velocity.x != 0:
		$AnimatedSprite2D.play("walk")
	else:
		$AnimatedSprite2D.play("idle")

	if velocity.x > 0:
		$AnimatedSprite2D.flip_h = false
	elif velocity.x < 0:
		$AnimatedSprite2D.flip_h = true

func _handle_attack(delta):
	if is_attacking:
		attack_timer -= delta
		if attack_timer <= 0:
			is_attacking = false
			hitbox.monitoring = false
			hitbox.visible = false  # quitamos esto cuando haya sprite
		return  # no permite atacar mientras ya está atacando

	if Input.is_action_just_pressed("attack"):
		is_attacking = true
		attack_timer = ATTACK_DURATION
		hitbox.monitoring = true
		hitbox.visible = true
		if Input.is_action_pressed("aim_up"):
			hitbox.position = Vector2(0, -HITBOX_OFFSET_Y)
		elif Input.is_action_pressed("aim_down"):
			hitbox.position = Vector2(0, HITBOX_OFFSET_Y)
		elif Input.is_action_pressed("aim_left"):
			hitbox.position = Vector2(-HITBOX_OFFSET_X, 0)
			print("hitbox position: ", hitbox.position)
		elif Input.is_action_pressed("aim_right"):
			hitbox.position = Vector2(HITBOX_OFFSET_X, 0)
		else:
			hitbox.position = Vector2(HITBOX_OFFSET_X * last_direction, 0)
