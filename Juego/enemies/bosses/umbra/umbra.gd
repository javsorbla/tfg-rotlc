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
var spawn_position = Vector2.ZERO

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
var _indexed_action_layout_warned := false
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
@export var debug_model_indicator := true
@export var use_runtime_finetuned_model := false
@export var debug_policy_trace := false
@export_range(1, 120, 1) var debug_policy_trace_every_frames := 12
@export var auto_fix_move_mapping := false
@export var invert_move_decode := false
@export_range(5, 120, 1) var move_mapping_probe_samples := 25
@export_range(0.5, 1.0, 0.01) var move_mapping_flip_threshold := 0.7

# Variables de poder
var current_power = "none"  # none, cyan, red, yellow

@onready var sprite = $AnimatedSprite2D
@onready var attack_hitbox = $AttackHitbox
@onready var hurtbox = $Hurtbox
@onready var ai_controller = $AIController2D
@onready var health = $Health
@onready var combat = $Combat
@onready var color_manager = $ColorManager

var _model_indicator_layer: CanvasLayer
var _model_indicator_label: Label
var _last_normalized_action: Dictionary = {}
var _last_action_used_heuristic := false
var _policy_trace_tick := 0
var _move_mapping_flipped := false
var _move_mapping_probe_total := 0
var _move_mapping_probe_away := 0
var _move_collapse_active := false
var _move_dominant_raw := 1
var _recent_raw_moves: Array[int] = []

func _ready():
	add_to_group("umbra_boss")
	spawn_position = global_position
	combat.setup()
	health.setup()
	color_manager.setup()
	# Asignar poder según nivel
	_assign_power()
	_apply_level_balance()
	_apply_persistent_difficulty()
	_apply_player_profile_adaptation()
	var player = _resolve_player_target()
	if player:
		ai_controller.init(player)
	print("Control mode: ", ai_controller.control_mode)
	print("ONNX path: ", ai_controller.onnx_model_path)
	print("ONNX model (ready snapshot): ", ai_controller.onnx_model)
	_setup_model_indicator()
	_update_model_indicator()
	call_deferred("_log_model_indicator_snapshot")
	if not GameState.level_reset.is_connected(_on_level_reset):
		GameState.level_reset.connect(_on_level_reset)


func _process(_delta):
	_update_model_indicator()


func _ensure_onnx_model_ready() -> bool:
	if ai_controller == null:
		return false

	if ai_controller.onnx_model != null:
		return true

	if ai_controller.onnx_model_path.is_empty():
		return false

	var sync_node = get_tree().get_first_node_in_group("sync_node")
	if sync_node != null and sync_node.has_method("reload_onnx_for_agents"):
		sync_node.reload_onnx_for_agents(ai_controller.onnx_model_path)

	return ai_controller.onnx_model != null

func _on_level_reset():
	global_position = spawn_position
	velocity = Vector2.ZERO
	current_health = max_health
	is_active = false
	is_dashing = false
	is_attacking = false
	ai_move_direction = 0
	ai_should_jump = false
	ai_should_attack = false
	ai_should_dash = false
	ai_should_use_power = false
	_has_received_valid_action = false
	_last_action_received_time = Time.get_ticks_msec() / 1000.0
	_encounter_reported = false
	attack_hitbox.set_deferred("monitoring", false)
	attack_hitbox.set_deferred("monitorable", false)
	hurtbox.set_deferred("monitorable", true)

func _setup_model_indicator() -> void:
	if not debug_model_indicator:
		return
	if _model_indicator_layer != null:
		return

	_model_indicator_layer = CanvasLayer.new()
	_model_indicator_layer.name = "ModelIndicatorLayer"
	_model_indicator_layer.layer = 20
	add_child(_model_indicator_layer)

	_model_indicator_label = Label.new()
	_model_indicator_label.name = "ModelIndicatorLabel"
	_model_indicator_label.text = ""
	_model_indicator_label.add_theme_font_size_override("font_size", 9)
	_model_indicator_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_model_indicator_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_model_indicator_label.size = Vector2(64, 12)
	_model_indicator_label.position = Vector2.ZERO
	_model_indicator_layer.add_child(_model_indicator_label)


