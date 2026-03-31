extends CharacterBody2D

signal defeated(umbra_won: bool)

const UMBRA_SHADER := preload("res://enemies/bosses/umbra/Umbra.gdshader")
const DARKNESS_ZONE_SCRIPT := preload("res://enemies/bosses/umbra/darkness_zone.gd")

# Constantes de movimiento (similares a Iris)
const SPEED = 140.0
const JUMP_VELOCITY = -300.0
const DASH_SPEED = 280.0
const DASH_DURATION = 0.20
const ACCELERATION = 900.0
const FRICTION = 650.0

# Constantes de combate
const MAX_HEALTH = 3
const DAMAGE = 1
const ATTACK_DURATION = 0.3
const ATTACK_COOLDOWN = 1.0
const INVINCIBILITY_DURATION = 0.5
const POWER_SPEED_MULTIPLIER = 1.45
const POWER_DAMAGE_MULTIPLIER = 2

const TINT_CYAN_PRIMARY := Color(0.0, 0.85, 1.0, 1.0)
const TINT_RED_PRIMARY := Color(1.0, 0.2, 0.2, 1.0)
const TINT_YELLOW_PRIMARY := Color(1.0, 0.9, 0.0, 1.0)

# Variables de movimiento
var can_double_jump = false
var was_on_floor = false
var is_dashing = false
var dash_timer = 0.0
var dash_cooldown_timer = 0.0
var dash_direction = 1.0
var air_dash_used = false
var last_direction = 1

# Variables de combate
var current_health = MAX_HEALTH
var is_attacking = false
var attack_timer = 0.0
var attack_cooldown_timer = 0.0
var is_invincible = false
var invincibility_timer = 0.0

# Variables de IA
var ai_move_direction = 0
var ai_should_jump = false
var ai_should_attack = false
var ai_should_dash = false
var ai_should_use_power = false
var is_active = false

var _last_action_received_time := 0.0
var _encounter_reported := false
var _darkness_cooldown_timer := 0.0
var _power_active := false
var _power_timer := 0.0
var _power_cooldown_timer := 0.0
var _jump_cooldown_timer := 0.0
var _double_jump_cooldown_timer := 0.0
var _darkness_try_timer := 0.0
var _prev_ai_should_jump := false
var _prev_ai_should_dash := false

const ACTION_TIMEOUT_SECONDS := 0.35
const HEURISTIC_ATTACK_DISTANCE := 44.0
const HEURISTIC_DASH_DISTANCE := 180.0
const AUTO_ATTACK_DISTANCE_X := 72.0
const AUTO_ATTACK_DISTANCE_Y := 44.0

@export var force_heuristic_only := false
@export var debug_combat_logs := false
@export var despawn_on_death := true
@export var jump_cooldown_seconds := 0.85
@export var double_jump_cooldown_seconds := 1.30
@export var dash_cooldown_seconds := 2.35
@export var darkness_cast_cooldown := 5.0
@export var darkness_zone_radius := 36.0
@export var darkness_zone_duration := 2.8
@export var darkness_zone_tick_damage := 1
@export var darkness_zone_tick_interval := 0.60
@export var darkness_zone_arming_delay := 0.55
@export var darkness_spawn_offset_x := 0.0
@export var darkness_spawn_offset_y := 0.0
@export var debug_darkness_logs := false
@export var power_duration_cyan := 3.8
@export var power_duration_red := 3.2
@export var power_duration_yellow := 2.4
@export var power_cooldown_cyan := 4.2
@export var power_cooldown_red := 5.5
@export var power_cooldown_yellow := 7.5
@export var darkness_requires_power := false
@export var darkness_available_in_all_powers := true
@export var darkness_try_interval := 0.25
@export var darkness_try_chance := 1.0
@export var darkness_min_cast_distance := 34.0
@export var darkness_max_cast_distance := 260.0
@export var darkness_cast_interval_seconds := 6.0
@export var darkness_relax_distance_checks := true
@export_enum("auto", "cyan", "red", "yellow") var forced_power := "auto"

