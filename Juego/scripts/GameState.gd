extends Node

var spawn_position = Vector2.ZERO
var checkpoint_activated = false
var coming_from_transition: bool = false

const UMBRA_SAVE_PATH := "user://umbra_progress.json"
const UMBRA_TRAINING_LOG_PATH := "user://umbra_training_episodes.jsonl"

const DEFAULT_UMBRA_PLAYER_METRICS := {
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

var current_level: int = 1
var cleared_boss_rooms: Dictionary = {}

var umbra_progress := _make_default_umbra_progress()


func _make_default_umbra_progress() -> Dictionary:
	return {
		"encounters": 0,
		"wins": 0,
		"losses": 0,
		"difficulty_scale": 1.0,
		"player_metrics": DEFAULT_UMBRA_PLAYER_METRICS.duplicate(true),
		"latest_model_path": ""
	}


func _ready() -> void:
	_load_umbra_progress()


func _load_umbra_progress() -> void:
	if not FileAccess.file_exists(UMBRA_SAVE_PATH):
		_save_umbra_progress()
		return

	var file := FileAccess.open(UMBRA_SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("No se pudo abrir el progreso de Umbra para lectura")
		return

	var json_text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(json_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Progreso de Umbra invalido, usando valores por defecto")
		umbra_progress = _make_default_umbra_progress()
		_save_umbra_progress()
		return

	for key in umbra_progress.keys():
		if parsed.has(key):
			umbra_progress[key] = parsed[key]

	if not umbra_progress.has("player_metrics"):
		umbra_progress["player_metrics"] = DEFAULT_UMBRA_PLAYER_METRICS.duplicate(true)
	else:
		for metric_key in DEFAULT_UMBRA_PLAYER_METRICS.keys():
			if not umbra_progress["player_metrics"].has(metric_key):
				umbra_progress["player_metrics"][metric_key] = DEFAULT_UMBRA_PLAYER_METRICS[metric_key]


func reset_umbra_learning(clear_training_log := true, clear_latest_model := true) -> void:
	var previous_model := str(umbra_progress.get("latest_model_path", ""))
	umbra_progress = _make_default_umbra_progress()

	if not clear_latest_model and previous_model != "":
		umbra_progress["latest_model_path"] = previous_model

	_save_umbra_progress()

	if clear_training_log:
		var file := FileAccess.open(UMBRA_TRAINING_LOG_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string("")
			file.close()


func get_umbra_learning_summary() -> Dictionary:
	var encounters := int(umbra_progress.get("encounters", 0))
	var wins := int(umbra_progress.get("wins", 0))
	return {
		"encounters": encounters,
		"wins": wins,
		"losses": int(umbra_progress.get("losses", 0)),
		"win_rate": float(wins) / float(max(1, encounters)),
		"difficulty_scale": float(umbra_progress.get("difficulty_scale", 1.0)),
		"latest_model_path": str(umbra_progress.get("latest_model_path", ""))
	}


func _save_umbra_progress() -> void:
	var file := FileAccess.open(UMBRA_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("No se pudo abrir el progreso de Umbra para escritura")
		return
	file.store_string(JSON.stringify(umbra_progress, "\t"))
	file.close()


func get_umbra_player_metrics() -> Dictionary:
	return umbra_progress.get("player_metrics", {}).duplicate(true)


func get_umbra_difficulty_scale() -> float:
	return float(umbra_progress.get("difficulty_scale", 1.0))


func get_umbra_latest_model_path() -> String:
	return str(umbra_progress.get("latest_model_path", ""))


func set_umbra_latest_model_path(model_path: String) -> void:
	umbra_progress["latest_model_path"] = model_path
	_save_umbra_progress()


func get_umbra_bootstrap_data() -> Dictionary:
	return {
		"encounters": int(umbra_progress.get("encounters", 0)),
		"wins": int(umbra_progress.get("wins", 0)),
		"difficulty_scale": float(umbra_progress.get("difficulty_scale", 1.0)),
		"latest_model_path": str(umbra_progress.get("latest_model_path", "")),
		"player_metrics": get_umbra_player_metrics()
	}


func make_boss_room_key(scene_path: String, room_node_path: String) -> String:
	return "%s::%s" % [scene_path, room_node_path]


func mark_boss_room_cleared(room_key: String) -> void:
	if room_key == "":
		return
	cleared_boss_rooms[room_key] = true


func is_boss_room_cleared(room_key: String) -> bool:
	if room_key == "":
		return false
	return bool(cleared_boss_rooms.get(room_key, false))


func record_umbra_training_episode(episode_data: Dictionary) -> void:
	var file := FileAccess.open(UMBRA_TRAINING_LOG_PATH, FileAccess.WRITE_READ)
	if file == null:
		push_warning("No se pudo abrir el log de entrenamiento de Umbra")
		return

	file.seek_end()
	file.store_line(JSON.stringify(episode_data))
	file.close()


func register_umbra_encounter(encounter_data: Dictionary) -> void:
	umbra_progress["encounters"] = int(umbra_progress.get("encounters", 0)) + 1

	var umbra_won := bool(encounter_data.get("umbra_won", false))
	if umbra_won:
		umbra_progress["wins"] = int(umbra_progress.get("wins", 0)) + 1
	else:
		umbra_progress["losses"] = int(umbra_progress.get("losses", 0)) + 1

	var previous_metrics: Dictionary = get_umbra_player_metrics()
	var incoming_metrics: Dictionary = encounter_data.get("player_metrics", {})
	var blended: Dictionary = previous_metrics.duplicate(true)

	# Blend metrics to preserve long-term tendencies while adapting each encounter.
	for metric_key in previous_metrics.keys():
		var previous_value := float(previous_metrics.get(metric_key, 0.0))
		var incoming_value := float(incoming_metrics.get(metric_key, previous_value))
		blended[metric_key] = lerp(previous_value, incoming_value, 0.35)

	umbra_progress["player_metrics"] = blended

	var encounters: int = int(max(1, int(umbra_progress["encounters"])))
	var wins := int(umbra_progress.get("wins", 0))
	var win_rate := float(wins) / float(encounters)

	# Keep difficulty bounded to avoid spikes between sessions.
	umbra_progress["difficulty_scale"] = clamp(0.8 + win_rate * 0.6, 0.8, 1.4)

	_save_umbra_progress()