func _log_model_indicator_snapshot() -> void:
	_update_model_indicator()


func _get_model_indicator_state() -> Dictionary:
	if not is_active:
		return {
			"text": "INACT",
			"color": Color(0.70, 0.70, 0.70, 1.0)
		}

	if force_heuristic_only:
		return {
			"text": "HEUR",
			"color": Color(0.95, 0.25, 0.25, 1.0)
		}

	var is_onnx := false
	if ai_controller != null:
		is_onnx = (
			ai_controller.control_mode == ai_controller.ControlModes.ONNX_INFERENCE
			and ai_controller.onnx_model != null
		)

	if is_onnx and not _has_received_valid_action:
		return {
			"text": "WAIT",
			"color": Color(0.95, 0.85, 0.25, 1.0)
		}

	if is_onnx and _should_use_heuristic():
		return {
			"text": "HEUR",
			"color": Color(0.95, 0.25, 0.25, 1.0)
		}

	if is_onnx:
		return {
			"text": "ONNX",
			"color": Color(0.25, 0.95, 0.35, 1.0)
		}

	return {
		"text": "HEUR",
		"color": Color(0.95, 0.25, 0.25, 1.0)
	}


func _update_model_indicator() -> void:
	if not debug_model_indicator:
		return
	if _model_indicator_layer == null or _model_indicator_label == null:
		return

	var state := _get_model_indicator_state()
	_model_indicator_label.text = state["text"]
	_model_indicator_label.add_theme_color_override("font_color", state["color"])
	_model_indicator_label.position = get_global_transform_with_canvas().origin + Vector2(-20.0, -30.0)

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

	if ai_controller != null and ai_controller.control_mode == ai_controller.ControlModes.ONNX_INFERENCE:
		if not _ensure_onnx_model_ready():
			_has_received_valid_action = false
			_last_action_received_time = Time.get_ticks_msec() / 1000.0
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
	_debug_policy_trace_tick()
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
		if ai_move_direction != 0:
			dash_direction = ai_move_direction
		else:
			var player := get_tree().get_first_node_in_group("player") as Node2D
			if player != null:
				var rel_x := player.global_position.x - global_position.x
				dash_direction = signf(rel_x)
				if dash_direction == 0.0:
					dash_direction = float(last_direction)
			else:
				dash_direction = float(last_direction)
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
	if use_runtime_finetuned_model:
		GameState.start_finetuning(2000)
	emit_signal("defeated", false)
	is_active = false
	if despawn_on_death:
		queue_free()
		return

	velocity = Vector2.ZERO
	is_attacking = false
	is_dashing = false
	attack_hitbox.set_deferred("monitoring", false)
	attack_hitbox.set_deferred("monitorable", false)

func activate():
	is_active = true
	var player := _resolve_player_target()
	if player != null:
		ai_controller.init(player)
	if ai_controller != null and ai_controller.onnx_model_path != "":
		var sync_node = get_tree().get_first_node_in_group("sync_node")
		if sync_node != null and sync_node.has_method("reload_onnx_for_agents"):
			sync_node.reload_onnx_for_agents(ai_controller.onnx_model_path)
	if ai_controller != null and ai_controller.control_mode == ai_controller.ControlModes.ONNX_INFERENCE:
		_ensure_onnx_model_ready()
	if use_runtime_finetuned_model and GameState.check_finetuning_done():
		var runtime_model_path := GameState.get_umbra_runtime_model_path()
		if runtime_model_path != "":
			var sync_node = get_tree().get_first_node_in_group("sync_node")
			if sync_node != null and sync_node.has_method("reload_onnx_for_agents"):
				sync_node.reload_onnx_for_agents(runtime_model_path)
				ai_controller.onnx_model_path = runtime_model_path
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
	_reset_move_mapping_probe()
	hurtbox.set_deferred("monitorable", true)
	is_invincible = false
	invincibility_timer = 0.0

