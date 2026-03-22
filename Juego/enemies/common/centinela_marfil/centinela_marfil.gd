extends CharacterBody2D

const MAX_HEALTH: int = 4
const DAMAGE: int = 1

const STUN_DURATION: float  = 1   # segundos inmovilizado al recibir daño
const IDLE_DISTANCE: float = 200.0  # distancia mínima para detectar al jugador
const LOSE_DISTANCE: float = 250.0
const GRAVITY: float = 700.0 

enum State { IDLE, ATTACK, DEAD }

var current_state: State = State.IDLE
var current_health: int = MAX_HEALTH
var player: Node2D = null
var stun_timer: float = 0.0


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")

	$EnemyHitbox.body_entered.connect(_on_enemy_hitbox_area_entered)
	$EnemyHitbox.area_entered.connect(_on_enemy_hurtbox_area_entered)

	_enter_state(State.IDLE)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0

	match current_state:
		State.IDLE:
			_state_idle()
		State.ATTACK:
			_state_attack()
		State.DEAD:
			pass

	move_and_slide()


func _enter_state(new_state: State) -> void:
	current_state = new_state

	match new_state:
		State.IDLE:
			$AnimatedSprite2D.play("shield")

		State.ATTACK:
			$AnimatedSprite2D.play("damaged")


func _state_idle() -> void:
	velocity.x = 0

	if not player:
		return

	var dist = global_position.distance_to(player.global_position)

	if dist <= IDLE_DISTANCE:
		_enter_state(State.ATTACK)


func _state_attack() -> void:
	velocity.x = 0
	velocity.y = 0
	if not player:
		_enter_state(State.IDLE)
		return
	var dist = global_position.distance_to(player.global_position)
	if dist > LOSE_DISTANCE:
		_enter_state(State.IDLE)
		return
	# Mirar al jugador
	$AnimatedSprite2D.flip_h = player.global_position.x > global_position.x


func _state_stunned(delta):
	stun_timer -= delta
	velocity.x = 0

	if stun_timer <= 0:
		_enter_state(State.IDLE)


func _on_enemy_hitbox_area_entered(area: Area2D): 
	if area.is_in_group("player_hurtbox"): 
		var player = area.get_parent() 
		if player.has_method("take_damage"): 
			player.take_damage(DAMAGE) 
			


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


func die() -> void:
	_enter_state(State.DEAD)
