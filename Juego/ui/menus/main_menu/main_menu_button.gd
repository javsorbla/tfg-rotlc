extends Button

@onready var arrow: TextureRect = $Arrow
@export var normal_font_color: Color = Color(0.82, 0.82, 0.82, 0.92)
@export var focus_font_color: Color = Color(1, 1, 1, 1)
@export_range(0.05, 0.4, 0.01) var arrow_duration := 0.15
@export_range(2.0, 32.0, 1.0) var arrow_slide_distance := 12.0

var _arrow_tween: Tween
var _arrow_base_position := Vector2.ZERO
var _is_hovered := false
var _highlighted := false
var _gem_time := 0.0
var _gem_material: ShaderMaterial

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	_arrow_base_position = arrow.position
	arrow.visible = false
	arrow.modulate.a = 0.0
	_setup_gem_material()

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(_on_focus_changed)
	focus_exited.connect(_on_focus_changed)

	_apply_text_state(false)
	set_process(true)


func _process(delta: float) -> void:
	if _gem_material == null:
		return
	_gem_time += delta
	_gem_material.set_shader_parameter("time", _gem_time)


func _on_mouse_entered() -> void:
	_is_hovered = true
	_update_highlight_state()


func _on_mouse_exited() -> void:
	_is_hovered = false
	_update_highlight_state()


func _on_focus_changed() -> void:
	_update_highlight_state()


func _update_highlight_state() -> void:
	var target_state := _is_hovered or has_focus()
	if target_state == _highlighted:
		return

	_highlighted = target_state
	_apply_text_state(_highlighted)
	_animate_arrow(_highlighted)


func _apply_text_state(active: bool) -> void:
	if active:
		add_theme_color_override("font_color", focus_font_color)
	else:
		add_theme_color_override("font_color", normal_font_color)
	_update_gem_material_colors()


func set_level_colors(normal_color: Color, focus_color: Color) -> void:
	normal_font_color = normal_color
	focus_font_color = focus_color
	_apply_text_state(_highlighted)


func _setup_gem_material() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec4 base_tint : source_color = vec4(0.75, 0.85, 1.0, 1.0);
uniform vec4 accent_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float time = 0.0;

void fragment() {
	float wave = sin((UV.x * 24.0) + (UV.y * 9.0) + (time * 2.0)) * 0.5 + 0.5;
	float glint = smoothstep(0.83, 1.0, sin((UV.x * 40.0) - (UV.y * 12.0) + (time * 3.3)) * 0.5 + 0.5);
	vec3 gem = mix(base_tint.rgb, accent_tint.rgb, wave * 0.55);
	gem += vec3(0.28, 0.28, 0.28) * glint;
	COLOR = vec4(COLOR.rgb * gem, COLOR.a);
}
"""
	_gem_material = ShaderMaterial.new()
	_gem_material.shader = shader
	material = _gem_material
	_update_gem_material_colors()


func _update_gem_material_colors() -> void:
	if _gem_material == null:
		return
	var accent := focus_font_color.lerp(Color(1, 1, 1, 1), 0.2)
	_gem_material.set_shader_parameter("base_tint", normal_font_color)
	_gem_material.set_shader_parameter("accent_tint", accent)


func _animate_arrow(show: bool) -> void:
	if _arrow_tween != null and _arrow_tween.is_running():
		_arrow_tween.kill()

	_arrow_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var hidden_position := _arrow_base_position + Vector2(-arrow_slide_distance, 0)

	if show:
		arrow.visible = true
		arrow.position = hidden_position
		arrow.modulate.a = 0.0
		_arrow_tween.parallel().tween_property(arrow, "position", _arrow_base_position, arrow_duration)
		_arrow_tween.parallel().tween_property(arrow, "modulate:a", 1.0, arrow_duration)
		return

	arrow.visible = true
	_arrow_tween.parallel().tween_property(arrow, "position", hidden_position, arrow_duration)
	_arrow_tween.parallel().tween_property(arrow, "modulate:a", 0.0, arrow_duration)
	_arrow_tween.finished.connect(_on_hide_tween_finished, CONNECT_ONE_SHOT)


func _on_hide_tween_finished() -> void:
	if _highlighted:
		return
	arrow.visible = false
	arrow.position = _arrow_base_position
