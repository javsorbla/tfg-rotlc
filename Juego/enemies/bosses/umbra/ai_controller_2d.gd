extends AIController2D

@export var debug_action_logs := false
@export var use_preferred_side_in_obs := false
@export var use_player_velocity_in_obs := false
@export_range(0.0, 1.0, 0.05) var player_velocity_obs_scale := 0.35
@export var debug_move_diagnostics := false
@export_range(30, 600, 10) var debug_move_diag_interval_ticks := 120

var player_metrics = {
	"avg_distance": 200.0,
	"dash_frequency": 0.0,
	"attack_frequency": 0.0,
	"jump_frequency": 0.0,
	"preferred_side": 0.0,
	"air_time_ratio": 0.0,
	"close_range_ratio": 0.0,
	"low_health_ratio": 0.0,
	"power_usage_frequency": 0.0
}

var _umbra: CharacterBody2D
var _prev_player_health = 3
var _prev_umbra_health = 15
var _prev_distance := -1.0
var _prev_rel_x := 0.0
var _prev_move_dir := 0
var _same_move_streak := 0
var _stagnant_move_streak := 0
var _direction_mismatch_streak := 0
var _recent_move_dirs: Array[int] = []

var _distance_sum := 0.0
var _sample_count := 0
var _player_dash_ticks := 0
var _player_attack_ticks := 0
var _player_jump_events := 0
var _left_side_ticks := 0
var _right_side_ticks := 0
var _player_air_ticks := 0
var _close_range_ticks := 0
var _low_health_ticks := 0
var _power_active_ticks := 0

var _prev_player_is_dashing := false
var _prev_player_on_floor := true
var _last_action_printed_type := -1
var _missing_player_warned := false
var _diag_tick := 0
var _diag_total := 0
var _diag_desired_left := 0
var _diag_desired_right := 0
var _diag_desired_idle := 0
var _diag_move_left := 0
var _diag_move_right := 0
var _diag_move_idle := 0
var _diag_right_idle := 0
var _diag_right_left := 0
var _diag_right_ok := 0
var _diag_left_idle := 0
var _diag_left_right := 0
var _diag_left_ok := 0
var _diag_right_player_vx_left := 0
var _diag_right_player_vx_right := 0
var _diag_right_player_vx_idle := 0
var _diag_left_player_vx_left := 0
var _diag_left_player_vx_right := 0
var _diag_left_player_vx_idle := 0
var _last_obs_debug := {
	"player_ok": false,
	"rel_x": 0.0,
	"rel_y": 0.0,
	"player_vx": 0.0,
	"player_vy": 0.0,
	"dist": -1.0
}

func _ready():
	_umbra = get_parent()
	player_metrics = GameState.get_umbra_player_metrics()
	_resolve_player_if_missing()
	super._ready()


func _physics_process(delta):
	super._physics_process(delta)
	_collect_player_metrics()


func _collect_player_metrics() -> void:
	if not _player or not _umbra:
		return

	var distance := _umbra.global_position.distance_to(_player.global_position)
	_distance_sum += distance
	_sample_count += 1

	if _player.global_position.x < _umbra.global_position.x:
		_left_side_ticks += 1
	else:
		_right_side_ticks += 1

	var current_dash := bool(_player.get("is_dashing"))
	if current_dash:
		_player_dash_ticks += 1

	var combat_node = _player.get_node_or_null("Combat")
	if combat_node and bool(combat_node.get("is_attacking")):
		_player_attack_ticks += 1

	var current_on_floor := bool(_player.is_on_floor())
	if not current_on_floor:
		_player_air_ticks += 1

	if distance <= 90.0:
		_close_range_ticks += 1

	if float(_player.health.current_health) <= float(_player.health.MAX_HEALTH) * 0.35:
		_low_health_ticks += 1

	var color_manager = _player.get_node_or_null("ColorManager")
	if color_manager and bool(color_manager.get("power_active")):
		_power_active_ticks += 1

	if _prev_player_on_floor and not current_on_floor and float(_player.velocity.y) < 0.0:
		_player_jump_events += 1

	_prev_player_on_floor = current_on_floor
	_prev_player_is_dashing = current_dash

