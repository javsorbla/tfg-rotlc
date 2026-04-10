extends Node

const HUMAN_PLAYER_SCENE := preload("res://player/Player.tscn")

enum TrainingPreset {
	MANUAL,
	QUICK,
	SERIOUS,
	BALANCED_RELEASE
}

@export var human_training_mode := false
@export var auto_reset_delay := 0.8
@export var training_preset: TrainingPreset = TrainingPreset.QUICK
@export var preset_enabled := true
@export var auto_switch_mode_with_preset := true
@export var auto_stop_on_target := false
@export var min_episodes_before_stop := 30
@export var target_win_rate_low := 0.45
@export var target_win_rate_high := 0.65
@export var debug_overlay_enabled := true
@export var debug_overlay_refresh_interval := 0.2

@onready var umbra = $Umbra
@onready var player_dummy = $Player
@onready var spawn_umbra = $SpawnUmbra
@onready var spawn_player = $SpawnPlayer

var _episode_index := 0
var _episode_start_msec := 0
var _pending_reset := false
var _reset_timer := 0.0
var _reset_key_was_down := false
var _summary_key_was_down := false
var _toggle_mode_key_was_down := false
var _overlay_toggle_key_was_down := false
var _training_finished := false
var _preset_human_ratio := 0.3
var _preset_block_size := 10
var _manual_mode_override := false
var _human_player: CharacterBody2D
var _active_player: CharacterBody2D
var _overlay_layer: CanvasLayer
var _overlay_panel: Panel
var _overlay_label: RichTextLabel
var _overlay_refresh_timer := 0.0

func _ready():
	if umbra.has_signal("defeated"):
		umbra.defeated.connect(_on_umbra_defeated)

	if "despawn_on_death" in umbra:
		umbra.despawn_on_death = false

	_apply_preset_config()
	_apply_mode_from_preset()
	_set_training_mode(human_training_mode)
	umbra.ai_controller.init(_active_player)
	umbra.activate()
	_episode_start_msec = Time.get_ticks_msec()
	print("Entrenamiento Umbra | F9 reset aprendizaje | F10 resumen progreso")
	_setup_debug_overlay()
	_reset()


func _process(delta: float) -> void:
	var toggle_mode_down := Input.is_key_pressed(KEY_ENTER)
	if toggle_mode_down and not _toggle_mode_key_was_down:
		human_training_mode = not human_training_mode
		_manual_mode_override = true
		_set_training_mode(human_training_mode)
	_toggle_mode_key_was_down = toggle_mode_down

	var reset_down := Input.is_key_pressed(KEY_F9)
	if reset_down and not _reset_key_was_down:
		_hard_reset_learning()
	_reset_key_was_down = reset_down

	var summary_down := Input.is_key_pressed(KEY_F10)
	if summary_down and not _summary_key_was_down:
		_print_learning_summary()
	_summary_key_was_down = summary_down

	var overlay_down := Input.is_key_pressed(KEY_F11)
	if overlay_down and not _overlay_toggle_key_was_down:
		_toggle_debug_overlay()
	_overlay_toggle_key_was_down = overlay_down

	_update_debug_overlay(delta)

	if _training_finished:
		return

	if not _pending_reset:
		return

	_reset_timer -= delta
	if _reset_timer <= 0.0:
		_reset()


func _apply_preset_config() -> void:
	if not preset_enabled:
		return

	match training_preset:
		TrainingPreset.MANUAL:
			preset_enabled = false
		TrainingPreset.QUICK:
			_preset_human_ratio = 0.25
			_preset_block_size = 8
			auto_stop_on_target = false
		TrainingPreset.SERIOUS:
			_preset_human_ratio = 0.50
			_preset_block_size = 10
			auto_stop_on_target = false
		TrainingPreset.BALANCED_RELEASE:
			_preset_human_ratio = 0.35
			_preset_block_size = 12
			auto_stop_on_target = true
			min_episodes_before_stop = max(min_episodes_before_stop, 40)
			target_win_rate_low = 0.45
			target_win_rate_high = 0.60

	if preset_enabled:
		print(
			"Preset entrenamiento activo | ratio_humano=",
			_preset_human_ratio,
			" bloque=",
			_preset_block_size,
			" auto_stop=",
			auto_stop_on_target
		)


func _apply_mode_from_preset() -> void:
	if not preset_enabled or not auto_switch_mode_with_preset or _manual_mode_override:
		return

	var human_slots := int(round(float(_preset_block_size) * _preset_human_ratio))
	human_slots = clampi(human_slots, 0, _preset_block_size)
	var cycle_size: int = maxi(1, _preset_block_size)
	var slot: int = _episode_index % cycle_size
	human_training_mode = slot < human_slots


func _hard_reset_learning() -> void:
	GameState.reset_umbra_learning(true, true)
	_episode_index = 0
	_training_finished = false
	_manual_mode_override = false
	_apply_mode_from_preset()
	print("Entrenamiento Umbra | aprendizaje reseteado (progreso + log)")
	_reset()


