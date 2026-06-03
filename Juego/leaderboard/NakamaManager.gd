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
	"level_id": "",
	"start_time": 0,
	"deaths": 0,
	"enemies_killed": 0,
	"damage_dealt": 0,
	"damage_taken": 0,
	"skills_used": {},
	"prism_cores": 0
}

# =========================
# LIFECYCLE
# =========================
func _ready():
	device_id = OS.get_unique_id().trim_prefix("{").trim_suffix("}")
	if has_node("/root/GameState"):
		var gs = get_node("/root/GameState")
		nickname = gs.player_progress.get("nickname", "")
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

func submit_run(payload: Dictionary) -> void:
	if not has_authenticated:
		return

	var object = NakamaWriteStorageObject.new(
		"runs",                         # collection 
		str(Time.get_unix_time_from_system()),  # key
		0,                              # permission_read 
		0,                              # permission_write 
		JSON.stringify(payload),        # value 
		""                              # version 
	)

	var result = await client.write_storage_objects_async(session, [object])

	if result.is_exception():
		print("Nakama error:", result)
	else:
		print("Run stored OK")

func complete_run(success: bool) -> void:
	if not has_authenticated:
		return

	if _current_run.is_empty():
		return

	var end_time = Time.get_unix_time_from_system()
	var duration = end_time - _current_run["start_time"]

	var global_score = compute_global_score(duration)

	var metadata = {
		"deaths": _current_run["deaths"],
		"enemies_killed": _current_run["enemies_killed"],
		"damage_dealt": _current_run["damage_dealt"],
		"damage_taken": _current_run["damage_taken"],
		"skills_used": _current_run["skills_used"],
		"prism_cores": _current_run["prism_cores"]
	}

	var record = {
		"score": global_score,
		"success": success,
		"metadata": metadata
	}

	await submit_leaderboard("global_score", record)

	print("Run completed. Score:", global_score)
	_reset_current_run()

# =========================
# SCORE FORMULA
# =========================
func _reset_current_run() -> void:
	_current_run = {
		"level_id": "",
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

func fetch_leaderboard_top(limit := 50):
	if not has_authenticated:
		return []
	var result = await client.list_leaderboard_records_async(session, "global_score", null, null, limit)
	if result.is_exception():
		push_error("Failed to fetch leaderboard: " + str(result))
		return []
	return result.records


func fetch_leaderboard_around_me(limit := 10):
	if not has_authenticated:
		return []
	var result = await client.list_leaderboard_records_around_owner_async(session, "global_score", session.user_id, null, limit)
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
		0, # subscore obligatorio
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
