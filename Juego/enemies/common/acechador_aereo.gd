extends CharacterBody2D

const MAX_HEALTH = 2
const DAMAGE = 1

const DIVE_SPEED = 380.0  # velocidad al atacar
const STUN_DURATION = 0.4    # segundos inmovilizado al recibir daño
const IDLE_DISTANCE = 300.0  # distancia mínima para detectar al jugador

enum State { IDLE, DIVING, STUNNED, DEAD }

var current_state = State.IDLE
var current_health = MAX_HEALTH
var player = null
var dive_direction = Vector2.ZERO

var stun_timer = 0.0


func _ready() -> void:
	current_health = MAX_HEALTH
	player = get_tree().get_first_node_in_group("player")

	$EnemyHitbox.body_entered.connect(_on_enemy_hitbox_body_entered)
	$EnemyHitbox.area_entered.connect(_on_enemy_hitbox_area_entered)

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
			$AnimatedSprite2D.play("idle")

		State.DIVING:
			velocity = Vector2.ZERO
			if player.global_position.x < global_position.x:
				$AnimatedSprite2D.play("walk_left")
			else:
				$AnimatedSprite2D.play("walk_right")

		State.STUNNED:
			velocity = Vector2.ZERO
			stun_timer = STUN_DURATION
			$AnimatedSprite2D.play("dive")

		State.DEAD:
			velocity = Vector2.ZERO
			$AnimatedSprite2D.play("dead")
			set_collision_layer_value(1, false)
			$AnimatedSprite2D.animation_finished.connect(queue_free)
			set_collision_layer_value(1, false)
			$AnimatedSprite2D.animation_finished.connect(queue_free)

func _state_idle() -> void:
	velocity = Vector2.ZERO
	if not player:
		$AnimatedSprite2D.play("idle")
		return
	var dist = global_position.distance_to(player.global_position)
	if dist <= IDLE_DISTANCE:
		if player.global_position.x < global_position.x:
			$AnimatedSprite2D.play("walk_right")
		else:
			$AnimatedSprite2D.play("walk_left")
		_enter_state(State.DIVING)
	else:
		$AnimatedSprite2D.play("idle")


func _state_diving() -> void:
	velocity = Vector2.ZERO
	if not player:
		return
	# Actualizar animación y orientación según la posición actual del jugador
	if player.global_position.x < global_position.x:
		$AnimatedSprite2D.play("walk_left")
	else:
		$AnimatedSprite2D.play("walk_right")

func _state_stunned(delta: float) -> void:
	velocity = Vector2.ZERO
	stun_timer -= delta
	if stun_timer <= 0.0:
		_enter_state(State.IDLE)

func _on_hitbox_body_entered(body: Node) -> void:
	# Infligir daño al jugador al impactar durante el dive
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
