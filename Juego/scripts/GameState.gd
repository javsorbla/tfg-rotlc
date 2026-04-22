extends Node

signal level_reset

var spawn_position = Vector2.ZERO
var checkpoint_activated = false
var coming_from_transition: bool = false

const UMBRA_SAVE_PATH := "user://umbra_progress.json"
const PLAYER_PROGRESS_PATH := "user://player_progress.json"
const UMBRA_TRAINING_LOG_PATH := "user://umbra_training_episodes.jsonl"
const UMBRA_FINETUNE_METRICS_PATH := "user://umbra_metrics.json"
const UMBRA_FINETUNE_ONNX_PATH := "user://models/umbra_finetuned.onnx"
const UMBRA_FINETUNE_STATE_PATH := "user://umbra_finetune_state.json"
const UMBRA_BASE_MODEL_ZIP_PATH := "user://models/umbra_final.zip"
const UMBRA_FINETUNE_JOBS_LOG_PATH := "user://umbra_finetune_jobs.jsonl"
const UMBRA_FINETUNE_MAX_DURATION_MSEC := 180000
const UMBRA_HEADLESS_ENV_PATH := ""
const EDITOR_DISABLE_PLAYER_PROGRESS_PERSISTENCE := true

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

const BASE_PLAYER_MAX_HEALTH := 3

var current_level: int = 1
var cleared_boss_rooms: Dictionary = {}

var _finetuning_process_id: int = -1
var is_finetuning := false
var _finetune_job_started_msec: int = 0
var _finetune_last_completed_model_path := ""

var umbra_progress := _make_default_umbra_progress()
var player_progress := _make_default_player_progress()


func _make_default_player_progress() -> Dictionary:
	return {
		"max_health_bonus": 0,
		"prism_core_collected": false,
		"prism_core_collected_levels": {}
	}


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
	_load_player_progress()
	_load_umbra_progress()
	_load_finetune_state()


