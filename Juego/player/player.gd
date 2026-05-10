extends CharacterBody2D

const SPEED = 150.0
const JUMP_VELOCITY = -300.0
const DASH_SPEED = 300.0
const DASH_DURATION = 0.20
const DASH_COOLDOWN = 0.5
const ACCELERATION = 1000.0
const FRICTION = 700.0

var can_jump = true
var can_double_jump = false
var was_on_floor = false
var is_dashing = false
var dash_timer = 0.0
var can_dash = true
var dash_direction = 1.0
var dash_cooldown_timer = 0.0
var air_dash_used = false
var last_direction = 1
var speed_multiplier = 1.0
var can_attack = true
var damage_multiplier = 1.0
var is_shielding = false
var is_landing = false
var landing_should_run = false
var run_intro_done = false
var run_intro_timer = 0.0

@onready var sprite = $AnimatedSprite2D
@onready var hurtbox = $Hurtbox
@onready var health = $Health
@onready var combat = $Combat
@onready var color_manager = $ColorManager

func _ready():
	color_manager.unlock_power("cyan") # Para probar temporalmente
	color_manager.unlock_power("red") # Para probar temporalmente
	color_manager.unlock_power("yellow") # Para probar temporalmente
	var camera = get_tree().get_first_node_in_group("camera")
	if GameState.checkpoint_activated:
		global_position = GameState.spawn_position
	else:
		GameState.spawn_position = global_position

func _physics_process(delta: float) -> void:
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta

	if is_on_floor():
		air_dash_used = false

	can_dash = dash_cooldown_timer <= 0 and (is_on_floor() or not air_dash_used) and not is_shielding

	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false
			velocity.y = 0
			velocity.x = dash_direction * SPEED * 0.2
			if not health.is_invincible:
				hurtbox.monitorable = true
		else:
			velocity.x = dash_direction * DASH_SPEED
			move_and_slide()
			return

	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("jump") and can_jump:
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
			can_double_jump = true
		elif can_double_jump:
			velocity.y = JUMP_VELOCITY
			can_double_jump = false

	if was_on_floor and not is_on_floor() and velocity.y >= 0:
		can_double_jump = true

	if Input.is_action_just_pressed("dash") and can_dash:
		is_dashing = true
		hurtbox.monitorable = false
		dash_timer = DASH_DURATION
		dash_cooldown_timer = DASH_COOLDOWN
		if not is_on_floor():
			air_dash_used = true
		var dir = Input.get_axis("move_left", "move_right")
		dash_direction = dir if dir != 0 else (1.0 if not sprite.flip_h else -1.0)
		velocity.y = 0

	if is_on_floor() and dash_cooldown_timer <= 0:
		can_dash = true

	was_on_floor = is_on_floor()

	var direction := Input.get_axis("move_left", "move_right")
	if direction:
		last_direction = direction
		velocity.x = move_toward(velocity.x, direction * SPEED * speed_multiplier, ACCELERATION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)

	if direction != 0:
		sprite.flip_h = direction < 0
	elif not is_on_floor():
		sprite.flip_h = last_direction < 0

	if is_on_floor() and abs(velocity.x) <= 0.1 and not is_landing:
		run_intro_done = false

	if is_landing:
		is_landing = false
		if landing_should_run:
			run_intro_done = true
			run_intro_timer = 0.0
			sprite.play("run")
		else:
			sprite.play("idle")

	move_and_slide()
	_check_checkpoints()
	health.process(delta)
	combat.process(delta)
	color_manager.process(delta)
	_update_animation(delta)

func _update_animation(delta: float):
	if is_dashing:
		return

	# Detectar aterrizaje: justo cuando toca el suelo viniendo del aire
	if is_on_floor() and not was_on_floor:
		landing_should_run = abs(velocity.x) > 0.1 or abs(Input.get_axis("move_left", "move_right")) > 0.1
		is_landing = true
		sprite.play("jump")
		sprite.speed_scale = 1.0
		sprite.frame = 5  # último frame antes de pasar a correr o quedar quieto
		return

	# Mientras está aterrizando, deja que la animación corra sola
	if is_landing:
		sprite.speed_scale = 1.0
		if last_direction != 0:
			sprite.flip_h = last_direction < 0
		return

	if is_on_floor():
		sprite.speed_scale = 1.0
		if velocity.x > 0:
			if not run_intro_done:
				run_intro_done = true
				run_intro_timer = 1.0 / sprite.sprite_frames.get_animation_speed("run_intro")
				sprite.play("run_intro")
				return
			if run_intro_timer > 0.0:
				run_intro_timer -= delta
				if run_intro_timer > 0.0:
					return
				sprite.play("run")
			elif sprite.animation != "run":
				sprite.play("run")
		elif velocity.x < 0:
			if not run_intro_done:
				run_intro_done = true
				run_intro_timer = 1.0 / sprite.sprite_frames.get_animation_speed("run_intro")
				sprite.play("run_intro")
				return
			if run_intro_timer > 0.0:
				run_intro_timer -= delta
				if run_intro_timer > 0.0:
					return
				sprite.play("run")
			elif sprite.animation != "run":
				sprite.play("run")
		else:
			run_intro_timer = 0.0
			if sprite.animation != "idle":
				sprite.play("idle")
		landing_should_run = false
		return

	# En el aire
	run_intro_timer = 0.0
	if sprite.animation != "jump":
		sprite.play("jump")
	sprite.speed_scale = 0.0
	if velocity.x != 0:
		sprite.flip_h = velocity.x < 0
	elif last_direction != 0:
		sprite.flip_h = last_direction < 0
	if was_on_floor:
		sprite.frame = 2
	elif velocity.y < 0.0:
		sprite.frame = 3
	else:
		sprite.frame = 4

func _check_checkpoints():
	for checkpoint in get_tree().get_nodes_in_group("checkpoint"):
		if global_position.distance_to(checkpoint.global_position) < 32:
			if checkpoint.global_position != GameState.spawn_position:
				GameState.spawn_position = checkpoint.global_position
				GameState.checkpoint_activated = true
