extends Node

# =========================
# CONFIG SERVER
# =========================
const SERVER_KEY := "defaultkey"
const AUTH_TIMEOUT_SECONDS := 10
const NETWORK_CONFIG_PATH := "user://network_config.json"

var _network_config := {
	"scheme": "http",
	"host": "64.226.80.31",
	"port": 7350,
}

# =========================
# NAKAMA CORE
# =========================
var client
var session

# =========================
# PLAYER DATA
# =========================
var device_id: String
var nickname: String = ""
var has_authenticated := false

# =========================
# CURRENT RUN STATS
# =========================
var _current_run := {
	"level_id": -1,
	"start_time": 0,
	"total_level_time": 0,
	"deaths": 0,
	"enemies_killed": 0,
	"damage_dealt": 0,
	"damage_taken": 0,
	"skills_used": {},
	"prism_cores": 0
}

# =========================
# CAMPAIGN STATS (accumulated across all levels, persisted)
# =========================
var _campaign_stats := _make_default_campaign_stats()

static func _make_default_campaign_stats() -> Dictionary:
	return {
		"total_time": 0,
		"total_kills": 0,
		"total_deaths": 0,
		"total_damage_dealt": 0,
		"total_damage_taken": 0,
		"total_prism_cores": 0,
		"campaign_completed": false,
		"levels_completed": {}
	}

# =========================
# OFFLINE QUEUE & LOCAL CACHE
# =========================
var _pending_queue := []
var _retry_timer: Timer
var _local_best_runs := {}

# =========================
# LIFECYCLE
# =========================
func _ready():
	_load_network_config()
	device_id = OS.get_unique_id().trim_prefix("{").trim_suffix("}")
	if has_node("/root/GameState"):
		var gs = get_node("/root/GameState")
		nickname = gs.player_progress.get("nickname", "")
		if gs.player_progress.has("campaign_stats"):
			load_campaign_stats(gs.player_progress["campaign_stats"])
		if gs.player_progress.has("pending_queue"):
			_pending_queue = gs.player_progress["pending_queue"].duplicate(true)
		if gs.player_progress.has("local_best_runs"):
			_local_best_runs = gs.player_progress["local_best_runs"].duplicate(true)
		gs.player_progress_reset.connect(_on_player_progress_reset)
	if not _pending_queue.is_empty():
		_start_retry_timer()
	await authenticate()
	_flush_pending_queue()

func _load_network_config() -> void:
	if FileAccess.file_exists(NETWORK_CONFIG_PATH):
		var file := FileAccess.open(NETWORK_CONFIG_PATH, FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			file.close()
			if typeof(parsed) == TYPE_DICTIONARY:
				for key in _network_config.keys():
					if parsed.has(key):
						_network_config[key] = parsed[key]
				print("Network config loaded:", _network_config["host"])
				return
	_save_network_config()


func _save_network_config() -> void:
	var file := FileAccess.open(NETWORK_CONFIG_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_network_config, "\t"))
		file.close()


# =========================
# AUTH
# =========================
func authenticate():
	client = Nakama.create_client(SERVER_KEY, _network_config["host"], _network_config["port"], _network_config["scheme"], AUTH_TIMEOUT_SECONDS)

	var nakama_node := get_node("/root/Nakama")
	var adapter: NakamaHTTPAdapter = nakama_node.get_client_adapter()
	adapter.use_threads = false
	adapter.timeout = AUTH_TIMEOUT_SECONDS

	var result = await client.authenticate_device_async(device_id)

	if result.is_exception():
		push_error("Nakama auth failed: " + str(result))
		return

	session = result
	has_authenticated = true
	_flush_pending_queue()

	print("Nakama logged in:", session.user_id)

	if not nickname.is_empty():
		print("Syncing pending nickname to server:", nickname)
		var update_result = await client.update_account_async(session, nickname, nickname)
		if update_result.is_exception():
			push_error("Failed to update username: " + str(update_result))

	var account = await client.get_account_async(session)
	if account.is_exception():
		push_error("Failed to get account: " + str(account))
	else:
		print("Account username on server:", account.user.username)

