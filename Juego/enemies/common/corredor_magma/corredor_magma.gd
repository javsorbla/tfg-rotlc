extends CharacterBody2D

# --- CONSTANTES ---
const MAX_HEALTH: int = 3
const DAMAGE: int = 1
const PATROL_SPEED: float = 40.0
const CHASE_SPEED: float = 190.0
const JUMP_VELOCITY: float = -300.0
const DETECTION_DISTANCE: float = 250.0 
const PATROL_X_RANGE: float = 80.0
const STUN_DURATION: float = 0.4
const DASH_SPEED: float = 300.0
const DASH_RANGE: float = 150.0 

# --- ESTADOS ---
enum State { IDLE, PATROL, CHASE, STUNNED, DEAD, PREPARE_DASH, DASH }

# --- VARIABLES ---
var current_state: State = State.IDLE
var current_health: int = MAX_HEALTH
var player: Node2D = null
var facing_dir: float = 1.0 
var patrol_origin_x: float = 0.0
var spawn_position = Vector2.ZERO

# Temporizadores y Cooldowns
var stun_timer: float = 0.0
var idle_timer: float = 0.0
var patrol_timer: float = 0.0
var flip_cooldown: float = 0.0 
var jump_cooldown: float = 0.0 
var dash_cooldown: float = 0.0
var dash_timer: float = 0.0
var _combat_reset_state: Dictionary = {}

# --- NODOS ---
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var vision: RayCast2D = $Vision


# --- CICLO PRINCIPAL ---

func _ready() -> void:
	current_health = MAX_HEALTH
	player = get_tree().get_first_node_in_group("player")
	patrol_origin_x = global_position.x
	spawn_position = global_position
	GameState.level_reset.connect(_on_level_reset)

	if not $EnemyHitbox.area_entered.is_connected(_on_enemy_hitbox_area_entered):
		$EnemyHitbox.area_entered.connect(_on_enemy_hitbox_area_entered)
	if not $EnemyHurtbox.area_entered.is_connected(_on_enemy_hurtbox_area_entered):
		$EnemyHurtbox.area_entered.connect(_on_enemy_hurtbox_area_entered)
	_combat_reset_state = EnemyResetUtils.capture_collider_state($EnemyHitbox, $EnemyHurtbox)

	vision.target_position = Vector2(20, 40) 
	_enter_state(State.IDLE)


func _physics_process(delta: float) -> void:
	# Gestión de cooldowns
	if flip_cooldown > 0: flip_cooldown -= delta
	if jump_cooldown > 0: jump_cooldown -= delta
	if dash_cooldown > 0: dash_cooldown -= delta 

	# Gravedad
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Máquina de estados
	match current_state:
		State.IDLE:
			_state_idle(delta)
		State.PATROL:
			_state_patrol(delta)
		State.CHASE:
			_state_chase()
		State.PREPARE_DASH:
			_state_prepare_dash(delta)
		State.DASH:
			_state_dash(delta)
		State.STUNNED:
			_state_stunned(delta)
		State.DEAD:
			velocity.x = move_toward(velocity.x, 0, 200 * delta)

	move_and_slide()

	# Control global de animación de salto
	if not is_on_floor():
		if current_state not in [State.STUNNED, State.DEAD, State.DASH, State.PREPARE_DASH]:
			sprite.play("jump")
	else:
		if sprite.animation == "jump":
			if current_state == State.IDLE:
				sprite.play("iddle")
			elif current_state in [State.PATROL, State.CHASE]:
				sprite.play("run")

func _on_level_reset():
	set_physics_process(true)
	visible = true
	current_health = MAX_HEALTH
	global_position = spawn_position
	velocity = Vector2.ZERO
	EnemyResetUtils.restore_collider_state($EnemyHitbox, $EnemyHurtbox, _combat_reset_state)
	_enter_state(State.IDLE)


func _despawn_dead_instance() -> void:
	velocity = Vector2.ZERO
	EnemyResetUtils.despawn(self)

# --- MANEJO DE ESTADOS ---