func set_ai_action(action):
	var normalized := _normalize_ai_action(action)
	# Primera accion valida: marcar recepcion inmediatamente para evitar bloqueo en timeout inicial.
	if not normalized.is_empty():
		_has_received_valid_action = true
		_last_action_received_time = Time.get_ticks_msec() / 1000.0

	var using_heuristic := _should_use_heuristic()
	_last_normalized_action = normalized.duplicate(true)
	_last_action_used_heuristic = using_heuristic
	print("Accion recibida: ", action, " | Normalizada: ", normalized, " | Heuristica: ", using_heuristic)
	# Si no hay acción válida o está en timeout, usar heurística
	if normalized.is_empty() or using_heuristic:
		_use_heuristic()
		return
	
	# Procesar la acción del modelo
	var raw_move := int(normalized.get("move", 1))
	_update_move_collapse_probe(raw_move)
	var decoded_move := _decode_move_action(raw_move)
	ai_move_direction = _apply_move_guardrail(decoded_move)
	ai_should_jump = int(normalized.get("jump", 0)) == 1
	ai_should_attack = int(normalized.get("attack", 0)) == 1
	ai_should_dash = int(normalized.get("dash", 0)) == 1
	ai_should_use_power = int(normalized.get("power", 0)) == 1


func _debug_policy_trace_tick() -> void:
	if not debug_policy_trace:
		return

	_policy_trace_tick += 1
	if _policy_trace_tick % maxi(1, debug_policy_trace_every_frames) != 0:
		return

	var player := _resolve_player_target()
	if player == null:
		print("TRACE Umbra | sin player | action=", _last_normalized_action, " heur=", _last_action_used_heuristic)
		return

	var rel := player.global_position - global_position
	var side := "RIGHT" if rel.x > 0.0 else "LEFT"
	if absf(rel.x) < 1.0:
		side = "CENTER"

	var obs_debug: Dictionary = {}
	if ai_controller != null and ai_controller.has_method("get_last_obs_debug"):
		obs_debug = ai_controller.get_last_obs_debug()

	print(
		"TRACE Umbra | rel_x=", snappedf(rel.x, 0.1),
		" rel_y=", snappedf(rel.y, 0.1),
		" dist=", snappedf(rel.length(), 0.1),
		" side=", side,
		" inv_decode=", invert_move_decode,
		" map_flip=", _move_mapping_flipped,
		" move_collapse=", _move_collapse_active,
		" move_dom=", _move_dominant_raw,
		" move_dir=", ai_move_direction,
		" vel_x=", snappedf(velocity.x, 0.1),
		" action=", _last_normalized_action,
		" heur=", _last_action_used_heuristic,
		" obs=", obs_debug
	)


func _decode_move_action(raw_move: int) -> int:
	if invert_move_decode:
		match raw_move:
			0:
				return 1
			2:
				return -1
			_:
				return 0
	return raw_move - 1  # 0,1,2 -> -1,0,1


func _update_move_collapse_probe(raw_move: int) -> void:
	_recent_raw_moves.append(raw_move)
	while _recent_raw_moves.size() > move_mapping_probe_samples:
		_recent_raw_moves.pop_front()

	var sample_size := _recent_raw_moves.size()
	if sample_size < move_mapping_probe_samples:
		return

	var c0 := 0
	var c1 := 0
	var c2 := 0
	for m in _recent_raw_moves:
		if m == 0:
			c0 += 1
		elif m == 1:
			c1 += 1
		elif m == 2:
			c2 += 1

	var dominant := 0
	var dominant_count := c0
	if c1 > dominant_count:
		dominant = 1
		dominant_count = c1
	if c2 > dominant_count:
		dominant = 2
		dominant_count = c2
	var dominant_ratio := float(dominant_count) / float(maxi(1, sample_size))

	_move_dominant_raw = dominant
	_move_collapse_active = dominant_ratio >= move_mapping_flip_threshold


