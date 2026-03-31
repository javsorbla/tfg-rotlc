extends Area2D

const DARKNESS_FRAMES := preload("res://assets/enemies/bosses/umbra/oscuridad.tres")

var tick_damage := 1
var tick_interval := 0.45
var remaining_lifetime := 2.8
var arming_delay := 0.55

var _tick_timer := 0.0
var _arm_timer := 0.0
var _armed := false
var _visual: AnimatedSprite2D


func configure(damage: int, interval: float, lifetime: float, delay := 0.55) -> void:
	tick_damage = damage
	tick_interval = interval
	remaining_lifetime = lifetime
	arming_delay = delay


func _ready() -> void:
	monitoring = true
	monitorable = true
	collision_layer = 16
	collision_mask = 4
	_tick_timer = tick_interval
	_arm_timer = arming_delay
	_armed = arming_delay <= 0.0
	_setup_visual()


func _setup_visual() -> void:
	_visual = AnimatedSprite2D.new()
	_visual.name = "Visual"
	_visual.sprite_frames = DARKNESS_FRAMES
	_visual.animation = &"default"
	_visual.modulate = Color(1.0, 1.0, 1.0, 0.45)
	_visual.z_index = -1
	add_child(_visual)
	_visual.play()


func _physics_process(delta: float) -> void:
	remaining_lifetime -= delta
	if remaining_lifetime <= 0.0:
		queue_free()
		return

	if not _armed:
		_arm_timer -= delta
		if _arm_timer <= 0.0:
			_armed = true
			if _visual != null:
				_visual.modulate = Color(1.0, 1.0, 1.0, 0.82)
		return

	_tick_timer -= delta
	if _tick_timer > 0.0:
		return

	_tick_timer = tick_interval
	_apply_tick_damage()


func _apply_tick_damage() -> void:
	for area in get_overlapping_areas():
		if area.is_in_group("player_hurtbox"):
			var owner = area.get_parent()
			if owner and owner.has_method("get"):
				var health_node = owner.get("health")
				if health_node and health_node.has_method("take_damage"):
					health_node.take_damage(tick_damage)
