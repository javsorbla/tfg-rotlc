extends CharacterBody2D

const DAMAGE: int = 2
const STUN_DURATION: float = 3.0
const SLEEP_DISTANCE: float = 200.0
const GRAVITY: float = 700.0
const ROLL_SPEED: float = 120.0
const JUMP_VELOCITY: float = -150.0

enum State { SLEEP, JUMP, ROLLING, STUNNED }

var current_state: State = State.SLEEP
var player: Node2D = null
var stun_timer: float = 0.0
var roll_direction: float = 1.0
var has_hit_player: bool = false


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	
	$EnemyHitbox.body_entered.connect(_on_enemy_hitbox_area_entered)
	$EnemyHurtbox.area_entered.connect(_on_enemy_hurtbox_area_entered)
	
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
			
	move_and_slide()


func _enter_state(new_state: State) -> void:
	current_state = new_state
	match new_state:
		State.SLEEP:
			$AnimatedSprite2D.rotation = 0.0
			velocity.x = 0
			$AnimatedSprite2D.play("sleep")
		State.JUMP:
			# Determinar dirección según posición del jugador
			if player:
				roll_direction = sign(player.global_position.x - global_position.x)
			velocity.y = JUMP_VELOCITY
			velocity.x = 0
			$AnimatedSprite2D.play("idle")
			$AnimatedSprite2D.flip_h = roll_direction > 0 
		State.ROLLING:
			$AnimatedSprite2D.play("rolling")
			$AnimatedSprite2D.flip_h = roll_direction > 0  
		State.STUNNED:
			$AnimatedSprite2D.rotation = 0.0
			velocity.x = 0
			velocity.y = 0
			$AnimatedSprite2D.play("stunned")


func _state_sleep() -> void:
	velocity.x = 0
	if not player:
		return
	var dist = global_position.distance_to(player.global_position)
	if dist <= SLEEP_DISTANCE:
		_enter_state(State.JUMP)


func _state_jump() -> void:
	velocity.x = 0
	if is_on_floor():
		_enter_state(State.ROLLING)


func _state_rolling() -> void:
	velocity.x = ROLL_SPEED * roll_direction


func _state_stunned(delta: float) -> void:
	stun_timer -= delta
	velocity.x = move_toward(velocity.x, 0, 100.0 * delta)  # frena progresivamente
	if stun_timer <= 0:
		_enter_state(State.SLEEP)


func _on_enemy_hitbox_area_entered(area: Area2D): 
	if area.is_in_group("player_hurtbox"): 
		var player = area.get_parent() 
		has_hit_player = true 
		if player.has_method("take_damage"): 
			player.take_damage(DAMAGE) 
		if player is CharacterBody2D: 
			var dir = (player.global_position - global_position).normalized() 
			dir.y = 0 
			player.velocity = dir * 230 


func _on_enemy_hurtbox_area_entered(area: Area2D):
	if area.is_in_group("player_hitbox"):
		take_damage(0)


func take_damage(amount: int) -> void:
	stun_timer = STUN_DURATION
	_enter_state(State.STUNNED)
	
	if player and player is CharacterBody2D:
		var dir = sign(player.global_position.x - global_position.x)
		# retroceso cuando el jugador golpea al enemigo
		velocity.x = -dir * 80.0 
		velocity.y = -60.0
		player.velocity.x = dir * 50.0
		player.velocity.y = -60.0
