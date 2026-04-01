extends CharacterBody2D

signal defeated(umbra_won: bool)

# Constantes de movimiento
const SPEED = 100.0
const JUMP_VELOCITY = -300.0
const DASH_SPEED = 280.0
const DASH_DURATION = 0.20
const ACCELERATION = 900.0
const FRICTION = 650.0

# Constantes de combate
const DAMAGE = 1
const ATTACK_DURATION = 0.3
const ATTACK_COOLDOWN = 1.0
const INVINCIBILITY_DURATION = 0.5
const POWER_SPEED_MULTIPLIER = 1.45
const POWER_DAMAGE_MULTIPLIER = 2

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
var current_health = max_health
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
var _has_received_valid_action := false
var _encounter_reported := false
var _darkness_cooldown_timer := 0.0
var _power_active := false
var _power_timer := 0.0
var _power_cooldown_timer := 0.0
var _jump_cooldown_timer := 0.0
var _double_jump_cooldown_timer := 0.0
var _darkness_try_timer := 0.0
var _attack_cooldown_runtime := ATTACK_COOLDOWN
var _jump_cooldown_runtime := 0.0
var _double_jump_cooldown_runtime := 0.0
var _dash_cooldown_runtime := 0.0
var _darkness_cooldown_runtime := 0.0
var _darkness_cast_interval_runtime := 0.0
var _power_cooldown_scale := 1.0
var _heuristic_jump_chance := 0.35
var _heuristic_dash_chance := 0.35
var _allow_darkness_cast := true
var _runtime_metrics_enabled := false
var _runtime_distance_sum := 0.0
var _runtime_sample_count := 0
var _runtime_player_dash_ticks := 0
var _runtime_player_attack_ticks := 0
var _runtime_player_jump_events := 0
var _runtime_left_side_ticks := 0
var _runtime_right_side_ticks := 0
var _runtime_player_air_ticks := 0
var _runtime_close_range_ticks := 0
var _runtime_low_health_ticks := 0
var _runtime_power_active_ticks := 0
var _runtime_prev_player_on_floor := true

const ACTION_TIMEOUT_SECONDS := 0.35
const HEURISTIC_ATTACK_DISTANCE := 44.0
const HEURISTIC_DASH_DISTANCE := 130.0
const AUTO_ATTACK_DISTANCE_X := 72.0
const AUTO_ATTACK_DISTANCE_Y := 44.0

@export var max_health = 3
@export var force_heuristic_only := false
@export var debug_combat_logs := false
@export var debug_mobility_logs := false
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
@export var apply_level_balance := true

# Variables de poder
var current_power = "none"  # none, cyan, red, yellow

@onready var sprite = $AnimatedSprite2D
@onready var attack_hitbox = $AttackHitbox
@onready var hurtbox = $Hurtbox
@onready var ai_controller = $AIController2D
@onready var health = $Health
@onready var combat = $Combat
@onready var color_manager = $ColorManager

func _ready():
	add_to_group("umbra_boss")
	combat.setup()
	health.setup()
	color_manager.setup()
	# Asignar poder según nivel
	_assign_power()
	_apply_level_balance()
	_apply_persistent_difficulty()
	_apply_player_profile_adaptation()
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
	
	_handle_timers(delta)
	_handle_gravity(delta)
	_handle_movement(delta)
	_handle_jump(ai_should_jump)
	_handle_dash(delta, ai_should_dash)
	_handle_attack(delta)
	_apply_pattern_overrides()
	_handle_power()
	_collect_runtime_player_metrics()
	_update_animation()
	_update_power_visuals()
	
	was_on_floor = is_on_floor()
	move_and_slide()


