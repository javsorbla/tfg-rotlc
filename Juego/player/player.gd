extends CharacterBody2D


const SPEED = 150.0
const JUMP_VELOCITY = -300.0

# Constantes de ataque
const ATTACK_DURATION = 0.3
const HITBOX_OFFSET_X = 14
const HITBOX_OFFSET_Y = 22

# Constantes de vida
const MAX_HEALTH = 3
const INVINCIBILITY_DURATION = 1.0

# Variables de movimiento
var can_double_jump = false
var was_on_floor = false
var jumped = false

# Variables de vida
var current_health = 3
var is_invincible = false
var invincibility_timer = 0.0
var spawn_position = Vector2.ZERO
@onready var hurtbox = $Hurtbox

func _ready():
	hitbox.monitoring = false
	hitbox.visible = false
	spawn_position = global_position

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
			if not is_invincible:
				hurtbox.monitorable = true  
		else:
			velocity.x = dash_direction * DASH_SPEED
			move_and_slide()
			return

	# Gravedad
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

	# Al caerse de plataforma, conceder doble salto
	if was_on_floor and not is_on_floor() and velocity.y >= 0:
		can_double_jump = true

	# Dash
	if Input.is_action_just_pressed("dash") and can_dash:
		is_dashing = true
		hurtbox.monitorable = false
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

	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
	_handle_attack(delta)
	_handle_invincibility(delta)
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
		elif Input.is_action_pressed("aim_right"):
			hitbox.position = Vector2(HITBOX_OFFSET_X, 0)
		else:
			hitbox.position = Vector2(HITBOX_OFFSET_X * last_direction, 0)

func take_damage(amount: int):
	if is_invincible:
		return
	current_health -= amount
	is_invincible = true
	invincibility_timer = INVINCIBILITY_DURATION
	if current_health <= 0:
		die()

func die():
	current_health = MAX_HEALTH
	is_invincible = false
	hurtbox.monitorable = true
	$AnimatedSprite2D.visible = true
	# Reaparecer al inicio del nivel
	global_position = spawn_position

func _handle_invincibility(delta):
	if is_invincible:
		invincibility_timer -= delta
		hurtbox.monitorable = false  # desactivado mientras es invencible
		# Parpadeo visual
		$AnimatedSprite2D.visible = not $AnimatedSprite2D.visible if fmod(invincibility_timer, 0.2) < 0.1 else true
		if invincibility_timer <= 0:
			is_invincible = false
			hurtbox.monitorable = true  # reactivar al terminar
			$AnimatedSprite2D.visible = true


func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy_hitbox"):
		take_damage(1)


func _on_attack_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy_hitbox"):
		area.get_parent().take_damage(1)
