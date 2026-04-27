extends MainMenu

@export_range(2, 50, 1) var max_level := 8
@export var grayscale_background_color := Color(0.42, 0.44, 0.5, 1.0)
@export var overlay_base_alpha := 0.55
@export var overlay_min_alpha := 0.12
@export var breathing_enabled := true
@export_range(0.5, 5.0, 0.1) var breathing_speed := 1.0
@export_range(1.0, 3.0, 0.1) var breathing_amplitude := 2.0

@onready var background_texture_rect: TextureRect = $BackgroundTextureRect
@onready var progression_overlay: ColorRect = $ProgressionOverlay
@onready var entry_fade_rect: ColorRect = $EntryFadeCanvasLayer/EntryFadeRect
@onready var menu_container_fx: MarginContainer = %MenuContainer
@onready var menu_buttons_box_container_fx: BoxContainer = %MenuButtonsBoxContainer
@onready var gem_particles: CPUParticles2D = $GemCanvasLayer/GemParticles

var _progress := 0.0
var _base_menu_y := 0.0
var _breathing_time := 0.0


func _ready() -> void:
	super._ready()
	_base_menu_y = menu_container_fx.position.y
	_progress = _resolve_progress()
	_update_effect_layout()
	_apply_color_progression(_progress)
	_play_entry_fade()
	menu_buttons_box_container_fx.focus_first()
	set_process(breathing_enabled)


func _process(delta: float) -> void:
	if not breathing_enabled:
		return

	_breathing_time += delta * breathing_speed
	menu_container_fx.position.y = _base_menu_y + sin(_breathing_time) * breathing_amplitude


func _resolve_progress() -> float:
	var game_state := _get_game_state()
	if game_state == null:
		return 0.0

	var denominator := float(max(1, max_level - 1))
	return clamp((float(game_state.current_level) - 1.0) / denominator, 0.0, 1.0)


func _apply_color_progression(progress: float) -> void:
	# Solo afecta fondo y capas de ambientacion para preservar legibilidad de texto.
	background_texture_rect.modulate = grayscale_background_color.lerp(Color(1, 1, 1, 1), progress)
	progression_overlay.color.a = lerp(overlay_base_alpha, overlay_min_alpha, progress)
	_apply_gem_particles_style(progress)


func _apply_gem_particles_style(progress: float) -> void:
	var desaturated := Color(0.44, 0.48, 0.56, 0.2)
	var energized := Color(0.62, 0.95, 1.0, 0.48)
	gem_particles.modulate = desaturated.lerp(energized, progress)
	gem_particles.amount = int(16 + progress * 28.0)


func _play_entry_fade() -> void:
	entry_fade_rect.color = Color(0, 0, 0, 1)
	entry_fade_rect.show()
	var fade_tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fade_tween.tween_property(entry_fade_rect, "color:a", 0.0, 1.0)
	fade_tween.finished.connect(func() -> void:
		entry_fade_rect.hide()
	, CONNECT_ONE_SHOT)


func _update_effect_layout() -> void:
	gem_particles.position = get_viewport_rect().size * 0.5


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_effect_layout()


func _get_game_state() -> Node:
	if has_node("/root/GameState"):
		return get_node("/root/GameState")
	return null