func get_obs() -> Dictionary:
	var obs = []
	_resolve_player_if_missing()
	
	if not _player:
		_last_obs_debug = {
			"player_ok": false,
			"rel_x": 0.0,
			"rel_y": 0.0,
			"player_vx": 0.0,
			"player_vy": 0.0,
			"dist": -1.0
		}
		if not _missing_player_warned:
			push_warning("Umbra AIController2D sin player en grupo 'player'; usando observacion neutra")
			_missing_player_warned = true
		# Mantener tamaño de observación consistente para ONNX incluso sin player temporalmente.
		return {
			"obs": [
				0.0, 0.0,
				0.0, 0.0,
				1.0, 0.0, 0.0,
				1.0,
				1.0, 0.0,
				0.4, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0
			]
		}
	
	# Posición relativa del jugador normalizada
	var rel_pos = (_player.global_position - _umbra.global_position)
	_last_obs_debug = {
		"player_ok": true,
		"rel_x": rel_pos.x,
		"rel_y": rel_pos.y,
		"player_vx": _player.velocity.x,
		"player_vy": _player.velocity.y,
		"dist": rel_pos.length()
	}
	obs.append(clamp(rel_pos.x / 500.0, -1.0, 1.0))
	obs.append(clamp(rel_pos.y / 300.0, -1.0, 1.0))
	
	# Velocidad del jugador normalizada
	var vel_scale := player_velocity_obs_scale if use_player_velocity_in_obs else 0.0
	obs.append(clamp((_player.velocity.x / 300.0) * vel_scale, -1.0, 1.0))
	obs.append(clamp((_player.velocity.y / 400.0) * vel_scale, -1.0, 1.0))
	
	# Estado de Umbra
	obs.append(float(_umbra.is_on_floor()))
	obs.append(float(_umbra.is_dashing))
	obs.append(float(_umbra.is_attacking))
	obs.append(clamp(float(_umbra.current_health) / float(_umbra.max_health), 0.0, 1.0))
	
	# Estado del jugador
	obs.append(clamp(float(_player.health.current_health) / float(_player.health.MAX_HEALTH), 0.0, 1.0))
	obs.append(float(_player.is_dashing))
	
	# Métricas del encuentro anterior
	obs.append(clamp(player_metrics["avg_distance"] / 500.0, 0.0, 1.0))
	obs.append(clamp(player_metrics["dash_frequency"], 0.0, 1.0))
	obs.append(clamp(player_metrics["attack_frequency"], 0.0, 1.0))
	obs.append(clamp(player_metrics["jump_frequency"], 0.0, 1.0))
	# Evita realimentar sesgo direccional entre episodios (izquierda/derecha) en entrenamiento e inferencia.
	obs.append(clamp(player_metrics["preferred_side"], -1.0, 1.0) if use_preferred_side_in_obs else 0.0)
	obs.append(clamp(player_metrics["air_time_ratio"], 0.0, 1.0))
	obs.append(clamp(player_metrics["close_range_ratio"], 0.0, 1.0))
	obs.append(clamp(player_metrics["low_health_ratio"], 0.0, 1.0))
	obs.append(clamp(player_metrics["power_usage_frequency"], 0.0, 1.0))
	
	return {"obs": obs}

func get_action_space() -> Dictionary:
	# Mantener un orden canonico estable para la conversion a MultiDiscrete (SB3/ONNX).
	# (coincide con `ACTION_KEY_ORDER` en `sync.gd`.)
	return {
		"attack": {"size": 2, "action_type": "discrete"},
		"dash": {"size": 2, "action_type": "discrete"},
		"jump": {"size": 2, "action_type": "discrete"},
		"move": {"size": 3, "action_type": "discrete"},
		"power": {"size": 2, "action_type": "discrete"},
	}

