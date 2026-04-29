class_name MenuProgressionHelper

const GEM_SHADER_CODE := """
shader_type canvas_item;

uniform vec4 base_tint : source_color = vec4(0.75, 0.85, 1.0, 1.0);
uniform vec4 accent_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	float wave = sin((UV.x * 24.0) + (UV.y * 9.0) + (TIME * 2.0)) * 0.5 + 0.5;
	float glint = smoothstep(0.83, 1.0, sin((UV.x * 40.0) - (UV.y * 12.0) + (TIME * 3.3)) * 0.5 + 0.5);
	vec3 gem = mix(base_tint.rgb, accent_tint.rgb, wave * 0.55);
	gem += vec3(0.28, 0.28, 0.28) * glint;
	COLOR = vec4(COLOR.rgb * gem, COLOR.a);
}
"""

const BUTTON_LEVEL_NORMAL_COLORS := {
	0: Color(0.74, 0.78, 0.88, 0.95),
	1: Color(0.72, 0.88, 1.0, 0.98),
	2: Color(0.95, 0.36, 0.36, 0.99),
	3: Color(1.0, 0.76, 0.28, 1.0),
	4: Color(0.72, 0.52, 1.0, 1.0),
	5: Color(0.95, 0.96, 0.99, 1.0),
}

static func resolve_progress(max_level: int = 5) -> float:
	if GameState == null:
		return 0.0
	var denom := float(max(1, max_level))
	return clamp(float(GameState.current_level) / denom, 0.0, 1.0)

static func apply_progress_to_node(root: Node, max_level: int = 5, overlay_min_alpha: float = 0.12, overlay_base_alpha: float = 0.55) -> void:
	var progress := resolve_progress(max_level)
	# Background texture - search recursively for BackgroundTextureRect
	var tex = root.find_child("BackgroundTextureRect", true, false)
	if tex is TextureRect:
		tex.modulate = Color(0.42, 0.44, 0.5, 1.0).lerp(Color(1, 1, 1, 1), progress)
	# Overlay - search recursively
	var po = root.find_child("ProgressionOverlay", true, false)
	if po is ColorRect:
		po.color.a = lerp(overlay_base_alpha, overlay_min_alpha, progress)
	var bo = root.find_child("BackgroundOverlay", true, false)
	if bo is ColorRect:
		bo.color.a = lerp(overlay_base_alpha, overlay_min_alpha, progress)
	# Gem particles - search recursively
	if root.has_node("GemCanvasLayer/GemParticles"):
		var gp = root.get_node("GemCanvasLayer/GemParticles")
		if gp is GPUParticles2D:
			_configure_gem_particles(gp)
			var desat := Color(0.74, 0.78, 0.88, 0.24)
			var energ := Color(0.86, 0.93, 0.98, 0.38)
			gp.modulate = desat.lerp(energ, progress)
			gp.amount = int(120 + progress * 95.0)
			gp.speed_scale = lerpf(0.7, 1.35, progress)
			var mat := gp.process_material as ParticleProcessMaterial
			if mat != null:
				mat.initial_velocity_min = lerpf(8.0, 20.0, progress)
				mat.initial_velocity_max = lerpf(22.0, 48.0, progress)
				mat.scale_min = lerpf(0.22, 0.28, progress)
				mat.scale_max = lerpf(0.58, 0.76, progress)
	# Buttons - search recursively for all Button nodes
	if GameState == null:
		return
	var level: int = int(clampi(GameState.current_level, 0, max_level))
	var normal_color: Color = BUTTON_LEVEL_NORMAL_COLORS.get(level, BUTTON_LEVEL_NORMAL_COLORS[0]) as Color
	var focus_color: Color = normal_color.lerp(Color(1, 1, 1, 1), 0.3)
	var bg_color: Color = normal_color.lerp(Color(0, 0, 0, 0), 0.75)  # Oscuro 75% hacia negro
	var focus_bg_color: Color = normal_color.lerp(Color(0, 0, 0, 0), 0.6)  # Un poco más claro
	var pressed_bg_color: Color = normal_color.lerp(Color(0, 0, 0, 0), 0.85)  # Más oscuro para pressed
	
	var buttons = root.find_children("*", "Button", true, false)
	for btn in buttons:
		if btn is Button and btn.visible:
			# Text colors
			if btn.has_method("set_level_colors"):
				btn.set_level_colors(normal_color, focus_color)
			else:
				btn.add_theme_color_override("font_color", normal_color)
				btn.add_theme_color_override("font_focus_color", focus_color)
				btn.add_theme_color_override("font_hover_color", focus_color)
			_apply_gem_material(btn, normal_color, focus_color)
			_apply_button_background_styles(btn, bg_color, focus_bg_color, pressed_bg_color)

	var labels = root.find_children("*", "Label", true, false)
	for label in labels:
		if label is Label and label.visible:
			_apply_gem_material(label, normal_color, focus_color)

