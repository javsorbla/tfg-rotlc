extends CharacterBody2D

enum State { IDLE, HURT, KNOCKED }

@export var knock_damage_threshold: int = 4
@export var knock_duration: float = 2.0
@export var hurt_anim_duration: float = 0.4

var current_state: State = State.IDLE
var accumulated_damage: int = 0
var knock_timer: float = 0.0
var hurt_timer: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	if not $EnemyHurtbox.area_entered.is_connected(_on_enemy_hurtbox_area_entered):
		$EnemyHurtbox.area_entered.connect(_on_enemy_hurtbox_area_entered)
	_enter_state(State.IDLE)


func _physics_process(delta: float) -> void:
	velocity = Vector2.ZERO

	if knock_timer > 0.0:
		knock_timer -= delta
		if knock_timer <= 0.0 and current_state == State.KNOCKED:
			_enter_state(State.IDLE)
		return

	if hurt_timer > 0.0:
		hurt_timer -= delta
		if hurt_timer <= 0.0 and current_state == State.HURT:
			_enter_state(State.IDLE)
		return

	if current_state != State.IDLE:
		_enter_state(State.IDLE)


func take_damage(amount: int) -> void:
	if amount <= 0:
		return

	if current_state == State.KNOCKED:
		knock_timer = max(knock_timer, knock_duration)
		return

	accumulated_damage += amount
	if accumulated_damage >= knock_damage_threshold:
		accumulated_damage = 0
		_enter_state(State.KNOCKED)
		knock_timer = knock_duration
		return

	_enter_state(State.HURT)
	hurt_timer = hurt_anim_duration


func _enter_state(new_state: State) -> void:
	current_state = new_state

	match new_state:
		State.IDLE:
			sprite.play("idle")
		State.HURT:
			sprite.play("receive_damage")
		State.KNOCKED:
			sprite.play("knock_up")
			
func _on_enemy_hurtbox_area_entered(area: Area2D):
	if area.is_in_group("player_hitbox"):
		var player_node = get_tree().get_first_node_in_group("player")
		var multiplier = player_node.damage_multiplier if player_node else 1.0
		take_damage(int(1 * multiplier)) 