# Variables de poder
var current_power = "none"  # none, cyan, red, yellow

@onready var sprite = $AnimatedSprite2D
@onready var attack_hitbox = $AttackHitbox
@onready var hurtbox = $Hurtbox
@onready var ai_controller = $AIController2D

var _darkness_container: Node2D

func _ready():
	add_to_group("umbra_boss")
	attack_hitbox.monitoring = false
	attack_hitbox.monitorable = false
	hurtbox.monitorable = true
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	attack_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)
	attack_hitbox.area_entered.connect(_on_attack_hitbox_area_entered)
	_ensure_visual_shader()
	_ensure_darkness_container()
	# Asignar poder según nivel
	_assign_power()
	_apply_persistent_difficulty()
	var player = get_tree().get_first_node_in_group("player")
	if player:
		ai_controller.init(player)

func _assign_power():
	if forced_power != "auto":
		current_power = forced_power
		return

	var level = GameState.current_level if "current_level" in GameState else 1
	match level:
		1: current_power = "cyan"
		2: current_power = "red"
		3: current_power = "yellow"

func _physics_process(delta):
	if not is_active:
		return

	if force_heuristic_only or _should_use_heuristic():
		_use_heuristic()

	var jump_pressed := ai_should_jump and not _prev_ai_should_jump
	var dash_pressed := ai_should_dash and not _prev_ai_should_dash
	
	_handle_timers(delta)
	_handle_gravity(delta)
	_handle_movement(delta)
	_handle_jump(jump_pressed)
	_handle_dash(delta, dash_pressed)
	_handle_attack(delta)
	_apply_pattern_overrides()
	_handle_power()
	_update_animation()
	_update_power_visuals()
	
	was_on_floor = is_on_floor()
	_prev_ai_should_jump = ai_should_jump
	_prev_ai_should_dash = ai_should_dash
	move_and_slide()


func _apply_persistent_difficulty() -> void:
	var difficulty_scale := GameState.get_umbra_difficulty_scale()
	current_health = int(round(float(MAX_HEALTH) * difficulty_scale))

func _handle_timers(delta):
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
	if _darkness_cooldown_timer > 0:
		_darkness_cooldown_timer -= delta
	if _darkness_try_timer > 0:
		_darkness_try_timer -= delta
	if _power_cooldown_timer > 0:
		_power_cooldown_timer -= delta
	if _jump_cooldown_timer > 0:
		_jump_cooldown_timer -= delta
	if _double_jump_cooldown_timer > 0:
		_double_jump_cooldown_timer -= delta
	if _power_active:
		_power_timer -= delta
		if _power_timer <= 0.0:
			_power_active = false
			_power_cooldown_timer = _get_power_cooldown(current_power)
	if invincibility_timer > 0:
		invincibility_timer -= delta
		if invincibility_timer <= 0:
			is_invincible = false
			hurtbox.monitorable = true

func _handle_gravity(delta):
	if not is_on_floor():
		velocity += get_gravity() * delta

func _handle_movement(delta):
	if is_dashing:
		return
	if ai_move_direction != 0:
		last_direction = ai_move_direction
		velocity.x = move_toward(velocity.x, ai_move_direction * _get_speed(), ACCELERATION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)

func _get_speed():
	# Cyan aumenta la velocidad
	if current_power == "cyan" and _is_power_active():
		return SPEED * POWER_SPEED_MULTIPLIER
	return SPEED

func _handle_jump(jump_pressed: bool):
	if is_dashing:
		return
	if not jump_pressed:
		return

	if is_on_floor() and _jump_cooldown_timer <= 0.0:
		velocity.y = JUMP_VELOCITY
		can_double_jump = true
		_jump_cooldown_timer = jump_cooldown_seconds
		return

	if can_double_jump and _double_jump_cooldown_timer <= 0.0:
		velocity.y = JUMP_VELOCITY
		can_double_jump = false
		_double_jump_cooldown_timer = double_jump_cooldown_seconds
	if was_on_floor and not is_on_floor() and velocity.y >= 0:
		can_double_jump = true

