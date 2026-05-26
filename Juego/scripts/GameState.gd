extends Node

signal level_reset
signal save_started(reason: String)
signal save_finished(success: bool)

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
const SAVE_DATA_VERSION := 1
const SAVE_PATH := "user://savegame.json"
const SAVE_TMP_PATH := "user://savegame.json.tmp"
const SAVE_BAK_PATH := "user://savegame.json.bak"

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

var current_level: int = 0
var cleared_boss_rooms: Dictionary = {}
var current_level_path: String = ""

const LEVEL_ORDER := [
	"res://scenes/Tutorial.tscn",
	"res://scenes/CamposDeZafiro.tscn",
	"res://scenes/MontañasDeCeniza.tscn",
	"res://scenes/CostaAmbar.tscn",
]

var _finetuning_process_id: int = -1
var is_finetuning := false
var _finetune_job_started_msec: int = 0
var _finetune_last_completed_model_path := ""
var _onnx_models: Dictionary = {}
var _onnx_model_file_mtimes: Dictionary = {}

var umbra_progress := _make_default_umbra_progress()
var player_progress := _make_default_player_progress()


func _make_default_player_progress() -> Dictionary:
	return {
		"max_health_bonus": 0,
		"prism_core_collected": false,
		"prism_core_collected_levels": {},
		"unlocked_powers": _make_default_unlocked_powers()
	}


