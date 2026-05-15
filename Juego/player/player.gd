extends CharacterBody2D

const SPEED = 150.0
const JUMP_VELOCITY = -300.0
const DASH_SPEED = 300.0
const DASH_DURATION = 0.30
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
var dash_started_on_floor = false
var dash_frame_stage = 0  # 0: inicial, 1: comienzo, 2: main, 3: fin, 4: transición
var showing_dash_transition_frame = false
var AFTERIMAGE_LIFETIME = 0.20
var AFTERIMAGE_SPAWN_INTERVAL = 0.06
var _afterimage_timer = 0.0

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
			showing_dash_transition_frame = true
			velocity.y = 0
			velocity.x = dash_direction * SPEED * 0.2
			if not health.is_invincible:
				hurtbox.monitorable = true
		else:
			velocity.x = dash_direction * DASH_SPEED
			move_and_slide()
			was_on_floor = is_on_floor()
			_check_checkpoints()
			health.process(delta)
			combat.process(delta)
			color_manager.process(delta)
			
			_afterimage_timer -= delta
			if _afterimage_timer <= 0.0:
				var tex2 = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
				if tex2 != null:
					_spawn_afterimage(tex2)
				_afterimage_timer = AFTERIMAGE_SPAWN_INTERVAL
			_update_animation(delta)
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
		dash_started_on_floor = is_on_floor() and abs(velocity.x) <= 0.1
		dash_frame_stage = 0
		hurtbox.monitorable = false
		dash_timer = DASH_DURATION
		dash_cooldown_timer = DASH_COOLDOWN
		var dir = Input.get_axis("move_left", "move_right")
		dash_direction = dir if dir != 0 else (1.0 if not sprite.flip_h else -1.0)
		var tex = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		if tex:
			_spawn_afterimage(tex)
		_afterimage_timer = AFTERIMAGE_SPAWN_INTERVAL
		if not is_on_floor():
			air_dash_used = true
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
	# Lógica del dash
	if is_dashing:
		if sprite.animation != "dash":
			sprite.play("dash")
			sprite.speed_scale = 0.0  # Control manual de frames
		
		# Actualizar stage del dash según dash_timer
		if dash_timer > DASH_DURATION * 0.9:  # Al inicio del dash
			if dash_started_on_floor:
				sprite.frame = 0  # Frame inicial solo si arranque estático
			else:
				sprite.frame = 1  # Frame de comienzo si es aire
		elif dash_timer > DASH_DURATION * 0.1:  # Durante el main dash
			sprite.frame = 2  # Frame principal del dash
		else:  # Final del dash
			sprite.frame = 3  # Frame de fin del dash
		return

	# Transición post-dash: mostrar frame 4 solo si está en suelo sin movimiento
	if showing_dash_transition_frame:
		if is_on_floor() and abs(velocity.x) <= 0.1 and abs(Input.get_axis("move_left", "move_right")) <= 0.1:
			if sprite.animation != "dash":
				sprite.play("dash")
				sprite.speed_scale = 0.0
			sprite.frame = 4  # Frame de transición a estático
			showing_dash_transition_frame = false  # Solo mostrar un frame
		else:
			# Si se mueve o salta, saltar directamente a la animación normal
			showing_dash_transition_frame = false

	# Ataque en suelo: animación estática o ataque corriendo
	if combat.is_attacking and is_on_floor():
		var moving_on_floor = abs(velocity.x) > 0.1 or abs(Input.get_axis("move_left", "move_right")) > 0.1
		if moving_on_floor:
			if sprite.animation != "attack_run":
				var previous_animation = sprite.animation
				var previous_frame = sprite.frame
				sprite.play("attack_run")
				sprite.speed_scale = 1.0
				if previous_animation == "run" or previous_animation == "attack_run":
					var attack_run_frames = sprite.sprite_frames.get_frame_count("attack_run")
					if attack_run_frames > 0:
						sprite.frame = (previous_frame + 1) % attack_run_frames
			elif sprite.animation == "attack_run":
				sprite.speed_scale = 1.0
			if velocity.x != 0:
				sprite.flip_h = velocity.x < 0
			elif last_direction != 0:
				sprite.flip_h = last_direction < 0
			return
		else:
			if sprite.animation != "attack":
				sprite.play("attack")
				sprite.speed_scale = 1.0
			if velocity.x != 0:
				sprite.flip_h = velocity.x < 0
			elif last_direction != 0:
				sprite.flip_h = last_direction < 0
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

func _spawn_afterimage(tex):
	var si := Sprite2D.new()
	si.texture = tex
	si.global_position = global_position
	si.flip_h = sprite.flip_h
	si.scale = sprite.scale
	si.z_index = sprite.z_index - 1
	var pcol := Color(1, 1, 1, 0.85)
	if sprite.material != null and sprite.material.has_method("get_shader_parameter"):
		var sc = sprite.material.get_shader_parameter("color_primary")
		if sc != null:
			pcol = Color(sc.r, sc.g, sc.b, 0.85)
	si.modulate = pcol
	get_parent().add_child(si)
	var tw = si.create_tween()
	tw.tween_property(si, "modulate:a", 0.0, AFTERIMAGE_LIFETIME)
	tw.tween_property(si, "scale", si.scale * 0.85, AFTERIMAGE_LIFETIME)
	tw.finished.connect(Callable(si, "queue_free"))

func _on_dash_clear_restore(timer: Timer) -> void:
	if timer and timer.is_inside_tree():
		timer.queue_free()
