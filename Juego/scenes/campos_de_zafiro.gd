extends Node2D

const MONTANAS_SCENE := "res://scenes/MontañasDeCeniza.tscn"
const PAUSE_MENU_LAYER_SCENE := preload("res://ui/menus/windows/pause_menu_layer.tscn")
const DEATH_SCREEN_SCENE := preload("res://ui/menus/windows/death_screen.tscn")
const CAMPOS_ZAFIRO_MUSIC := preload("res://music/scenes/campos_zafiro/campos_zafiro.ogg")
const VIENTO_SOUND := preload("res://music/scenes/campos_zafiro/viento.ogg")

const WIND_ZONE_X_MIN: float = 9700
const WIND_ZONE_X_MAX: float = 12800.0
const WIND_AMBIENT_VOLUME: float = -12.0

var wind_player: AudioStreamPlayer
var _wind_tween: Tween


# Called when the node enters the scene tree for the first time.
func _enter_tree() -> void:
	GameState.current_level = 1
	GameState.current_level_path = "res://scenes/CamposDeZafiro.tscn"

func _ready() -> void:

	if GameState.has_method("auto_unlock_power_for_level"):
		GameState.auto_unlock_power_for_level()
	
	NakamaManager.start_run(GameState.current_level)
	
	_ensure_pause_menu_layer()
	_ensure_death_screen()
	call_deferred("_wire_player_death")
	call_deferred("_mover_player")
	call_deferred("_start_level_music")
	_setup_wind_player()

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
		var camera = get_tree().get_first_node_in_group("camera")
		Hud.show_hud()
		Hud.update_hearts(player_health.current_health, player_health.MAX_HEALTH)
		if GameState.coming_from_transition:
			GameState.coming_from_transition = false
			GameState.checkpoint_activated = false
			player.global_position = Vector2(38, -7)
		elif GameState.checkpoint_activated:
			player.global_position = GameState.spawn_position
		else:
			player.global_position = Vector2(38, -7)
		if camera != null:
			camera.global_position = player.global_position + Vector2(30, -10)
			if camera.has_method("reset_smoothing"):
				camera.reset_smoothing()

func _on_final_body_entered(body) -> void:
	if body is CharacterBody2D:
		GameState.coming_from_transition = true
		ProjectMusicController.stop()
		get_tree().call_deferred("change_scene_to_file", MONTANAS_SCENE)

func _on_player_died(_owner: Node) -> void:
	var death_screen = get_node_or_null("DeathScreenLayer/DeathScreen")
	if death_screen != null and death_screen.has_method("show"):
		death_screen.call_deferred("show")

func _start_level_music() -> void:
	ProjectMusicController.play_stream(CAMPOS_ZAFIRO_MUSIC)

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var in_zone := player.global_position.x >= WIND_ZONE_X_MIN and player.global_position.x <= WIND_ZONE_X_MAX
	if in_zone:
		_fade_wind_to(4.0)
	else:
		_fade_wind_to(WIND_AMBIENT_VOLUME)

func _setup_wind_player() -> void:
	wind_player = AudioStreamPlayer.new()
	wind_player.name = "WindPlayer"
	wind_player.stream = VIENTO_SOUND
	wind_player.bus = &"EFX"
	wind_player.volume_db = WIND_AMBIENT_VOLUME
	add_child(wind_player)
	wind_player.play()

func _fade_wind_to(target_db: float) -> void:
	if _wind_tween and _wind_tween.is_valid():
		_wind_tween.kill()
	if absf(wind_player.volume_db - target_db) < 0.5:
		return
	_wind_tween = create_tween()
	_wind_tween.tween_property(wind_player, "volume_db", target_db, 1.5)
