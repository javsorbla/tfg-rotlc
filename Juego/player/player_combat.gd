extends Node

const ATTACK_DURATION = 0.3
const HITBOX_OFFSET_X = 14
const HITBOX_OFFSET_Y = 22
const HITSTOP_DURATION = 0.05

var is_attacking = false
var attack_timer = 0.0
var hitstop_timer = 0.0

@onready var player = get_parent()
@onready var hitbox = get_parent().get_node("AttackHitbox")
@onready var sprite = get_parent().get_node("AnimatedSprite2D")
@onready var hit_particles_scene = preload("res://scenes/effects/HitParticles.tscn")

func _ready():
	hitbox.monitoring = false
	hitbox.monitorable = false
	hitbox.visible = false
	hitbox.area_entered.connect(_on_attack_hitbox_area_entered)

func process(delta):
	_handle_attack(delta)
	_handle_hitstop(delta)

func _handle_attack(delta):
	if is_attacking:
		attack_timer -= delta
		if attack_timer <= 0:
			is_attacking = false
			hitbox.monitoring = false
			hitbox.monitorable = false
			hitbox.visible = false
		return

	if Input.is_action_just_pressed("attack") and player.can_attack:
		is_attacking = true
		attack_timer = ATTACK_DURATION
		hitbox.monitoring = true
		hitbox.monitorable = true
		hitbox.visible = true
		if Input.is_action_pressed("aim_up"):
			hitbox.position = Vector2(0, -HITBOX_OFFSET_Y)
		elif Input.is_action_pressed("aim_down"):
			hitbox.position = Vector2(0, HITBOX_OFFSET_Y)
		elif Input.is_action_pressed("aim_left"):
			hitbox.position = Vector2(-HITBOX_OFFSET_X, 0)
		elif Input.is_action_pressed("aim_right"):
			hitbox.position = Vector2(HITBOX_OFFSET_X, 0)
		else:
			hitbox.position = Vector2(HITBOX_OFFSET_X * player.last_direction, 0)

func _handle_hitstop(delta):
	if hitstop_timer > 0:
		hitstop_timer -= delta
		Engine.time_scale = 0.5
	else:
		Engine.time_scale = 1.0

func spawn_hit_particles(pos: Vector2):
	var particles = hit_particles_scene.instantiate()
	player.get_parent().add_child(particles)
	particles.global_position = pos
	particles.play()

func _on_attack_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("boss_core"):
		var damage = int(player.damage_multiplier)
		area.get_parent().take_damage(damage)
		spawn_hit_particles(area.global_position)
		hitstop_timer = HITSTOP_DURATION
	elif area.is_in_group("enemy_hurtbox"):
		spawn_hit_particles(area.global_position)
		hitstop_timer = HITSTOP_DURATION
