extends CharacterBody2D

const MAX_HEALTH: int = 3 # momentaneamente por error en el daño del jugador, será 2
const DAMAGE: int = 1
const DIVE_SPEED: float = 200.0
const RETURN_SPEED: float = 100.0
const IDLE_DISTANCE: float = 200.0
const PATROL_SPEED: float = 60.0
const PATROL_X_RANGE: float = 80.0
const PATROL_Y_RANGE: float = 7.0
const STUN_DURATION: float = 0.4
const HIT_KNOCKBACK_FORCE: float = 120.0

const RETURN_ARC_HEIGHT: float = 40.0
const KNOCKBACK_FORCE: float = 10.0
const DIVE_MAX_DISTANCE: float = 300.0  # distancia máxima antes de volver

enum State { IDLE, DIVING, RETURNING, STUNNED, DEAD }

var current_state: State = State.IDLE
var current_health: int = MAX_HEALTH
var player: Node2D = null
var dive_direction: Vector2 = Vector2.ZERO
var dive_started_pos: Vector2 = Vector2.ZERO
var has_hit_player: bool = false
var stun_timer: float = 0.0

# Returning
var return_start_pos: Vector2 = Vector2.ZERO
var return_progress: float = 0.0

# Patrullaje
var patrol_origin: Vector2 = Vector2.ZERO
var patrol_dir: float = 1.0
var patrol_y_phase: float = 0.0

# Despawn tras morir
var death_grounded_timer: float = -1.0
var has_landed: bool = false


func _ready() -> void:
	current_health = MAX_HEALTH
	player = get_tree().get_first_node_in_group("player")

	if not $EnemyHitbox.area_entered.is_connected(_on_enemy_hitbox_area_entered):
		$EnemyHitbox.area_entered.connect(_on_enemy_hitbox_area_entered)
	if not $EnemyHurtbox.area_entered.is_connected(_on_enemy_hurtbox_area_entered):
		$EnemyHurtbox.area_entered.connect(_on_enemy_hurtbox_area_entered)

	patrol_origin = global_position
	_enter_state(State.IDLE)


func _physics_process(delta: float) -> void:
	match current_state:
		State.IDLE:
			_state_idle()
		State.DIVING:
			_state_diving()
		State.RETURNING:
			_state_returning()
		State.STUNNED:
			_state_stunned(delta)
		State.DEAD:
			velocity.y += 800 * delta
			# Despawn al tocar el suelo
			if is_on_floor() and not has_landed:
				has_landed = true
				death_grounded_timer = 0.7
			if has_landed:
				death_grounded_timer -= delta
				if death_grounded_timer <= 0.0:
					queue_free()

	move_and_slide()


# Cambio de estados
func _enter_state(new_state: State) -> void:
	current_state = new_state

	match new_state:
		State.IDLE:
			velocity = Vector2.ZERO
			has_hit_player = false

		State.DIVING:
			if player:
				var head_pos = player.global_position + Vector2(0, -10)
				dive_direction = (head_pos - global_position).normalized()
				velocity = dive_direction * DIVE_SPEED
				has_hit_player = false
				dive_started_pos = global_position

		State.RETURNING:
			velocity = Vector2.ZERO
			return_start_pos = global_position
			return_progress = 0.0

		State.DEAD:
			$AnimatedSprite2D.play("dead")

			if $EnemyHitbox:
				$EnemyHitbox.set_deferred("monitoring", false)
				$EnemyHitbox.set_deferred("monitorable", false)
				$EnemyHitbox.set_deferred("collision_layer", 0)
				$EnemyHitbox.set_deferred("collision_mask", 0)
			
			if $EnemyHurtbox:
				$EnemyHurtbox.set_deferred("monitoring", false)
				$EnemyHurtbox.set_deferred("monitorable", false)
				$EnemyHurtbox.set_deferred("collision_layer", 0)
				$EnemyHurtbox.set_deferred("collision_mask", 0)

			velocity = Vector2(0, 0)


func _state_idle() -> void:
	if player:
		var dist = global_position.distance_to(player.global_position)

		$Vision.target_position = player.global_position - global_position

		if dist <= IDLE_DISTANCE and not $Vision.is_colliding():
			_enter_state(State.DIVING)
			return

	velocity.x = patrol_dir * PATROL_SPEED
	patrol_y_phase += get_physics_process_delta_time() * 2.0
	global_position.y = patrol_origin.y + sin(patrol_y_phase) * PATROL_Y_RANGE

	# Detectar muros
	move_and_slide()
	if is_on_wall():
		patrol_dir *= -1   # cambiar dirección si choca con un muro

	if global_position.x >= patrol_origin.x + PATROL_X_RANGE:
		patrol_dir = -1.0
	elif global_position.x <= patrol_origin.x - PATROL_X_RANGE:
		patrol_dir = 1.0

	if patrol_dir > 0:
		$AnimatedSprite2D.play("walk_right")
	else:
		$AnimatedSprite2D.play("walk_left")


func _state_diving() -> void:
	if not player:
		return

	$AnimatedSprite2D.play("dive")
	velocity = dive_direction * DIVE_SPEED

	# Si choca con un muro, cancela el ataque
	if is_on_wall():
		_enter_state(State.RETURNING)
		return

	# Se considera “fallido” si recorre demasiada distancia sin golpear
	if not has_hit_player:
		if global_position.distance_to(dive_started_pos) >= DIVE_MAX_DISTANCE:
			_enter_state(State.RETURNING)


func _state_returning() -> void:
	var total_dir = patrol_origin - return_start_pos
	var total_dist = total_dir.length()
	if total_dist == 0:
		_enter_state(State.IDLE)
		return

	return_progress += RETURN_SPEED * get_physics_process_delta_time()
	var t = clamp(return_progress / total_dist, 0, 1)

	var new_pos = return_start_pos.lerp(patrol_origin, t)
	new_pos.y -= sin(t * PI) * RETURN_ARC_HEIGHT
	global_position = new_pos

	if total_dir.x < 0:
		$AnimatedSprite2D.play("walk_left")
	else:
		$AnimatedSprite2D.play("walk_right")

	if t >= 1.0:
		global_position = patrol_origin
		patrol_y_phase = 0.0
		_enter_state(State.IDLE)


func _state_stunned(delta):
	stun_timer -= delta
	velocity = Vector2.ZERO

	if stun_timer <= 0:
		_enter_state(State.RETURNING)


func _on_enemy_hitbox_area_entered(area: Area2D): 
	if current_state != State.DIVING or has_hit_player: 
		return 
		
	if area.is_in_group("player_hurtbox"): 
		var target = area.get_parent() 
		has_hit_player = true 
		if target.has_method("take_damage"): 
			target.take_damage(DAMAGE) 
				
		# knockback 
		if target is CharacterBody2D and not target.is_shielding: 
			var dir = (target.global_position - global_position).normalized() 
			dir.y = 0 
			target.velocity = dir * 150 
		_enter_state(State.RETURNING) 


func _on_enemy_hurtbox_area_entered(area: Area2D): 					
	if area.is_in_group("player_hitbox"): 
		take_damage(1) 

			
func take_damage(amount: int) -> void: 
	if current_state == State.DEAD: 
		return 
	current_health -= amount 
	if current_health <= 0: 
		die() 
		return 

	stun_timer = STUN_DURATION
	_enter_state(State.STUNNED) 
	$AnimatedSprite2D.play("dazed")


func die() -> void:
	_enter_state(State.DEAD)