func _apply_level_balance() -> void:
	_attack_cooldown_runtime = ATTACK_COOLDOWN
	_jump_cooldown_runtime = jump_cooldown_seconds
	_double_jump_cooldown_runtime = double_jump_cooldown_seconds
	_dash_cooldown_runtime = dash_cooldown_seconds
	_darkness_cooldown_runtime = darkness_cast_cooldown
	_darkness_cast_interval_runtime = darkness_cast_interval_seconds
	_power_cooldown_scale = 1.0
	_heuristic_jump_chance = 0.35
	_heuristic_dash_chance = 0.35
	_allow_darkness_cast = true

	if not apply_level_balance:
		return

	var scene_root := get_tree().current_scene
	if scene_root != null:
		var scene_path := String(scene_root.scene_file_path).to_lower()
		if scene_path.find("entrenamiento_umbra") != -1:
			return

	var level := GameState.current_level if "current_level" in GameState else 1
	match level:
		1:
			_attack_cooldown_runtime *= 1.70
			_jump_cooldown_runtime *= 1.30
			_double_jump_cooldown_runtime *= 1.25
			_dash_cooldown_runtime *= 1.35
			_darkness_cooldown_runtime *= 2.10
			_darkness_cast_interval_runtime *= 1.95
			_power_cooldown_scale = 1.35
			_heuristic_jump_chance = 0.24
			_heuristic_dash_chance = 0.38
			_allow_darkness_cast = true
		2:
			_attack_cooldown_runtime *= 1.20
			_jump_cooldown_runtime *= 1.10
			_double_jump_cooldown_runtime *= 1.08
			_dash_cooldown_runtime *= 1.12
			_darkness_cooldown_runtime *= 1.18
			_darkness_cast_interval_runtime *= 1.12
			_power_cooldown_scale = 1.12
			_heuristic_jump_chance = 0.30
			_heuristic_dash_chance = 0.28


func _apply_persistent_difficulty() -> void:
	var difficulty_scale := GameState.get_umbra_difficulty_scale()
	current_health = int(round(float(max_health) * difficulty_scale))


func _apply_player_profile_adaptation() -> void:
	var metrics := GameState.get_umbra_player_metrics()
	if metrics.is_empty():
		return

	# Adapt baseline behavior against the player profile learned across level encounters.
	var dash_frequency := clampf(float(metrics.get("dash_frequency", 0.0)), 0.0, 1.0)
	var jump_frequency := clampf(float(metrics.get("jump_frequency", 0.0)), 0.0, 1.0)
	var close_range_ratio := clampf(float(metrics.get("close_range_ratio", 0.0)), 0.0, 1.0)
	var air_time_ratio := clampf(float(metrics.get("air_time_ratio", 0.0)), 0.0, 1.0)
	var power_usage := clampf(float(metrics.get("power_usage_frequency", 0.0)), 0.0, 1.0)

	_heuristic_dash_chance = clampf(_heuristic_dash_chance + dash_frequency * 0.25 + power_usage * 0.10, 0.18, 0.90)
	_heuristic_jump_chance = clampf(_heuristic_jump_chance + jump_frequency * 0.20 + air_time_ratio * 0.12, 0.16, 0.85)
	_attack_cooldown_runtime = clampf(_attack_cooldown_runtime - close_range_ratio * 0.22, 0.25, 3.0)
	_darkness_cast_interval_runtime = clampf(_darkness_cast_interval_runtime - power_usage * 0.75, 1.8, 12.0)

	_runtime_metrics_enabled = true

func _handle_timers(delta):
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
	if _jump_cooldown_timer > 0:
		_jump_cooldown_timer -= delta
	if _double_jump_cooldown_timer > 0:
		_double_jump_cooldown_timer -= delta
	combat.process_timers(delta)
	color_manager.process_timers(delta)
	health.process_timers(delta)

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
	return color_manager.get_speed()