func _load_player_progress() -> void:
	if _is_editor_ephemeral_player_progress_enabled():
		player_progress = _make_default_player_progress()
		return

	if not FileAccess.file_exists(PLAYER_PROGRESS_PATH):
		_save_player_progress()
		return

	var file := FileAccess.open(PLAYER_PROGRESS_PATH, FileAccess.READ)
	if file == null:
		push_warning("No se pudo abrir el progreso del jugador para lectura")
		return

	var json_text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(json_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Progreso del jugador invalido, usando valores por defecto")
		player_progress = _make_default_player_progress()
		_save_player_progress()
		return

	for key in player_progress.keys():
		if parsed.has(key):
			player_progress[key] = parsed[key]

	if typeof(player_progress.get("prism_core_collected_levels", {})) != TYPE_DICTIONARY:
		player_progress["prism_core_collected_levels"] = {}

	# Evita estados inconsistentes si el bonus existe pero la bandera no.
	if int(player_progress.get("max_health_bonus", 0)) > 0:
		player_progress["prism_core_collected"] = true

	# Migracion desde progreso antiguo: convertir bonus acumulado a niveles desbloqueados.
	var collected_levels: Dictionary = player_progress.get("prism_core_collected_levels", {})
	if collected_levels.is_empty() and int(player_progress.get("max_health_bonus", 0)) > 0:
		var legacy_bonus := int(player_progress.get("max_health_bonus", 0))
		for level_idx in range(1, legacy_bonus + 1):
			collected_levels[str(level_idx)] = true
		player_progress["prism_core_collected_levels"] = collected_levels

	_recompute_player_bonus_from_levels()


func _save_player_progress() -> void:
	if _is_editor_ephemeral_player_progress_enabled():
		return

	var file := FileAccess.open(PLAYER_PROGRESS_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("No se pudo abrir el progreso del jugador para escritura")
		return
	file.store_string(JSON.stringify(player_progress, "\t"))
	file.close()


func _is_editor_ephemeral_player_progress_enabled() -> bool:
	return EDITOR_DISABLE_PLAYER_PROGRESS_PERSISTENCE and OS.has_feature("editor")


func get_player_max_health() -> int:
	var bonus := int(player_progress.get("max_health_bonus", 0))
	return max(BASE_PLAYER_MAX_HEALTH, BASE_PLAYER_MAX_HEALTH + bonus)


func has_prism_core_upgrade(level_id: int = -1) -> bool:
	var resolved_level := _resolve_prism_core_level(level_id)
	var collected_levels: Dictionary = player_progress.get("prism_core_collected_levels", {})
	return bool(collected_levels.get(str(resolved_level), false))


func collect_prism_core(level_id: int = -1) -> bool:
	var resolved_level := _resolve_prism_core_level(level_id)
	if has_prism_core_upgrade(resolved_level):
		return false

	var collected_levels: Dictionary = player_progress.get("prism_core_collected_levels", {})
	collected_levels[str(resolved_level)] = true
	player_progress["prism_core_collected_levels"] = collected_levels
	_recompute_player_bonus_from_levels()
	_save_player_progress()
	return true


func _resolve_prism_core_level(level_id: int) -> int:
	if level_id > 0:
		return level_id
	return maxi(1, current_level)


func _recompute_player_bonus_from_levels() -> void:
	var collected_levels: Dictionary = player_progress.get("prism_core_collected_levels", {})
	player_progress["max_health_bonus"] = collected_levels.size()
	player_progress["prism_core_collected"] = collected_levels.size() > 0


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


func get_umbra_runtime_model_path() -> String:
	if _finetune_last_completed_model_path != "":
		return _finetune_last_completed_model_path
	return str(umbra_progress.get("latest_model_path", ""))


func save_metrics_for_finetuning() -> bool:
	var metrics := get_umbra_player_metrics()
	if metrics.is_empty():
		return false

	var file := FileAccess.open(UMBRA_FINETUNE_METRICS_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("No se pudieron guardar metricas para fine-tuning")
		return false

	file.store_string(JSON.stringify(metrics))
	file.close()
	return true


func start_finetuning(timesteps := 2000) -> bool:
	if is_finetuning:
		return false

	if not save_metrics_for_finetuning():
		return false

	var script_abs := ProjectSettings.globalize_path("res://../finetune_umbra.py")
	var metrics_abs := ProjectSettings.globalize_path(UMBRA_FINETUNE_METRICS_PATH)
	var model_zip_abs := _resolve_base_model_zip_absolute()
	if model_zip_abs.is_empty():
		push_warning("No hay modelo base .zip disponible para fine-tuning")
		_append_finetune_job_log({
			"status": "failed",
			"reason": "missing_base_model_zip"
		})
		return false
	var onnx_abs := ProjectSettings.globalize_path(UMBRA_FINETUNE_ONNX_PATH)
	var python_abs := ProjectSettings.globalize_path("res://../venv/Scripts/python.exe")
	var headless_env_abs := _resolve_headless_env_absolute()

	if not FileAccess.file_exists(script_abs):
		push_warning("No existe finetune_umbra.py: %s" % script_abs)
		return false

	if not FileAccess.file_exists(python_abs):
		push_warning("No existe Python del venv: %s" % python_abs)
		return false

	var output_dir_abs := onnx_abs.get_base_dir()
	DirAccess.make_dir_recursive_absolute(output_dir_abs)

	var args := [
		script_abs,
		metrics_abs,
		model_zip_abs,
		onnx_abs,
		str(timesteps),
		headless_env_abs
	]

	_finetuning_process_id = OS.create_process(python_abs, args)
	if _finetuning_process_id <= 0:
		push_warning("No se pudo iniciar fine-tuning en background")
		_finetuning_process_id = -1
		_append_finetune_job_log({
			"status": "failed",
			"reason": "create_process_failed"
		})
		return false

	is_finetuning = true
	_finetune_job_started_msec = Time.get_ticks_msec()
	_append_finetune_job_log({
		"status": "started",
		"pid": _finetuning_process_id,
		"timesteps": timesteps,
		"model_zip": model_zip_abs,
		"output_onnx": onnx_abs,
		"headless_env": headless_env_abs
	})
	print("Fine-tuning iniciado (PID): ", _finetuning_process_id)
	return true


func check_finetuning_done() -> bool:
	if not is_finetuning:
		return true

	if _finetuning_process_id <= 0:
		is_finetuning = false
		return true

	if OS.is_process_running(_finetuning_process_id):
		if (Time.get_ticks_msec() - _finetune_job_started_msec) > UMBRA_FINETUNE_MAX_DURATION_MSEC:
			push_warning("Fine-tuning supero el tiempo maximo; se mantiene el modelo anterior")
			_append_finetune_job_log({
				"status": "timeout",
				"pid": _finetuning_process_id,
				"elapsed_msec": Time.get_ticks_msec() - _finetune_job_started_msec
			})
			is_finetuning = false
			_finetuning_process_id = -1
			return true
		return false

	is_finetuning = false
	_finetuning_process_id = -1

	var finetuned_onnx_abs := ProjectSettings.globalize_path(UMBRA_FINETUNE_ONNX_PATH)
	if _is_valid_onnx_output(finetuned_onnx_abs):
		_finetune_last_completed_model_path = UMBRA_FINETUNE_ONNX_PATH
		set_umbra_latest_model_path(_finetune_last_completed_model_path)
		_save_finetune_state()
		_append_finetune_job_log({
			"status": "completed",
			"output_onnx": finetuned_onnx_abs,
			"elapsed_msec": Time.get_ticks_msec() - _finetune_job_started_msec
		})
		print("Fine-tuning completado. ONNX listo en: ", _finetune_last_completed_model_path)
	else:
		_append_finetune_job_log({
			"status": "failed",
			"reason": "invalid_onnx_output",
			"output_onnx": finetuned_onnx_abs
		})
		push_warning("Fine-tuning finalizado pero ONNX invalido/no generado. Se mantiene modelo anterior")

	return true


func _save_finetune_state() -> void:
	var file := FileAccess.open(UMBRA_FINETUNE_STATE_PATH, FileAccess.WRITE)
	if file == null:
		return

	var payload := {
		"last_completed_model_path": _finetune_last_completed_model_path
	}
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()


func _load_finetune_state() -> void:
	if not FileAccess.file_exists(UMBRA_FINETUNE_STATE_PATH):
		return

	var file := FileAccess.open(UMBRA_FINETUNE_STATE_PATH, FileAccess.READ)
	if file == null:
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(parsed) == TYPE_DICTIONARY:
		_finetune_last_completed_model_path = str(parsed.get("last_completed_model_path", ""))


func _is_valid_onnx_output(absolute_path: String) -> bool:
	if absolute_path.is_empty():
		return false
	if not FileAccess.file_exists(absolute_path):
		return false
	if not absolute_path.to_lower().ends_with(".onnx"):
		return false

	var file := FileAccess.open(absolute_path, FileAccess.READ)
	if file == null:
		return false

	var length := file.get_length()
	file.close()
	return length > 256


func _resolve_base_model_zip_absolute() -> String:
	var primary_abs := ProjectSettings.globalize_path(UMBRA_BASE_MODEL_ZIP_PATH)
	if FileAccess.file_exists(primary_abs):
		return primary_abs

	var latest := str(umbra_progress.get("latest_model_path", ""))
	if latest.ends_with(".zip"):
		var latest_abs := ProjectSettings.globalize_path(latest)
		if FileAccess.file_exists(latest_abs):
			return latest_abs

	return ""


func _resolve_headless_env_absolute() -> String:
	if UMBRA_HEADLESS_ENV_PATH.is_empty():
		return ""

	if UMBRA_HEADLESS_ENV_PATH.begins_with("res://") or UMBRA_HEADLESS_ENV_PATH.begins_with("user://"):
		return ProjectSettings.globalize_path(UMBRA_HEADLESS_ENV_PATH)

	return UMBRA_HEADLESS_ENV_PATH


func _append_finetune_job_log(payload: Dictionary) -> void:
	var file := FileAccess.open(UMBRA_FINETUNE_JOBS_LOG_PATH, FileAccess.WRITE_READ)
	if file == null:
		return

	file.seek_end()
	payload["timestamp_unix"] = Time.get_unix_time_from_system()
	file.store_line(JSON.stringify(payload))
	file.close()


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
