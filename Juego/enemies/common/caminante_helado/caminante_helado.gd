extends CharacterBody2D

const PLAYER_KNOCKBACK_TIMER_META := "caminante_helado_knockback_timer"
const PLAYER_KNOCKBACK_SPEED_META := "caminante_helado_knockback_speed"

var target: Node2D = null

@export_group("Balance base")
@export var base_health := 3
@export var base_contact_damage := 1
@export var base_move_speed := 50.0
@export var base_detection_range := 260.0
@export var base_attack_interval := 0.9

@export_group("Escalado")
@export_range(0, 10, 1) var appearance_tier := 1
@export_range(-1.0, 1.0, 0.01) var player_progression_override := -1.0

@export_group("Knockback")
@export var player_knockback_force := 350.0
@export var player_knockback_duration := 0.35

@export_group("Patrulla")
@export var patrol_distance := 48.0
@export var patrol_speed_multiplier := 0.45

@export_group("Vision")
@export var vision_memory_time := 0.2
@export var vision_eye_height := 10.0
@export var vision_overhead_x_tolerance := 28.0
@export var vision_overhead_y_tolerance := 42.0

var max_health = 3
var current_health = 3
var contact_damage = 1
var speed = 50.0
var detection_range = 180.0
var attack_interval = 0.9

var hit_cooldown_timer = 0.0
var hit_cooldown = 0.9
var hit_pause_timer = 0.0

@export var hit_pause_duration := 1.0

var stop_distance = 0.0
var last_move_dir = -1.0
var patrol_origin_x = 0.0
var patrol_direction = -1.0
var target_visible_timer = 0.0
var has_spotted_target = false

# --- NUEVO: stun + invulnerabilidad + parpadeo seguro ---
var is_invulnerable = false
var stun_timer = 0.0
var stun_duration = 0.5
var blink_timer = 0.0
var blink_interval = 0.1
var is_dead = false
var hit_from_right := false

@export var death_time := 1.5

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	target = _find_player_target()
	patrol_origin_x = global_position.x
	patrol_direction = last_move_dir
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

func _process_player_knockback(delta: float) -> void:
	if not target or not is_instance_valid(target):
		return

	if not target.has_meta(PLAYER_KNOCKBACK_TIMER_META):
		return

	var time_left := float(target.get_meta(PLAYER_KNOCKBACK_TIMER_META)) - delta
	if time_left <= 0.0:
		target.remove_meta(PLAYER_KNOCKBACK_TIMER_META)
		target.remove_meta(PLAYER_KNOCKBACK_SPEED_META)
		return

	var horizontal_speed := float(target.get_meta(PLAYER_KNOCKBACK_SPEED_META))
	var progress: float = clamp(time_left / max(player_knockback_duration, 0.001), 0.0, 1.0)
	if target is CharacterBody2D:
		var player_body := target as CharacterBody2D
		var sustained_speed: float = horizontal_speed * max(0.18, progress)
		if abs(player_body.velocity.x) < abs(sustained_speed):
			player_body.velocity.x = sustained_speed
	target.set_meta(PLAYER_KNOCKBACK_TIMER_META, time_left)

func _get_facing_direction() -> float:
	if abs(velocity.x) > 5.0:
		return sign(velocity.x)
	if last_move_dir != 0:
		return last_move_dir
	if patrol_direction != 0:
		return patrol_direction
	return -1.0

func _can_see_target() -> bool:
	if not target or not is_instance_valid(target):
		has_spotted_target = false
		return false

	var dx = target.global_position.x - global_position.x
	var distance_to_target = global_position.distance_to(target.global_position)
	if distance_to_target > detection_range:
		has_spotted_target = false
		return false

	if not _has_line_of_sight():
		return false

	var facing_dir = _get_facing_direction()
	var is_facing_target = dx == 0 or sign(dx) == facing_dir
	var is_target_overhead = _is_target_overhead(dx)

	if has_spotted_target:
		if is_facing_target or is_target_overhead:
			return true

		has_spotted_target = false
		return false

	if dx == 0:
		has_spotted_target = true
		return true

	if is_facing_target:
		has_spotted_target = true
		return true

	return false

func _is_target_overhead(dx: float) -> bool:
	if not target or not is_instance_valid(target):
		return false

	var dy = target.global_position.y - global_position.y
	var near_x = abs(dx) <= vision_overhead_x_tolerance
	var above_enemy = dy < 0 and abs(dy) <= vision_overhead_y_tolerance
	return near_x and above_enemy

func _has_line_of_sight() -> bool:
	if not target or not is_instance_valid(target):
		return false

	var space_state := get_world_2d().direct_space_state
	var eye_from := global_position + Vector2(0.0, -vision_eye_height)
	var eye_to := target.global_position + Vector2(0.0, -vision_eye_height)
	var query := PhysicsRayQueryParameters2D.create(eye_from, eye_to)
	query.exclude = [self]
	query.collide_with_areas = false
	var result := space_state.intersect_ray(query)

	if result.is_empty():
		return true

	return result.get("collider") == target

