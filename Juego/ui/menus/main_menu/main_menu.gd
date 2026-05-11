extends MainMenu

@export_range(0, 50, 1) var max_level := 5
@export var grayscale_background_color := Color(0.42, 0.44, 0.5, 1.0)
@export var overlay_base_alpha := 0.55
@export var overlay_min_alpha := 0.12
@export var breathing_enabled := false
@export_range(0.5, 5.0, 0.1) var breathing_speed := 1.0
@export_range(1.0, 3.0, 0.1) var breathing_amplitude := 2.0

const BUTTON_LEVEL_NORMAL_COLORS := {
	0: Color(0.74, 0.78, 0.88, 0.95),
	1: Color(0.72, 0.88, 1.0, 0.98),
	2: Color(0.95, 0.36, 0.36, 0.99),
	3: Color(1.0, 0.76, 0.28, 1.0),
	4: Color(0.72, 0.52, 1.0, 1.0),
	5: Color(0.95, 0.96, 0.99, 1.0),
}

@onready var background_texture_rect: TextureRect = $BackgroundTextureRect
@onready var progression_overlay: ColorRect = $ProgressionOverlay
@onready var entry_fade_rect: ColorRect = $EntryFadeCanvasLayer/EntryFadeRect
@onready var menu_container_fx: MarginContainer = %MenuContainer
@onready var menu_buttons_box_container_fx: BoxContainer = %MenuButtonsBoxContainer
@onready var gem_particles: GPUParticles2D = $GemCanvasLayer/GemParticles

var _progress := 0.0
var _base_menu_y := 0.0
var _breathing_time := 0.0


func _ready() -> void:
	super._ready()
	Hud.hide_hud()
	_base_menu_y = menu_container_fx.position.y
	_progress = _resolve_progress()
	_configure_gem_sparkle_particles()
	_update_effect_layout()
	_apply_color_progression(_progress)
	_apply_gem_particles_style(_progress)
	if gem_particles != null:
		gem_particles.emitting = true
	_play_entry_fade()
	menu_buttons_box_container_fx.focus_first()
	set_process(breathing_enabled)


func _process(delta: float) -> void:
	if not breathing_enabled:
		return

	_breathing_time += delta * breathing_speed
	menu_container_fx.position.y = _base_menu_y + sin(_breathing_time) * breathing_amplitude


func _input(event: InputEvent) -> void:
	# Debug input is disabled - levels are set directly by scene load
	pass


func _on_level_changed() -> void:
	_progress = _resolve_progress()
	_apply_color_progression(_progress)


func _resolve_progress() -> float:
	var game_state := _get_game_state()
	if game_state == null:
		return 0.0

	var denominator := float(max(1, max_level))
	return clamp(float(game_state.current_level) / denominator, 0.0, 1.0)


func _apply_color_progression(progress: float) -> void:
	# Solo afecta fondo y capas de ambientacion para preservar legibilidad de texto.
	background_texture_rect.modulate = grayscale_background_color.lerp(Color(1, 1, 1, 1), progress)
	progression_overlay.color.a = lerp(overlay_base_alpha, overlay_min_alpha, progress)
	_apply_gem_particles_style(progress)
	_apply_button_color_progression()


func _apply_gem_particles_style(progress: float) -> void:
	if gem_particles == null:
		return
	var desaturated := Color(0.74, 0.78, 0.88, 0.24)
	var energized := Color(0.86, 0.93, 0.98, 0.38)
	gem_particles.modulate = desaturated.lerp(energized, progress)
	gem_particles.amount = int(120 + progress * 95.0)
	gem_particles.speed_scale = lerpf(0.7, 1.35, progress)
	var mat := gem_particles.process_material as ParticleProcessMaterial
	if mat != null:
		mat.initial_velocity_min = lerpf(8.0, 20.0, progress)
		mat.initial_velocity_max = lerpf(22.0, 48.0, progress)
		mat.scale_min = lerpf(0.22, 0.28, progress)
		mat.scale_max = lerpf(0.58, 0.76, progress)


func _apply_button_color_progression() -> void:
	var level := _resolve_current_level()
	var normal_color: Color = BUTTON_LEVEL_NORMAL_COLORS.get(level, BUTTON_LEVEL_NORMAL_COLORS[1])
	var focus_color := normal_color.lerp(Color(1, 1, 1, 1), 0.3)

	for child in menu_buttons_box_container_fx.get_children():
		if child is Button:
			if child.has_method("set_level_colors"):
				child.set_level_colors(normal_color, focus_color)
			else:
				child.add_theme_color_override("font_color", normal_color)
				child.add_theme_color_override("font_focus_color", focus_color)
				child.add_theme_color_override("font_hover_color", focus_color)


func _resolve_current_level() -> int:
	var game_state := _get_game_state()
	if game_state == null:
		return 0
	return clampi(int(game_state.current_level), 0, max_level)


func _configure_gem_sparkle_particles() -> void:
	if gem_particles == null:
		return

	gem_particles.local_coords = false
	gem_particles.one_shot = false
	gem_particles.explosiveness = 0.0
	gem_particles.randomness = 0.8

	var mat := gem_particles.process_material as ParticleProcessMaterial
	if mat == null:
		mat = ParticleProcessMaterial.new()
		gem_particles.process_material = mat

	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.gravity = Vector3(0, -6.0, 0)
	mat.scale_min = 0.2
	mat.scale_max = 0.65
	mat.angular_velocity_min = -22.0
	mat.angular_velocity_max = 22.0
	mat.damping_min = 3.0
	mat.damping_max = 8.0

	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.2, 0.65, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 0.0),
		Color(1.0, 1.0, 1.0, 0.8),
		Color(0.95, 0.99, 1.0, 0.45),
		Color(1, 1, 1, 0.0),
	])
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	mat.color_ramp = ramp

	# Rombo procedural para que cada particula se lea como "brillo de gema".
	var size: int = 12
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center: float = float(size - 1) * 0.5
	for y in range(size):
		for x in range(size):
			var dx: float = absf(float(x) - center)
			var dy: float = absf(float(y) - center)
			var d: float = (dx + dy) / center
			if d <= 1.0:
				var alpha: float = pow(1.0 - d, 1.35)
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	gem_particles.texture = ImageTexture.create_from_image(image)


func _play_entry_fade() -> void:
	entry_fade_rect.color = Color(0, 0, 0, 1)
	entry_fade_rect.show()
	var fade_tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fade_tween.tween_property(entry_fade_rect, "color:a", 0.0, 1.0)
	fade_tween.finished.connect(func() -> void:
		entry_fade_rect.hide()
	, CONNECT_ONE_SHOT)


func _update_effect_layout() -> void:
	if gem_particles == null:
		return
	var viewport_size := get_viewport_rect().size
	gem_particles.position = viewport_size * 0.5
	gem_particles.visibility_rect = Rect2(-viewport_size * 0.5, viewport_size)
	gem_particles.lifetime = 2.6
	var mat := gem_particles.process_material as ParticleProcessMaterial
	if mat != null:
		mat.emission_box_extents = Vector3(viewport_size.x * 0.42, viewport_size.y * 0.24, 0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_effect_layout()


func _get_game_state() -> Node:
	if has_node("/root/GameState"):
		return get_node("/root/GameState")
	return null