# =========================
# RUN SYSTEM
# =========================
func start_run(level_id: int):
	var old_run = _current_run.duplicate(true)
	_current_run = {
		"level_id": level_id,
		"start_time": Time.get_unix_time_from_system(),
		"total_level_time": 0,
		"deaths": 0,
		"enemies_killed": 0,
		"damage_dealt": 0,
		"damage_taken": 0,
		"skills_used": {},
		"prism_cores": 0
	}
	if old_run["level_id"] == level_id and old_run["start_time"] > 0:
		_current_run["start_time"] = old_run["start_time"]
		_current_run["total_level_time"] = old_run["total_level_time"]
		_current_run["deaths"] = old_run["deaths"]
		_current_run["enemies_killed"] = old_run["enemies_killed"]
		_current_run["damage_dealt"] = old_run["damage_dealt"]
		_current_run["damage_taken"] = old_run["damage_taken"]
		_current_run["skills_used"] = old_run["skills_used"].duplicate(true)
		_current_run["prism_cores"] = old_run["prism_cores"]

	print("▶ Run started:", level_id, " (preserved: ", old_run["level_id"] == level_id and old_run["start_time"] > 0, ")")


func resume_run_timer(start_time: float) -> void:
	_current_run["start_time"] = start_time


func notify_death() -> void:
	if _current_run["start_time"] > 0:
		var segment := int(Time.get_unix_time_from_system() - _current_run["start_time"])
		_campaign_stats["total_time"] += max(0, segment)
		_current_run["total_level_time"] += max(0, segment)
	_campaign_stats["total_deaths"] += 1
	_persist_campaign_stats()
	_current_run["start_time"] = Time.get_unix_time_from_system()
	_current_run["deaths"] += 1


func complete_run(success: bool) -> void:
	if _current_run.is_empty() or _current_run["level_id"] == -1:
		return

	var end_time = Time.get_unix_time_from_system()
	var last_segment = int(end_time - _current_run["start_time"])
	var total_duration = _current_run["total_level_time"] + max(0, last_segment)
	var level_id = _current_run["level_id"]

	var metadata = {
		"level_id": level_id,
		"duration": total_duration,
		"deaths": _current_run["deaths"],
		"enemies_killed": _current_run["enemies_killed"],
		"damage_dealt": _current_run["damage_dealt"],
		"damage_taken": _current_run["damage_taken"],
		"skills_used": _current_run["skills_used"],
		"prism_cores": _current_run["prism_cores"],
		"nickname": nickname
	}

	# Per-level leaderboards only on completed runs
	if success:
		await _submit_level_leaderboards(level_id, total_duration, metadata)

	# Always accumulate to campaign stats (use last_segment for time to avoid double-count)
	var campaign_meta = metadata.duplicate()
	campaign_meta["duration"] = max(0, last_segment)
	_accumulate_to_campaign(campaign_meta)

	# Final level → submit campaign leaderboards
	if success and level_id == 4:
		await submit_campaign_leaderboards()

	# Persist campaign stats
	_persist_campaign_stats()

	print("Run completed. Level:", level_id, " Success:", success)
	_reset_current_run()


func _write_record(leaderboard_id: String, score: int, metadata: Dictionary) -> void:
	var meta_json := JSON.stringify(metadata)
	if not has_authenticated:
		_update_local_best(leaderboard_id, score, metadata)
		_enqueue_submission({"id": leaderboard_id, "score": score, "metadata_json": meta_json})
		return
	var result = await client.write_leaderboard_record_async(
		session, leaderboard_id, score, 0, meta_json
	)
	if result.is_exception():
		push_error("Failed to submit " + leaderboard_id + ": " + str(result))
		_enqueue_submission({"id": leaderboard_id, "score": score, "metadata_json": meta_json})
	else:
		_update_local_best(leaderboard_id, score, metadata)
		print("Leaderboard submitted:", leaderboard_id)


