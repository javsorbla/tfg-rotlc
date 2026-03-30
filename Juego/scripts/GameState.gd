extends Node

var spawn_position = Vector2.ZERO
var checkpoint_activated = false
var coming_from_transition: bool = false

const UMBRA_SAVE_PATH := "user://umbra_progress.json"

var current_level: int = 1

var umbra_progress := {
	"encounters": 0,
	"wins": 0,
	"losses": 0,
	"difficulty_scale": 1.0,
	"player_metrics": {
		"avg_distance": 200.0,
		"dash_frequency": 0.0,
		"attack_frequency": 0.0,
		"jump_frequency": 0.0,
		"preferred_side": 0.0
	},
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
		_save_umbra_progress()
		return

	for key in umbra_progress.keys():
		if parsed.has(key):
			umbra_progress[key] = parsed[key]

	if not umbra_progress.has("player_metrics"):
		umbra_progress["player_metrics"] = {
			"avg_distance": 200.0,
			"dash_frequency": 0.0,
			"attack_frequency": 0.0,
			"jump_frequency": 0.0,
			"preferred_side": 0.0
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
