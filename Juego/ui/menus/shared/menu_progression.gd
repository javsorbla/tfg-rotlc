class_name MenuProgressionHelper

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
    var buttons = root.find_children("*", "Button", true, false)
    for btn in buttons:
        if btn is Button and btn.visible:
            if btn.has_method("set_level_colors"):
                btn.set_level_colors(normal_color, focus_color)
            else:
                btn.add_theme_color_override("font_color", normal_color)
                btn.add_theme_color_override("font_focus_color", focus_color)
                btn.add_theme_color_override("font_hover_color", focus_color)

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