func _submit_level_leaderboards(level_id: int, total_duration: int, metadata: Dictionary) -> void:
	var score = compute_global_score(total_duration)
	var level_prefix = "level_%d" % level_id
	var score_lb_id = level_prefix + "_score"

	# Only submit if composite score improved
	var existing = get_local_best_for(score_lb_id)
	if not existing.is_empty() and score <= existing.get("score", 0):
		print("Score not improved for ", score_lb_id, " — skipping level leaderboards")
		return

	await _write_record(score_lb_id, score, metadata)

	var entries = [
		{"id": level_prefix + "_time", "score": max(1, int(1000000.0 / max(total_duration, 1)))},
		{"id": level_prefix + "_kills", "score": metadata["enemies_killed"]},
		{"id": level_prefix + "_deaths", "score": max(0, 1000 - metadata["deaths"])},
		{"id": level_prefix + "_damage_dealt", "score": metadata["damage_dealt"]},
		{"id": level_prefix + "_damage_received", "score": max(0, 100000 - metadata["damage_taken"])},
		{"id": level_prefix + "_prism_cores", "score": metadata["prism_cores"]},
	]

	for entry in entries:
		await _write_record(entry["id"], entry["score"], metadata)


func submit_campaign_leaderboards() -> void:
	if _campaign_stats["total_time"] <= 0:
		return

	_campaign_stats["campaign_completed"] = true

	var campaign_score_val: int = max(1, _campaign_stats["total_kills"] * 50 - _campaign_stats["total_deaths"] * 100 + _campaign_stats["total_prism_cores"] * 500)

	# Only submit if campaign score improved
	var existing = get_local_best_for("campaign_score")
	if not existing.is_empty() and campaign_score_val <= existing.get("score", 0):
		print("Campaign score not improved — skipping campaign leaderboards")
		return

	var entries = [
		{"id": "campaign_score", "score": campaign_score_val},
		{"id": "campaign_time", "score": max(1, int(1000000.0 / max(_campaign_stats["total_time"], 1)))},
		{"id": "campaign_kills", "score": _campaign_stats["total_kills"]},
		{"id": "campaign_deaths", "score": max(0, 10000 - _campaign_stats["total_deaths"])},
		{"id": "campaign_damage_dealt", "score": _campaign_stats["total_damage_dealt"]},
		{"id": "campaign_damage_received", "score": max(0, 1000000 - _campaign_stats["total_damage_taken"])},
		{"id": "campaign_prism_cores", "score": _campaign_stats["total_prism_cores"]},
	]

	var campaign_meta = _campaign_stats.duplicate()
	campaign_meta["nickname"] = nickname
	for entry in entries:
		await _write_record(entry["id"], entry["score"], campaign_meta)

	_persist_campaign_stats()


func _accumulate_to_campaign(metadata: Dictionary) -> void:
	_campaign_stats["total_time"] += max(0, int(metadata.get("duration", 0)))
	_campaign_stats["total_kills"] += max(0, int(metadata.get("enemies_killed", 0)))
	_campaign_stats["total_deaths"] += max(0, int(metadata.get("deaths", 0)))
	_campaign_stats["total_damage_dealt"] += max(0, int(metadata.get("damage_dealt", 0)))
	_campaign_stats["total_damage_taken"] += max(0, int(metadata.get("damage_taken", 0)))
	_campaign_stats["total_prism_cores"] += max(0, int(metadata.get("prism_cores", 0)))
	_campaign_stats["levels_completed"][str(metadata.get("level_id", -1))] = true


func _persist_campaign_stats() -> void:
	if not has_node("/root/GameState"):
		return
	var gs = get_node("/root/GameState")
	gs.player_progress["campaign_stats"] = _campaign_stats.duplicate(true)
	gs._save_player_progress()


func load_campaign_stats(stats: Dictionary) -> void:
	if typeof(stats) == TYPE_DICTIONARY and not stats.is_empty():
		for key in _campaign_stats.keys():
			if stats.has(key):
				_campaign_stats[key] = stats[key]


func reset_campaign_stats() -> void:
	_campaign_stats = _make_default_campaign_stats()
	_reset_current_run()


func _start_retry_timer() -> void:
	if _retry_timer == null or not is_instance_valid(_retry_timer):
		_retry_timer = Timer.new()
		_retry_timer.wait_time = 30.0
		_retry_timer.one_shot = true
		_retry_timer.timeout.connect(_flush_pending_queue)
		add_child(_retry_timer)
	_retry_timer.start()


func _stop_retry_timer() -> void:
	if _retry_timer != null and is_instance_valid(_retry_timer):
		_retry_timer.stop()


