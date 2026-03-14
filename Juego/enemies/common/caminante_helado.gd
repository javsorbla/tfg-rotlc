extends CharacterBody2D

var target: Node2D = null

@export_group("Balance base")
@export var base_health := 3
@export var base_contact_damage := 1
@export var base_move_speed := 50.0
@export var base_detection_range := 180.0
@export var base_attack_interval := 0.9

@export_group("Escalado")
@export_range(0, 10, 1) var appearance_tier := 1
@export_range(-1.0, 1.0, 0.01) var player_progression_override := -1.0

@export_group("Knockback")
@export var knockback_speed := 420.0
@export var knockback_distance := 72.0

var max_health = 3
var current_health = 3
var contact_damage = 1
var speed = 50.0
var detection_range = 180.0
var attack_interval = 0.9

var knockback_timer = 0.0
var hit_cooldown_timer = 0.0
var hit_cooldown = 0.9

var stop_distance = 0.0
var last_move_dir = -1.0

# --- NUEVO: stun + invulnerabilidad + parpadeo seguro ---
var is_invulnerable = false
var stun_timer = 0.0
var stun_duration = 0.5
var blink_timer = 0.0
var blink_interval = 0.1

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	target = _find_player_target()
	_apply_balanced_stats()

	if not $Hurtbox.body_entered.is_connected(_on_hurtbox_body_entered):
		$Hurtbox.body_entered.connect(_on_hurtbox_body_entered)

func _apply_balanced_stats():
	var player_progress = _read_player_progression_ratio()
	var tier_scale = float(max(0, appearance_tier - 1))

	var health_scale = 1.0 + tier_scale * 0.35 + player_progress * 0.45
	var damage_scale = 1.0 + tier_scale * 0.18 + player_progress * 0.30
	var speed_scale = 1.0 + tier_scale * 0.08 + player_progress * 0.20
	var detection_scale = 1.0 + tier_scale * 0.12 + player_progress * 0.25
	var attack_rate_scale = 1.0 + tier_scale * 0.10 + player_progress * 0.35

	max_health = max(1, int(round(base_health * health_scale)))
	current_health = max_health
	contact_damage = max(1, int(round(base_contact_damage * damage_scale)))
	speed = base_move_speed * speed_scale
	detection_range = base_detection_range * detection_scale
	attack_interval = max(0.2, base_attack_interval / attack_rate_scale)
	hit_cooldown = attack_interval

func _read_player_progression_ratio() -> float:
	if player_progression_override >= 0.0:
		return clamp(player_progression_override, 0.0, 1.0)

	var player_ref = target if target else _find_player_target()
	if not player_ref:
		return 0.0

	if player_ref.has_method("get_progression_ratio"):
		return clamp(float(player_ref.call("get_progression_ratio")), 0.0, 1.0)

	for prop_name in ["progression_ratio", "player_progression", "progression"]:
		var ratio_value = _get_numeric_property(player_ref, prop_name)
		if ratio_value >= 0.0:
			return clamp(ratio_value, 0.0, 1.0)

	for level_prop in ["level", "player_level"]:
		var level_value = _get_numeric_property(player_ref, level_prop)
		if level_value >= 0.0:
			return clamp((level_value - 1.0) / 9.0, 0.0, 1.0)

	return 0.0

func _get_numeric_property(node: Object, prop_name: String) -> float:
	for prop in node.get_property_list():
		if String(prop.name) == prop_name:
			var value = node.get(prop_name)
			if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
				return float(value)
	return -1.0

func _find_player_target() -> Node2D:
	for node in get_tree().get_nodes_in_group("player"):
		if node != self and node is Node2D and node.name == "Player":
			return node as Node2D
	for node in get_tree().get_nodes_in_group("player"):
		if node != self and node is Node2D:
			return node as Node2D
	return null

func _physics_process(delta):

	if hit_cooldown_timer > 0:
		hit_cooldown_timer -= delta

	# --- STUN ---
	if stun_timer > 0:
		stun_timer -= delta

		blink_timer -= delta
		if blink_timer <= 0:
			blink_timer = blink_interval
			# parpadeo seguro usando modulate
			var alpha = animated_sprite.modulate.a
			alpha = 1.0 if alpha == 0.0 else 0.0
			animated_sprite.modulate.a = alpha

		velocity.x = 0
		move_and_slide()
		return

	# restaurar modulate alfa si stun terminó
	if animated_sprite.modulate.a != 1.0:
		animated_sprite.modulate.a = 1.0

	if not is_on_floor():
		velocity += get_gravity() * delta
	elif knockback_timer <= 0:
		velocity.y = 0.0

	if not target:
		target = _find_player_target()
		_check_player_overlap()
		_update_animation_state()
		move_and_slide()
		return

	if knockback_timer > 0:
		knockback_timer -= delta
	else:
		var dx = target.global_position.x - global_position.x
		var distance_to_target = global_position.distance_to(target.global_position)

		if distance_to_target > detection_range:
			velocity.x = move_toward(velocity.x, 0.0, speed)
		else:
			last_move_dir = sign(dx)
			velocity.x = last_move_dir * speed

	_check_player_overlap()
	_update_animation_state()

	move_and_slide()

func _update_animation_state():

	if not target:
		animated_sprite.play("idle")
		return

	var distance_to_target = global_position.distance_to(target.global_position)
	var dx = target.global_position.x - global_position.x

	if distance_to_target > detection_range:
		animated_sprite.play("idle")
	elif dx < 0:
		animated_sprite.play("walk_left")
	elif dx > 0:
		animated_sprite.play("walk_right")
	else:
		animated_sprite.play("idle")

func _check_player_overlap():

	if knockback_timer > 0 or hit_cooldown_timer > 0:
		return

	for body in $Hurtbox.get_overlapping_bodies():
		if body is Node2D and (body.name == "Player" or body.is_in_group("player")):
			_apply_knockback_from_body(body as Node2D)
			break

func _on_hurtbox_body_entered(body):

	if knockback_timer > 0 or hit_cooldown_timer > 0:
		return

	if body is Node2D and (body.name == "Player" or body.is_in_group("player")):
		_apply_knockback_from_body(body as Node2D)

func _apply_knockback_from_body(body: Node2D):

	var away_x = sign(global_position.x - body.global_position.x)

	if away_x == 0:
		away_x = last_move_dir

	if away_x == 0:
		away_x = -1.0

	var knock_direction = Vector2(away_x, -0.15).normalized()

	velocity = knock_direction * knockback_speed
	knockback_timer = knockback_distance / knockback_speed
	hit_cooldown_timer = hit_cooldown

	if body.has_method("take_damage"):
		body.call("take_damage", contact_damage)

func take_damage(amount: int):

	if is_invulnerable:
		return

	current_health -= amount

	if current_health <= 0:
		die()
		return

	# cancelar knockback actual
	knockback_timer = 0
	velocity = Vector2.ZERO

	# activar stun + invulnerabilidad
	is_invulnerable = true
	stun_timer = stun_duration
	blink_timer = blink_interval

	await get_tree().create_timer(stun_duration).timeout

	is_invulnerable = false
	# restaurar alfa seguro
	animated_sprite.modulate.a = 1.0

func die():
	queue_free()