func _handle_dash(delta, dash_pressed: bool):
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false
			velocity.x = dash_direction * SPEED * 0.2
		else:
			velocity.x = dash_direction * DASH_SPEED
		return
	
	if dash_pressed and dash_cooldown_timer <= 0 and (is_on_floor() or not air_dash_used):
		is_dashing = true
		dash_timer = DASH_DURATION
		dash_cooldown_timer = dash_cooldown_seconds
		if not is_on_floor():
			air_dash_used = true
		dash_direction = ai_move_direction if ai_move_direction != 0 else last_direction
		velocity.y = 0

	if is_on_floor():
		air_dash_used = false

func _handle_attack(delta):
	if is_attacking:
		velocity.x = 0.0
		attack_timer -= delta
		if attack_timer <= 0:
			is_attacking = false
			attack_hitbox.monitoring = false
			attack_hitbox.monitorable = false
		return

	var auto_attack := false
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		var rel: Vector2 = player.global_position - global_position
		auto_attack = absf(rel.x) <= AUTO_ATTACK_DISTANCE_X and absf(rel.y) <= AUTO_ATTACK_DISTANCE_Y
		if auto_attack and absf(rel.x) > 6.0:
			last_direction = signi(int(rel.x))

	if (ai_should_attack or auto_attack) and attack_cooldown_timer <= 0:
		is_attacking = true
		ai_move_direction = 0
		attack_timer = ATTACK_DURATION
		attack_cooldown_timer = ATTACK_COOLDOWN
		attack_hitbox.monitoring = true
		attack_hitbox.monitorable = true
		# Posicionar hitbox según dirección
		attack_hitbox.position = Vector2(14 * last_direction, 0)
		if debug_combat_logs:
			print("Umbra ATTACK start | ai=", ai_should_attack, " auto=", auto_attack, " dir=", last_direction)
		


func _apply_pattern_overrides() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return

	var rel := player.global_position - global_position
	var abs_x := absf(rel.x)

	if current_power == "yellow" and current_health <= int(ceil(float(MAX_HEALTH) * 0.45)):
		ai_should_use_power = true
	elif current_power == "red" and abs_x <= 120.0:
		ai_should_use_power = true
	elif current_power == "cyan" and abs_x > 140.0:
		ai_should_use_power = true

	if player.has_method("get") and bool(player.get("is_dashing")) and abs_x < 95.0 and dash_cooldown_timer <= 0.0:
		ai_should_dash = true

func _handle_power():
	if _darkness_try_timer <= 0.0:
		_darkness_try_timer = darkness_cast_interval_seconds
		_try_cast_darkness_zone()

	if ai_should_use_power and not _power_active and _power_cooldown_timer <= 0.0:
		_power_active = true
		_power_timer = _get_power_duration(current_power)

	# Amarillo activa escudo
	if current_power == "yellow" and _is_power_active():
		is_invincible = true
		hurtbox.monitorable = false
	elif current_power == "yellow" and not _is_power_active():
		if invincibility_timer <= 0.0:
			is_invincible = false
			hurtbox.monitorable = true

	var darkness_power_gate := (not darkness_requires_power) or _is_power_active()
	var darkness_power_type_gate := darkness_available_in_all_powers or current_power == "red"
	if not (darkness_power_gate and darkness_power_type_gate):
		_darkness_try_timer = minf(_darkness_try_timer, 0.6)

func _update_animation():
	if is_dashing:
		return
	if is_attacking:
		sprite.play("attack")
		return
	if not is_on_floor():
		pass
	elif velocity.x > 0:
		sprite.play("run")
	elif velocity.x < 0:
		sprite.play("run")
	else:
		sprite.play("idle")
	
	if velocity.x > 0:
		sprite.flip_h = false
	elif velocity.x < 0:
		sprite.flip_h = true

func take_damage(amount: int):
	if is_invincible:
		return
	current_health -= amount
	is_invincible = true
	invincibility_timer = INVINCIBILITY_DURATION
	hurtbox.monitorable = false
	if current_health <= 0:
		die()

