extends Node

const UMBRA_SHADER := preload("res://enemies/bosses/umbra/Umbra.gdshader")

const TINT_CYAN_PRIMARY := Color(0.0, 0.85, 1.0, 1.0)
const TINT_RED_PRIMARY := Color(1.0, 0.2, 0.2, 1.0)
const TINT_YELLOW_PRIMARY := Color(1.0, 0.9, 0.0, 1.0)

@onready var umbra = get_parent()
@onready var sprite: AnimatedSprite2D = umbra.get_node("AnimatedSprite2D")


func setup() -> void:
	_ensure_visual_shader()


func process_timers(delta: float) -> void:
	if umbra._power_cooldown_timer > 0.0:
		umbra._power_cooldown_timer -= delta
	if umbra._power_active:
		umbra._power_timer -= delta
		if umbra._power_timer <= 0.0:
			umbra._power_active = false
			umbra._power_cooldown_timer = _get_power_cooldown(umbra.current_power)


func handle_power() -> void:
	if umbra.ai_should_use_power and not umbra._power_active and umbra._power_cooldown_timer <= 0.0:
		umbra._power_active = true
		umbra._power_timer = _get_power_duration(umbra.current_power)

	if umbra.current_power == "yellow" and _is_power_active():
		umbra.is_invincible = true
		umbra.hurtbox.monitorable = false
	elif umbra.current_power == "yellow" and not _is_power_active():
		if umbra.invincibility_timer <= 0.0:
			umbra.is_invincible = false
			umbra.hurtbox.monitorable = true


func _is_power_active() -> bool:
	return umbra._power_active


func get_speed() -> float:
	if umbra.current_power == "cyan" and _is_power_active():
		return umbra.SPEED * umbra.POWER_SPEED_MULTIPLIER
	return umbra.SPEED


func _get_power_duration(power_name: String) -> float:
	match power_name:
		"cyan":
			return umbra.power_duration_cyan
		"red":
			return umbra.power_duration_red
		"yellow":
			return umbra.power_duration_yellow
		_:
			return 0.0


func _get_power_cooldown(power_name: String) -> float:
	match power_name:
		"cyan":
			return umbra.power_cooldown_cyan * umbra._power_cooldown_scale
		"red":
			return umbra.power_cooldown_red * umbra._power_cooldown_scale
		"yellow":
			return umbra.power_cooldown_yellow * umbra._power_cooldown_scale
		_:
			return 0.0


func get_attack_damage() -> int:
	if umbra.current_power == "red" and _is_power_active():
		return int(umbra.DAMAGE * umbra.POWER_DAMAGE_MULTIPLIER)
	return umbra.DAMAGE


func _ensure_visual_shader() -> void:
	if sprite == null:
		return

	var material := sprite.material as ShaderMaterial
	if material == null:
		material = ShaderMaterial.new()
		material.shader = UMBRA_SHADER
		sprite.material = material
	elif material.shader == null:
		material.shader = UMBRA_SHADER


func update_power_visuals() -> void:
	var material := sprite.material as ShaderMaterial
	if material == null:
		return

	if not _is_power_active():
		material.set_shader_parameter("power_strength", 0.0)
		return

	var tint := Color(1.0, 1.0, 1.0, 1.0)
	match umbra.current_power:
		"cyan":
			tint = TINT_CYAN_PRIMARY
		"red":
			tint = TINT_RED_PRIMARY
		"yellow":
			tint = TINT_YELLOW_PRIMARY

	material.set_shader_parameter("power_tint", tint)
	material.set_shader_parameter("power_strength", 0.78)
