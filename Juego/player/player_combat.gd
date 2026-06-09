extends Node

const ATTACK_DURATION = 0.3
const HITBOX_OFFSET_X = 14
const HITBOX_OFFSET_Y = 22
const HITSTOP_DURATION = 0.05
const PUNCH_SOUND := preload("res://music/player/punch.mp3")

var is_attacking = false
var attack_timer = 0.0
var hitstop_timer = 0.0
var _punch_player: AudioStreamPlayer

@onready var player = get_parent()
@onready var hitbox = get_parent().get_node("AttackHitbox")
@onready var sprite = get_parent().get_node("AnimatedSprite2D")
@onready var hit_particles_scene = preload("res://scenes/effects/HitParticles.tscn")

func _ready():
	_punch_player = AudioStreamPlayer.new()
	_punch_player.stream = PUNCH_SOUND
	_punch_player.bus = &"EFX"
	_punch_player.volume_db = -6.0
	add_child(_punch_player)
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
		_punch_player.play()
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
		NakamaManager.add_damage_dealt(damage)
	elif area.is_in_group("enemy_hurtbox"):
		var target := area.get_parent()
		var hit_position: Vector2 = area.global_position
		if target != null and target.is_in_group("umbra_boss") and target.has_method("take_damage"):
			var umbra_damage := maxi(1, int(round(float(player.damage_multiplier))))
			target.take_damage(umbra_damage)
			NakamaManager.add_damage_dealt(umbra_damage)
		else:
			NakamaManager.add_damage_dealt(maxi(1, int(round(float(player.damage_multiplier)))))
		var delay = 0.05
		await get_tree().create_timer(delay).timeout
		spawn_hit_particles(hit_position)
		hitstop_timer = HITSTOP_DURATION