static func _apply_button_background_styles(btn: Button, normal_bg: Color, focus_bg: Color, pressed_bg: Color) -> void:
	"""Aplica estilos de fondo dinámicos a un botón basados en colores del nivel"""
	# Normal state
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = normal_bg
	normal_style.border_width_left = 2
	normal_style.border_width_top = 2
	normal_style.border_width_right = 2
	normal_style.border_width_bottom = 2
	normal_style.border_color = Color(1, 1, 1, 0.3)
	normal_style.corner_radius_top_left = 4
	normal_style.corner_radius_top_right = 4
	normal_style.corner_radius_bottom_right = 4
	normal_style.corner_radius_bottom_left = 4
	normal_style.content_margin_left = 8
	normal_style.content_margin_top = 8
	normal_style.content_margin_right = 8
	normal_style.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", normal_style)
	
	# Focus state
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = focus_bg
	focus_style.border_width_left = 3
	focus_style.border_width_top = 3
	focus_style.border_width_right = 3
	focus_style.border_width_bottom = 3
	focus_style.border_color = Color(1, 1, 1, 0.6)
	focus_style.corner_radius_top_left = 4
	focus_style.corner_radius_top_right = 4
	focus_style.corner_radius_bottom_right = 4
	focus_style.corner_radius_bottom_left = 4
	focus_style.content_margin_left = 8
	focus_style.content_margin_top = 8
	focus_style.content_margin_right = 8
	focus_style.content_margin_bottom = 8
	btn.add_theme_stylebox_override("focus", focus_style)
	
	# Pressed state
	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = pressed_bg
	pressed_style.border_width_left = 2
	pressed_style.border_width_top = 2
	pressed_style.border_width_right = 2
	pressed_style.border_width_bottom = 2
	pressed_style.border_color = Color(1, 1, 1, 0.4)
	pressed_style.corner_radius_top_left = 4
	pressed_style.corner_radius_top_right = 4
	pressed_style.corner_radius_bottom_right = 4
	pressed_style.corner_radius_bottom_left = 4
	pressed_style.content_margin_left = 8
	pressed_style.content_margin_top = 8
	pressed_style.content_margin_right = 8
	pressed_style.content_margin_bottom = 8
	btn.add_theme_stylebox_override("pressed", pressed_style)
	
	# Hover state
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = focus_bg
	hover_style.border_width_left = 2
	hover_style.border_width_top = 2
	hover_style.border_width_right = 2
	hover_style.border_width_bottom = 2
	hover_style.border_color = Color(1, 1, 1, 0.5)
	hover_style.corner_radius_top_left = 4
	hover_style.corner_radius_top_right = 4
	hover_style.corner_radius_bottom_right = 4
	hover_style.corner_radius_bottom_left = 4
	hover_style.content_margin_left = 8
	hover_style.content_margin_top = 8
	hover_style.content_margin_right = 8
	hover_style.content_margin_bottom = 8
	btn.add_theme_stylebox_override("hover", hover_style)
	
	# Disabled state
	var disabled_style := StyleBoxFlat.new()
	disabled_style.bg_color = Color(0.5, 0.5, 0.5, 0.4)
	disabled_style.border_width_left = 2
	disabled_style.border_width_top = 2
	disabled_style.border_width_right = 2
	disabled_style.border_width_bottom = 2
	disabled_style.border_color = Color(1, 1, 1, 0.2)
	disabled_style.corner_radius_top_left = 4
	disabled_style.corner_radius_top_right = 4
	disabled_style.corner_radius_bottom_right = 4
	disabled_style.corner_radius_bottom_left = 4
	disabled_style.content_margin_left = 8
	disabled_style.content_margin_top = 8
	disabled_style.content_margin_right = 8
	disabled_style.content_margin_bottom = 8
	btn.add_theme_stylebox_override("disabled", disabled_style)

static func _apply_gem_material(node: CanvasItem, normal_color: Color, focus_color: Color) -> void:
	if node == null:
		return
	var shader := Shader.new()
	shader.code = GEM_SHADER_CODE
	var gem_material := ShaderMaterial.new()
	gem_material.shader = shader
	gem_material.set_shader_parameter("base_tint", normal_color)
	gem_material.set_shader_parameter("accent_tint", focus_color.lerp(Color(1, 1, 1, 1), 0.2))
	node.material = gem_material

static func _configure_gem_particles(gem_particles: GPUParticles2D) -> void:
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
