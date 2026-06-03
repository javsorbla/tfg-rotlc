extends Node

# =========================
# CONFIG SERVER
# =========================
const SCHEME := "http"
const HOST := "127.0.0.1"
const PORT := 7350
const SERVER_KEY := "defaultkey"
const AUTH_TIMEOUT_SECONDS := 10

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
# LIFECYCLE
# =========================
func _ready():
	device_id = OS.get_unique_id().trim_prefix("{").trim_suffix("}")
	if has_node("/root/GameState"):
		var gs = get_node("/root/GameState")
		nickname = gs.player_progress.get("nickname", "")
		if gs.player_progress.has("campaign_stats"):
			load_campaign_stats(gs.player_progress["campaign_stats"])
		gs.player_progress_reset.connect(_on_player_progress_reset)
	await authenticate()

# =========================
# AUTH
# =========================
func authenticate():
	client = Nakama.create_client(SERVER_KEY, HOST, PORT, SCHEME, AUTH_TIMEOUT_SECONDS)

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

	print("Nakama logged in:", session.user_id)

	if not nickname.is_empty():
		print("Syncing pending nickname to server:", nickname)
		var update_result = await client.update_account_async(session, nickname)
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
	var preserved_start = _current_run["start_time"]
	_current_run = {
		"level_id": level_id,
		"start_time": Time.get_unix_time_from_system(),
		"deaths": 0,
		"enemies_killed": 0,
		"damage_dealt": 0,
		"damage_taken": 0,
		"skills_used": {},
		"prism_cores": 0
	}
	if preserved_start > 0:
		_current_run["start_time"] = preserved_start

	print("▶ Run started:", level_id)


func resume_run_timer(start_time: float) -> void:
	_current_run["start_time"] = start_time


func complete_run(success: bool) -> void:
	if not has_authenticated:
		return
	if _current_run.is_empty() or _current_run["level_id"] == -1:
		return

	var end_time = Time.get_unix_time_from_system()
	var duration = int(end_time - _current_run["start_time"])
	var level_id = _current_run["level_id"]

	var metadata = {
		"level_id": level_id,
		"duration": duration,
		"deaths": _current_run["deaths"],
		"enemies_killed": _current_run["enemies_killed"],
		"damage_dealt": _current_run["damage_dealt"],
		"damage_taken": _current_run["damage_taken"],
		"skills_used": _current_run["skills_used"],
		"prism_cores": _current_run["prism_cores"]
	}

	# Per-level leaderboards only on completed runs
	if success:
		await _submit_level_leaderboards(level_id, duration, metadata)

	# Always accumulate to campaign stats
	_accumulate_to_campaign(metadata)

	# Final level → submit campaign leaderboards
	if success and level_id == 4:
		await submit_campaign_leaderboards()

	# Persist campaign stats
	_persist_campaign_stats()

	print("Run completed. Level:", level_id, " Success:", success)
	_reset_current_run()


func _submit_level_leaderboards(level_id: int, duration: int, metadata: Dictionary) -> void:
	var score = compute_global_score(duration)
	var level_prefix = "level_%d" % level_id
	var meta_json = JSON.stringify(metadata)

	# Composite score
	await submit_leaderboard(level_prefix + "_score", {
		"score": score,
		"success": true,
		"metadata": metadata
	})

	# Metric entries
	var entries = [
		{"id": level_prefix + "_time", "score": max(1, int(1000000.0 / max(duration, 1)))},
		{"id": level_prefix + "_kills", "score": metadata["enemies_killed"]},
		{"id": level_prefix + "_deaths", "score": max(0, 1000 - metadata["deaths"])},
		{"id": level_prefix + "_damage_dealt", "score": metadata["damage_dealt"]},
		{"id": level_prefix + "_damage_received", "score": max(0, 100000 - metadata["damage_taken"])},
		{"id": level_prefix + "_prism_cores", "score": metadata["prism_cores"]},
	]

	for entry in entries:
		var result = await client.write_leaderboard_record_async(
			session, entry["id"], entry["score"], 0, meta_json
		)
		if result.is_exception():
			push_error("Failed to submit " + entry["id"] + ": " + str(result))


func submit_campaign_leaderboards() -> void:
	if not has_authenticated:
		return
	if _campaign_stats["total_time"] <= 0:
		return

	_campaign_stats["campaign_completed"] = true
	var meta_json = JSON.stringify(_campaign_stats)

	var entries = [
		{"id": "campaign_time", "score": max(1, int(1000000.0 / max(_campaign_stats["total_time"], 1)))},
		{"id": "campaign_kills", "score": _campaign_stats["total_kills"]},
		{"id": "campaign_deaths", "score": max(0, 10000 - _campaign_stats["total_deaths"])},
		{"id": "campaign_damage_dealt", "score": _campaign_stats["total_damage_dealt"]},
		{"id": "campaign_damage_received", "score": max(0, 1000000 - _campaign_stats["total_damage_taken"])},
		{"id": "campaign_prism_cores", "score": _campaign_stats["total_prism_cores"]},
	]

	for entry in entries:
		var result = await client.write_leaderboard_record_async(
			session, entry["id"], entry["score"], 0, meta_json
		)
		if result.is_exception():
			push_error("Failed to submit campaign " + entry["id"] + ": " + str(result))
		else:
			print("Campaign leaderboard submitted:", entry["id"], " score:", entry["score"])

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


func _on_player_progress_reset() -> void:
	reset_campaign_stats()

# =========================
# SCORE FORMULA
# =========================
func _reset_current_run() -> void:
	_current_run = {
		"level_id": -1,
		"start_time": 0,
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
	var result = await client.update_account_async(session, nickname)
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
	if not has_authenticated:
		return
	var metadata_json := JSON.stringify(record["metadata"])

	var result = await client.write_leaderboard_record_async(
		session,
		leaderboard_id,
		record["score"],
		0,
		metadata_json
	)

	if result.is_exception():
		push_error("Failed leaderboard submit: " + str(result))
		return

	print("Leaderboard submitted:", leaderboard_id)

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
