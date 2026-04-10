extends AIController2D

@export var debug_action_logs := true

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

func _ready():
	_umbra = get_parent()
	player_metrics = GameState.get_umbra_player_metrics()
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
	
	if not _player:
		return {"obs": Array()}
	
	# Posición relativa del jugador normalizada
	var rel_pos = (_player.global_position - _umbra.global_position)
	obs.append(clamp(rel_pos.x / 500.0, -1.0, 1.0))
	obs.append(clamp(rel_pos.y / 300.0, -1.0, 1.0))
	
	# Velocidad del jugador normalizada
	obs.append(clamp(_player.velocity.x / 300.0, -1.0, 1.0))
	obs.append(clamp(_player.velocity.y / 400.0, -1.0, 1.0))
	
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
	obs.append(clamp(player_metrics["preferred_side"], -1.0, 1.0))
	obs.append(clamp(player_metrics["air_time_ratio"], 0.0, 1.0))
	obs.append(clamp(player_metrics["close_range_ratio"], 0.0, 1.0))
	obs.append(clamp(player_metrics["low_health_ratio"], 0.0, 1.0))
	obs.append(clamp(player_metrics["power_usage_frequency"], 0.0, 1.0))
	
	return {"obs": obs}

func get_action_space() -> Dictionary:
	return {
		"move": {"size": 3, "action_type": "discrete"},
		"jump": {"size": 2, "action_type": "discrete"},
		"attack": {"size": 2, "action_type": "discrete"},
		"dash": {"size": 2, "action_type": "discrete"},
		"power": {"size": 2, "action_type": "discrete"},
	}

func get_reward() -> float:
	var r = 0.0
	
	if not _player:
		return r
	
	# Recompensa por dañar al jugador
	var player_health_diff = _prev_player_health - _player.health.current_health
	r += player_health_diff * 2.0
	
	# Penalización por recibir daño
	var umbra_health_diff = _prev_umbra_health - _umbra.current_health
	r -= umbra_health_diff * 1.5
	
	# Recompensa por sobrevivir
	r += 0.001
	
	# Penalización por estar lejos del jugador
	var dist = _umbra.global_position.distance_to(_player.global_position)
	if dist > 300.0:
		r -= 0.002
	
	# Actualizar valores previos
	_prev_player_health = _player.health.current_health
	_prev_umbra_health = _umbra.current_health
	
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
	_umbra.current_health = _umbra.max_health
	if _player:
		_prev_player_health = _player.health.current_health
	_prev_umbra_health = _umbra.current_health