func _enter_state(new_state: State) -> void:
	current_state = new_state
	
	# Reiniciar efectos visuales
	sprite.modulate = Color(1, 1, 1) 
	sprite.speed_scale = 1.0         

	match new_state:
		State.IDLE:
			velocity.x = 0
			if is_on_floor(): sprite.play("iddle")
			idle_timer = randf_range(1.0, 2.5) 
			
		State.PATROL:
			patrol_timer = randf_range(2.0, 4.0) 
			
		State.CHASE:
			sprite.play("run")
			
		State.PREPARE_DASH:
			velocity.x = 0
			sprite.play("iddle")
			sprite.modulate = Color(1.0, 0.4, 0.4) # Feedback visual de carga
			dash_timer = 0.5 
			
		State.DASH:
			sprite.play("run")
			sprite.speed_scale = 2.0 
			dash_timer = 0.4 
			
		State.STUNNED:
			sprite.play("stun") 
			velocity.x = 0 
			
		State.DEAD:
			sprite.play("dead") 
			if $EnemyHitbox:
				$EnemyHitbox.set_deferred("monitoring", false)
				$EnemyHitbox.set_deferred("monitorable", false)
				$EnemyHitbox.set_deferred("collision_layer", 0)
				$EnemyHitbox.set_deferred("collision_mask", 0)
			velocity.x = 0
			
			await get_tree().create_timer(0.7).timeout
			_despawn_dead_instance()


# --- LÓGICA DE VISIÓN ---

func _has_line_of_sight() -> bool:
	if not player: return false
	var space_state = get_world_2d().direct_space_state
	var eye_pos = global_position + Vector2(0, -15)
	var target_pos = player.global_position + Vector2(0, -15)
	
	var query = PhysicsRayQueryParameters2D.create(eye_pos, target_pos)
	query.collision_mask = 1 
	var result = space_state.intersect_ray(query)
	
	return result.is_empty() 


func _check_for_player() -> bool:
	if player:
		var dist = global_position.distance_to(player.global_position)
		if dist <= DETECTION_DISTANCE:
			var dir_to_player = sign(player.global_position.x - global_position.x)
			if dir_to_player == sign(facing_dir) or dir_to_player == 0:
				if _has_line_of_sight():
					_enter_state(State.CHASE)
					return true
	return false


# --- FUNCIONES DE ESTADO ---

func _state_idle(delta: float) -> void:
	if _check_for_player(): return
	
	idle_timer -= delta
	if idle_timer <= 0: 
		_enter_state(State.PATROL)


func _state_patrol(delta: float) -> void:
	if _check_for_player(): return

	velocity.x = facing_dir * PATROL_SPEED
	if is_on_floor() and sprite.animation != "run": sprite.play("run")

	patrol_timer -= delta
	if patrol_timer <= 0 and is_on_floor():
		_enter_state(State.IDLE)
		return

	var reached_limit_right = (global_position.x >= patrol_origin_x + PATROL_X_RANGE) and facing_dir == 1.0
	var reached_limit_left = (global_position.x <= patrol_origin_x - PATROL_X_RANGE) and facing_dir == -1.0

	if (reached_limit_right or reached_limit_left) and is_on_floor():
		_flip()
		_enter_state(State.IDLE)
		return

	var hit_ledge = not vision.is_colliding()
	var hit_wall = is_on_wall() and sign(get_wall_normal().x) == -sign(facing_dir)

	if is_on_floor():
		if hit_wall or hit_ledge:
			_flip()
			_enter_state(State.IDLE)
	else:
		if hit_wall: velocity.x = 0