func _update_patrol_movement() -> void:
	var left_limit = patrol_origin_x - patrol_distance
	var right_limit = patrol_origin_x + patrol_distance

	if patrol_direction < 0 and global_position.x <= left_limit:
		patrol_direction = 1.0
	elif patrol_direction > 0 and global_position.x >= right_limit:
		patrol_direction = -1.0

	last_move_dir = patrol_direction
	velocity.x = patrol_direction * speed * patrol_speed_multiplier

func _physics_process(delta):
	if not target:
		target = _find_player_target()

	_process_player_knockback(delta)

	if is_dead:
		return

	if hit_cooldown_timer > 0:
		hit_cooldown_timer -= delta

	if hit_pause_timer > 0:
		hit_pause_timer -= delta

	# --- STUN ---
	if stun_timer > 0:
		stun_timer -= delta
		if animated_sprite.animation != "dazed":
			animated_sprite.flip_h = hit_from_right
			animated_sprite.play("dazed")

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
	else:
		velocity.y = 0.0

	if not target:
		_check_player_overlap()
		_update_animation_state()
		move_and_slide()
		return

	var dx = target.global_position.x - global_position.x
	var sees_target_now = _can_see_target()
	if sees_target_now:
		target_visible_timer = vision_memory_time
	else:
		target_visible_timer = max(0.0, target_visible_timer - delta)

	var sees_target = sees_target_now or target_visible_timer > 0.0

	if hit_pause_timer > 0:
		velocity.x = move_toward(velocity.x, 0.0, speed * 4)
	elif sees_target:
		if sees_target_now and dx != 0:
			last_move_dir = sign(dx)
		velocity.x = last_move_dir * speed
	else:
		_update_patrol_movement()

	_check_player_overlap()
	_update_animation_state()

	move_and_slide()

func _update_animation_state():

	animated_sprite.flip_h = false

	if hit_pause_timer > 0 and abs(velocity.x) < 5.0:
		animated_sprite.play("idle")
		return

	if abs(velocity.x) < 5.0:
		animated_sprite.play("idle")
		return

	if velocity.x < 0:
		animated_sprite.play("walk_left")
	elif velocity.x > 0:
		animated_sprite.play("walk_right")
	else:
		animated_sprite.play("idle")

func _check_player_overlap():
	if is_dead:
		return

	if hit_cooldown_timer > 0:
		return

	for body in $Hurtbox.get_overlapping_bodies():
		if body is Node2D and (body.name == "Player" or body.is_in_group("player")):
			_apply_knockback_from_body(body as Node2D)
			break

func _on_hurtbox_body_entered(body):
	if is_dead:
		return

	if hit_cooldown_timer > 0:
		return

	if body is Node2D and (body.name == "Player" or body.is_in_group("player")):
		_apply_knockback_from_body(body as Node2D)

func _apply_knockback_from_body(body: Node2D):

	# El jugador sale empujado en dirección opuesta al enemigo
	var push_x = sign(body.global_position.x - global_position.x)

	if push_x == 0:
		push_x = -last_move_dir

	if push_x == 0:
		push_x = 1.0

	var knock_direction = Vector2(push_x * 0.45, -1.0).normalized()
	if body is CharacterBody2D:
		var player_body := body as CharacterBody2D
		player_body.velocity = knock_direction * player_knockback_force
		player_body.set_meta(PLAYER_KNOCKBACK_TIMER_META, player_knockback_duration)
		player_body.set_meta(PLAYER_KNOCKBACK_SPEED_META, knock_direction.x * player_knockback_force)

	hit_pause_timer = hit_pause_duration
	hit_cooldown_timer = hit_cooldown

	if body.has_method("take_damage"):
		body.call("take_damage", contact_damage)

func take_damage(amount: int):
	if is_dead:
		return

	if is_invulnerable:
		return

	if not target:
		target = _find_player_target()

	has_spotted_target = true
	target_visible_timer = vision_memory_time

	# guardar de qué lado vino el golpe (donde está el jugador)
	if target:
		hit_from_right = target.global_position.x > global_position.x

	current_health -= amount

	if current_health <= 0:
		die()
		return

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
	if is_dead:
		return

	is_dead = true
	is_invulnerable = true
	velocity = Vector2.ZERO
	hit_cooldown_timer = 0.0

	if has_node("Hurtbox"):
		$Hurtbox.monitoring = false
		$Hurtbox.set_deferred("collision_layer", 0)
		$Hurtbox.set_deferred("collision_mask", 0)

	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)

	if animated_sprite:
		animated_sprite.modulate.a = 1.0
		animated_sprite.flip_h = hit_from_right
		animated_sprite.play("dead")

	await get_tree().create_timer(death_time).timeout
	queue_free()