func _print_learning_summary() -> void:
	var summary: Dictionary = GameState.get_umbra_learning_summary()
	print(
		"Umbra resumen | episodios=", summary.get("encounters", 0),
		" wins=", summary.get("wins", 0),
		" losses=", summary.get("losses", 0),
		" win_rate=", summary.get("win_rate", 0.0),
		" difficulty=", summary.get("difficulty_scale", 1.0)
	)


func _setup_debug_overlay() -> void:
	if not debug_overlay_enabled:
		return

	if _overlay_layer != null:
		return

	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "TrainingDebugOverlay"
	add_child(_overlay_layer)

	_overlay_panel = Panel.new()
	_overlay_panel.name = "OverlayPanel"
	_overlay_panel.position = Vector2(12, 10)
	_overlay_panel.size = Vector2(520, 210)
	_overlay_layer.add_child(_overlay_panel)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.05, 0.08, 0.78)
	panel_style.border_color = Color(0.22, 0.33, 0.50, 0.95)
	panel_style.set_border_width_all(2)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	_overlay_panel.add_theme_stylebox_override("panel", panel_style)

	_overlay_label = RichTextLabel.new()
	_overlay_label.name = "OverlayLabel"
	_overlay_label.position = Vector2(12, 10)
	_overlay_label.size = Vector2(496, 188)
	_overlay_label.bbcode_enabled = true
	_overlay_label.fit_content = false
	_overlay_label.scroll_active = false
	_overlay_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay_label.add_theme_font_size_override("normal_font_size", 14)
	_overlay_label.text = ""
	_overlay_panel.add_child(_overlay_label)

	print("Overlay entrenamiento activo | F11 mostrar/ocultar")


func _toggle_debug_overlay() -> void:
	if _overlay_layer == null:
		_setup_debug_overlay()
	if _overlay_layer == null:
		return
	_overlay_layer.visible = not _overlay_layer.visible


func _update_debug_overlay(delta: float) -> void:
	if not debug_overlay_enabled:
		return
	if _overlay_layer == null or _overlay_label == null:
		return
	if not _overlay_layer.visible:
		return

	_overlay_refresh_timer -= delta
	if _overlay_refresh_timer > 0.0:
		return
	_overlay_refresh_timer = debug_overlay_refresh_interval

	var summary: Dictionary = GameState.get_umbra_learning_summary()
	var episodes := int(summary.get("encounters", 0))
	var win_rate := float(summary.get("win_rate", 0.0))
	var difficulty := float(summary.get("difficulty_scale", 1.0))

	var player_hp := _get_active_player_health()
	var umbra_hp := int(umbra.current_health)

	var power_name := str(umbra.current_power)
	var power_active := bool(umbra.get("_power_active")) if "_power_active" in umbra else false
	var power_cd := float(umbra.get("_power_cooldown_timer")) if "_power_cooldown_timer" in umbra else 0.0
	var dark_cd := float(umbra.get("_darkness_cooldown_timer")) if "_darkness_cooldown_timer" in umbra else 0.0

	var mode_color := "#5ad1ff" if human_training_mode else "#ffa95a"
	var power_color := "#9ad0ff"
	match power_name:
		"cyan":
			power_color = "#44d6ff"
		"red":
			power_color = "#ff6f6f"
		"yellow":
			power_color = "#ffd95a"

	var active_color := "#69e39d" if power_active else "#9aa7b8"
	var win_color := "#69e39d" if win_rate <= 0.60 else "#ff8b8b"

	var bb := ""
	bb += "[b][color=#d8e7ff]UMBRA TRAINING OVERLAY[/color][/b]\n"
	bb += "[color=#8aa4c9]Modo:[/color] [color=" + mode_color + "]" + ("HUMANO" if human_training_mode else "SMART_BOT") + "[/color]\n"
	bb += "[color=#8aa4c9]Episodios:[/color] [b]" + str(episodes) + "[/b]    [color=#8aa4c9]WinRate:[/color] [color=" + win_color + "]" + str(snappedf(win_rate, 0.001)) + "[/color]\n"
	bb += "[color=#8aa4c9]Dificultad:[/color] [b]" + str(snappedf(difficulty, 0.01)) + "[/b]\n"
	bb += "[color=#8aa4c9]HP Umbra:[/color] " + str(umbra_hp) + "    [color=#8aa4c9]HP Player:[/color] " + str(player_hp) + "\n"
	bb += "[color=#8aa4c9]Poder:[/color] [color=" + power_color + "]" + power_name + "[/color]    [color=#8aa4c9]Activo:[/color] [color=" + active_color + "]" + str(power_active) + "[/color]\n"
	bb += "[color=#8aa4c9]CD poder:[/color] " + str(snappedf(power_cd, 0.01)) + "    [color=#8aa4c9]CD oscuridad:[/color] " + str(snappedf(dark_cd, 0.01)) + "\n"
	bb += "[color=#6e819e]F9 reset | F10 resumen consola | F11 overlay[/color]"

	_overlay_label.clear()
	_overlay_label.append_text(bb)


