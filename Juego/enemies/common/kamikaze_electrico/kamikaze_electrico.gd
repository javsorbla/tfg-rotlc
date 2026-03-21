extends CharacterBody2D

const MAX_HEALTH: int = 1
const DAMAGE: int = 10
const ATTACK_SPEED: float = 320.0
const SLEEP_DISTANCE: float = 250.0

enum State { SLEEP, ATTACK, EXPLODE, DEAD }

var current_state: State = State.SLEEP
var current_health: int = MAX_HEALTH
var player: Node2D = null
var attack_direction: Vector2 = Vector2.ZERO
var explode_timer: float = 0.0
var explode_from_death: bool = false
var dead_timer: float = 0.0


func _ready() -> void:
	current_health = MAX_HEALTH
	player = get_tree().get_first_node_in_group("player")

	$EnemyHitbox.area_entered.connect(_on_enemy_hitbox_area_entered)
	$EnemyHurtbox.area_entered.connect(_on_enemy_hurtbox_area_entered)

	_enter_state(State.SLEEP)


func _physics_process(delta: float) -> void:
	match current_state:
		State.SLEEP:
			_state_sleep()
		State.ATTACK:
			_state_attack(delta)
		State.EXPLODE:
			pass
		State.DEAD:
			_state_dead(delta)

	move_and_slide()


func _enter_state(new_state: State) -> void:
	current_state = new_state

	match new_state:
		State.SLEEP:
			velocity = Vector2.ZERO

		State.ATTACK:
			$AnimatedSprite2D.play("charged")
			if player:
				var head_pos = player.global_position + Vector2(0, 10)
				attack_direction = (head_pos - global_position).normalized()
				explode_timer = 0.0
				
		State.EXPLODE:
			velocity = Vector2.ZERO
			$AnimatedSprite2D.play("explode")
			if $EnemyHitbox:
				$EnemyHitbox.monitoring = false
				$EnemyHitbox.monitorable = false
			if player and global_position.distance_to(player.global_position) < 30.0:
				if explode_from_death:
					player.get_node("Health").is_invincible = false 
				player.get_node("Health").take_damage(DAMAGE)
			await get_tree().create_timer(0.75).timeout
			queue_free()
	
		State.DEAD:
			explode_from_death = false
			$AnimatedSprite2D.play("dead")
			if $EnemyHitbox:
				$EnemyHitbox.monitoring = false
				$EnemyHitbox.monitorable = false
				$EnemyHitbox.set_deferred("collision_layer", 0)
				$EnemyHitbox.set_deferred("collision_mask", 0)
			velocity = Vector2(0, 0)


func _state_sleep() -> void:
	velocity = Vector2.ZERO
	if not player:
		return

	var dist = global_position.distance_to(player.global_position)
	$Vision.target_position = player.global_position - global_position

	if dist <= SLEEP_DISTANCE and not $Vision.is_colliding():
		_enter_state(State.ATTACK)
		return

	$AnimatedSprite2D.play("sleep")


func _state_attack(delta: float) -> void:
	# Si entra en contacto con un muro o el jugador, explota
	if not player:
		_enter_state(State.SLEEP)
		return

	explode_timer += delta
	if explode_timer >= 1.2 or is_on_wall():
		_enter_state(State.EXPLODE)
		return

	velocity = attack_direction * ATTACK_SPEED
	$AnimatedSprite2D.flip_h = attack_direction.x >= 0
		

func _state_dead(delta: float) -> void:
	velocity.y += 800 * delta
	if is_on_floor():
		dead_timer += delta
		if dead_timer >= 2.0:
			_enter_state(State.EXPLODE)


func _on_enemy_hitbox_area_entered(area: Area2D):
	if area.is_in_group("player_hurtbox"):
		_enter_state(State.EXPLODE)


func _on_enemy_hurtbox_area_entered(area: Area2D):
	if area.is_in_group("player_hitbox"): 
		take_damage(1) 


func take_damage(amount: int) -> void:
	if current_state == State.DEAD or current_state == State.EXPLODE:
		return
	current_health -= amount
	if current_health <= 0:
		die()


func die() -> void:
	_enter_state(State.DEAD)
