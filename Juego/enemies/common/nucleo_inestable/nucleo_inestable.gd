extends CharacterBody2D

const MAX_HEALTH: int = 1
const DAMAGE: int = 2
const STUN_DURATION: float = 2.5
const SLEEP_DISTANCE: float = 200.0
const GRAVITY: float = 700.0
const ROLL_SPEED: float = 120.0
const JUMP_VELOCITY: float = -150.0
const EDGE_CHECK_DISTANCE: float = 20.0
const KNOCKBACK_ENEMY: float = 80.0
const KNOCKBACK_PLAYER: float = 150.0

enum State { SLEEP, JUMP, ROLLING, STUNNED, DEAD }

var current_state: State = State.SLEEP
var current_health: int = MAX_HEALTH
var stun_timer: float = 0.0
var roll_direction: float = 1.0
var spawn_position = Vector2.ZERO

var player: Node2D = null
var space_state: PhysicsDirectSpaceState2D = null

var death_timer: float = -1.0
var _combat_reset_state: Dictionary = {}


func _ready() -> void:
	current_health = MAX_HEALTH
	player = get_tree().get_first_node_in_group("player")
	spawn_position = global_position
	GameState.level_reset.connect(_on_level_reset)
	
	if not $EnemyHitbox.area_entered.is_connected(_on_enemy_hitbox_area_entered):
		$EnemyHitbox.area_entered.connect(_on_enemy_hitbox_area_entered)
	if not $EnemyHurtbox.area_entered.is_connected(_on_enemy_hurtbox_area_entered):
		$EnemyHurtbox.area_entered.connect(_on_enemy_hurtbox_area_entered)
	_combat_reset_state = EnemyResetUtils.capture_collider_state($EnemyHitbox, $EnemyHurtbox)
	
	space_state = get_world_2d().direct_space_state
	_enter_state(State.SLEEP)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
		
	match current_state:
		State.SLEEP:
			_state_sleep()
		State.JUMP:
			_state_jump()
		State.ROLLING:
			_state_rolling()
			$AnimatedSprite2D.rotation += roll_direction * 5.0 * delta
		State.STUNNED:
			_state_stunned(delta)
		State.DEAD:
			if death_timer > 0:
				death_timer -= delta
				if death_timer <= 0.0:
					_despawn_dead_instance()
			
	move_and_slide()

func _on_level_reset():
	set_physics_process(true)
	visible = true
	current_health = MAX_HEALTH
	global_position = spawn_position
	velocity = Vector2.ZERO
	death_timer = -1.0
	EnemyResetUtils.restore_collider_state($EnemyHitbox, $EnemyHurtbox, _combat_reset_state)
	_enter_state(State.SLEEP)


func _despawn_dead_instance() -> void:
	velocity = Vector2.ZERO
	EnemyResetUtils.despawn(self)

func _enter_state(new_state: State) -> void:
	current_state = new_state
	match new_state:
		State.SLEEP:
			velocity.x = 0
			$AnimatedSprite2D.rotation = 0.0
			$AnimatedSprite2D.play("sleep")
			$EnemyHitbox.set_deferred("monitorable", false)

		State.JUMP:
			if player:
				roll_direction = sign(player.global_position.x - global_position.x)
			velocity.x = 0
			velocity.y = JUMP_VELOCITY
			$AnimatedSprite2D.flip_h = roll_direction > 0
			$AnimatedSprite2D.play("idle")
			$EnemyHitbox.set_deferred("monitorable", false)

		State.ROLLING:
			$AnimatedSprite2D.flip_h = roll_direction > 0
			$AnimatedSprite2D.play("rolling")
			$EnemyHitbox.set_deferred("monitorable", true)

		State.STUNNED:
			velocity.x = 0
			velocity.y = 0
			$AnimatedSprite2D.rotation = 0.0
			$AnimatedSprite2D.play("stunned")
			$EnemyHitbox.set_deferred("monitorable", false)
			
		State.DEAD:
			velocity = Vector2.ZERO
			$AnimatedSprite2D.rotation = 0.0
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
				
			death_timer = 1.0


func _state_sleep() -> void:
	velocity.x = 0
	if not player:
		return
		
	$Vision.target_position = player.global_position - global_position

	if global_position.distance_to(player.global_position) <= SLEEP_DISTANCE and not $Vision.is_colliding():
		_enter_state(State.JUMP)


func _state_jump() -> void:
	velocity.x = 0
	if is_on_floor():
		_enter_state(State.ROLLING)


func _state_rolling() -> void:
	# Cambiar dirección si choca contra un muro
	if is_on_wall():
		roll_direction *= -1
		$AnimatedSprite2D.flip_h = roll_direction > 0

	# Cambiar dirección si llega al borde del suelo
	var edge_check_pos = global_position + Vector2(roll_direction * EDGE_CHECK_DISTANCE, 0)
	var query = PhysicsRayQueryParameters2D.create(
		edge_check_pos,
		edge_check_pos + Vector2(0, 40.0),
		collision_mask
	)
	query.exclude = [self]
	if not space_state.intersect_ray(query):
		roll_direction *= -1
		$AnimatedSprite2D.flip_h = roll_direction > 0

	velocity.x = ROLL_SPEED * roll_direction


func _state_stunned(delta: float) -> void:
	stun_timer -= delta
	velocity.x = move_toward(velocity.x, 0, 100.0 * delta)
	if stun_timer <= 0:
		_enter_state(State.SLEEP)


func _on_enemy_hitbox_area_entered(area: Area2D):
	if area.is_in_group("player_hurtbox"):
		var target = area.get_parent()
		
		# Si el jugador tiene escudo, rebota como contra una pared
		if target.get("is_shielding") == true:
			roll_direction *= -1
			$AnimatedSprite2D.flip_h = roll_direction > 0
			return
		
		if target.has_method("take_damage"):
			target.take_damage(DAMAGE)
			
		if target is CharacterBody2D:
			var dir = (target.global_position - global_position).normalized()
			dir.y = 0
			target.velocity = dir * 230


func _on_enemy_hurtbox_area_entered(area: Area2D):
	if area.is_in_group("player_hitbox"):
		var player_node = get_tree().get_first_node_in_group("player")
		var multiplier = player_node.damage_multiplier if player_node else 1.0
		take_damage(int(1 * multiplier))


func take_damage(amount: int) -> void:
	if current_state == State.DEAD: 
		return 
	
	var color_manager = player.get_node("ColorManager")
	var has_red_power = color_manager and color_manager.active_power == "red"
	
	# Sin el poder rojo: no inflinges daño y aplicas retroceso
	if not has_red_power:
		stun_timer = STUN_DURATION
		_enter_state(State.STUNNED)
		if player and player is CharacterBody2D:
			var dir = sign(player.global_position.x - global_position.x)
			velocity.x = -dir * KNOCKBACK_ENEMY
			velocity.y = -60.0
			player.velocity.x = dir * KNOCKBACK_PLAYER
			player.velocity.y = -60.0
		return

	# Con el poder rojo: el enemigo recibe daño
	current_health -= amount
	if current_health <= 0:
		die()
		return


func die() -> void:
	_enter_state(State.DEAD)
