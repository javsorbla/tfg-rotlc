extends CharacterBody2D

const MAX_HEALTH: int = 2
const DAMAGE: int = 1

const DIVE_SPEED: float = 200.0
const IDLE_DISTANCE: float = 200.0
const STUN_DURATION: float = 0.4
const PATROL_SPEED: float = 60.0
const PATROL_X_RANGE: float = 80.0
const PATROL_Y_RANGE: float = 7.0

enum State { IDLE, DIVING, STUNNED, DEAD }

var current_state  : State   = State.IDLE
var current_health : int     = MAX_HEALTH
var player         : Node2D  = null
var dive_direction : Vector2 = Vector2.ZERO

var stun_timer     : float   = 0.0
var patrol_origin  : Vector2 = Vector2.ZERO
var patrol_dir     : float   = 1.0
var patrol_y_phase : float   = 0.0


func _ready() -> void:
	current_health = MAX_HEALTH
	player = get_tree().get_first_node_in_group("player")

	$EnemyHitbox.body_entered.connect(_on_enemy_hitbox_body_entered)
	$EnemyHitbox.area_entered.connect(_on_enemy_hitbox_area_entered)

	patrol_origin = global_position
	_enter_state(State.IDLE)


func _physics_process(delta: float) -> void:
	match current_state:
		State.IDLE:
			_state_idle()
		State.DIVING:
			_state_diving()
		State.STUNNED:
			_state_stunned(delta)
		State.DEAD:
			pass

	move_and_slide()


func _enter_state(new_state: State) -> void:
	current_state = new_state
	match new_state:
		State.IDLE:
			velocity = Vector2.ZERO

		State.DIVING:
			# Calcular dirección hacia la cabeza del jugador UNA sola vez
			var head_pos = player.global_position + Vector2(0, -20)
			dive_direction = (head_pos - global_position).normalized()
			velocity = Vector2.ZERO
			if player.global_position.x < global_position.x:
				$AnimatedSprite2D.play("walk_left")
			else:
				$AnimatedSprite2D.play("walk_right")

		State.STUNNED:
			velocity = Vector2.ZERO
			stun_timer = STUN_DURATION
			$AnimatedSprite2D.play("dazed")

		State.DEAD:
			velocity = Vector2.ZERO
			$AnimatedSprite2D.play("dead")
			set_collision_layer_value(1, false)
			$AnimatedSprite2D.animation_finished.connect(queue_free)


func _state_idle() -> void:
	if player:
		var dist = global_position.distance_to(player.global_position)
		if dist <= IDLE_DISTANCE:
			_enter_state(State.DIVING)
			return

	velocity.x = patrol_dir * PATROL_SPEED

	patrol_y_phase += get_physics_process_delta_time() * 2.0
	global_position.y = patrol_origin.y + sin(patrol_y_phase) * PATROL_Y_RANGE

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
	if player.global_position.x < global_position.x:
		$AnimatedSprite2D.play("dive")
	else:
		$AnimatedSprite2D.play("dive")
	velocity = dive_direction * DIVE_SPEED


func _state_stunned(delta: float) -> void:
	velocity = Vector2.ZERO
	stun_timer -= delta
	if stun_timer <= 0.0:
		_enter_state(State.IDLE)


func _on_hitbox_body_entered(body: Node) -> void:
	if current_state == State.DIVING and body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(DAMAGE)


func _on_enemy_hitbox_body_entered(body: Node) -> void:
	pass


func _on_enemy_hitbox_area_entered(area: Area2D) -> void:
	if area.name == "AttackHitbox":
		take_damage(1)


func take_damage(amount: int) -> void:
	if current_state == State.DEAD:
		return
	current_health -= amount
	if current_health <= 0:
		die()
		return
	_enter_state(State.STUNNED)


func die() -> void:
	_enter_state(State.DEAD)
