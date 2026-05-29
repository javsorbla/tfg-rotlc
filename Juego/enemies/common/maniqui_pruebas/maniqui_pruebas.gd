extends CharacterBody2D

enum State { IDLE, HURT, KNOCKED }

@export var knock_damage_threshold: int = 4
@export var knock_duration: float = 2.0
@export var hurt_anim_duration: float = 0.4
@export var damage_flash_duration: float = 0.08
@export var damage_flash_color: Color = Color(2.2, 2.2, 2.2, 1.0)

var current_state: State = State.IDLE
var accumulated_damage: int = 0
var knock_timer: float = 0.0
var hurt_timer: float = 0.0
var damage_flash_tween: Tween = null
var _original_sprite_color: Color = Color.WHITE

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hit_particles_scene = preload("res://scenes/effects/HitParticles.tscn")

func _ready() -> void:
	_original_sprite_color = sprite.modulate
	var hurtbox := get_node_or_null("EnemyHurtbox")
	if hurtbox:
		if not hurtbox.area_entered.is_connected(_on_enemy_hurtbox_area_entered):
			hurtbox.area_entered.connect(_on_enemy_hurtbox_area_entered)
	sprite.animation_finished.connect(_on_animation_finished)
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
	_play_damage_feedback()
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
			sprite.frame = 0
		State.HURT:
			sprite.play("receive_damage")
			sprite.frame = 0
		State.KNOCKED:
			sprite.play("knock_up")
			sprite.frame = 0

func _on_animation_finished() -> void:
	if current_state == State.HURT:
		sprite.stop()
	elif current_state == State.KNOCKED:
		sprite.stop()

func _on_enemy_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_hitbox"):
		var player_node = get_tree().get_first_node_in_group("player")
		var multiplier := 1.0
		if player_node and "damage_multiplier" in player_node:
			multiplier = player_node.damage_multiplier
		take_damage(int(1 * multiplier))

func _play_damage_feedback() -> void:
	_play_damage_flash()
	_spawn_hit_particles()

func _play_damage_flash() -> void:
	if damage_flash_tween:
		damage_flash_tween.kill()
	damage_flash_tween = create_tween()
	damage_flash_tween.tween_property(sprite, "modulate", damage_flash_color, damage_flash_duration)
	damage_flash_tween.tween_property(sprite, "modulate", _original_sprite_color, damage_flash_duration)

func _spawn_hit_particles() -> void:
	if not hit_particles_scene:
		return
	var particles = hit_particles_scene.instantiate()
	get_parent().add_child(particles)
	particles.global_position = global_position
	particles.play()