func get_reward() -> float:
	var r = 0.0
	const DIRECTION_DEADZONE_PX := 12.0
	
	if not _player:
		return r

	var distance := _umbra.global_position.distance_to(_player.global_position)
	var rel_x := _player.global_position.x - _umbra.global_position.x
	var move_dir := int(_umbra.ai_move_direction)
	var desired_move := 0
	if absf(rel_x) > DIRECTION_DEADZONE_PX:
		desired_move = signi(int(rel_x))
	
	# Recompensa por dañar al jugador
	var player_health_diff = _prev_player_health - _player.health.current_health
	r += player_health_diff * 2.0
	
	# Penalización por recibir daño
	var umbra_health_diff = _prev_umbra_health - _umbra.current_health
	r -= umbra_health_diff * 1.5
	
	# Recompensa por sobrevivir
	r += 0.001

	# Recompensa por reducir la distancia horizontal al jugador.
	if _prev_distance >= 0.0:
		var horizontal_progress := absf(_prev_rel_x) - absf(rel_x)
		r += clamp(horizontal_progress / 180.0, -0.018, 0.018)

	# Recompensa secundaria por reducir distancia total.
	if _prev_distance >= 0.0:
		var distance_delta := (_prev_distance - distance) / 400.0
		r += clamp(distance_delta, -0.008, 0.008)

	# Alineación horizontal fuerte: evita que una politica sesgada sobreviva solo por acciones secundarias.
	if desired_move != 0:
		if move_dir == desired_move:
			r += 0.035
			_direction_mismatch_streak = 0
		elif move_dir == 0:
			r -= 0.015
			_direction_mismatch_streak += 1
		else:
			r -= 0.055
			_direction_mismatch_streak += 1
	else:
		# Cerca del objetivo horizontal, premiar estabilidad para no oscilar.
		if move_dir != 0:
			r -= 0.003

	if _direction_mismatch_streak > 10:
		r -= 0.0035 * float(min(_direction_mismatch_streak - 10, 40))

	_update_move_diagnostics(rel_x, move_dir, desired_move)

	# Regularización anti-colapso: penaliza mantener la misma direccion demasiado tiempo
	# cuando no hay mejora real de distancia.
	var distance_delta_raw := 0.0
	if _prev_distance >= 0.0:
		distance_delta_raw = _prev_distance - distance

	if move_dir != 0 and move_dir == _prev_move_dir:
		_same_move_streak += 1
		if distance_delta_raw < 0.35:
			_stagnant_move_streak += 1
		else:
			_stagnant_move_streak = 0
	else:
		_same_move_streak = 0
		_stagnant_move_streak = 0

	if _same_move_streak > 45 and _stagnant_move_streak > 20:
		var extra_streak := float(min(_same_move_streak - 45, 120))
		r -= 0.00008 * extra_streak

	# Regularizacion de diversidad a corto plazo para evitar colapso del canal move.
	_recent_move_dirs.append(move_dir)
	while _recent_move_dirs.size() > 64:
		_recent_move_dirs.pop_front()
	if _recent_move_dirs.size() >= 32:
		var left_count := 0
		var idle_count := 0
		var right_count := 0
		for m in _recent_move_dirs:
			if m < 0:
				left_count += 1
			elif m > 0:
				right_count += 1
			else:
				idle_count += 1
		var dominant := maxi(left_count, maxi(idle_count, right_count))
		var dominant_ratio := float(dominant) / float(_recent_move_dirs.size())
		if dominant_ratio > 0.88:
			r -= (dominant_ratio - 0.88) * 0.06

	# Penalización suave por abusar mucho del dash.
	if _umbra.is_dashing:
		r -= 0.001

	# Coste de acciones secundarias descontextualizadas para impedir vector fijo jump/dash/power=1.
	if bool(_umbra.ai_should_attack) and distance > 95.0:
		r -= 0.004
	if bool(_umbra.ai_should_dash) and distance < 45.0:
		r -= 0.003
	if bool(_umbra.ai_should_jump) and not _umbra.is_on_floor():
		r -= 0.0025
	if bool(_umbra.ai_should_use_power) and distance > 140.0:
		r -= 0.003
	
	# Penalización por estar lejos del jugador
	if distance > 300.0:
		r -= 0.002
	
	# Actualizar valores previos
	_prev_player_health = _player.health.current_health
	_prev_umbra_health = _umbra.current_health
	_prev_distance = distance
	_prev_rel_x = rel_x
	_prev_move_dir = move_dir
	
	return r

func set_action(action) -> void:
	if debug_action_logs:
		var t := typeof(action)
		if t != _last_action_printed_type:
			print("Accion recibida (tipo=", t, "): ", action)
			_last_action_printed_type = t
	_umbra.set_ai_action(action)


func build_encounter_snapshot(umbra_won: bool) -> Dictionary:
	if _sample_count <= 0:
		return {
			"umbra_won": umbra_won,
			"player_metrics": player_metrics.duplicate(true)
		}

	var avg_distance := _distance_sum / float(_sample_count)
	var dash_frequency := float(_player_dash_ticks) / float(_sample_count)
	var attack_frequency := float(_player_attack_ticks) / float(_sample_count)
	var jump_frequency := float(_player_jump_events) / float(max(1, _sample_count))
	var preferred_side := float(_right_side_ticks - _left_side_ticks) / float(_sample_count)
	var air_time_ratio := float(_player_air_ticks) / float(_sample_count)
	var close_range_ratio := float(_close_range_ticks) / float(_sample_count)
	var low_health_ratio := float(_low_health_ticks) / float(_sample_count)
	var power_usage_frequency := float(_power_active_ticks) / float(_sample_count)

	player_metrics = {
		"avg_distance": avg_distance,
		"dash_frequency": dash_frequency,
		"attack_frequency": attack_frequency,
		"jump_frequency": jump_frequency,
		"preferred_side": preferred_side,
		"air_time_ratio": air_time_ratio,
		"close_range_ratio": close_range_ratio,
		"low_health_ratio": low_health_ratio,
		"power_usage_frequency": power_usage_frequency
	}

	return {
		"umbra_won": umbra_won,
		"player_metrics": player_metrics.duplicate(true)
	}