func _set_training_mode(is_human: bool) -> void:
	if is_human:
		_set_dummy_enabled(false)
		if _human_player == null:
			_human_player = HUMAN_PLAYER_SCENE.instantiate()
			_human_player.name = "TrainingHumanPlayer"
			add_child(_human_player)
		_active_player = _human_player
		_wire_player_death_callback(_active_player)
	else:
		if _human_player != null:
			_human_player.queue_free()
			_human_player = null
		_set_dummy_enabled(true)
		_active_player = player_dummy
		if player_dummy.has_method("set_control_mode"):
			player_dummy.set_control_mode(0)
		_wire_player_death_callback(_active_player)

	if umbra.ai_controller and _active_player != null:
		umbra.ai_controller.init(_active_player)

	print("Entrenamiento Umbra | modo jugador:", "HUMANO" if is_human else "SMART_BOT", " (Enter para alternar)")


func _wire_player_death_callback(player_node: CharacterBody2D) -> void:
	if player_node == null:
		return
	var health = player_node.get_node_or_null("Health")
	if health and health.has_method("set_death_callback"):
		health.set_death_callback(Callable(self, "_on_player_defeated"))


func _set_dummy_enabled(enabled: bool) -> void:
	player_dummy.visible = enabled
	player_dummy.set_process(enabled)
	player_dummy.set_physics_process(enabled)
	if enabled:
		if not player_dummy.is_in_group("player"):
			player_dummy.add_to_group("player")
		var hurtbox = player_dummy.get_node_or_null("Hurtbox")
		if hurtbox and not hurtbox.is_in_group("player_hurtbox"):
			hurtbox.add_to_group("player_hurtbox")
	else:
		if player_dummy.is_in_group("player"):
			player_dummy.remove_from_group("player")
		var hurtbox = player_dummy.get_node_or_null("Hurtbox")
		if hurtbox and hurtbox.is_in_group("player_hurtbox"):
			hurtbox.remove_from_group("player_hurtbox")
		if hurtbox:
			hurtbox.monitorable = false


func _on_umbra_defeated(umbra_won: bool) -> void:
	_finish_episode(umbra_won)


func _on_player_defeated() -> void:
	if umbra.has_method("report_player_defeated"):
		umbra.report_player_defeated()
	else:
		_finish_episode(true)


func _finish_episode(umbra_won: bool) -> void:
	if _pending_reset or _training_finished:
		return

	var elapsed_sec := float(Time.get_ticks_msec() - _episode_start_msec) / 1000.0
	var episode_data := {
		"episode": _episode_index,
		"timestamp_unix": Time.get_unix_time_from_system(),
		"umbra_won": umbra_won,
		"duration_sec": elapsed_sec,
		"dummy_mode": "human_player" if human_training_mode else "smart_bot",
		"umbra_health_end": umbra.current_health,
		"player_health_end": _get_active_player_health()
	}
	GameState.record_umbra_training_episode(episode_data)

	if _check_target_reached():
		_training_finished = true
		_pending_reset = false
		print("Entrenamiento Umbra | objetivo alcanzado. Se detiene el ciclo automatico.")
		_print_learning_summary()
		return

	_pending_reset = true
	_reset_timer = auto_reset_delay
	_episode_index += 1
	_apply_mode_from_preset()
	if preset_enabled and auto_switch_mode_with_preset and not _manual_mode_override:
		_set_training_mode(human_training_mode)

func _reset():
	if _training_finished:
		return

	_pending_reset = false
	_episode_start_msec = Time.get_ticks_msec()
	umbra.global_position = spawn_umbra.global_position
	umbra.current_health = umbra.max_health
	umbra.activate()
	if umbra.ai_controller and umbra.ai_controller.has_method("reset"):
		umbra.ai_controller.reset()

	if human_training_mode and _human_player != null:
		_reset_human_player()
	elif player_dummy.has_method("reset_for_training"):
		player_dummy.reset_for_training(spawn_player.global_position)
	else:
		player_dummy.global_position = spawn_player.global_position
		player_dummy.get_node("Health").current_health = player_dummy.get_node("Health").MAX_HEALTH


func _check_target_reached() -> bool:
	if not auto_stop_on_target:
		return false

	var summary: Dictionary = GameState.get_umbra_learning_summary()
	var encounters := int(summary.get("encounters", 0))
	if encounters < min_episodes_before_stop:
		return false

	var win_rate := float(summary.get("win_rate", 0.0))
	return win_rate >= target_win_rate_low and win_rate <= target_win_rate_high


func _reset_human_player() -> void:
	if _human_player == null:
		return
	_human_player.global_position = spawn_player.global_position
	_human_player.velocity = Vector2.ZERO
	var health = _human_player.get_node_or_null("Health")
	if health:
		health.current_health = health.MAX_HEALTH
		health.is_invincible = false
		health.invincibility_timer = 0.0
	var hurtbox = _human_player.get_node_or_null("Hurtbox")
	if hurtbox:
		hurtbox.set_deferred("monitorable", true)


func _get_active_player_health() -> int:
	if _active_player == null:
		return 0
	var health = _active_player.get_node_or_null("Health")
	if health == null:
		return 0
	return int(health.current_health)