func _apply_move_guardrail(decoded_move: int) -> int:
	if not auto_fix_move_mapping or not _move_collapse_active:
		return decoded_move

	var player := _resolve_player_target()
	if player == null:
		return decoded_move

	var rel_x := player.global_position.x - global_position.x
	if absf(rel_x) < 24.0:
		return 0

	# En colapso de la cabeza de movimiento, priorizar cierre de distancia horizontal.
	return signi(int(rel_x))


func _reset_move_mapping_probe() -> void:
	_move_mapping_flipped = false
	_move_mapping_probe_total = 0
	_move_mapping_probe_away = 0
	_move_collapse_active = false
	_move_dominant_raw = 1
	_recent_raw_moves.clear()


func _normalize_indexed_ai_action(v0: int, v1: int, v2: int, v3: int, v4: int) -> Dictionary:
	# Layout esperado por SB3/ONNX: [attack,dash,jump,move,power]
	# Layout legacy soportado: [move,jump,attack,dash,power]
	var looks_like_legacy := (v0 == 2) and (v3 != 2)
	var has_unexpected_two := (v1 == 2) or (v2 == 2) or (v4 == 2)

	if has_unexpected_two and not _indexed_action_layout_warned:
		_indexed_action_layout_warned = true
		print("WARN Umbra | accion indexada con valor 2 fuera de 'move': ", [v0, v1, v2, v3, v4])

	if looks_like_legacy:
		return {
			"move": clampi(v0, 0, 2),
			"jump": clampi(v1, 0, 1),
			"attack": clampi(v2, 0, 1),
			"dash": clampi(v3, 0, 1),
			"power": clampi(v4, 0, 1)
		}

	return {
		"attack": clampi(v0, 0, 1),
		"dash": clampi(v1, 0, 1),
		"jump": clampi(v2, 0, 1),
		"move": clampi(v3, 0, 2),
		"power": clampi(v4, 0, 1)
	}


func _normalize_ai_action(action) -> Dictionary:
	if action == null:
		return {}

	if typeof(action) == TYPE_DICTIONARY:
		if action.has("move"):
			return action
		# Soporte para payloads indexados (p.ej. [attack,dash,jump,move,power] o legacy [move,jump,attack,dash,power]).
		if action.has("0"):
			return _normalize_indexed_ai_action(
				int(action.get("0", 0)),
				int(action.get("1", 0)),
				int(action.get("2", 0)),
				int(action.get("3", 1)),
				int(action.get("4", 0))
			)
		return {}

	if typeof(action) == TYPE_ARRAY and action.size() >= 5:
		return _normalize_indexed_ai_action(
			int(action[0]),
			int(action[1]),
			int(action[2]),
			int(action[3]),
			int(action[4])
		)

	if typeof(action) == TYPE_PACKED_FLOAT32_ARRAY and action.size() >= 5:
		return _normalize_indexed_ai_action(
			int(action[0]),
			int(action[1]),
			int(action[2]),
			int(action[3]),
			int(action[4])
		)

	return {}

func _should_use_heuristic() -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	var time_since_action := now - _last_action_received_time
	if not _has_received_valid_action:
		var startup_timeout := ACTION_TIMEOUT_SECONDS * 3.0
		if time_since_action > startup_timeout:
			print("Usando heuristica - timeout inicial sin accion: ", time_since_action)
		return time_since_action > startup_timeout
	if time_since_action > ACTION_TIMEOUT_SECONDS:
		print("Usando heuristica - tiempo sin accion: ", time_since_action)
	return time_since_action > ACTION_TIMEOUT_SECONDS


func _use_heuristic() -> void:
	var player: Node2D = _resolve_player_target()
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

	var player := _resolve_player_target() as CharacterBody2D
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

	var current_on_floor: bool = player.is_on_floor()
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


func _resolve_player_target() -> Node2D:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		return player
	var scene_root := get_tree().current_scene
	if scene_root != null:
		return scene_root.find_child("Player", true, false) as Node2D
	return null


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
