extends Node

# =========================
# CONFIG SERVER
# =========================
const SCHEME := "http"
const HOST := "127.0.0.1"
const PORT := 7350
const SERVER_KEY := "defaultkey"

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
	device_id = OS.get_unique_id()
	await authenticate()

# =========================
# AUTH
# =========================
func authenticate():
	client = Nakama.create_client(SERVER_KEY, HOST, PORT, SCHEME)

	var result = await client.authenticate_device_async(device_id)

	if result.is_exception():
		push_error("Nakama auth failed: " + str(result))
		return

	session = result
	has_authenticated = true

	print("Nakama logged in:", session.user_id)

# =========================
# RUN SYSTEM
# =========================
func start_run(level_id: int):
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

	print("▶ Run started:", level_id)

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

# =========================
# SCORE FORMULA
# =========================
func compute_global_score(time_seconds: int) -> int:
	var score = 0

	if time_seconds > 0:
		score += int(10000.0 / time_seconds)

	score += _current_run["enemies_killed"] * 50
	score -= _current_run["deaths"] * 100
	score += _current_run["prism_cores"] * 500

	return max(1, score)

# =========================
# LEADERBOARD
# =========================

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
	_current_run["deaths"] += 1


func add_enemy_kill():
	_current_run["enemies_killed"] += 1


func add_skill_used(color: String):
	if not _current_run["skills_used"].has(color):
		_current_run["skills_used"][color] = 0

	_current_run["skills_used"][color] += 1


func add_prism_core():
	_current_run["prism_cores"] += 1