func _handle_jump(jump_requested: bool):
	# Preserve double-jump availability while falling, even if jump is not pressed this frame.
	if was_on_floor and not is_on_floor() and velocity.y >= 0:
		can_double_jump = true

	if is_dashing:
		return
	if not jump_requested:
		return

	if is_on_floor() and _jump_cooldown_timer <= 0.0:
		velocity.y = JUMP_VELOCITY
		can_double_jump = true
		_jump_cooldown_timer = _jump_cooldown_runtime
		if debug_mobility_logs:
			print("Umbra JUMP start")
		return

	if can_double_jump and _double_jump_cooldown_timer <= 0.0:
		velocity.y = JUMP_VELOCITY
		can_double_jump = false
		_double_jump_cooldown_timer = _double_jump_cooldown_runtime
		if debug_mobility_logs:
			print("Umbra DOUBLE JUMP start")

func _handle_dash(delta, dash_requested: bool):
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false
			velocity.x = dash_direction * SPEED * 0.2
		else:
			velocity.x = dash_direction * DASH_SPEED
		return
	
	if dash_requested and dash_cooldown_timer <= 0 and (is_on_floor() or not air_dash_used):
		if is_attacking:
			_cancel_attack_state()
		is_dashing = true
		dash_timer = DASH_DURATION
		dash_cooldown_timer = _dash_cooldown_runtime
		if not is_on_floor():
			air_dash_used = true
		dash_direction = ai_move_direction if ai_move_direction != 0 else last_direction
		velocity.y = 0
		if debug_mobility_logs:
			print("Umbra DASH start dir=", dash_direction, " floor=", is_on_floor())

	if is_on_floor():
		air_dash_used = false

func _handle_attack(delta):
	combat.process(delta)


func _cancel_attack_state() -> void:
	combat.cancel_attack_state()
		


func _apply_pattern_overrides() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return

	var rel := player.global_position - global_position
	var abs_x := absf(rel.x)

	if current_power == "yellow" and current_health <= int(ceil(float(max_health) * 0.45)):
		ai_should_use_power = true
	elif current_power == "red" and abs_x <= 120.0:
		ai_should_use_power = true
	elif current_power == "cyan" and abs_x > 140.0:
		ai_should_use_power = true

	if player.has_method("get") and bool(player.get("is_dashing")) and abs_x < 95.0 and dash_cooldown_timer <= 0.0:
		ai_should_dash = true

func _handle_power():
	color_manager.handle_power()
	combat.handle_darkness_attack()

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
	health.take_damage(amount)

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
	_apply_level_balance()
	_apply_player_profile_adaptation()
	_encounter_reported = false
	_has_received_valid_action = false
	_last_action_received_time = Time.get_ticks_msec() / 1000.0
	_darkness_cooldown_timer = 0.0
	_power_active = false
	_power_timer = 0.0
	_power_cooldown_timer = 0.0
	_jump_cooldown_timer = 0.0
	_double_jump_cooldown_timer = 0.0
	_darkness_try_timer = 0.0
	_reset_runtime_metrics()
	hurtbox.monitorable = true
	is_invincible = false
	invincibility_timer = 0.0

func set_ai_action(action):
	var normalized := _normalize_ai_action(action)
	
	# Si no hay acción válida o está en timeout, usar heurística
	if normalized.is_empty() or _should_use_heuristic():
		_use_heuristic()
		return
	
	# Procesar la acción del modelo
	ai_move_direction = int(normalized.get("move", 1)) - 1  # 0,1,2 -> -1,0,1
	ai_should_jump = int(normalized.get("jump", 0)) == 1
	ai_should_attack = int(normalized.get("attack", 0)) == 1
	ai_should_dash = int(normalized.get("dash", 0)) == 1
	ai_should_use_power = int(normalized.get("power", 0)) == 1
	
	_has_received_valid_action = true
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
	var should_ground_jump := rel.y < -30.0 and is_on_floor() and _jump_cooldown_timer <= 0.0
	var should_air_double_jump := can_double_jump and (not is_on_floor()) and velocity.y > 30.0 and _double_jump_cooldown_timer <= 0.0 and abs_y > 20.0

	ai_move_direction = signi(int(rel.x))
	ai_should_attack = abs_x <= HEURISTIC_ATTACK_DISTANCE and abs_y < 24.0
	ai_should_jump = should_air_double_jump or (should_ground_jump and randf() < _heuristic_jump_chance)
	ai_should_dash = abs_x > HEURISTIC_DASH_DISTANCE and dash_cooldown_timer <= 0.0 and randf() < _heuristic_dash_chance
	ai_should_use_power = abs_x > 120.0


