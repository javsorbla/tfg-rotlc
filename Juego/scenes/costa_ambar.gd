extends Node2D

const PAUSE_MENU_LAYER_SCENE := preload("res://ui/menus/windows/pause_menu_layer.tscn")
const DEATH_SCREEN_SCENE := preload("res://ui/menus/windows/death_screen.tscn")
const TORMENTA_MUSIC := preload("res://music/scenes/costa_ambar/tormenta.ogg")
const CAVE_VOLUME_DB: float = -10.0
const VOLUME_FADE_DURATION: float = 1.5

var _in_cave: bool = false
var _prev_volume_target: float

func _ready() -> void:
	GameState.current_level = 3
	GameState.current_level_path = "res://scenes/CostaAmbar.tscn"
	if GameState.has_method("auto_unlock_power_for_level"):
		GameState.auto_unlock_power_for_level()
	NakamaManager.start_run(GameState.current_level)
	_ensure_pause_menu_layer()
	_ensure_death_screen()
	call_deferred("_init_level_hud_sync")
	call_deferred("_wire_player_death")
	call_deferred("_mover_player")
	call_deferred("_start_level_music")
	call_deferred("_connect_cave_zones")

func _ensure_pause_menu_layer() -> void:
	if get_node_or_null("PauseMenuLayer") != null:
		return
	add_child(PAUSE_MENU_LAYER_SCENE.instantiate())

func _ensure_death_screen() -> void:
	if get_node_or_null("DeathScreenLayer/DeathScreen") != null:
		return
	var death_layer := get_node_or_null("DeathScreenLayer")
	if death_layer == null:
		death_layer = CanvasLayer.new()
		death_layer.name = "DeathScreenLayer"
		death_layer.layer = 50
		add_child(death_layer)
	var death_screen = DEATH_SCREEN_SCENE.instantiate()
	death_screen.name = "DeathScreen"
	death_screen.hide()
	death_layer.add_child(death_screen)

func _wire_player_death() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var health = player.get_node_or_null("Health")
	if health == null:
		return
	health.auto_reset = false
	if health.has_method("set_death_callback"):
		health.set_death_callback(Callable(self, "_on_player_died"))
	elif health.has_signal("died") and not health.died.is_connected(_on_player_died):
		health.died.connect(_on_player_died)

func _mover_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var player_health = player.get_node("Health")
		Hud.show_hud()
		Hud.update_hearts(player_health.current_health, player_health.MAX_HEALTH)
		if GameState.coming_from_transition:
			GameState.coming_from_transition = false
			GameState.checkpoint_activated = false
			player.global_position = Vector2(-64, -14)
		elif GameState.checkpoint_activated:
			player.global_position = GameState.spawn_position
		else:
			player.global_position = Vector2(-64, -14)

func _process(_delta: float) -> void:
	var actual_player = ProjectMusicController.music_stream_player
	if not is_instance_valid(actual_player):
		return
	# Only adjust volume when tormenta is the current stream
	if actual_player.stream != TORMENTA_MUSIC:
		return
	var target_db = CAVE_VOLUME_DB if _in_cave else 0.0
	if not is_equal_approx(actual_player.volume_db, target_db):
		ProjectMusicController.blend_to(target_db, VOLUME_FADE_DURATION)

func _on_player_died(_owner: Node) -> void:
	var death_screen = get_node_or_null("DeathScreenLayer/DeathScreen")
	if death_screen != null and death_screen.has_method("show"):
		death_screen.call_deferred("show")

func _start_level_music() -> void:
	ProjectMusicController.play_stream(TORMENTA_MUSIC)
	_in_cave = _is_player_in_any_cave()
	if _in_cave:
		var p = ProjectMusicController.music_stream_player
		if is_instance_valid(p):
			p.volume_db = CAVE_VOLUME_DB

func _connect_cave_zones() -> void:
	for zone in get_tree().get_nodes_in_group("cave_zone"):
		if not zone.body_entered.is_connected(_on_cave_entered):
			zone.body_entered.connect(_on_cave_entered)
		if not zone.body_exited.is_connected(_on_cave_exited):
			zone.body_exited.connect(_on_cave_exited)

func _on_cave_entered(body: Node) -> void:
	if body.is_in_group("player") and not _in_cave:
		_in_cave = true
		_update_cave_volume()

func _on_cave_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_in_cave = _is_player_in_any_cave()
		if not _in_cave:
			_update_cave_volume()

func _is_player_in_any_cave() -> bool:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	for zone in get_tree().get_nodes_in_group("cave_zone"):
		if zone.overlaps_body(player):
			return true
	return false

func _update_cave_volume() -> void:
	var target_db = CAVE_VOLUME_DB if _in_cave else 0.0
	ProjectMusicController.blend_to(target_db, VOLUME_FADE_DURATION)
