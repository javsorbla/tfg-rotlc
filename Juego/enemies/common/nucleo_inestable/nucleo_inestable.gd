extends CharacterBody2D

const DAMAGE: int = 10

const STUN_DURATION: float  = 3   # segundos inmovilizado al recibir daño
const IDLE_DISTANCE: float = 200.0  # distancia mínima para detectar al jugador
const GRAVITY: float = 700.0 

enum State { IDLE, ROLLING, STUNNED }

var current_state: State = State.IDLE
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
		State.ROLLING:
			_state_rolling()
		State.STUNNED:
			_state_stunned(delta)

	move_and_slide()


func _enter_state(new_state: State) -> void:
	current_state = new_state

	match new_state:
		State.IDLE:
			$AnimatedSprite2D.play("idle")

		State.ROLLING:
			$AnimatedSprite2D.play("rolling")


func _state_idle() -> void:
	velocity.x = 0

	if not player:
		return

	var dist = global_position.distance_to(player.global_position)

	if dist <= IDLE_DISTANCE:
		_enter_state(State.ROLLING)


func _state_rolling() -> void:
	velocity.x = 0


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
		take_damage(0)  # vida infinita


func take_damage(amount: int) -> void: 
	# Vida infinita
	stun_timer = STUN_DURATION
	_enter_state(State.STUNNED) 
	$AnimatedSprite2D.play("stunned")