func _update_power_visuals() -> void:
	color_manager.update_power_visuals()


func _report_encounter(umbra_won: bool) -> void:
	if _encounter_reported:
		return

	if ai_controller and ai_controller.has_method("build_encounter_snapshot"):
		var snapshot = ai_controller.build_encounter_snapshot(umbra_won)
		GameState.register_umbra_encounter(snapshot)
	elif _runtime_sample_count > 0:
		GameState.register_umbra_encounter(_build_runtime_snapshot(umbra_won))

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


func _reset_runtime_metrics() -> void:
	_runtime_distance_sum = 0.0
	_runtime_sample_count = 0
	_runtime_player_dash_ticks = 0
	_runtime_player_attack_ticks = 0
	_runtime_player_jump_events = 0
	_runtime_left_side_ticks = 0
	_runtime_right_side_ticks = 0
	_runtime_player_air_ticks = 0
	_runtime_close_range_ticks = 0
	_runtime_low_health_ticks = 0
	_runtime_power_active_ticks = 0

	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player != null:
		_runtime_prev_player_on_floor = player.is_on_floor()
	else:
		_runtime_prev_player_on_floor = true


func _collect_runtime_player_metrics() -> void:
	if not _runtime_metrics_enabled:
		return

	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player == null:
		return

	var distance := global_position.distance_to(player.global_position)
	_runtime_distance_sum += distance
	_runtime_sample_count += 1

	if player.global_position.x < global_position.x:
		_runtime_left_side_ticks += 1
	else:
		_runtime_right_side_ticks += 1

	if bool(player.get("is_dashing")):
		_runtime_player_dash_ticks += 1

	var combat_node = player.get_node_or_null("Combat")
	if combat_node and bool(combat_node.get("is_attacking")):
		_runtime_player_attack_ticks += 1

	var current_on_floor := player.is_on_floor()
	if not current_on_floor:
		_runtime_player_air_ticks += 1

	if distance <= 90.0:
		_runtime_close_range_ticks += 1

	var health_node = player.get_node_or_null("Health")
	if health_node != null and float(health_node.get("current_health")) <= float(health_node.get("MAX_HEALTH")) * 0.35:
		_runtime_low_health_ticks += 1

	var color_manager = player.get_node_or_null("ColorManager")
	if color_manager and bool(color_manager.get("power_active")):
		_runtime_power_active_ticks += 1

	if _runtime_prev_player_on_floor and not current_on_floor and float(player.velocity.y) < 0.0:
		_runtime_player_jump_events += 1

	_runtime_prev_player_on_floor = current_on_floor


func _build_runtime_snapshot(umbra_won: bool) -> Dictionary:
	if _runtime_sample_count <= 0:
		return {
			"umbra_won": umbra_won,
			"player_metrics": GameState.get_umbra_player_metrics()
		}

	var count := float(_runtime_sample_count)
	var metrics := {
		"avg_distance": _runtime_distance_sum / count,
		"dash_frequency": float(_runtime_player_dash_ticks) / count,
		"attack_frequency": float(_runtime_player_attack_ticks) / count,
		"jump_frequency": float(_runtime_player_jump_events) / count,
		"preferred_side": float(_runtime_right_side_ticks - _runtime_left_side_ticks) / count,
		"air_time_ratio": float(_runtime_player_air_ticks) / count,
		"close_range_ratio": float(_runtime_close_range_ticks) / count,
		"low_health_ratio": float(_runtime_low_health_ticks) / count,
		"power_usage_frequency": float(_runtime_power_active_ticks) / count
	}

	return {
		"umbra_won": umbra_won,
		"player_metrics": metrics
	}
