extends LoadingScreen

@onready var progress_bar: ProgressBar = %ProgressBar

# 0 = normal bar, 1 = slow final progress, 2 = bottom-right dot spinner
@export var loading_ui_style: int = 2 :
	set(value):
		loading_ui_style = clampi(value, 0, 2)

const SPINNER_DOT_COUNT := 5
const SPINNER_SIZE := Vector2(120, 120)
const SPINNER_MARGIN := 28.0
const SPINNER_ANIMATION_SPEED := 2.2

var _spinner_root: Control = null
var _spinner_dots: Array[TextureRect] = []
var _spinner_time := 0.0

func _ready() -> void:
	_apply_progress_bar_style()
	
	if loading_ui_style == 2:
		_setup_spinner()
	
	# Wait one frame before applying progression
	await get_tree().process_frame
	MenuProgressionHelper.apply_progress_to_node(self)

func _apply_progress_bar_style() -> void:
	if progress_bar == null:
		return

	var level := 0
	if has_node("/root/GameState"):
		level = clampi(int(GameState.current_level), 0, 5)

	var normal_color: Color = MenuProgressionHelper.BUTTON_LEVEL_NORMAL_COLORS.get(level, MenuProgressionHelper.BUTTON_LEVEL_NORMAL_COLORS[0])
	var accent_color := normal_color.lerp(Color(1, 1, 1, 1), 0.35)
	var dark_color := normal_color.lerp(Color(0.05, 0.06, 0.09, 1.0), 0.82)

	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.04, 0.05, 0.08, 0.88)
	background.border_width_left = 2
	background.border_width_top = 2
	background.border_width_right = 2
	background.border_width_bottom = 2
	background.border_color = dark_color
	background.corner_radius_top_left = 8
	background.corner_radius_top_right = 8
	background.corner_radius_bottom_left = 8
	background.corner_radius_bottom_right = 8
	background.content_margin_left = 4
	background.content_margin_top = 4
	background.content_margin_right = 4
	background.content_margin_bottom = 4
	progress_bar.add_theme_stylebox_override("background", background)

	var fill := StyleBoxFlat.new()
	fill.bg_color = normal_color
	fill.border_width_left = 1
	fill.border_width_top = 1
	fill.border_width_right = 1
	fill.border_width_bottom = 1
	fill.border_color = accent_color
	fill.corner_radius_top_left = 8
	fill.corner_radius_top_right = 8
	fill.corner_radius_bottom_left = 8
	fill.corner_radius_bottom_right = 8
	fill.content_margin_left = 0
	fill.content_margin_top = 0
	fill.content_margin_right = 0
	fill.content_margin_bottom = 0
	progress_bar.add_theme_stylebox_override("fill", fill)

	progress_bar.add_theme_color_override("font_color", accent_color)
	progress_bar.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	progress_bar.add_theme_constant_override("outline_size", 2)
	
	if loading_ui_style == 2:
		progress_bar.visible = false

func _setup_spinner() -> void:
	if progress_bar == null:
		return
	var root := get_node_or_null("Control") as Control
	if root == null:
		return

	_spinner_root = root.get_node_or_null("LoadingSpinner") as Control
	if _spinner_root != null:
		return

	var level := 0
	if has_node("/root/GameState"):
		level = clampi(int(GameState.current_level), 0, 5)
	var normal_color: Color = MenuProgressionHelper.BUTTON_LEVEL_NORMAL_COLORS.get(level, MenuProgressionHelper.BUTTON_LEVEL_NORMAL_COLORS[0])
	var accent_color := normal_color.lerp(Color(1, 1, 1, 1), 0.35)

	var dot_texture := _create_spinner_dot_texture(accent_color)

	_spinner_root = Control.new()
	_spinner_root.name = "LoadingSpinner"
	_spinner_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spinner_root.custom_minimum_size = SPINNER_SIZE
	_spinner_root.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_spinner_root.offset_left = -SPINNER_SIZE.x - SPINNER_MARGIN
	_spinner_root.offset_top = -SPINNER_SIZE.y - SPINNER_MARGIN
	_spinner_root.offset_right = -SPINNER_MARGIN
	_spinner_root.offset_bottom = -SPINNER_MARGIN
	root.add_child(_spinner_root)

	_spinner_dots.clear()
	var center := SPINNER_SIZE * 0.5
	var radius := 30.0
	for i in range(SPINNER_DOT_COUNT):
		var dot := TextureRect.new()
		dot.name = "Dot%d" % i
		dot.texture = dot_texture
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		dot.custom_minimum_size = Vector2(16, 16)
		dot.size = Vector2(16, 16)
		var angle := TAU * float(i) / float(SPINNER_DOT_COUNT)
		dot.position = center + Vector2(cos(angle), sin(angle)) * radius - dot.size * 0.5
		dot.modulate = Color(1, 1, 1, 0.2)
		_spinner_root.add_child(dot)
		_spinner_dots.append(dot)

	progress_bar.visible = false


func _create_spinner_dot_texture(color: Color) -> Texture2D:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in range(8):
		for x in range(8):
			var dx := float(x) - 3.5
			var dy := float(y) - 3.5
			var distance := sqrt(dx * dx + dy * dy)
			if distance <= 3.2:
				var alpha := clampf(1.0 - (distance / 3.2), 0.0, 1.0)
				image.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))
	return ImageTexture.create_from_image(image)

func _process(delta: float) -> void:
	super._process(delta)

	if loading_ui_style == 2 and _spinner_root != null and not _spinner_dots.is_empty():
		_spinner_time += delta * SPINNER_ANIMATION_SPEED
		var phase := fposmod(_spinner_time, 1.0)
		var level := 0
		if has_node("/root/GameState"):
			level = clampi(int(GameState.current_level), 0, 5)
		var normal_color: Color = MenuProgressionHelper.BUTTON_LEVEL_NORMAL_COLORS.get(level, MenuProgressionHelper.BUTTON_LEVEL_NORMAL_COLORS[0])
		var accent_color := normal_color.lerp(Color(1, 1, 1, 1), 0.35)
		for i in range(_spinner_dots.size()):
			var offset := float(i) / float(_spinner_dots.size())
			var dot_phase := fposmod(phase + offset, 1.0)
			var intensity := pow(1.0 - dot_phase, 2.0)
			var tint := normal_color.lerp(accent_color, intensity)
			_spinner_dots[i].modulate = Color(tint.r, tint.g, tint.b, lerpf(0.28, 1.0, intensity))
	
	if loading_ui_style == 1 and progress_bar.visible:
		var current_progress := progress_bar.value
		if current_progress >= 0.95 and current_progress < 1.0:
			progress_bar.value = minf(0.995, current_progress + delta * 0.16)
