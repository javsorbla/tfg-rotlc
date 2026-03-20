extends CharacterBody2D

const MAX_HEALTH: int = 1
const DAMAGE: int = 10
const IDLE_DISTANCE: float = 200.0
const LOSE_DISTANCE: float = 350.0

enum State { IDLE, ATTACK, DEAD }

var current_state: State = State.IDLE
var player: Node2D = null
var health: int = 1


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")

	$EnemyHitbox.body_entered.connect(_on_enemy_hitbox_area_entered)
	$EnemyHitbox.area_entered.connect(_on_enemy_hurtbox_area_entered)

	_enter_state(State.IDLE)


func _physics_process(delta: float) -> void:

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
			$AnimatedSprite2D.play("idle")

		State.ATTACK:
			$AnimatedSprite2D.play("charged")


func _state_idle() -> void:
	velocity.x = 0
	velocity.y = 0 

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
	if player.global_position.x < global_position.x:
		$AnimatedSprite2D.flip_h = false
	else:
		$AnimatedSprite2D.flip_h = true


func _on_enemy_hitbox_area_entered(area: Area2D): 
	if area.is_in_group("player_hurtbox"): 
		var player = area.get_parent() 
		if player.has_method("take_damage"): 
			player.take_damage(DAMAGE) 


func _on_enemy_hurtbox_area_entered(area: Area2D):
	if area.is_in_group("player_hitbox"): 
		take_damage(1)


func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		_enter_state(State.DEAD)
		$AnimatedSprite2D.play("stunned")