func _make_default_unlocked_powers() -> Dictionary:
	return {
		"cyan": false,
		"red": false,
		"yellow": false
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

	_ensure_unlocked_powers_defaults()

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


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(SAVE_BAK_PATH)


func save_game(reason := "") -> bool:
	emit_signal("save_started", reason)
	_ensure_unlocked_powers_defaults()
	var payload := _build_save_payload()
	var wrapper := _wrap_save_payload(payload)
	var json_text := JSON.stringify(wrapper, "\t")
	var success := _write_save_file(json_text)
	emit_signal("save_finished", success)
	return success


func reset_for_new_game() -> void:
	# Remove existing save files and reset in-memory progress to defaults.
	if FileAccess.file_exists(SAVE_PATH):
		var abs := ProjectSettings.globalize_path(SAVE_PATH)
		DirAccess.remove_absolute(abs)
	if FileAccess.file_exists(SAVE_BAK_PATH):
		var abs_bak := ProjectSettings.globalize_path(SAVE_BAK_PATH)
		DirAccess.remove_absolute(abs_bak)
	if FileAccess.file_exists(PLAYER_PROGRESS_PATH):
		var abs_pp := ProjectSettings.globalize_path(PLAYER_PROGRESS_PATH)
		DirAccess.remove_absolute(abs_pp)
	if FileAccess.file_exists(UMBRA_SAVE_PATH):
		var abs_umbra := ProjectSettings.globalize_path(UMBRA_SAVE_PATH)
		DirAccess.remove_absolute(abs_umbra)

	player_progress = _make_default_player_progress()
	umbra_progress = _make_default_umbra_progress()
	current_level = 0
	current_level_path = ""
	spawn_position = Vector2.ZERO
	checkpoint_activated = false

	# Persist cleared player progress (so has_save() returns false)
	_save_player_progress()


func load_game() -> bool:
	var loaded := _load_game_from_path(SAVE_PATH)
	if loaded:
		return true
	return _load_game_from_path(SAVE_BAK_PATH)


func activate_checkpoint(position: Vector2, reason := "checkpoint") -> bool:
	if position == spawn_position and checkpoint_activated:
		return false
	spawn_position = position
	checkpoint_activated = true
	save_game(reason)
	return true


func get_unlocked_powers() -> Dictionary:
	var unlocked_var: Variant = player_progress.get("unlocked_powers", _make_default_unlocked_powers())
	if typeof(unlocked_var) != TYPE_DICTIONARY:
		unlocked_var = _make_default_unlocked_powers()
	var unlocked: Dictionary = unlocked_var
	return unlocked.duplicate(true)


func unlock_power(color: String, save := true) -> bool:
	var unlocked := get_unlocked_powers()
	if not unlocked.has(color):
		return false
	if unlocked[color]:
		return false
	unlocked[color] = true
	player_progress["unlocked_powers"] = unlocked
	if save:
		_save_player_progress()
		save_game("unlock_power")
	return true


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
	save_game("prism_core")
	return true


func has_boss_crystal(level_id: int = -1, variant: int = 0) -> bool:
	var resolved: int = level_id if level_id > 0 else current_level
	var collected_var: Variant = player_progress.get("boss_crystals", {})
	if typeof(collected_var) != TYPE_DICTIONARY:
		return false
	var collected: Dictionary = collected_var as Dictionary
	var level_dict_var: Variant = collected.get(str(resolved), {})
	if typeof(level_dict_var) != TYPE_DICTIONARY:
		return false
	var level_dict: Dictionary = level_dict_var as Dictionary
	return bool(level_dict.get(str(variant), false))


func collect_boss_crystal(level_id: int = -1, variant: int = 0) -> bool:
	var resolved: int = level_id if level_id > 0 else current_level
	if has_boss_crystal(resolved, variant):
		return false
	var collected_var: Variant = player_progress.get("boss_crystals", {})
	var collected: Dictionary
	if typeof(collected_var) != TYPE_DICTIONARY:
		collected = {}
	else:
		collected = collected_var as Dictionary

	var level_key: String = str(resolved)
	var level_dict_var: Variant = collected.get(level_key, {})
	var level_dict: Dictionary
	if typeof(level_dict_var) != TYPE_DICTIONARY:
		level_dict = {}
	else:
		level_dict = level_dict_var as Dictionary

	level_dict[str(variant)] = true
	collected[level_key] = level_dict
	player_progress["boss_crystals"] = collected
	_save_player_progress()
	save_game("boss_crystal")
	return true


func _resolve_prism_core_level(level_id: int) -> int:
	if level_id > 0:
		return level_id
	return maxi(1, current_level)

func _recompute_player_bonus_from_levels() -> void:
	var collected_levels: Dictionary = player_progress.get("prism_core_collected_levels", {})
	player_progress["max_health_bonus"] = collected_levels.size()
	player_progress["prism_core_collected"] = collected_levels.size() > 0
	_ensure_unlocked_powers_defaults()


func _ensure_unlocked_powers_defaults() -> void:
	var unlocked_var: Variant = player_progress.get("unlocked_powers", _make_default_unlocked_powers())
	if typeof(unlocked_var) != TYPE_DICTIONARY:
		unlocked_var = _make_default_unlocked_powers()
	var unlocked: Dictionary = unlocked_var
	for key in _make_default_unlocked_powers().keys():
		if not unlocked.has(key):
			unlocked[key] = false
	player_progress["unlocked_powers"] = unlocked


func _build_save_payload() -> Dictionary:
	return {
		"version": SAVE_DATA_VERSION,
		"saved_at_msec": Time.get_ticks_msec(),
		"current_level": current_level,
		"current_level_path": current_level_path,
		"spawn_position": {
			"x": spawn_position.x,
			"y": spawn_position.y
		},
		"checkpoint_activated": checkpoint_activated,
		"player_progress": player_progress.duplicate(true)
	}


func _wrap_save_payload(payload: Dictionary) -> Dictionary:
	var payload_text := JSON.stringify(payload)
	return {
		"checksum": _compute_checksum(payload_text),
		"payload": payload
	}


func _compute_checksum(text: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(text.to_utf8_buffer())
	return context.finish().hex_encode()


func _write_save_file(json_text: String) -> bool:
	var tmp := FileAccess.open(SAVE_TMP_PATH, FileAccess.WRITE)
	if tmp == null:
		push_warning("No se pudo abrir el archivo temporal de guardado")
		return false
	tmp.store_string(json_text)
	tmp.close()

	if FileAccess.file_exists(SAVE_PATH):
		_copy_file(SAVE_PATH, SAVE_BAK_PATH)

	var tmp_abs := ProjectSettings.globalize_path(SAVE_TMP_PATH)
	var save_abs := ProjectSettings.globalize_path(SAVE_PATH)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(save_abs)
	var err := DirAccess.rename_absolute(tmp_abs, save_abs)
	if err != OK:
		push_warning("No se pudo completar el guardado: %s" % err)
		return false
	return true


func _copy_file(source_path: String, target_path: String) -> void:
	var bytes := FileAccess.get_file_as_bytes(source_path)
	if bytes.is_empty():
		return
	var file := FileAccess.open(target_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_buffer(bytes)
	file.close()


func _load_game_from_path(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	if not _validate_save_wrapper(parsed):
		return false
	var payload_var: Variant = parsed.get("payload", {})
	if typeof(payload_var) != TYPE_DICTIONARY:
		return false
	var payload: Dictionary = payload_var
	_apply_loaded_state(payload)
	return true


func _validate_save_wrapper(wrapper: Dictionary) -> bool:
	if not wrapper.has("checksum") or not wrapper.has("payload"):
		return false
	if typeof(wrapper["payload"]) != TYPE_DICTIONARY:
		return false
	var payload_text := JSON.stringify(wrapper["payload"])
	var checksum := str(wrapper.get("checksum", ""))
	return checksum == _compute_checksum(payload_text)


func _apply_loaded_state(payload: Dictionary) -> void:
	current_level = int(payload.get("current_level", current_level))
	current_level_path = str(payload.get("current_level_path", current_level_path))
	checkpoint_activated = bool(payload.get("checkpoint_activated", checkpoint_activated))
	var spawn_var: Variant = payload.get("spawn_position", {})
	if typeof(spawn_var) == TYPE_DICTIONARY:
		var spawn: Dictionary = spawn_var
		spawn_position = Vector2(float(spawn.get("x", spawn_position.x)), float(spawn.get("y", spawn_position.y)))
	var progress_var: Variant = payload.get("player_progress", {})
	if typeof(progress_var) == TYPE_DICTIONARY:
		var progress: Dictionary = progress_var
		player_progress = _make_default_player_progress()
		for key in player_progress.keys():
			if progress.has(key):
				player_progress[key] = progress[key]
		_recompute_player_bonus_from_levels()


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


func bind_onnx_model_for_agent(agent: Node, model_path: String) -> bool:
	if agent == null or not is_instance_valid(agent):
		return false

	var resolved_path := _resolve_onnx_model_path(model_path)
	if resolved_path.is_empty():
		return false

	prints("[GameState] bind_onnx_model_for_agent: agent=", agent, " model_path=", model_path, " resolved=", resolved_path)
	var model: ONNXModel = get_or_create_onnx_model(resolved_path)
	if model == null:
		prints("[GameState] bind_onnx_model_for_agent: failed to get model for ", resolved_path)
		return false

	if agent.has_method("set"):
		agent.set("onnx_model_path", resolved_path)
		agent.set("onnx_model", model)
		if not bool(model.action_means_only_set) and agent.has_method("get_action_space"):
			var action_space: Variant = agent.get_action_space()
			model.set_action_means_only(action_space)
		return true

	return false


func get_or_create_onnx_model(model_path: String) -> ONNXModel:
	var resolved_path := _resolve_onnx_model_path(model_path)
	if resolved_path.is_empty():
		return null

	prints("[GameState] get_or_create_onnx_model: requesting ", model_path)
	var current_mtime := FileAccess.get_modified_time(resolved_path)
	if _onnx_models.has(resolved_path):
		var existing_model: ONNXModel = _onnx_models[resolved_path]
		var cached_mtime := int(_onnx_model_file_mtimes.get(resolved_path, -1))
		prints("[GameState] cache hit check for ", resolved_path, " cached_mtime=", cached_mtime, " current=", current_mtime)
		if existing_model != null and cached_mtime == current_mtime:
			prints("[GameState] returning cached ONNX model for ", resolved_path)
			return existing_model
		_onnx_models.erase(resolved_path)
		_onnx_model_file_mtimes.erase(resolved_path)

	prints("[GameState] creating ONNX model for ", resolved_path)
	var inferencer_script = load("res://addons/godot_rl_agents/onnx/wrapper/ONNX_wrapper.gd")
	var created_model: ONNXModel = inferencer_script.new(resolved_path, 1)
	_onnx_models[resolved_path] = created_model
	_onnx_model_file_mtimes[resolved_path] = current_mtime
	prints("[GameState] created ONNX model and cached: ", resolved_path)
	return created_model


func clear_onnx_model_cache_for_path(model_path: String) -> void:
	var resolved_path := _resolve_onnx_model_path(model_path)
	if resolved_path.is_empty():
		return
	_onnx_models.erase(resolved_path)
	_onnx_model_file_mtimes.erase(resolved_path)


func _resolve_onnx_model_path(model_path: String) -> String:
	if model_path.is_empty():
		return ""

	if FileAccess.file_exists(model_path):
		return model_path

	if not model_path.begins_with("res://") and not model_path.begins_with("user://"):
		var res_path := "res://" + model_path
		if FileAccess.file_exists(res_path):
			return res_path

	return ""


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


func get_next_level_scene() -> String:
	# Return the scene path for the next level in LEVEL_ORDER based on current_level
	var next_index := int(current_level) + 1
	if next_index >= 0 and next_index < LEVEL_ORDER.size():
		return LEVEL_ORDER[next_index]
	return ""


func _append_finetune_job_log(payload: Dictionary) -> void:
	var file := FileAccess.open(UMBRA_FINETUNE_JOBS_LOG_PATH, FileAccess.WRITE_READ)
	if file == null:
		return

	file.seek_end()
	payload["timestamp_unix"] = Time.get_unix_time_from_system()
	file.store_line(JSON.stringify(payload))
	file.close()


func request_level_change(next_scene: String) -> void:
	if next_scene == "":
		# try to resolve next scene from level order
		var resolved := get_next_level_scene()
		if resolved == "":
			push_warning("request_level_change called with empty next_scene and no next level available")
			return
		next_scene = resolved
	# mark that we're coming from a transition so respawn logic can adapt
	coming_from_transition = true
	# persist current state before changing (small save)
	save_game("level_change")
	# change scene
	get_tree().change_scene(next_scene)


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