func die():
	# Guardar métricas para el siguiente encuentro
	_report_encounter(false)
	emit_signal("defeated", false)
	is_active = false
	if despawn_on_death:
		queue_free()
		return

	velocity = Vector2.ZERO
	is_attacking = false
	is_dashing = false
	attack_hitbox.monitoring = false
	attack_hitbox.monitorable = false

func activate():
	is_active = true
	_encounter_reported = false
	_last_action_received_time = Time.get_ticks_msec() / 1000.0
	_darkness_cooldown_timer = 0.0
	_power_active = false
	_power_timer = 0.0
	_power_cooldown_timer = 0.0
	_jump_cooldown_timer = 0.0
	_double_jump_cooldown_timer = 0.0
	_darkness_try_timer = 0.0
	_prev_ai_should_jump = false
	_prev_ai_should_dash = false
	hurtbox.monitorable = true
	is_invincible = false
	invincibility_timer = 0.0

func set_ai_action(action):
	var normalized := _normalize_ai_action(action)
	if normalized.is_empty():
		_use_heuristic()
		return

	ai_move_direction = int(normalized.get("move", 1)) - 1  # 0,1,2 → -1,0,1
	ai_should_jump = int(normalized.get("jump", 0)) == 1
	ai_should_attack = int(normalized.get("attack", 0)) == 1
	ai_should_dash = int(normalized.get("dash", 0)) == 1
	ai_should_use_power = int(normalized.get("power", 0)) == 1

	_last_action_received_time = Time.get_ticks_msec() / 1000.0


func _normalize_ai_action(action) -> Dictionary:
	if action == null:
		return {}

	if typeof(action) == TYPE_DICTIONARY:
		if action.has("move"):
			return action
		if action.has("0"):
			return {
				"move": int(action.get("0", 1)),
				"jump": int(action.get("1", 0)),
				"attack": int(action.get("2", 0)),
				"dash": int(action.get("3", 0)),
				"power": int(action.get("4", 0))
			}
		return {}

	if typeof(action) == TYPE_ARRAY and action.size() >= 5:
		return {
			"move": int(action[0]),
			"jump": int(action[1]),
			"attack": int(action[2]),
			"dash": int(action[3]),
			"power": int(action[4])
		}

	if typeof(action) == TYPE_PACKED_FLOAT32_ARRAY and action.size() >= 5:
		return {
			"move": int(action[0]),
			"jump": int(action[1]),
			"attack": int(action[2]),
			"dash": int(action[3]),
			"power": int(action[4])
		}

	return {}


func _should_use_heuristic() -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	return now - _last_action_received_time > ACTION_TIMEOUT_SECONDS


func _use_heuristic() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return

	var rel: Vector2 = player.global_position - global_position
	var abs_x := absf(rel.x)
	var abs_y := absf(rel.y)

	ai_move_direction = signi(int(rel.x))
	ai_should_attack = abs_x <= HEURISTIC_ATTACK_DISTANCE and abs_y < 24.0
	ai_should_jump = rel.y < -30.0 and is_on_floor() and _jump_cooldown_timer <= 0.0 and randf() < 0.35
	ai_should_dash = abs_x > HEURISTIC_DASH_DISTANCE and dash_cooldown_timer <= 0.0 and randf() < 0.35
	ai_should_use_power = abs_x > 120.0


func _is_power_active() -> bool:
	return _power_active


func _get_power_duration(power_name: String) -> float:
	match power_name:
		"cyan":
			return power_duration_cyan
		"red":
			return power_duration_red
		"yellow":
			return power_duration_yellow
		_:
			return 0.0


func _get_power_cooldown(power_name: String) -> float:
	match power_name:
		"cyan":
			return power_cooldown_cyan
		"red":
			return power_cooldown_red
		"yellow":
			return power_cooldown_yellow
		_:
			return 0.0


func _get_attack_damage() -> int:
	if current_power == "red" and _is_power_active():
		return int(DAMAGE * POWER_DAMAGE_MULTIPLIER)
	return DAMAGE