func _state_chase() -> void:
	if not player or not _has_line_of_sight():
		patrol_origin_x = global_position.x
		_enter_state(State.IDLE)
		return

	var dist = global_position.distance_to(player.global_position)
	var y_diff = abs(player.global_position.y - global_position.y)
	
	# Comprobar si puede iniciar la embestida
	if dist <= DASH_RANGE and dash_cooldown <= 0 and is_on_floor() and y_diff < 40:
		_enter_state(State.PREPARE_DASH)
		return

	# Comprobar si pierde el agro
	if dist > DETECTION_DISTANCE * 1.5:
		patrol_origin_x = global_position.x
		_enter_state(State.IDLE)
		return

	# Darse la vuelta si el jugador le sobrepasa
	var x_diff = player.global_position.x - global_position.x
	if abs(x_diff) > 5.0 and is_on_floor():
		var dir_to_player = sign(x_diff)
		if dir_to_player != 0 and dir_to_player != facing_dir:
			_flip()

	velocity.x = facing_dir * CHASE_SPEED
	if is_on_floor() and sprite.animation != "run": sprite.play("run")

	var hit_ledge = not vision.is_colliding()
	var hit_wall = is_on_wall() and sign(get_wall_normal().x) == -sign(facing_dir)

	# Manejo de obstáculos durante la persecución
	if is_on_floor():
		if hit_wall or hit_ledge:
			if jump_cooldown <= 0:
				velocity.y = JUMP_VELOCITY
				jump_cooldown = 1.0 
			else:
				_flip()
				patrol_origin_x = global_position.x
				_enter_state(State.IDLE)
	else:
		if hit_wall and velocity.y >= 0: 
			velocity.x = 0


func _state_prepare_dash(delta: float) -> void:
	dash_timer -= delta
	velocity.x = move_toward(velocity.x, 0, 400 * delta)
	
	if dash_timer <= 0:
		_enter_state(State.DASH)


func _state_dash(delta: float) -> void:
	dash_timer -= delta
	velocity.x = facing_dir * DASH_SPEED

	var hit_wall = is_on_wall() and sign(get_wall_normal().x) == -sign(facing_dir)
	var hit_ledge = not vision.is_colliding() and is_on_floor()

	if hit_wall:
		dash_cooldown = 3.0 
		stun_timer = STUN_DURATION * 2.0 
		_enter_state(State.STUNNED)
		return
		
	if hit_ledge:
		dash_cooldown = 3.0
		_enter_state(State.IDLE)
		return

	if dash_timer <= 0:
		dash_cooldown = 3.0
		_enter_state(State.IDLE)


func _state_stunned(delta: float) -> void:
	stun_timer -= delta
	if stun_timer <= 0: 
		_enter_state(State.IDLE)


# --- FUNCIONES AUXILIARES ---

func _flip() -> void:
	if flip_cooldown > 0: return
	
	facing_dir *= -1.0
	sprite.flip_h = (facing_dir < 0)
	vision.target_position.x = abs(vision.target_position.x) * facing_dir
	flip_cooldown = 0.3


# --- COMBATE ---

func _on_enemy_hitbox_area_entered(area: Area2D) -> void:
	if current_state == State.DEAD: return
	
	if area.is_in_group("player_hurtbox"):
		var hit_player = area.get_parent()
		
		# Si el jugador tiene escudo, actua como si se chocase con una pared
		if hit_player.get("is_shielding") == true:
			flip_cooldown = 0.0
			_flip()
			if current_state == State.DASH:
				dash_cooldown = 3.0
				stun_timer = STUN_DURATION * 2.0
				_enter_state(State.STUNNED)
			else:
				stun_timer = 0.6
				_enter_state(State.STUNNED)
				velocity.x = facing_dir * PATROL_SPEED
			return
		
		if hit_player.has_method("take_damage"):
			hit_player.take_damage(DAMAGE)
			
		# Knockback al jugador
		if hit_player is CharacterBody2D:
			var dir = (hit_player.global_position - global_position).normalized()
			dir.y = 0
			
			if current_state == State.DASH:
				hit_player.velocity = dir * 250
			else:
				hit_player.velocity = dir * 150


func _on_enemy_hurtbox_area_entered(area: Area2D):
	if area.is_in_group("player_hitbox"):
		var player_node = get_tree().get_first_node_in_group("player")
		var multiplier = player_node.damage_multiplier if player_node else 1.0
		take_damage(int(1 * multiplier))


func take_damage(amount: int) -> void:
	if current_state == State.DEAD: return
	
	current_health -= amount
	if current_health <= 0:
		die()
		return
		
	# Girarse automáticamente si es atacado por la espalda
	if player:
		var dir_to_player = sign(player.global_position.x - global_position.x)
		if dir_to_player != 0 and dir_to_player != sign(facing_dir):
			flip_cooldown = 0.0
			_flip()

	stun_timer = STUN_DURATION
	_enter_state(State.STUNNED)


func die() -> void:
	_enter_state(State.DEAD)