func reset():
	super.reset()
	_resolve_player_if_missing()
	_umbra.current_health = _umbra.max_health
	if _player:
		_prev_player_health = _player.health.current_health
	_prev_umbra_health = _umbra.current_health
	_prev_distance = -1.0
	_prev_rel_x = 0.0
	_prev_move_dir = 0
	_same_move_streak = 0
	_stagnant_move_streak = 0
	_reset_move_diagnostics()


func _update_move_diagnostics(rel_x: float, move_dir: int, desired_move: int) -> void:
	if not debug_move_diagnostics:
		return
	if _player == null:
		return

	_diag_tick += 1
	_diag_total += 1

	if desired_move < 0:
		_diag_desired_left += 1
	elif desired_move > 0:
		_diag_desired_right += 1
	else:
		_diag_desired_idle += 1

	if move_dir < 0:
		_diag_move_left += 1
	elif move_dir > 0:
		_diag_move_right += 1
	else:
		_diag_move_idle += 1

	var player_vx_sign := signi(int(_player.velocity.x))
	if rel_x > 0.0:
		if move_dir > 0:
			_diag_right_ok += 1
		elif move_dir < 0:
			_diag_right_left += 1
		else:
			_diag_right_idle += 1

		if player_vx_sign < 0:
			_diag_right_player_vx_left += 1
		elif player_vx_sign > 0:
			_diag_right_player_vx_right += 1
		else:
			_diag_right_player_vx_idle += 1
	elif rel_x < 0.0:
		if move_dir < 0:
			_diag_left_ok += 1
		elif move_dir > 0:
			_diag_left_right += 1
		else:
			_diag_left_idle += 1

		if player_vx_sign < 0:
			_diag_left_player_vx_left += 1
		elif player_vx_sign > 0:
			_diag_left_player_vx_right += 1
		else:
			_diag_left_player_vx_idle += 1

	if _diag_tick >= maxi(1, debug_move_diag_interval_ticks):
		_print_move_diagnostics()
		_diag_tick = 0


func _print_move_diagnostics() -> void:
	var right_total := _diag_right_ok + _diag_right_left + _diag_right_idle
	var left_total := _diag_left_ok + _diag_left_right + _diag_left_idle
	var right_ok_rate := float(_diag_right_ok) / float(max(1, right_total))
	var left_ok_rate := float(_diag_left_ok) / float(max(1, left_total))

	print(
		"DIAG MOVE | total=", _diag_total,
		" desired(L/I/R)=", _diag_desired_left, "/", _diag_desired_idle, "/", _diag_desired_right,
		" move(L/I/R)=", _diag_move_left, "/", _diag_move_idle, "/", _diag_move_right,
		" right(ok/idle/left)=", _diag_right_ok, "/", _diag_right_idle, "/", _diag_right_left,
		" right_ok=", snappedf(right_ok_rate, 0.001),
		" left(ok/idle/right)=", _diag_left_ok, "/", _diag_left_idle, "/", _diag_left_right,
		" left_ok=", snappedf(left_ok_rate, 0.001),
		" right_vx(L/I/R)=", _diag_right_player_vx_left, "/", _diag_right_player_vx_idle, "/", _diag_right_player_vx_right,
		" left_vx(L/I/R)=", _diag_left_player_vx_left, "/", _diag_left_player_vx_idle, "/", _diag_left_player_vx_right
	)


func _reset_move_diagnostics() -> void:
	_diag_tick = 0
	_diag_total = 0
	_diag_desired_left = 0
	_diag_desired_right = 0
	_diag_desired_idle = 0
	_diag_move_left = 0
	_diag_move_right = 0
	_diag_move_idle = 0
	_diag_right_idle = 0
	_diag_right_left = 0
	_diag_right_ok = 0
	_diag_left_idle = 0
	_diag_left_right = 0
	_diag_left_ok = 0
	_diag_right_player_vx_left = 0
	_diag_right_player_vx_right = 0
	_diag_right_player_vx_idle = 0
	_diag_left_player_vx_left = 0
	_diag_left_player_vx_right = 0
	_diag_left_player_vx_idle = 0


func _resolve_player_if_missing() -> void:
	if _player != null and is_instance_valid(_player):
		return
	var candidate := get_tree().get_first_node_in_group("player") as Node2D
	if candidate == null:
		var scene_root := get_tree().current_scene
		if scene_root != null:
			candidate = scene_root.find_child("Player", true, false) as Node2D
	if candidate != null:
		_player = candidate
		_missing_player_warned = false


func get_last_obs_debug() -> Dictionary:
	return _last_obs_debug.duplicate(true)