func _ensure_visual_shader() -> void:
	if sprite == null:
		return

	var material := sprite.material as ShaderMaterial
	if material == null:
		material = ShaderMaterial.new()
		material.shader = UMBRA_SHADER
		sprite.material = material
	elif material.shader == null:
		material.shader = UMBRA_SHADER


func _update_power_visuals() -> void:
	var material := sprite.material as ShaderMaterial
	if material == null:
		return

	if not _is_power_active():
		material.set_shader_parameter("power_strength", 0.0)
		return

	var tint := Color(1.0, 1.0, 1.0, 1.0)
	match current_power:
		"cyan":
			tint = TINT_CYAN_PRIMARY
		"red":
			tint = TINT_RED_PRIMARY
		"yellow":
			tint = TINT_YELLOW_PRIMARY

	material.set_shader_parameter("power_tint", tint)
	material.set_shader_parameter("power_strength", 0.78)


func _ensure_darkness_container() -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		scene_root = get_tree().root

	_darkness_container = scene_root.get_node_or_null("DarknessContainer") as Node2D
	if _darkness_container != null:
		return

	_darkness_container = Node2D.new()
	_darkness_container.name = "DarknessContainer"
	scene_root.add_child(_darkness_container)


func _try_cast_darkness_zone() -> void:
	if _darkness_cooldown_timer > 0.0:
		return

	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return

	var dist := global_position.distance_to(player.global_position)
	if not darkness_relax_distance_checks and (dist < darkness_min_cast_distance or dist > darkness_max_cast_distance):
		return

	if darkness_try_chance < 0.999 and randf() > darkness_try_chance:
		return

	var spawn_pos := player.global_position + Vector2(darkness_spawn_offset_x, darkness_spawn_offset_y)
	_spawn_darkness_zone(spawn_pos)
	_darkness_cooldown_timer = darkness_cast_cooldown

	if debug_darkness_logs:
		print("Umbra CAST darkness @", spawn_pos)


func _spawn_darkness_zone(spawn_pos: Vector2) -> void:
	if _darkness_container == null:
		_ensure_darkness_container()

	var zone := Area2D.new()
	zone.script = DARKNESS_ZONE_SCRIPT
	zone.global_position = spawn_pos
	zone.collision_layer = 16
	zone.collision_mask = 4

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = darkness_zone_radius
	shape.shape = circle
	zone.add_child(shape)

	if zone.has_method("configure"):
		zone.configure(
			darkness_zone_tick_damage,
			darkness_zone_tick_interval,
			darkness_zone_duration,
			darkness_zone_arming_delay
		)

	_darkness_container.add_child(zone)


func _report_encounter(umbra_won: bool) -> void:
	if _encounter_reported:
		return

	if ai_controller and ai_controller.has_method("build_encounter_snapshot"):
		var snapshot = ai_controller.build_encounter_snapshot(umbra_won)
		GameState.register_umbra_encounter(snapshot)

	_encounter_reported = true


func report_player_defeated() -> void:
	if _encounter_reported:
		return
	_report_encounter(true)
	emit_signal("defeated", true)


func _exit_tree() -> void:
	if is_active and not _encounter_reported:
		# If Umbra leaves the tree while alive, treat it as a win for Umbra.
		_report_encounter(true)

func _on_hurtbox_area_entered(area: Area2D):
	if area.is_in_group("player_hitbox"):
		take_damage(1)

func _on_attack_hitbox_body_entered(body):
	if body.is_in_group("player"):
		if debug_combat_logs:
			print("Umbra HIT player")
		if body.has_method("get"):
			var health_node = body.get("health")
			if health_node and health_node.has_method("take_damage"):
				health_node.take_damage(_get_attack_damage())


func _on_attack_hitbox_area_entered(area: Area2D) -> void:
	if not area.is_in_group("player_hurtbox"):
		return

	var owner = area.get_parent()
	if owner and owner.is_in_group("player"):
		if debug_combat_logs:
			print("Umbra HIT player hurtbox")
		if owner.has_method("get"):
			var health_node = owner.get("health")
			if health_node and health_node.has_method("take_damage"):
				health_node.take_damage(_get_attack_damage())