func _flush_pending_queue() -> void:
	if _pending_queue.is_empty():
		_stop_retry_timer()
		return

	if not has_authenticated:
		await authenticate()
		if not has_authenticated:
			_start_retry_timer()
			return

	var failed: Array = []
	for entry in _pending_queue:
		var result = await client.write_leaderboard_record_async(
			session, entry["id"], entry["score"], 0, entry["metadata_json"]
		)
		if result.is_exception():
			failed.append(entry)
		else:
			print("Deferred leaderboard submitted:", entry["id"])
	_pending_queue = failed
	_persist_pending_queue()

	if _pending_queue.is_empty():
		_stop_retry_timer()
	else:
		_start_retry_timer()


func _enqueue_submission(entry: Dictionary) -> void:
	_pending_queue.append(entry)
	_persist_pending_queue()
	_start_retry_timer()


func _persist_pending_queue() -> void:
	if not has_node("/root/GameState"):
		return
	var gs = get_node("/root/GameState")
	gs.player_progress["pending_queue"] = _pending_queue.duplicate(true)
	gs._save_player_progress()


func _update_local_best(leaderboard_id: String, score: int, metadata: Dictionary) -> void:
	var existing: Dictionary = _local_best_runs.get(leaderboard_id, {})
	if existing.is_empty() or score > existing.get("score", 0):
		_local_best_runs[leaderboard_id] = {
			"score": score,
			"metadata": metadata,
			"timestamp": Time.get_unix_time_from_system()
		}
		_persist_local_best_runs()


func _persist_local_best_runs() -> void:
	if not has_node("/root/GameState"):
		return
	var gs = get_node("/root/GameState")
	gs.player_progress["local_best_runs"] = _local_best_runs.duplicate(true)
	gs._save_player_progress()


func get_local_best_for(leaderboard_id: String) -> Dictionary:
	return _local_best_runs.get(leaderboard_id, {})


func _on_player_progress_reset() -> void:
	reset_campaign_stats()

# =========================
# SCORE FORMULA
# =========================
func _reset_current_run() -> void:
	_current_run = {
		"level_id": -1,
		"start_time": 0,
		"total_level_time": 0,
		"deaths": 0,
		"enemies_killed": 0,
		"damage_dealt": 0,
		"damage_taken": 0,
		"skills_used": {},
		"prism_cores": 0
	}


func compute_global_score(time_seconds: int) -> int:
	var score = 0

	if time_seconds > 0:
		score += int(10000.0 / time_seconds)

	score += _current_run["enemies_killed"] * 50
	score -= _current_run["deaths"] * 100
	score += _current_run["prism_cores"] * 500

	return max(1, score)

# =========================
# NICKNAME
# =========================

func set_nickname(p_nickname: String) -> void:
	nickname = p_nickname
	if not has_authenticated:
		return
	var result = await client.update_account_async(session, nickname, nickname)
	if result.is_exception():
		push_error("Failed to set nickname on server: " + str(result))
	else:
		print("Nickname synced to server:", nickname)

# =========================
# LEADERBOARD
# =========================

func fetch_leaderboard_top(leaderboard_id: String, limit := 50):
	if not has_authenticated:
		return []
	var result = await client.list_leaderboard_records_async(session, leaderboard_id, null, null, limit)
	if result.is_exception():
		push_error("Failed to fetch leaderboard: " + str(result))
		return []
	return result.records


func fetch_leaderboard_around_me(leaderboard_id: String, limit := 10):
	if not has_authenticated:
		return []
	var result = await client.list_leaderboard_records_around_owner_async(session, leaderboard_id, session.user_id, null, limit)
	if result.is_exception():
		push_error("Failed to fetch leaderboard around me: " + str(result))
		return []
	return result.records


func submit_leaderboard(leaderboard_id: String, record: Dictionary):
	await _write_record(leaderboard_id, record["score"], record["metadata"])

# =========================
# RUN UPDATES
# =========================
func add_damage_dealt(amount: int):
	_current_run["damage_dealt"] += amount


func add_damage_taken(amount: int):
	_current_run["damage_taken"] += amount


func add_enemy_kill():
	_current_run["enemies_killed"] += 1


func add_skill_used(color: String):
	if not _current_run["skills_used"].has(color):
		_current_run["skills_used"][color] = 0

	_current_run["skills_used"][color] += 1


func add_prism_core():
	_current_run["prism_cores"] += 1
